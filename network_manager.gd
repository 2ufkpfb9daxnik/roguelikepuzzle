extends Node

## 通信対戦用のWebSocketクライアント。
## Cloudflare Workers + Durable Objects のルームサーバーに接続する。

signal connection_opened
signal connection_closed(code: int, reason: String)
signal welcome_received(data: Dictionary)
signal room_updated(room: Dictionary)
signal match_started(data: Dictionary)
signal turn_started(data: Dictionary)
signal action_received(from: int, payload: Dictionary)
signal phase_updated(data: Dictionary)
signal shop_started(data: Dictionary)
signal shop_ended(data: Dictionary)
signal stats_received(from: int, stats: Dictionary)
signal match_ended(data: Dictionary)
signal turn_timed_out(data: Dictionary)
signal shop_timed_out(data: Dictionary)
signal opponent_disconnected(data: Dictionary)
signal match_resumed(data: Dictionary)
signal network_error(message: String)
signal reconnecting(attempt: int, max_attempts: int)

const MAX_RECONNECT_ATTEMPTS: int = 5
const RECONNECT_DELAY_SEC: float = 2.0

# デプロイ後にCloudflare WorkersのURLへ変更してください。
const DEFAULT_SERVER_URL: String = "wss://roguelike-puzzle-online.roguelikepuzzle1120.workers.dev"

var server_url: String = DEFAULT_SERVER_URL
var room_code: String = ""
var player_name: String = ""
var player_index: int = -1
var reconnect_token: String = ""
var pvp_mode: bool = false
var my_player_id: String = ""      # レーティング用プレイヤーID
var opponent_player_id: String = "" # レーティング用対戦相手ID

var room: Dictionary = {}
var rules: Dictionary = {}
var match_data: Dictionary = {}
var last_turn: Dictionary = {}
var last_shop: Dictionary = {}
var last_stats: Dictionary = { 0: {}, 1: {} }
var server_time_offset_ms: int = 0

var _socket: WebSocketPeer = null
var _is_open: bool = false
var _connecting: bool = false
var _last_url: String = ""
var _intentional_close: bool = false
var _ping_timer: float = 0.0
const PING_INTERVAL_SEC: float = 25.0
var _reconnect_attempts: int = 0
var _reconnect_timer: float = 0.0
var _reconnect_enabled: bool = false

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if _reconnect_timer > 0.0 and not _is_open:
		_reconnect_timer = maxf(0.0, _reconnect_timer - delta)
		if _reconnect_timer <= 0.0 and _reconnect_enabled and _reconnect_attempts > 0:
			_connect()

	if _socket == null:
		return

	# iOS Safari等でのクラッシュ防止のため例外処理
	_socket.poll()
	var state: int = _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _is_open:
			_is_open = true
			_connecting = false
			_reconnect_attempts = 0
			_reconnect_timer = 0.0
			_ping_timer = 0.0
			connection_opened.emit()
		# iOS Safari等での切断防止キープアライブ
		_ping_timer += delta
		if _ping_timer >= PING_INTERVAL_SEC:
			_ping_timer = 0.0
			send_ping()
		while _socket.get_available_packet_count() > 0:
			var packet: PackedByteArray = _socket.get_packet()
			_handle_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _is_open or _connecting:
			var code: int = _socket.get_close_code()
			var reason: String = _socket.get_close_reason()
			_is_open = false
			_connecting = false
			_socket = null

			var can_reconnect: bool = _reconnect_enabled and not _intentional_close \
				and not room_code.is_empty() and _reconnect_attempts < MAX_RECONNECT_ATTEMPTS
			if can_reconnect:
				_reconnect_attempts += 1
				_reconnect_timer = RECONNECT_DELAY_SEC
				reconnecting.emit(_reconnect_attempts, MAX_RECONNECT_ATTEMPTS)
			else:
				connection_closed.emit(code, reason)

func is_connected_to_room() -> bool:
	return _is_open and _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func create_room(name: String, code: String = "") -> String:
	player_name = name
	room_code = code.strip_edges().to_upper()
	if room_code.is_empty():
		room_code = _generate_room_code()
	reconnect_token = ""
	player_index = -1
	_intentional_close = false
	_reconnect_enabled = true
	_reconnect_attempts = 0
	_reconnect_timer = 0.0
	_connect()
	return room_code

func join_room(code: String, name: String) -> void:
	player_name = name
	room_code = code.strip_edges().to_upper()
	reconnect_token = ""
	player_index = -1
	_intentional_close = false
	_reconnect_enabled = true
	_reconnect_attempts = 0
	_reconnect_timer = 0.0
	_connect()

func reconnect() -> void:
	if room_code.is_empty():
		network_error.emit("再接続するルームがありません")
		return
	_intentional_close = false
	_reconnect_enabled = true
	_reconnect_attempts = 0
	_reconnect_timer = 0.0
	_connect()

func _connect() -> void:
	if _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.close()
	_socket = WebSocketPeer.new()
	_is_open = false
	_connecting = true

	var base: String = server_url.strip_edges().rstrip("/")
	if base.begins_with("https://"):
		base = "wss://" + base.substr(8)
	elif base.begins_with("http://"):
		base = "ws://" + base.substr(7)
	if base.is_empty() or base.contains("YOUR-WORKER"):
		_connecting = false
		network_error.emit("サーバーURLが設定されていません")
		return

	var url: String = "%s/room/%s?name=%s" % [
		base,
		room_code.uri_encode(),
		player_name.uri_encode()
	]
	if not reconnect_token.is_empty():
		url += "&token=" + reconnect_token.uri_encode()

	_last_url = url
	var err: int = _socket.connect_to_url(url)
	if err != OK:
		_connecting = false
		network_error.emit("接続に失敗しました (error %d)" % err)

func close() -> void:
	_intentional_close = true
	_reconnect_enabled = false
	_reconnect_timer = 0.0
	if _socket != null:
		_socket.close()
	_socket = null
	_is_open = false
	_connecting = false

func send_ready() -> bool:
	return _send({ "type": "ready" })

func send_character(character_id: String) -> bool:
	return _send({ "type": "select_character", "character": character_id })

func send_action(payload: Dictionary) -> bool:
	return _send({ "type": "action", "payload": payload })

func send_move_started() -> bool:
	return _send({ "type": "move_started" })

func send_end_turn() -> bool:
	return _send({ "type": "end_turn" })

func send_stats(stats: Dictionary) -> bool:
	return _send({ "type": "stats", "payload": stats })

func send_shop_choice(choice: Dictionary) -> bool:
	return _send({ "type": "shop_choice", "payload": choice })

func send_shop_done() -> bool:
	return _send({ "type": "shop_done" })

func send_surrender() -> bool:
	return _send({ "type": "surrender" })

## デバッグ用: 指定ターンへ強制ジャンプ（オンライン対戦のみ）
func debug_jump_turn(turn_number: int = 5) -> bool:
	return _send({ "type": "debug_jump", "turnNumber": maxi(1, turn_number) })

## デバッグ用: 指定ラウンドのショップ（レリック選択）を直接開く（オンライン対戦のみ）
func debug_open_shop(round_number: int = 5) -> bool:
	return _send({ "type": "debug_shop", "round": maxi(1, round_number) })

func send_ping() -> bool:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return _socket.send_text(JSON.stringify({"type": "ping"})) == OK

func _send(data: Dictionary) -> bool:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		network_error.emit("通信が接続されていません")
		return false
	return _socket.send_text(JSON.stringify(data)) == OK

func _handle_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	var msg_type: String = str(data.get("type", ""))
	if data.has("serverNow"):
		_update_server_time(int(data["serverNow"]))

	match msg_type:
		"welcome":
			player_index = int(data.get("player", -1))
			reconnect_token = str(data.get("token", ""))
			room = data.get("room", {})
			rules = data.get("rules", {})
			welcome_received.emit(data)
			room_updated.emit(room)
		"room_updated":
			room = data.get("room", room)
			room_updated.emit(room)
		"match_start":
			match_data = data
			rules = data.get("rules", rules)
			last_stats = { 0: {}, 1: {} }
			var max_hp: int = int(rules.get("maxHp", 5000))
			var coins: int = int(rules.get("startCoins", 0))
			for i in range(2):
				last_stats[i] = { "hp": max_hp, "maxHp": max_hp, "shield": 0, "coins": coins }
			match_started.emit(data)
		"turn_start":
			last_turn = data
			last_shop = {}
			turn_started.emit(data)
		"action":
			action_received.emit(int(data.get("from", 0)), data.get("payload", {}))
		"phase_updated":
			if not last_turn.is_empty():
				last_turn["phase"] = data.get("phase", last_turn.get("phase", ""))
				last_turn["deadline"] = data.get("deadline", last_turn.get("deadline", 0))
			phase_updated.emit(data)
		"stats":
			var from: int = int(data.get("from", 0))
			var stats: Dictionary = data.get("stats", {})
			last_stats[from] = stats
			stats_received.emit(from, stats)
		"shop_start":
			last_shop = data
			shop_started.emit(data)
		"shop_end":
			last_shop = {}
			shop_ended.emit(data)
		"shop_choice":
			pass
		"shop_done":
			pass
		"turn_timeout":
			turn_timed_out.emit(data)
		"shop_timeout":
			shop_timed_out.emit(data)
		"opponent_disconnected":
			room = data.get("room", room)
			opponent_disconnected.emit(data)
		"resumed":
			if not last_turn.is_empty():
				last_turn["deadline"] = data.get("deadline", last_turn.get("deadline", 0))
			match_resumed.emit(data)
		"match_end":
			match_ended.emit(data)
		"pong":
			pass
		_:
			pass

func _update_server_time(server_now: int) -> void:
	var local_now: int = int(Time.get_unix_time_from_system() * 1000.0)
	server_time_offset_ms = server_now - local_now

func now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0) + server_time_offset_ms

func remaining_ms(deadline: int) -> int:
	if deadline <= 0:
		return 0
	return maxi(0, deadline - now_ms())

func _generate_room_code() -> String:
	const CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var result: String = ""
	for i in range(6):
		result += CHARS[randi() % CHARS.length()]
	return result

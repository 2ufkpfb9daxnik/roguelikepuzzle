extends Control

## フレンド対戦用のルーム作成・参加画面。

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")
const CharacterData = preload("res://character_data.gd")
const TITLE_SCENE = "res://title_screen.tscn"
const MATCH_SCENE = "res://current_stage.tscn"

var _net: Node = null
var _name_input: LineEdit = null
var _code_input: LineEdit = null
var _server_input: LineEdit = null
var _create_btn: Button = null
var _join_btn: Button = null
var _ready_btn: Button = null
var _back_btn: Button = null
var _status_lbl: Label = null
var _room_code_lbl: Label = null
var _players_lbl: Label = null
var _lobby_box: VBoxContainer = null

var _generated_code: String = ""
var _bgm: AudioStreamPlayer = null
var _selected_character: String = CharacterData.DEFAULT_ID
var _char_buttons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_net = get_node_or_null("/root/NetworkManager")
	_build_ui()
	_connect_network_signals()
	_start_bgm()

func _start_bgm() -> void:
	var stream = load("res://Sound/bgm/bgmnokouho/ending.wav")
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = stream
	_bgm.volume_db = -12.0
	_bgm.name = "OnlineBGM"
	add_child(_bgm)
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("enable_bgm_loop"):
		sm.enable_bgm_loop(_bgm)
	else:
		_bgm.finished.connect(func():
			if is_instance_valid(_bgm):
				_bgm.play()
		)
	_bgm.play()

func _connect_network_signals() -> void:
	if _net == null:
		_status_lbl.text = "NetworkManager が見つかりません"
		return
	_net.connection_opened.connect(_on_connection_opened)
	_net.connection_closed.connect(_on_connection_closed)
	_net.reconnecting.connect(_on_reconnecting)
	_net.welcome_received.connect(_on_welcome)
	_net.room_updated.connect(_on_room_updated)
	_net.match_started.connect(_on_match_started)
	_net.network_error.connect(_on_network_error)

func _make_font() -> Font:
	var f = load("res://font/NotoSansJP.ttf")
	f.set_fallbacks([load("res://font/NotoEmoji.ttf")])
	return f

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.012, 0.016, 0.028, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.04, 0.07, 0.96)
	panel_style.border_color = Color(1.0, 0.82, 0.25, 0.9)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0, 0, 0, 0.8)
	panel_style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var font = _make_font()

	var title = Label.new()
	title.text = "🌐 オンライン対戦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "ルームコードを共有してフレンドとターン制対戦"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", font)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90))
	box.add_child(subtitle)

	box.add_child(_make_spacer(8))
	box.add_child(_make_label("プレイヤー名", font, 18, Color(0.75, 0.82, 0.92)))
	_name_input = LineEdit.new()
	_name_input.text = "Player%d" % (randi() % 100)
	_name_input.custom_minimum_size = Vector2(0, 46)
	_name_input.add_theme_font_override("font", font)
	_name_input.add_theme_font_size_override("font_size", 24)
	box.add_child(_name_input)

	box.add_child(_make_label("キャラクター選択（全キャラクター）", font, 18, Color(0.75, 0.82, 0.92)))
	var char_scroll = ScrollContainer.new()
	char_scroll.custom_minimum_size = Vector2(0, 100)
	char_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(char_scroll)
	var char_box = GridContainer.new()
	char_box.columns = 4
	char_box.add_theme_constant_override("h_separation", 8)
	char_box.add_theme_constant_override("v_separation", 8)
	char_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_scroll.add_child(char_box)
	for cid in CharacterData.get_ids():
		var info: Dictionary = CharacterData.get_character(str(cid))
		var cbtn = _make_button(str(info.get("name", cid)), Color(0.08, 0.10, 0.16, 1.0), Color(0.45, 0.55, 0.75, 1.0), font)
		cbtn.custom_minimum_size = Vector2(0, 44)
		cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cbtn.add_theme_font_size_override("font_size", 13)
		if ResourceLoader.exists(str(info.get("texture", ""))):
			cbtn.icon = load(str(info["texture"]))
			cbtn.expand_icon = true
			cbtn.add_theme_constant_override("icon_max_width", 24)
		var chosen_id: String = str(cid)
		cbtn.pressed.connect(func(): _on_character_selected(chosen_id))
		char_box.add_child(cbtn)
		_char_buttons[chosen_id] = cbtn
	_update_character_buttons()

	box.add_child(_make_label("ルームコード（参加時）", font, 18, Color(0.75, 0.82, 0.92)))
	_code_input = LineEdit.new()
	_code_input.placeholder_text = "例: ABC123"
	_code_input.max_length = 8
	_code_input.custom_minimum_size = Vector2(0, 46)
	_code_input.add_theme_font_override("font", font)
	_code_input.add_theme_font_size_override("font_size", 24)
	box.add_child(_code_input)

	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	box.add_child(buttons)

	_create_btn = _make_button("部屋を作る", Color(0.12, 0.32, 0.22, 1.0), Color(0.4, 1.0, 0.7, 1.0), font)
	_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_btn.pressed.connect(_on_create_pressed)
	buttons.add_child(_create_btn)

	_join_btn = _make_button("コードで参加", Color(0.12, 0.20, 0.34, 1.0), Color(0.4, 0.78, 1.0, 1.0), font)
	_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_btn.pressed.connect(_on_join_pressed)
	buttons.add_child(_join_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "部屋を作るか、ルームコードで参加してください"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_lbl.add_theme_font_override("font", font)
	_status_lbl.add_theme_font_size_override("font_size", 18)
	_status_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(_status_lbl)

	_room_code_lbl = Label.new()
	_room_code_lbl.text = ""
	_room_code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_code_lbl.add_theme_font_override("font", font)
	_room_code_lbl.add_theme_font_size_override("font_size", 34)
	_room_code_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	box.add_child(_room_code_lbl)

	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 10)
	_lobby_box.visible = false
	box.add_child(_lobby_box)

	_players_lbl = Label.new()
	_players_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_players_lbl.add_theme_font_override("font", font)
	_players_lbl.add_theme_font_size_override("font_size", 19)
	_players_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	_lobby_box.add_child(_players_lbl)

	_ready_btn = _make_button("準備完了", Color(0.24, 0.18, 0.04, 1.0), Color(1.0, 0.84, 0.2, 1.0), font)
	_ready_btn.pressed.connect(_on_ready_pressed)
	_lobby_box.add_child(_ready_btn)

	box.add_child(_make_spacer(4))

	_back_btn = _make_button("タイトルへ戻る", Color(0.14, 0.14, 0.18, 1.0), Color(0.6, 0.64, 0.72, 1.0), font)
	_back_btn.pressed.connect(_on_back_pressed)
	box.add_child(_back_btn)

func _make_label(text: String, font: Font, size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _make_button(text: String, bg: Color, border: Color, font: Font) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 23)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 4)
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	hover.border_color = border.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed = normal.duplicate()
	pressed.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn

func _apply_server_url() -> void:
	if _server_input == null:
		return
	var url = _server_input.text.strip_edges()
	if not url.is_empty():
		_net.server_url = url

func _on_create_pressed() -> void:
	_apply_server_url()
	_create_btn.disabled = true
	_join_btn.disabled = true
	_status_lbl.text = "ルームを作成しています..."
	_generated_code = _net.create_room(_name_input.text.strip_edges())
	_room_code_lbl.text = "ルームコード: %s" % _generated_code

func _on_join_pressed() -> void:
	var code = _code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_status_lbl.text = "ルームコードを入力してください"
		return
	_apply_server_url()
	_create_btn.disabled = true
	_join_btn.disabled = true
	_status_lbl.text = "ルームに接続しています..."
	_generated_code = code
	_room_code_lbl.text = "ルームコード: %s" % code
	_net.join_room(code, _name_input.text.strip_edges())

func _on_character_selected(character_id: String) -> void:
	_selected_character = character_id
	_update_character_buttons()
	if _net and _net.is_connected_to_room():
		_net.send_character(_selected_character)

func _update_character_buttons() -> void:
	for cid in _char_buttons.keys():
		var btn: Button = _char_buttons[cid]
		var selected: bool = str(cid) == _selected_character
		btn.modulate = Color.WHITE if selected else Color(0.68, 0.70, 0.76)
		if selected:
			var info: Dictionary = CharacterData.get_character(str(cid))
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.16, 0.14, 0.06, 1.0)
			style.border_color = Color.from_string(str(info.get("color", "#FFD54F")), Color(1.0, 0.85, 0.3))
			style.set_border_width_all(3)
			style.set_corner_radius_all(12)
			btn.add_theme_stylebox_override("normal", style)
		else:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.08, 0.10, 0.16, 1.0)
			style.border_color = Color(0.35, 0.40, 0.52, 1.0)
			style.set_border_width_all(2)
			style.set_corner_radius_all(12)
			btn.add_theme_stylebox_override("normal", style)

func _on_ready_pressed() -> void:
	_ready_btn.disabled = true
	_ready_btn.text = "準備完了 ✓"
	if _net and _net.is_connected_to_room():
		_net.send_character(_selected_character)
	_net.send_ready()

func _on_connection_opened() -> void:
	_status_lbl.text = "サーバーに接続しました。相手を待っています..."

func _on_connection_closed(code: int, reason: String) -> void:
	_create_btn.disabled = false
	_join_btn.disabled = false
	_ready_btn.disabled = false
	_ready_btn.text = "準備完了"
	_status_lbl.text = "接続が切れました (%d %s)" % [code, reason]

func _on_reconnecting(attempt: int, max_attempts: int) -> void:
	_status_lbl.text = "再接続中... (%d/%d)" % [attempt, max_attempts]

func _on_welcome(data: Dictionary) -> void:
	_status_lbl.text = "接続しました。準備完了を押してください。"
	_room_code_lbl.text = "ルームコード: %s" % str(data.get("room", {}).get("code", _generated_code))
	_lobby_box.visible = true
	if _net:
		_net.send_character(_selected_character)
	_update_players(data.get("room", {}))

func _on_room_updated(room_data: Dictionary) -> void:
	_update_players(room_data)

func _update_players(room_data: Dictionary) -> void:
	var players: Array = room_data.get("players", [])
	var lines: Array[String] = []
	for i in range(players.size()):
		var p = players[i]
		if p == null:
			lines.append("プレイヤー%d: 待機中" % (i + 1))
		else:
			var mark = "✓" if bool(p.get("ready", false)) else "…"
			var conn = "" if bool(p.get("connected", false)) else "（切断）"
			var cid = str(p.get("character", ""))
			var cname = ""
			if cid != "":
				cname = " [%s]" % str(CharacterData.get_character(cid).get("name", cid))
			lines.append("プレイヤー%d: %s%s %s%s" % [i + 1, str(p.get("name", "")), cname, mark, conn])
	_players_lbl.text = "\n".join(PackedStringArray(lines))
	if players.size() >= 2 and players[1] != null:
		_status_lbl.text = "2人そろいました。準備完了を押してください。"

func _on_match_started(_data: Dictionary) -> void:
	_status_lbl.text = "対戦開始！"
	if _net:
		_net.pvp_mode = true
	get_tree().change_scene_to_file(MATCH_SCENE)

func _on_network_error(message: String) -> void:
	_status_lbl.text = "エラー: %s" % message
	_create_btn.disabled = false
	_join_btn.disabled = false

func _on_back_pressed() -> void:
	_net.close()
	get_tree().change_scene_to_file(TITLE_SCENE)

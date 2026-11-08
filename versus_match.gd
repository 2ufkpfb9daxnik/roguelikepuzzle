extends CanvasLayer

## オンライン対戦の本体。
## 既存の current_stage.tscn（PuzzleBoard / ScoreManager / StageManager）に
## PvPモードでアタッチし、10秒ターン・20秒ショップ・HP同期を担当する。

const TITLE_SCENE = "res://title_screen.tscn"
const CharacterData = preload("res://character_data.gd")

var _net: Node = null
var _stage: Node = null
var _board: Node = null
var _stage_mgr: Node = null
var _hud_root: Control = null

var _my_index: int = 0
var _my_name: String = "YOU"
var _remote_name: String = "RIVAL"
var _opp_character_id: String = CharacterData.DEFAULT_ID
var _stage_bg_index: int = 0
var _my_stats: Dictionary = { "hp": 5000, "maxHp": 5000, "shield": 0, "coins": 0 }
var _remote_stats: Dictionary = { "hp": 5000, "maxHp": 5000, "shield": 0, "coins": 0 }

var _phase: String = "turn"
var _active_player: int = 0
var _deadline: int = 0
var _round: int = 1
var _turn_number: int = 0
var _shop_offer_seed: String = ""
var _match_seed: int = 0
var _selected_relic: String = ""
var _shop_relic_ids: Array = []
var _shop_done_sent: bool = false
var _end_turn_pending: bool = false

var _timer_lbl: Label = null
var _round_lbl: Label = null
var _phase_lbl: Label = null
var _my_name_lbl: Label = null
var _my_hp_lbl: Label = null
var _my_hp_bar: ProgressBar = null
var _my_status_lbl: Label = null
var _remote_name_lbl: Label = null
var _remote_hp_lbl: Label = null
var _remote_hp_bar: ProgressBar = null
var _remote_status_lbl: Label = null
var _hint_lbl: Label = null
var _bottom_timer_lbl: Label = null
var _turn_frame: Panel = null
var _rival_sprite: TextureRect = null
var _rival_name_lbl: Label = null
var _log_lbl: RichTextLabel = null
var _shop_panel: PanelContainer = null
var _shop_timer_lbl: Label = null
var _shop_relic_box: VBoxContainer = null
var _shop_item_box: VBoxContainer = null
var _shop_done_btn: Button = null
var _shop_note_lbl: Label = null
var _shop_title_lbl: Label = null
var _shop_items_title_lbl: Label = null
var _shop_stage: String = "relic"
var _shop_overlay_root: Control = null
var _pvp_shop_done_btn: Button = null
var _pvp_shop_timer_lbl: Label = null
var _offline_shop_open: bool = false
var _result_overlay: Control = null
var _result_lbl: Label = null
var _rating_change_lbl: Label = null
var _announce_root: Control = null
var _announce_bg: ColorRect = null
var _announce_lbl: Label = null
var _announce_tween: Tween = null
var _intro_pending: bool = true
var _intro_playing: bool = false

func _ready() -> void:
	layer = 110
	_net = get_node_or_null("/root/NetworkManager")
	if _net != null:
		_net.pvp_mode = true

	_stage = get_parent()
	_board = _stage.get_node_or_null("PuzzleBoard") if _stage else null
	_stage_mgr = _stage.get_node_or_null("StageManager") if _stage else null

	_my_index = _net.player_index if _net != null and _net.player_index >= 0 else 0
	_pull_cached_data()
	_build_hud()
	_connect_network_signals()
	_connect_shop_signals()

	if _board:
		_board.set_pvp_mode(true)
		_board.set_pvp_my_turn(false)
		_board.pvp_my_player_index = _my_index
		_board.pvp_turn_resolved.connect(_on_pvp_turn_resolved)
		_board.pvp_turn_completed.connect(_on_pvp_turn_completed)
		_board.pvp_move_started.connect(_on_pvp_move_started)

	_setup_pvp_enemy()
	_apply_cached_state()
	_sync_stage_hp()
	_start_bgm()
	if _intro_pending and not _intro_playing:
		_play_match_countdown()

func _start_bgm() -> void:
	var stream = load("res://Sound/bgm/bgmnokouho/battle2.mp3")
	var bgm = AudioStreamPlayer.new()
	bgm.stream = stream
	bgm.volume_db = -12.0
	bgm.name = "PvPBGM"
	add_child(bgm)
	var settings = get_node_or_null("/root/SettingsManager")
	if settings and settings.has_method("enable_bgm_loop"):
		settings.enable_bgm_loop(bgm)
	else:
		bgm.finished.connect(func():
			if is_instance_valid(bgm):
				bgm.play()
		)
	bgm.play()

func _exit_tree() -> void:
	if _net != null:
		_net.pvp_mode = false

func _pull_cached_data() -> void:
	var players: Array = _net.match_data.get("players", _net.room.get("players", []))
	if players.size() > _my_index and players[_my_index] != null:
		_my_name = str(players[_my_index].get("name", "YOU"))
	var opp: int = 1 - _my_index
	if players.size() > opp and players[opp] != null:
		_remote_name = str(players[opp].get("name", "RIVAL"))
		_opp_character_id = str(players[opp].get("character", CharacterData.DEFAULT_ID))
		if _opp_character_id.is_empty():
			_opp_character_id = CharacterData.DEFAULT_ID
	if _net.last_stats.has(_my_index):
		_my_stats = _net.last_stats[_my_index].duplicate(true)
	if _net.last_stats.has(opp):
		_remote_stats = _net.last_stats[opp].duplicate(true)

func _connect_shop_signals() -> void:
	var score_mgr = _stage.get_node_or_null("ScoreManager") if _stage else null
	if score_mgr == null:
		return
	if score_mgr.has_signal("shop_purchased"):
		if not score_mgr.shop_purchased.is_connected(_on_shop_purchased):
			score_mgr.shop_purchased.connect(_on_shop_purchased)
	if score_mgr.has_signal("skill_upgraded"):
		if not score_mgr.skill_upgraded.is_connected(_on_shop_skill_upgraded):
			score_mgr.skill_upgraded.connect(_on_shop_skill_upgraded)

func _sync_stats_from_stage() -> void:
	var score_mgr = _stage.get_node_or_null("ScoreManager") if _stage else null
	if _stage_mgr:
		_my_stats["maxHp"] = int(_stage_mgr.myhpmax)
		_my_stats["hp"] = int(_stage_mgr.myhp)
	if score_mgr and "divscore" in score_mgr and score_mgr.divscore.size() > 2:
		_my_stats["coins"] = int(score_mgr.divscore[2])
	_refresh_stats()
	_sync_stage_hp()

func _on_shop_purchased() -> void:
	if not _offline_shop_open:
		return
	_sync_stats_from_stage()
	if _net and _net.has_method("send_stats"):
		_net.send_stats(_my_stats)

func _on_shop_skill_upgraded(_skill_id: String, _sp_type: int, _new_level: int) -> void:
	if not _offline_shop_open:
		return
	_sync_stats_from_stage()
	if _net and _net.has_method("send_stats"):
		_net.send_stats(_my_stats)

func _connect_network_signals() -> void:
	if _net == null:
		return
	_net.action_received.connect(_on_action_received)
	_net.stats_received.connect(_on_stats_received)
	_net.turn_started.connect(_on_turn_started)
	_net.phase_updated.connect(_on_phase_updated)
	_net.shop_started.connect(_on_shop_started)
	_net.shop_ended.connect(_on_shop_ended)
	_net.match_ended.connect(_on_match_ended)
	_net.turn_timed_out.connect(_on_turn_timed_out)
	_net.shop_timed_out.connect(_on_shop_timed_out)
	_net.opponent_disconnected.connect(_on_opponent_disconnected)
	_net.match_resumed.connect(_on_match_resumed)
	_net.connection_closed.connect(_on_connection_closed)
	_net.network_error.connect(_on_network_error)
	_net.reconnecting.connect(_on_reconnecting)

func _apply_cached_state() -> void:
	# オンライン対戦開始時のシードを両者で共有し、演出の乱数列を一致させる
	if _net != null and _net.match_data is Dictionary:
		_match_seed = int(_net.match_data.get("seed", 0))
	if not _net.last_turn.is_empty():
		_on_turn_started(_net.last_turn)
	if not _net.last_shop.is_empty():
		_on_shop_started(_net.last_shop)
	_refresh_stats()

var _cached_ui_font: Font = null

func _make_font() -> Font:
	if _cached_ui_font != null:
		return _cached_ui_font
	_cached_ui_font = load("res://font/NotoSansJP.ttf")
	_cached_ui_font.set_fallbacks([load("res://font/NotoEmoji.ttf")])
	return _cached_ui_font

func _play_ui_se(kind: String) -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("play_ui_se"):
		sm.play_ui_se(kind)

func _panel_style(border: Color, alpha: float = 0.94) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, alpha)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 8
	return style

func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "PvPHUDRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	var font = _make_font()
	_build_left_panel(font)
	# オフライン同様の右側ステータス欄を使用するため、重なるPlayerStatusPanelの追加を廃止
	_build_turn_frame()
	_build_bottom_panel(font)
	_build_shop_panel(font)
	_build_shop_overlay(font)
	_build_announce_overlay(font)
	_build_result_overlay(font)

func _build_announce_overlay(font: Font) -> void:
	var root = Control.new()
	root.name = "PvPAnnounceOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 80
	root.visible = false
	_hud_root.add_child(root)
	_announce_root = root

	_announce_bg = ColorRect.new()
	_announce_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_announce_bg.color = Color(0, 0, 0, 0.55)
	_announce_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_announce_bg)

	_announce_lbl = Label.new()
	_announce_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_announce_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_lbl.add_theme_font_override("font", font)
	_announce_lbl.add_theme_font_size_override("font_size", 92)
	_announce_lbl.add_theme_color_override("font_color", Color.WHITE)
	_announce_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	_announce_lbl.add_theme_constant_override("outline_size", 16)
	_announce_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	root.add_child(_announce_lbl)

func _set_announce_text(text: String, color: Color) -> void:
	if _announce_lbl == null:
		return
	_announce_lbl.text = text
	_announce_lbl.add_theme_color_override("font_color", color)
	_announce_lbl.pivot_offset = _announce_lbl.size / 2.0
	if _announce_lbl.pivot_offset.x <= 0.0:
		var vp = get_viewport()
		_announce_lbl.pivot_offset = (vp.get_visible_rect().size / 2.0) if vp else Vector2(960, 540)
	_announce_lbl.scale = Vector2(0.55, 0.55)
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce_lbl, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.tween_property(_announce_lbl, "scale", Vector2(1.0, 1.0), 0.12)

func _play_match_countdown() -> void:
	if _intro_playing:
		return
	_intro_playing = true
	if _board:
		_board.set_pvp_my_turn(false)
	if _announce_root:
		_announce_root.visible = true
		_announce_root.mouse_filter = Control.MOUSE_FILTER_STOP
	if _announce_bg:
		_announce_bg.color = Color(0, 0, 0, 0.62)
	for n in [3, 2, 1, 0]:
		if not is_inside_tree():
			return
		_set_announce_text(str(n), Color(1.0, 0.92, 0.35))
		await get_tree().create_timer(0.8).timeout
	_intro_pending = false
	_intro_playing = false
	if _announce_root:
		_announce_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _board:
		_board.set_pvp_my_turn(_active_player == _my_index)
	_show_turn_banner()

func _show_turn_banner() -> void:
	if _announce_root == null or _announce_lbl == null:
		return
	var is_my_turn: bool = _active_player == _my_index
	var player_name: String = _my_name if is_my_turn else _remote_name
	_announce_root.visible = true
	_announce_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _announce_bg:
		_announce_bg.color = Color(0, 0, 0, 0.32)
	_set_announce_text("%s のターン" % player_name, Color(0.55, 1.0, 0.65) if is_my_turn else Color(1.0, 0.55, 0.45))
	await get_tree().create_timer(1.15).timeout
	if not is_inside_tree():
		return
	if _announce_tween and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce_lbl, "modulate:a", 0.0, 0.28)
	_announce_tween.tween_callback(func():
		if _announce_root:
			_announce_root.visible = false
		if _announce_lbl:
			_announce_lbl.modulate.a = 1.0
			_announce_lbl.scale = Vector2.ONE
	)

func _build_left_panel(font: Font) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(8, 8)
	panel.size = Vector2(246, 924)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.3, 0.8, 1.0, 0.75)))
	_hud_root.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_label("ROOM %s" % _net.room_code, font, 15, Color(0.75, 0.82, 0.92)))
	_round_lbl = _label("ROUND 1", font, 17, Color(1.0, 0.9, 0.4))
	box.add_child(_round_lbl)
	_phase_lbl = _label("YOUR TURN", font, 16, Color(0.6, 1.0, 0.8))
	box.add_child(_phase_lbl)
	_timer_lbl = _label("10.0", font, 34, Color(1.0, 0.85, 0.3))
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_lbl)

	box.add_child(_label("YOU: %s" % _my_name, font, 14, Color(0.65, 0.92, 1.0)))
	box.add_child(_label("VS  %s" % _remote_name, font, 14, Color(1.0, 0.65, 0.65)))

	box.add_child(HSeparator.new())

	var log_title = _label("BATTLE LOG", font, 14, Color(0.7, 0.75, 0.85))
	log_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(log_title)

	_log_lbl = RichTextLabel.new()
	_log_lbl.bbcode_enabled = true
	_log_lbl.scroll_active = true
	_log_lbl.scroll_following = true
	_log_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_lbl.add_theme_font_override("normal_font", font)
	_log_lbl.add_theme_font_size_override("normal_font_size", 13)
	box.add_child(_log_lbl)

func _build_player_panel(font: Font) -> void:
	var panel = PanelContainer.new()
	panel.name = "PlayerStatusPanel"
	panel.position = Vector2(1194, 420)
	panel.size = Vector2(717, 128)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.35, 0.8, 1.0, 0.75), 0.92))
	_hud_root.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	_my_name_lbl = _label("YOU  %s" % _my_name, font, 19, Color(0.65, 0.92, 1.0))
	_my_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_my_name_lbl)

	_my_hp_lbl = _label("HP 5000 / 5000", font, 17, Color.WHITE)
	_my_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_my_hp_lbl)

	_my_hp_bar = ProgressBar.new()
	_my_hp_bar.custom_minimum_size = Vector2(0, 20)
	_my_hp_bar.max_value = 100
	_my_hp_bar.value = 100
	_my_hp_bar.show_percentage = false
	box.add_child(_my_hp_bar)

	_my_status_lbl = _label("SHIELD 0   COIN 0", font, 14, Color(0.8, 0.85, 0.95))
	_my_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_my_status_lbl)

func _build_remote_panel(font: Font) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(1194, 277)
	panel.size = Vector2(717, 130)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.45, 0.45, 0.75), 0.90))
	_hud_root.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_remote_name_lbl = _label(_remote_name, font, 22, Color(1.0, 0.65, 0.65))
	_remote_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_remote_name_lbl)

	_remote_hp_lbl = _label("HP 5000 / 5000", font, 18, Color.WHITE)
	_remote_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_remote_hp_lbl)

	_remote_hp_bar = ProgressBar.new()
	_remote_hp_bar.custom_minimum_size = Vector2(0, 22)
	_remote_hp_bar.max_value = 100
	_remote_hp_bar.value = 100
	_remote_hp_bar.show_percentage = false
	box.add_child(_remote_hp_bar)

	_remote_status_lbl = _label("SHIELD 0   COIN 0", font, 15, Color(0.85, 0.85, 0.95))
	_remote_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_remote_status_lbl)

func _build_rival_avatar(font: Font) -> void:
	var opp: int = 1 - _my_index
	var path: String = "res://Texture/enemy/2CDF0D54-BB4C-40BC-9FDA-BFFC9BE514ED-preview.png"
	if opp == 1:
		path = "res://Texture/enemy/7CD13BE7-4A80-4A6A-9B38-8CF11176BBB6-preview.png"

	_rival_name_lbl = _label("RIVAL  %s" % _remote_name, font, 18, Color(1.0, 0.55, 0.55))
	_rival_name_lbl.position = Vector2(1194, 13)
	_rival_name_lbl.size = Vector2(717, 30)
	_rival_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rival_name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_rival_name_lbl.add_theme_constant_override("outline_size", 5)
	_hud_root.add_child(_rival_name_lbl)

	_rival_sprite = TextureRect.new()
	_rival_sprite.name = "RivalCharacter"
	_rival_sprite.position = Vector2(1422, 38)
	_rival_sprite.size = Vector2(260, 236)
	_rival_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rival_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_rival_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rival_sprite.texture = load(path)
	_hud_root.add_child(_rival_sprite)

func _build_turn_frame() -> void:
	_turn_frame = Panel.new()
	_turn_frame.name = "TurnFrame"
	_turn_frame.position = Vector2(250, 17)
	_turn_frame.size = Vector2(920, 920)
	_turn_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_frame.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0.4, 1.0, 0.6, 0.9)
	style.set_border_width_all(6)
	style.set_corner_radius_all(14)
	_turn_frame.add_theme_stylebox_override("panel", style)
	_hud_root.add_child(_turn_frame)

func _build_bottom_panel(font: Font) -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(255, 946)
	panel.size = Vector2(910, 116)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.85, 0.72, 0.35, 0.75), 0.90))
	_hud_root.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	_hint_lbl = _label("▶ あなたのターン：駒を入れ替えて攻撃", font, 24, Color(0.5, 1.0, 0.65))
	_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint_lbl.add_theme_constant_override("outline_size", 5)
	hbox.add_child(_hint_lbl)

	_bottom_timer_lbl = _label("10.0", font, 38, Color(1.0, 0.85, 0.3))
	_bottom_timer_lbl.custom_minimum_size = Vector2(130, 0)
	_bottom_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_timer_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_bottom_timer_lbl)

	var leave = _make_button("退出", Color(0.20, 0.10, 0.10, 1.0), Color(1.0, 0.45, 0.4, 1.0), font)
	leave.custom_minimum_size = Vector2(120, 56)
	leave.pressed.connect(_on_leave_pressed)
	hbox.add_child(leave)

func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_button(text: String, bg: Color, border: Color, font: Font) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 4)
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover)
	return btn

func _build_shop_panel(font: Font) -> void:
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(center)

	_shop_panel = PanelContainer.new()
	_shop_panel.visible = false
	_shop_panel.custom_minimum_size = Vector2(760, 0)
	_shop_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.9, 0.5, 1.0, 0.9), 0.98))
	center.add_child(_shop_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_shop_panel.add_child(margin)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_shop_title_lbl = _label("🧪 レリック選択", font, 28, Color(0.9, 0.75, 1.0))
	_shop_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_shop_title_lbl)

	_shop_timer_lbl = _label("20.0", font, 24, Color(1.0, 0.85, 0.3))
	_shop_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_shop_timer_lbl)

	_shop_relic_box = VBoxContainer.new()
	_shop_relic_box.add_theme_constant_override("separation", 8)
	box.add_child(_shop_relic_box)

	_shop_items_title_lbl = _label("🛒 ショップ", font, 19, Color(1.0, 0.9, 0.6))
	_shop_items_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_items_title_lbl.visible = false
	box.add_child(_shop_items_title_lbl)

	_shop_item_box = VBoxContainer.new()
	_shop_item_box.add_theme_constant_override("separation", 6)
	_shop_item_box.visible = false
	box.add_child(_shop_item_box)

	_shop_note_lbl = _label("レリックを1つ選択してください。", font, 15, Color(0.7, 0.75, 0.85))
	_shop_note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_shop_note_lbl)

	_shop_done_btn = _make_button("準備完了", Color(0.18, 0.12, 0.28, 1.0), Color(0.8, 0.5, 1.0, 1.0), font)
	_shop_done_btn.pressed.connect(_on_shop_done_pressed)
	_shop_done_btn.visible = false
	box.add_child(_shop_done_btn)

func _build_shop_overlay(font: Font) -> void:
	var layer = CanvasLayer.new()
	layer.name = "PvPShopOverlayLayer"
	layer.layer = 120
	add_child(layer)

	_shop_overlay_root = Control.new()
	_shop_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_overlay_root.visible = false
	layer.add_child(_shop_overlay_root)

	var panel = PanelContainer.new()
	panel.position = Vector2(1400, 900)
	panel.size = Vector2(500, 84)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.9, 0.5, 1.0, 0.9), 0.98))
	_shop_overlay_root.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	margin.add_child(hbox)

	_pvp_shop_timer_lbl = _label("20.0", font, 24, Color(1.0, 0.85, 0.3))
	_pvp_shop_timer_lbl.custom_minimum_size = Vector2(90, 0)
	_pvp_shop_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_pvp_shop_timer_lbl)

	_pvp_shop_done_btn = _make_button("準備完了", Color(0.18, 0.12, 0.28, 1.0), Color(0.8, 0.5, 1.0, 1.0), font)
	_pvp_shop_done_btn.custom_minimum_size = Vector2(300, 56)
	_pvp_shop_done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pvp_shop_done_btn.pressed.connect(_on_shop_done_pressed)
	hbox.add_child(_pvp_shop_done_btn)

func _build_result_overlay(font: Font) -> void:
	_result_overlay = Control.new()
	_result_overlay.visible = false
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.add_child(_result_overlay)

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(dim)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.84, 0.25, 1.0), 0.98))
	center.add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_result_lbl = _label("MATCH END", font, 38, Color(1.0, 0.9, 0.4))
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_lbl)

	_rating_change_lbl = _label("", font, 22, Color(0.4, 0.9, 1.0))
	_rating_change_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_change_lbl.visible = false
	box.add_child(_rating_change_lbl)

	var back = _make_button("タイトルへ戻る", Color(0.14, 0.14, 0.18, 1.0), Color(0.6, 0.64, 0.72, 1.0), font)
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)

func _process(_delta: float) -> void:
	if _phase == "turn" or _phase == "resolve" or _phase == "shop":
		var rem: int = _net.remaining_ms(_deadline)
		var text: String = "%.1f" % (float(rem) / 1000.0)
		if _phase == "shop":
			if _shop_timer_lbl:
				_shop_timer_lbl.text = text
				_shop_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if rem <= 3000 else Color(1.0, 0.85, 0.3))
			if _pvp_shop_timer_lbl and _offline_shop_open:
				_pvp_shop_timer_lbl.text = text
				_pvp_shop_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if rem <= 3000 else Color(1.0, 0.85, 0.3))
		else:
			_timer_lbl.text = text
			_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if rem <= 3000 else Color(1.0, 0.85, 0.3))
		if _bottom_timer_lbl:
			_bottom_timer_lbl.text = text
			_bottom_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if rem <= 3000 else Color(1.0, 0.85, 0.3))
	_update_hint()
	_update_turn_frame()

func _update_turn_frame() -> void:
	if _turn_frame == null:
		return
	if _phase != "turn" and _phase != "resolve":
		_turn_frame.visible = false
		return
	_turn_frame.visible = true
	var my_turn: bool = _phase == "turn" and _active_player == _my_index
	var color: Color = Color(0.4, 1.0, 0.6, 0.95) if my_turn else Color(1.0, 0.4, 0.4, 0.75)
	var style = _turn_frame.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		if style.border_color != color:
			var dup = style.duplicate() as StyleBoxFlat
			dup.border_color = color
			_turn_frame.add_theme_stylebox_override("panel", dup)
	_turn_frame.modulate.a = (0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.006)) if my_turn else 0.45

func _update_hint() -> void:
	if _phase_lbl == null or _hint_lbl == null:
		return
	match _phase:
		"shop":
			_phase_lbl.text = "SHOP PHASE"
			_hint_lbl.text = "🧪 レリック選択＋ショップ（20秒）"
			_hint_lbl.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
		"resolve":
			_phase_lbl.text = "RESOLVING"
			_hint_lbl.text = "⚔ 攻撃中..."
			_hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
		"ended":
			_phase_lbl.text = "MATCH END"
			_hint_lbl.text = "対戦終了"
			_hint_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_:
			if _active_player == _my_index:
				_phase_lbl.text = "YOUR TURN"
				_hint_lbl.text = "▶ あなたのターン：駒を入れ替えて攻撃"
				_hint_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))
			else:
				_phase_lbl.text = "OPPONENT TURN"
				_hint_lbl.text = "⏳ 相手のターン：待機中..."
				_hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))

func _refresh_stats() -> void:
	if _my_hp_lbl != null:
		var max_hp: float = maxf(1.0, float(_my_stats.get("maxHp", 5000)))
		var hp: float = float(_my_stats.get("hp", 0))
		_my_hp_lbl.text = "HP %d / %d" % [int(hp), int(max_hp)]
		if _my_hp_bar: _my_hp_bar.value = clampf(hp / max_hp * 100.0, 0.0, 100.0)
		if _my_status_lbl: _my_status_lbl.text = "SHIELD %d   COIN %d" % [int(_my_stats.get("shield", 0)), int(_my_stats.get("coins", 0))]

	if _remote_hp_lbl != null:
		var rmax: float = maxf(1.0, float(_remote_stats.get("maxHp", 5000)))
		var rhp: float = float(_remote_stats.get("hp", 0))
		_remote_hp_lbl.text = "HP %d / %d" % [int(rhp), int(rmax)]
		if _remote_hp_bar: _remote_hp_bar.value = clampf(rhp / rmax * 100.0, 0.0, 100.0)
		if _remote_status_lbl: _remote_status_lbl.text = "SHIELD %d   COIN %d" % [int(_remote_stats.get("shield", 0)), int(_remote_stats.get("coins", 0))]

	_sync_stage_hp()
	_sync_pvp_enemy_hp()

func _sync_stage_hp() -> void:
	if _stage_mgr == null:
		return
	_stage_mgr.myhp = float(_my_stats.get("hp", 5000))
	_stage_mgr.myhpmax = float(_my_stats.get("maxHp", 5000))
	_stage_mgr.myhppar = clampf(_stage_mgr.myhp / maxf(1.0, _stage_mgr.myhpmax), 0.0, 1.0)
	_stage_mgr.guard = float(_my_stats.get("shield", 0))
	_stage_mgr.isdeadf = false
	if _stage_mgr.has_method("displayhp"):
		_stage_mgr.displayhp()

func _setup_pvp_enemy() -> void:
	if _stage_mgr == null or not _stage_mgr.has_method("setup_pvp_enemy"):
		return
	var info: Dictionary = CharacterData.get_character(_opp_character_id)
	var tex: Texture2D = null
	if ResourceLoader.exists(str(info.get("texture", ""))):
		tex = load(str(info["texture"])) as Texture2D
	if tex == null:
		return
	_stage_mgr.setup_pvp_enemy(tex, _remote_name, str(info.get("element", "無属性")), float(_remote_stats.get("hp", 5000)), float(_remote_stats.get("maxHp", 5000)), str(info.get("anim_key", "")))
	_stage_mgr.set_pvp_background("plane")
	_stage_bg_index = 0

func _sync_pvp_enemy_hp() -> void:
	if _stage_mgr and _stage_mgr.has_method("update_pvp_enemy_hp"):
		_stage_mgr.update_pvp_enemy_hp(float(_remote_stats.get("hp", 5000)), float(_remote_stats.get("maxHp", 5000)), float(_remote_stats.get("shield", 0)))

func _advance_pvp_background() -> void:
	if _stage_mgr == null or not _stage_mgr.has_method("set_pvp_background"):
		return
	var backgrounds: Array[String] = ["plane", "cave", "desert", "snow field", "castle"]
	if _stage_bg_index >= backgrounds.size() - 1:
		return
	var next_bg: String = backgrounds[_stage_bg_index + 1]
	# 魔王城が次に来る場合は背景を変えない
	if next_bg == "castle":
		return
	_stage_bg_index += 1
	_stage_mgr.set_pvp_background(backgrounds[_stage_bg_index])
	_log("[color=#81C784]背景が「%s」に変化しました[/color]" % backgrounds[_stage_bg_index])

func _element_color_hex(element: String) -> String:
	match element:
		"fire": return "#FF7043"
		"water": return "#29B6F6"
		"ice": return "#80D8FF"
		"thunder": return "#FFD600"
		"wood": return "#76FF03"
		"wind": return "#69F0AE"
		"earth": return "#FFB74D"
		"poison": return "#B388FF"
		"light": return "#FFF59D"
		"dark": return "#EA80FC"
		_: return "#FFD54F"

func _show_enemy_damage(damage: int) -> void:
	if damage <= 0:
		return
	var pos := Vector2(1552, 180)
	var spr = _stage_mgr.enemy if _stage_mgr and "enemy" in _stage_mgr else null
	if is_instance_valid(spr):
		pos = spr.global_position + Vector2(0, -130)
		if _stage_mgr.has_method("play_single_enemy_animation"):
			_stage_mgr.play_single_enemy_animation(0, "damaged")
		spr.modulate = Color(1.0, 0.35, 0.35)
		var tw = create_tween()
		tw.tween_property(spr, "modulate", Color.WHITE, 0.35)
	_play_damage_text(pos, damage, Color(1.0, 0.35, 0.25))

func _log(text: String) -> void:
	if _log_lbl:
		_log_lbl.append_text(text + "\n")

func _on_pvp_turn_resolved(payload: Dictionary) -> void:
	var max_hp: int = int(payload.get("maxHp", _my_stats.get("maxHp", 5000)))
	_my_stats["maxHp"] = max_hp
	var hp_after_turn: int = int(payload.get("hp", _my_stats.get("hp", max_hp)))
	var heal: int = int(payload.get("heal", 0))
	_my_stats["hp"] = clampi(hp_after_turn + heal, 0, max_hp)
	_my_stats["shield"] = int(_my_stats.get("shield", 0)) + int(payload.get("shield", 0))
	_my_stats["coins"] = int(payload.get("coins", _my_stats.get("coins", 0)))
	_refresh_stats()
	_sync_stage_hp()

	var damage: int = int(payload.get("damage", 0))
	var net_payload: Dictionary = {
		"kind": "pvp_turn",
		"damage": damage,
		"heal": heal,
		"shield": int(payload.get("shield", 0)),
		"coins": int(payload.get("coins", 0)),
		"skillName": str(payload.get("skillName", "")),
		"skillElement": str(payload.get("skillElement", "")),
		"skills": payload.get("skills", []),
		"sword": int(payload.get("sword", 0)),
		"elements": payload.get("elements", {}),
		"swap": payload.get("swap", [])
	}
	_net.send_action(net_payload)
	if _net and _net.has_method("send_stats"):
		_net.send_stats(_my_stats)

	var rem_sh: int = int(_remote_stats.get("shield", 0))
	var rem_abs: int = mini(rem_sh, damage)
	_remote_stats["shield"] = rem_sh - rem_abs
	var rem_hp_dmg: int = damage - rem_abs
	_remote_stats["hp"] = maxi(0, int(_remote_stats.get("hp", 0)) - rem_hp_dmg)
	_refresh_stats()
	_log("[color=#81D4FA]あなたの攻撃: %d / 回復 %d / シールド +%d[/color]" % [damage, heal, int(payload.get("shield", 0))])
	_show_enemy_damage(damage)

	# 相手のHPが0になったら即座に勝利演出を表示する（match_end が遅れても勝敗が分かるように）
	if int(_remote_stats.get("hp", 1)) <= 0:
		_show_pvp_result(_my_index, "ko")

func _on_pvp_turn_completed() -> void:
	if _end_turn_pending:
		return
	_end_turn_pending = true
	if _board:
		_board.set_pvp_my_turn(false)
	# 攻撃演出が終わってから相手のターンへ移す
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	_net.send_end_turn()
	_end_turn_pending = false

func _play_attack_animation(damage: int) -> void:
	if damage <= 0 or _hud_root == null:
		return
	var start := Vector2(710, 470)
	var target := Vector2(1552, 155)

	var beam = Line2D.new()
	beam.points = PackedVector2Array([start, target])
	beam.width = 18.0
	beam.default_color = Color(1.0, 0.55, 0.15, 1.0)
	beam.z_index = 30
	beam.modulate.a = 0.0
	_hud_root.add_child(beam)
	var tw = create_tween()
	tw.tween_property(beam, "modulate:a", 1.0, 0.07)
	tw.tween_interval(0.12)
	tw.tween_property(beam, "modulate:a", 0.0, 0.18)
	tw.tween_callback(beam.queue_free)

	var burst = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(24):
		var a = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 90.0)
	burst.polygon = pts
	burst.color = Color(1.0, 0.65, 0.2, 0.9)
	burst.position = target
	burst.scale = Vector2(0.25, 0.25)
	burst.z_index = 31
	_hud_root.add_child(burst)
	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(burst, "scale", Vector2(1.6, 1.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(burst, "modulate:a", 0.0, 0.3)
	tw2.chain().tween_callback(burst.queue_free)

	_play_damage_text(target + Vector2(0, -40), damage, Color(1.0, 0.35, 0.25))
	if _rival_sprite:
		_rival_sprite.modulate = Color(1.0, 0.35, 0.35)
		var tw3 = create_tween()
		tw3.tween_property(_rival_sprite, "modulate", Color.WHITE, 0.35)

func _play_damage_text(pos: Vector2, damage: int, color: Color, format_str: String = "-%d") -> void:
	if _hud_root == null:
		return
	var lbl = Label.new()
	lbl.text = format_str % damage
	lbl.position = pos + Vector2(-100, 0)
	lbl.size = Vector2(200, 70)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _make_font())
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 40
	_hud_root.add_child(lbl)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 45.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.15)
	tw.chain().tween_callback(lbl.queue_free)

func _on_pvp_move_started() -> void:
	if _phase == "turn" and _active_player == _my_index:
		_net.send_move_started()

## 相手がそのターンに使ったスキルを、敵画面のキャラで順番に発動させる（最大4スキル）
## 攻撃1回と合わせて、1ターン最大5アクションの演出となる
## 相手ターンの行動を「剣 → 各属性スキル」の順に、敵画面のキャラで再現する
## 剣の値>0なら攻撃モーション、各属性値>0ならその属性のスキルモーションを行う（最大5アクション）
func _play_opponent_turn_motions(payload: Dictionary) -> void:
	var sword: int = int(payload.get("sword", 0))
	var elements: Dictionary = payload.get("elements", {})
	var mirror: Array = payload.get("skills", [])
	var idx: int = 0

	# 1) 剣の値 >0 またはスキル駒使用時 → 攻撃モーション
	if sword > 0 or not mirror.is_empty():
		var atk_idx: int = idx
		var tw_atk = create_tween()
		tw_atk.tween_interval(float(atk_idx) * 0.55)
		tw_atk.tween_callback(func():
			if _stage_mgr and _stage_mgr.has_method("play_single_enemy_animation"):
				_stage_mgr.play_single_enemy_animation(0, "attack")
			_play_enemy_skill_beam(Color(1.0, 0.35, 0.25))
		)
		idx += 1

	# 2) 各属性値が >0 なら、その属性のスキルモーション
	var order: Array[String] = ["fire", "water", "ice", "wood", "wind", "thunder", "earth", "poison", "light", "dark"]
	for key in order:
		if idx >= 5:
			break
		if int(elements.get(key, 0)) <= 0:
			continue
		# ミラー用の影響マス（使っていれば）
		var cells: Array = []
		for sk in mirror:
			if sk is Dictionary and str(sk.get("key", "")) == key:
				cells = sk.get("cells", [])
				break
		var tier: int = 1
		for sk in mirror:
			if sk is Dictionary and str(sk.get("key", "")) == key:
				tier = int(sk.get("tier", 1))
				break
		var beam_col: Color = Color(_element_color_hex(key))
		var skill_idx: int = idx
		var tw = create_tween()
		tw.tween_interval(float(skill_idx) * 0.55)
		tw.tween_callback(func():
			if _stage_mgr and _stage_mgr.has_method("play_single_enemy_animation"):
				_stage_mgr.play_single_enemy_animation(0, "skill")
			if _board and _board.has_method("_show_enemy_skill_banner"):
				_board._show_enemy_skill_banner(_skill_display_name(key), _element_color_hex(key), false, "相手プレイヤーのスキル")
			_play_enemy_skill_beam(beam_col)
			# 共有盤面モード（board フィールドあり）では盤面同期で反映済みなのでミラー適用しない
			if payload.get("board", null) == null and _board and _board.has_method("apply_pvp_mirror_skill"):
				_board.apply_pvp_mirror_skill(key, tier, cells)
		)
		idx += 1

func _skill_display_name(key: String) -> String:
	if _board and "PLAYER_SKILL_DEFS" in _board:
		var defs = _board.PLAYER_SKILL_DEFS
		if defs.has(key):
			return str(defs[key].get("name", key.to_upper()))
	return key.to_upper()

## 敵キャラから盤面へスキル属性色のビームを飛ばす（スキル攻撃の視覚表現）
func _play_enemy_skill_beam(col: Color) -> void:
	if _hud_root == null:
		return
	var start := Vector2(1552, 210)
	var spr = _stage_mgr.enemy if _stage_mgr and "enemy" in _stage_mgr else null
	if is_instance_valid(spr):
		start = spr.global_position
	var target := Vector2(760, 500)
	var beam = Line2D.new()
	beam.points = PackedVector2Array([start, target])
	beam.width = 16.0
	beam.default_color = Color(col.r, col.g, col.b, 1.0)
	beam.z_index = 30
	beam.modulate.a = 0.0
	_hud_root.add_child(beam)
	var tw = create_tween()
	tw.tween_property(beam, "modulate:a", 1.0, 0.07)
	tw.tween_interval(0.10)
	tw.tween_property(beam, "modulate:a", 0.0, 0.18)
	tw.tween_callback(beam.queue_free)

func _play_enemy_attack_animation(damage: int) -> void:
	if damage <= 0 or _hud_root == null:
		return
	var start := Vector2(1552, 210)
	var spr = _stage_mgr.enemy if _stage_mgr and "enemy" in _stage_mgr else null
	if is_instance_valid(spr):
		start = spr.global_position
	var target := Vector2(760, 500)

	var beam = Line2D.new()
	beam.points = PackedVector2Array([start, target])
	beam.width = 20.0
	beam.default_color = Color(1.0, 0.25, 0.25, 1.0)
	beam.z_index = 30
	beam.modulate.a = 0.0
	_hud_root.add_child(beam)
	var tw = create_tween()
	tw.tween_property(beam, "modulate:a", 1.0, 0.07)
	tw.tween_interval(0.12)
	tw.tween_property(beam, "modulate:a", 0.0, 0.18)
	tw.tween_callback(beam.queue_free)

	var burst = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(24):
		var a = TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * 80.0)
	burst.polygon = pts
	burst.color = Color(1.0, 0.35, 0.25, 0.9)
	burst.position = target
	burst.scale = Vector2(0.25, 0.25)
	burst.z_index = 31
	_hud_root.add_child(burst)
	var tw2 = create_tween().set_parallel(true)
	tw2.tween_property(burst, "scale", Vector2(1.5, 1.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(burst, "modulate:a", 0.0, 0.3)
	tw2.chain().tween_callback(burst.queue_free)

func _on_action_received(from: int, payload: Dictionary) -> void:
	if from == _my_index:
		return
	# 共有盤面モード: 相手のスワップを適用してカスケード解決（シード同期方式）
	var swap_data = payload.get("swap", null)
	if swap_data != null and typeof(swap_data) == TYPE_ARRAY and _board != null:
		if _board.has_method("_apply_pvp_swap"):
			_board._apply_pvp_swap(swap_data)
	var skill_name: String = str(payload.get("skillName", ""))
	if not skill_name.is_empty():
		var elem: String = str(payload.get("skillElement", ""))
		_log("[color=#FF8A65]相手のスキル: %s[/color]" % skill_name)
		if _board and _board.has_method("_show_enemy_skill_banner"):
			_board._show_enemy_skill_banner(skill_name, _element_color_hex(elem), false, "相手プレイヤーのスキル")
	var damage: int = int(payload.get("damage", 0))
	# 剣の値>0なら攻撃モーション、各属性値>0ならその属性のスキルモーションを敵画面で再現
	_play_opponent_turn_motions(payload)
	if damage <= 0:
		return
	if _stage_mgr and _stage_mgr.has_method("play_single_enemy_animation"):
		_stage_mgr.play_single_enemy_animation(0, "skill" if not skill_name.is_empty() else "attack")
	_play_enemy_attack_animation(damage)
	var shield: int = int(_my_stats.get("shield", 0))
	var absorbed: int = mini(shield, damage)
	_my_stats["shield"] = shield - absorbed
	var hp_damage: int = damage - absorbed
	_my_stats["hp"] = maxi(0, int(_my_stats.get("hp", 0)) - hp_damage)
	_refresh_stats()
	_sync_stage_hp()
	if _net and _net.has_method("send_stats"):
		_net.send_stats(_my_stats)
	_log("[color=#FF5252]相手の攻撃: %d ダメージ（シールド軽減 %d）[/color]" % [hp_damage, absorbed])

	if absorbed > 0:
		if _board and _board.has_method("play_pvp_shield_block"):
			_board.play_pvp_shield_block(absorbed, hp_damage, _my_stats["shield"])
		_play_damage_text(Vector2(760, 440), absorbed, Color(0.3, 0.9, 1.0), "🛡️ 防御 -%d")

	if hp_damage > 0:
		_play_damage_text(Vector2(760, 510), hp_damage, Color(1.0, 0.3, 0.3))
		if _stage_mgr and _stage_mgr.has_method("calchp"):
			_stage_mgr.last_damage_cause = "相手プレイヤーの攻撃"
		if _board and _board.has_method("_trigger_screen_shake"):
			_board._trigger_screen_shake(12.0)
		if _my_hp_bar:
			_my_hp_bar.modulate = Color(1.0, 0.3, 0.3)
			var tw = create_tween()
			tw.tween_property(_my_hp_bar, "modulate", Color.WHITE, 0.35)

	# HPが0になったら即座に敗北演出を表示する（match_end が遅れても勝敗が分かるように）
	if int(_my_stats.get("hp", 1)) <= 0:
		_show_pvp_result(1 - _my_index, "ko")

func _on_stats_received(from: int, stats: Dictionary) -> void:
	if from == _my_index:
		_my_stats = stats.duplicate(true)
		_sync_stage_hp()
	else:
		_remote_stats = stats.duplicate(true)
		_sync_pvp_enemy_hp()
	_refresh_stats()

func _on_turn_started(data: Dictionary) -> void:
	_phase = "turn"
	_end_turn_pending = false
	_active_player = int(data.get("player", 0))
	_deadline = int(data.get("deadline", 0))
	_round = int(data.get("round", _round))
	_turn_number = int(data.get("turnNumber", _turn_number))
	# 共有シード＋ターン番号から決定論的な乱数列を両者で再現する（通信量削減）
	if _board and _board.has_method("set_board_seed") and _match_seed != 0:
		_board.set_board_seed(_match_seed + _turn_number * 7919)
	if _round_lbl:
		_round_lbl.text = "ROUND %d / TURN %d" % [_round, _turn_number]
	if _shop_panel:
		_shop_panel.visible = false
	_close_offline_shop()
	_sync_pvp_enemy_hp()
	var is_my_turn_now: bool = _active_player == _my_index
	if is_my_turn_now:
		# 敵のターンが終了したので、前行動時に展開されていたシールドの持続期間が終了
		_my_stats["shield"] = 0
		if _board and _board.has_method("clear_pvp_shields"):
			_board.clear_pvp_shields()
	if _board:
		_board.set_pvp_my_turn(is_my_turn_now and not _intro_pending and not _intro_playing)
	_sync_stage_hp()
	_refresh_stats()
	if _intro_pending and not _intro_playing:
		_play_match_countdown()
	elif not _intro_playing:
		_show_turn_banner()
	if _active_player == _my_index:
		_log("[color=#A5D6A7]あなたのターン[/color]")
	else:
		_log("[color=#B0BEC5]相手のターン[/color]")

func _on_phase_updated(data: Dictionary) -> void:
	_phase = str(data.get("phase", _phase))
	_deadline = int(data.get("deadline", _deadline))

func _on_shop_started(data: Dictionary) -> void:
	_phase = "shop"
	_my_stats["shield"] = 0
	if _board and _board.has_method("clear_pvp_shields"):
		_board.clear_pvp_shields()
	_sync_stage_hp()
	_close_offline_shop()
	if _hud_root:
		_hud_root.visible = true
	_shop_stage = "relic"
	_deadline = int(data.get("deadline", 0))
	_shop_offer_seed = str(data.get("offerSeed", ""))
	_selected_relic = ""
	_shop_done_sent = false
	_shop_panel.visible = true
	_shop_title_lbl.text = "🧪 レリック選択"
	_shop_relic_box.visible = true
	_shop_items_title_lbl.visible = false
	_shop_item_box.visible = false
	_shop_done_btn.visible = false
	_shop_done_btn.disabled = false
	_shop_done_btn.text = "準備完了"
	_shop_note_lbl.text = "レリックを1つ選択してください。"
	_open_offline_relic_selection()
	_advance_pvp_background()
	if _board:
		_board.set_pvp_my_turn(false)
	_log("[color=#CE93D8]5ラウンド経過：レリック選択（20秒）[/color]")

func _open_shop_stage() -> void:
	if _shop_stage == "shop" or _shop_done_sent:
		return
	if _phase != "shop":
		return
	if _net and _net.has_method("remaining_ms") and _net.remaining_ms(_deadline) <= 0:
		return
	_shop_stage = "shop"
	_shop_panel.visible = false
	if _hud_root:
		_hud_root.visible = false
	if _shop_overlay_root:
		_shop_overlay_root.visible = true
	var score_mgr = _stage.get_node_or_null("ScoreManager") if _stage else null
	if score_mgr and score_mgr.has_method("set_shop_ui_visible"):
		score_mgr.set_shop_ui_visible(true)
	# PvPではオフライン用の「前に進む」ボタンを出さない
	if _stage_mgr and "move_front_btn" in _stage_mgr and _stage_mgr.move_front_btn:
		_stage_mgr.move_front_btn.visible = false
	_offline_shop_open = true
	_log("[color=#FFD54F]オフラインと同じショップが開きました。購入後「準備完了」で次へ。[/color]")

func _close_offline_shop(restore_hud: bool = true) -> void:
	var score_mgr = _stage.get_node_or_null("ScoreManager") if _stage else null
	if _offline_shop_open and score_mgr and score_mgr.has_method("set_shop_ui_visible"):
		score_mgr.set_shop_ui_visible(false)
	# オフライン用の下部バーはオンラインでも同じ見た目にするため表示する
	var rui = _stage.get_node_or_null("RelicUIManager") if _stage else null
	if rui and rui.has_method("set_bottom_bars_visible"):
		rui.set_bottom_bars_visible(true)
	if _stage_mgr and "move_front_btn" in _stage_mgr and _stage_mgr.move_front_btn:
		_stage_mgr.move_front_btn.visible = false
	_offline_shop_open = false
	if _shop_overlay_root:
		_shop_overlay_root.visible = false
	if restore_hud and _hud_root:
		_hud_root.visible = true

func _element_category_for_id(el_id: int) -> String:
	match el_id:
		1, 4, 10: # FIRE / THUNDER / EARTH
			return "force"
		2, 3, 8, 9: # WATER / WIND / ICE / WOOD
			return "nature"
		5, 6, 7: # LIGHT / DARK / POISON
			return "mystic"
	return ""

func _relic_matches_category(r_data: Dictionary, chosen_cat: String) -> bool:
	var r_cat: String = str(r_data.get("element_category", ""))
	if r_cat == "all":
		return true
	if r_cat != "":
		return r_cat == chosen_cat
	var inferred_cats: Dictionary = {}
	for lv in r_data.get("levels", []):
		if lv is Dictionary and lv.has("element"):
			var cat: String = _element_category_for_id(int(lv["element"]))
			if cat != "":
				inferred_cats[cat] = true
	if inferred_cats.is_empty():
		return true
	return inferred_cats.has(chosen_cat)

func _starter_skill_name(cat_key: String) -> String:
	match cat_key:
		"nature": return "清流展開"
		"force": return "紅蓮爆破"
		"mystic": return "瘴気毒霧"
	return ""

## オフラインと全く同じレリック選択UIを開く（見た目・操作・挙動を一致させる）
func _open_offline_relic_selection() -> void:
	_shop_panel.visible = false
	if _hud_root:
		_hud_root.visible = true
	var rm = _stage.get_node_or_null("RelicManager") if _stage else null
	var before_lv: Dictionary = {}
	if rm and rm.has_method("get_relic_levels"):
		before_lv = rm.get_relic_levels()
	var ui = load("res://relic_selection_ui.gd").new()
	ui.name = "RelicSelectionUI"
	if _stage:
		_stage.add_child(ui)
	await ui.selection_finished
	if not is_inside_tree():
		return
	# 選ばれたレリック（新規取得 or レベルアップ）を相手へ通知
	var chosen: String = ""
	if rm and rm.has_method("get_relic_levels"):
		var after_lv: Dictionary = rm.get_relic_levels()
		for k in after_lv.keys():
			if int(after_lv[k]) != int(before_lv.get(k, 0)):
				chosen = str(k)
				break
	if chosen != "" and _net and _net.has_method("send_shop_choice"):
		_net.send_shop_choice({ "relicId": chosen })
	_selected_relic = chosen
	_open_shop_stage()

func _build_relic_choices() -> void:
	for child in _shop_relic_box.get_children():
		_shop_relic_box.remove_child(child)
		child.queue_free()
	_shop_relic_ids.clear()

	var rm = _stage.get_node_or_null("RelicManager") if _stage else null
	var chosen_cat: String = ""
	if rm and rm.has_method("get_chosen_element_category"):
		chosen_cat = rm.get_chosen_element_category()

	var font = _make_font()

	# 最初のレリック選択はオフラインと同じ「属性カテゴリー（スキル解放権）」選択
	if chosen_cat == "":
		_shop_title_lbl.text = "🧪 スキル解放権（属性カテゴリー）選択"
		_shop_note_lbl.text = "最初に使用する属性系統を選択してください。選んだ系統のスキルをショップで解放できるようになります。"
		var cat_order: Array[String] = ["nature", "force", "mystic"]
		for key in cat_order:
			var cat: Dictionary = RelicDatabase.ELEMENT_CATEGORIES[key]
			var relic_id: String = str(cat.get("relic_id", "relic_cat_" + key))
			var elements_text: String = "・".join(PackedStringArray(cat.get("elements", [])))
			var btn = _make_button(
				"%s %s\n%s\n\n🔓 スキル解放権を獲得（『%s』など）" % [
					str(cat.get("icon", "")),
					str(cat.get("name", key)),
					elements_text,
					_starter_skill_name(key)
				],
				Color(0.07, 0.09, 0.14, 1.0),
				cat.get("color", Color(0.65, 0.55, 0.95, 1.0)),
				font
			)
			btn.custom_minimum_size = Vector2(0, 96)
			btn.tooltip_text = str(cat.get("desc", ""))
			btn.pressed.connect(_on_relic_selected.bind(relic_id, btn))
			btn.mouse_entered.connect(func(): _play_ui_se("hover"))
			_shop_relic_box.add_child(btn)
			_shop_relic_ids.append(relic_id)
		return

	# 2回目以降は選択済みカテゴリーに合うレリックから3つ提示（オフラインと同じ絞り込み）
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(_shop_offer_seed)
	var keys: Array = []
	for key in RelicDatabase.RELICS.keys():
		var d: Dictionary = RelicDatabase.RELICS[key]
		if str(key).begins_with("relic_cat_"):
			continue
		if not d.has("rarity") or not d.has("name"):
			continue
		if rm and rm.has_method("is_max_level") and rm.is_max_level(str(key)):
			continue
		if not _relic_matches_category(d, chosen_cat):
			continue
		keys.append(key)
	var picked: Array = []
	while picked.size() < 3 and not keys.is_empty():
		var idx: int = rng.randi_range(0, keys.size() - 1)
		picked.append(keys[idx])
		keys.remove_at(idx)

	for key in picked:
		var relic: Dictionary = RelicDatabase.RELICS[key]
		_shop_relic_ids.append(str(key))
		var btn = _make_button(
			"%s  [%s]" % [str(relic.get("name", key)), str(relic.get("rarity", ""))],
			Color(0.10, 0.12, 0.20, 1.0),
			Color(0.65, 0.55, 0.95, 1.0),
			font
		)
		btn.pressed.connect(_on_relic_selected.bind(str(key), btn))
		btn.mouse_entered.connect(func(): _play_ui_se("hover"))
		_shop_relic_box.add_child(btn)

func _on_relic_selected(relic_id: String, btn: Button) -> void:
	if not _selected_relic.is_empty():
		return
	_selected_relic = relic_id
	_play_ui_se("select")
	for child in _shop_relic_box.get_children():
		if child is Button:
			child.modulate = Color(0.65, 0.65, 0.65)
	btn.modulate = Color(1, 1, 1)
	var relic_name: String = str(RelicDatabase.RELICS.get(relic_id, {}).get("name", relic_id))
	_shop_note_lbl.text = "選択中: %s" % relic_name
	var rm = _stage.get_node_or_null("RelicManager") if _stage else null
	if rm and rm.has_method("add_relic"):
		rm.add_relic(relic_id)
	_net.send_shop_choice({ "relicId": relic_id })
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree():
		return
	_open_shop_stage()

func _build_shop_items() -> void:
	for child in _shop_item_box.get_children():
		_shop_item_box.remove_child(child)
		child.queue_free()

	var score_mgr = _stage.get_node_or_null("ScoreManager") if _stage else null
	if score_mgr == null or not ("shop_items" in score_mgr):
		return
	var font = _make_font()
	var count: int = mini(6, score_mgr.shop_items.size())
	for i in range(count):
		var item: Dictionary = score_mgr.shop_items[i]
		var btn = _make_button(
			"%s  Lv%d  %dG" % [str(item.get("name", "")), int(item.get("level", 0)), int(item.get("cost", 0))],
			Color(0.08, 0.12, 0.16, 1.0),
			Color(0.4, 0.75, 1.0, 1.0),
			font
		)
		btn.add_theme_font_size_override("font_size", 16)
		btn.custom_minimum_size = Vector2(0, 42)
		btn.pressed.connect(_on_shop_buy.bind(i))
		btn.mouse_entered.connect(func(): _play_ui_se("hover"))
		btn.pressed.connect(func(): _play_ui_se("select"))
		_shop_item_box.add_child(btn)

func _on_shop_buy(slot_idx: int) -> void:
	var score_mgr = _stage.get_node_or_null("ScoreManager") if _stage else null
	if score_mgr == null or not score_mgr.has_method("_purchase_buff"):
		return
	score_mgr._purchase_buff(slot_idx)
	if _stage_mgr:
		_my_stats["maxHp"] = int(_stage_mgr.myhpmax)
		_my_stats["hp"] = int(_stage_mgr.myhp)
	if "divscore" in score_mgr and score_mgr.divscore.size() > 2:
		_my_stats["coins"] = int(score_mgr.divscore[2])
	_refresh_stats()
	_sync_stage_hp()
	if _net and _net.has_method("send_stats"):
		_net.send_stats(_my_stats)
	_build_shop_items()

func _on_shop_done_pressed() -> void:
	if _shop_done_sent:
		return
	_auto_select_relic_if_needed()
	_play_ui_se("select")
	_shop_done_sent = true
	_shop_done_btn.disabled = true
	_shop_done_btn.text = "準備完了 ✓"
	_close_offline_shop()
	_net.send_shop_done()

func _auto_select_relic_if_needed() -> void:
	if not _selected_relic.is_empty():
		return
	if _shop_relic_ids.is_empty():
		return
	var first_btn = _shop_relic_box.get_child(0) if _shop_relic_box.get_child_count() > 0 else null
	if first_btn is Button:
		_on_relic_selected(str(_shop_relic_ids[0]), first_btn)

func _on_shop_ended(_data: Dictionary) -> void:
	_shop_panel.visible = false
	_close_offline_shop()
	_phase = "turn"
	_log("[color=#A5D6A7]ショップ終了。次のラウンドへ[/color]")

func _on_turn_timed_out(data: Dictionary) -> void:
	_log("[color=#FFB74D]時間切れ：プレイヤー%dは自動パス[/color]" % (int(data.get("player", 0)) + 1))

func _on_shop_timed_out(_data: Dictionary) -> void:
	_auto_select_relic_if_needed()
	_close_offline_shop()
	_log("[color=#FFB74D]ショップ時間切れ：未選択は自動処理[/color]")

func _on_opponent_disconnected(_data: Dictionary) -> void:
	_log("[color=#FFB74D]相手が切断しました。再接続を待っています...[/color]")

func _on_match_resumed(data: Dictionary) -> void:
	_deadline = int(data.get("deadline", _deadline))
	_log("[color=#81C784]再接続しました。対戦を再開します[/color]")

func _on_match_ended(data: Dictionary) -> void:
	var winner: int = int(data.get("winner", -1))
	var reason: String = str(data.get("reason", ""))
	_show_pvp_result(winner, reason)

## PvPの勝敗演出を表示する（match_end 受信時・KO確定時の共通処理）
func _show_pvp_result(winner: int, reason: String = "") -> void:
	if _phase == "ended" and _result_overlay != null and _result_overlay.visible:
		return
	_phase = "ended"
	_shop_panel.visible = false
	_close_offline_shop()
	if _board:
		_board.set_pvp_my_turn(false)
	if winner == _my_index:
		_result_lbl.text = "🏆 YOU WIN!"
	elif winner >= 0:
		_result_lbl.text = "💀 YOU LOSE..."
	else:
		_result_lbl.text = "MATCH END"
	_log("[color=#FFD54F]対戦終了: %s (%s)[/color]" % [_result_lbl.text, reason])
	# オフライン用のゲームオーバー表示を隠して、PvPの勝敗表示を確実に見せる
	if _stage_mgr:
		var go_node = _stage_mgr.get_node_or_null("gameover")
		if go_node:
			go_node.visible = false
	if _result_overlay:
		_result_overlay.visible = true
	_update_hint()
	# レーティング結果を報告
	_report_match_result(winner)

## 試合結果をレーティングAPIに報告してレート変動を表示する
func _report_match_result(winner: int) -> void:
	var net = _net
	if net == null:
		return
	var my_id: String = str(net.my_player_id)
	var opp_id: String = str(net.opponent_player_id)
	if my_id.is_empty() or opp_id.is_empty():
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			http.queue_free()
			return
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json == null or typeof(json) != TYPE_DICTIONARY:
			http.queue_free()
			return
		var i_won: bool = (winner == _my_index)
		var my_data = json.get("winner" if i_won else "loser", {})
		var my_delta: int = int(json.get("winnerDelta" if i_won else "loserDelta", 0))
		var my_rating: int = int(my_data.get("rating", 0))
		var color_hex: String = str(my_data.get("color", "#00C8C8"))
		if _rating_change_lbl:
			var sign: String = "+" if my_delta >= 0 else ""
			_rating_change_lbl.text = "レート: %d (%s%d)" % [my_rating, sign, my_delta]
			_rating_change_lbl.add_theme_color_override("font_color", Color.from_string(color_hex, Color(0.4, 0.9, 1.0)))
			_rating_change_lbl.visible = true
		http.queue_free()
	, CONNECT_ONE_SHOT)
	var winner_id: String = my_id if winner == _my_index else opp_id
	var loser_id: String = opp_id if winner == _my_index else my_id
	var body := JSON.stringify({"winnerId": winner_id, "loserId": loser_id, "draw": winner < 0})
	var headers := PackedStringArray(["Content-Type: application/json"])
	http.request("https://roguelike-puzzle-online.roguelikepuzzle1120.workers.dev/matchmake/result", headers, HTTPClient.METHOD_POST, body)

func _on_connection_closed(code: int, reason: String) -> void:
	_log("[color=#FF5252]接続が切れました (%d %s)[/color]" % [code, reason])

func _on_network_error(message: String) -> void:
	_log("[color=#FF5252]通信エラー: %s[/color]" % message)

func _on_reconnecting(attempt: int, max_attempts: int) -> void:
	_log("[color=#FFB74D]再接続中... (%d/%d)[/color]" % [attempt, max_attempts])

func _on_back_pressed() -> void:
	if _net:
		_net.pvp_mode = false
		_net.close()
	get_tree().change_scene_to_file(TITLE_SCENE)

func _on_leave_pressed() -> void:
	if _net:
		if _phase != "ended":
			_net.send_surrender()
		_net.pvp_mode = false
		_net.close()
	get_tree().change_scene_to_file(TITLE_SCENE)

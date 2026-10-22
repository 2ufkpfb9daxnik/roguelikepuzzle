extends Node

## グローバル設定マネージャー（Autoload: SettingsManager）
## 音量調整（BGM・SE）、ゲーム速度調整（全体速度＆オーディオ速度連動）、共通設定画面UIを提供

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")

# 設定値
var bgm_volume: float = 0.2   # 0.0 ~ 1.0
var se_volume: float = 0.2    # 0.0 ~ 1.0
var game_speed: float = 1.0   # 0.5 ~ 3.0

enum Difficulty {
	EASY = 0,
	NORMAL = 1,
	HARD = 2
}

var difficulty: int = Difficulty.NORMAL
signal difficulty_changed(new_diff: int)

const DIFFICULTY_NAMES: Dictionary = {
	Difficulty.EASY: "EASY",
	Difficulty.NORMAL: "NORMAL",
	Difficulty.HARD: "HARD"
}

const DIFFICULTY_LABELS: Dictionary = {
	Difficulty.EASY: "イージー (EASY)",
	Difficulty.NORMAL: "ノーマル (NORMAL)",
	Difficulty.HARD: "ハード (HARD)"
}

const DIFFICULTY_DESCS: Dictionary = {
	Difficulty.EASY: "敵の体力・攻撃力・スキル強度が約30%低下。初心者やカジュアルに楽しみたい方向け。",
	Difficulty.NORMAL: "標準的な難易度。通常のゲームバランスで楽しめます。",
	Difficulty.HARD: "敵の体力+40%、攻撃力+35%、スキル強度+35%。戦略と連鎖が試される上級者向け。"
}

const DIFFICULTY_HP_MULTS: Dictionary = {
	Difficulty.EASY: 0.75,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.40
}

const DIFFICULTY_ATK_MULTS: Dictionary = {
	Difficulty.EASY: 0.75,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.35
}

const DIFFICULTY_SKILL_MULTS: Dictionary = {
	Difficulty.EASY: 0.70,
	Difficulty.NORMAL: 1.0,
	Difficulty.HARD: 1.35
}

func get_difficulty_hp_mult() -> float:
	return DIFFICULTY_HP_MULTS.get(difficulty, 1.0)

func get_difficulty_atk_mult() -> float:
	return DIFFICULTY_ATK_MULTS.get(difficulty, 1.0)

func get_difficulty_skill_mult() -> float:
	return DIFFICULTY_SKILL_MULTS.get(difficulty, 1.0)

func set_difficulty(d: int) -> void:
	difficulty = clampi(d, Difficulty.EASY, Difficulty.HARD)
	emit_signal("difficulty_changed", difficulty)

func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES.get(difficulty, "NORMAL")

# 元のピッチ記憶用 Dictionary: { Node: float }
var _default_pitches: Dictionary = {}

# モーダルダイアログ関連
var _dialog_canvas: CanvasLayer = null
var _is_dialog_open: bool = false
var _was_paused_before_open: bool = false

# BGMとして認識するノード名キーワード
const BGM_KEYWORDS: Array[String] = [
	"bgm", "fieldbgm", "feverbgm", "bossbgm", "maoubgm", "ending", "titlebgm"
]

# SE音量ノーマライゼーションオフセット（全効果音の聴感音量を均一に揃えるキャリブレーション値）
const SE_NORMALIZATION_OFFSETS: Dictionary = {
	"gekiha": -12.0,
	"click": -5.5,
	"cancel": -2.0,
	"stagekirikae": -3.0,
	"coinsound": 0.0,
	"kaihuku": 0.0,
	"danger": 0.0,
	"lastbossclear": 0.0,
	"syutsugen": 0.0,
	"shieldmove": +1.5,
	"anten": +2.0,
	"haiboku": +3.5,
	"block": +4.0,
	"1rensa": +5.2,
	"potion": +8.5,
	"AudioStreamPlayer2": +12.0,
	"AudioStreamPlayer": +12.5,
	"fevertime": +14.0,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_ensure_fullscreen_startup")
	
	# 日本語フォントフォールバックの設定
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	var t = _get_tree_safe()
	if t and not t.node_added.is_connected(_on_node_added):
		t.node_added.connect(_on_node_added)
		
	apply_all_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_check_and_fix_maximized_window()

## 初回起動時の全画面保証
func _ensure_fullscreen_startup() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

## Windows での最大化時に発生するタイトルバーオフセットバグを物理的に回避
func _check_and_fix_maximized_window() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		call_deferred("_apply_fullscreen_fix")

func _apply_fullscreen_fix() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
			if get_viewport(): get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER and event.alt_pressed:
			toggle_fullscreen()
			if get_viewport(): get_viewport().set_input_as_handled()

## 画面表示モードの変更
func set_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
		var screen_rect = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var center_x = screen_rect.position.x + (screen_rect.size.x - 1600) / 2
		var center_y = screen_rect.position.y + (screen_rect.size.y - 900) / 2
		DisplayServer.window_set_position(Vector2i(center_x, center_y))

func is_fullscreen() -> bool:
	var mode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())

func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		_apply_settings_to_node(node)

func _get_tree_safe() -> SceneTree:
	if is_inside_tree() and get_tree():
		return get_tree()
	var ml = Engine.get_main_loop()
	if ml is SceneTree:
		return ml
	return null

func _get_scene_root() -> Node:
	var t = _get_tree_safe()
	if t:
		return t.root
	return null

func _process(_delta: float) -> void:
	Engine.time_scale = game_speed

## ゲーム速度の変更と反映（全体速度＋BGM・効果音速度に完全連動）
func set_game_speed(val: float) -> void:
	game_speed = clampf(val, 0.5, 3.0)
	Engine.time_scale = game_speed
	var r = _get_scene_root()
	if r:
		_sync_audio_nodes(r)

## BGM音量の変更と反映
func set_bgm_volume(val: float) -> void:
	bgm_volume = clampf(val, 0.0, 1.0)
	var r = _get_scene_root()
	if r:
		_sync_audio_nodes(r)

## SE音量の変更と反映
func set_se_volume(val: float) -> void:
	se_volume = clampf(val, 0.0, 1.0)
	var r = _get_scene_root()
	if r:
		_sync_audio_nodes(r)

## 全設定の一括適用
func apply_all_settings() -> void:
	Engine.time_scale = game_speed
	var r = _get_scene_root()
	if r:
		_sync_audio_nodes(r)

## ノードがBGMかSEかを判定
func is_bgm_node(node: Node) -> bool:
	var lower_name = node.name.to_lower()
	for kw in BGM_KEYWORDS:
		if kw in lower_name:
			return true
	return false

## SE名からノーマライゼーションオフセットを取得
func get_se_normalized_offset(node_name: String) -> float:
	if SE_NORMALIZATION_OFFSETS.has(node_name):
		return SE_NORMALIZATION_OFFSETS[node_name]
	var lower = node_name.to_lower()
	for k in SE_NORMALIZATION_OFFSETS.keys():
		if str(k).to_lower() == lower:
			return SE_NORMALIZATION_OFFSETS[k]
	return 0.0

## 単一オーディオノードへの設定適用（ピッチ連動 ＆ 均一音量ノーマライゼーション）
func _apply_settings_to_node(node: Node) -> void:
	if node == null:
		return
	if not (node is AudioStreamPlayer or node is AudioStreamPlayer2D):
		return
		
	var is_bgm = is_bgm_node(node)
	
	# ピッチ設定（連鎖数に応じて動的にピッチ変更する 1rensa は除外）
	if node.name != "1rensa":
		if not _default_pitches.has(node):
			_default_pitches[node] = node.pitch_scale
		var orig_pitch: float = _default_pitches[node]
		node.pitch_scale = orig_pitch * game_speed
	
	# 音量適用（全効果音を同一の聴感音量にノーマライズ）
	if is_bgm:
		if bgm_volume <= 0.001:
			node.volume_db = -80.0
		else:
			node.volume_db = linear_to_db(bgm_volume)
	else:
		if se_volume <= 0.001:
			node.volume_db = -80.0
		else:
			var offset = get_se_normalized_offset(node.name)
			node.volume_db = offset + linear_to_db(se_volume)
			
	# AudioStreamPlayer2D の場合、位置による減衰をゼロにして画面全体で均一に聞こえるように設定
	if node is AudioStreamPlayer2D:
		node.attenuation = 0.0
		node.panning_strength = 0.0

## シーンツリー内の全AudioStreamPlayer / AudioStreamPlayer2Dを再帰更新
func _sync_audio_nodes(parent: Node) -> void:
	if parent == null:
		return
		
	if parent is AudioStreamPlayer or parent is AudioStreamPlayer2D:
		_apply_settings_to_node(parent)
			
	for child in parent.get_children():
		_sync_audio_nodes(child)

## 設定画面モーダルダイアログの表示
func open_settings() -> void:
	if _is_dialog_open:
		return
		
	_is_dialog_open = true
	var t = _get_tree_safe()
	if t:
		_was_paused_before_open = t.paused
		t.paused = true
	
	_create_settings_dialog()

## 設定画面モーダルダイアログの終了
func close_settings() -> void:
	if not _is_dialog_open:
		return
		
	_is_dialog_open = false
	if _dialog_canvas and is_instance_valid(_dialog_canvas):
		_dialog_canvas.queue_free()
		_dialog_canvas = null
		
	# 開く前のポーズ状態に復帰
	var t = _get_tree_safe()
	if t:
		t.paused = _was_paused_before_open
	apply_all_settings()

## 設定ダイアログのUI生成
func _create_settings_dialog() -> void:
	_dialog_canvas = CanvasLayer.new()
	_dialog_canvas.layer = 100 # 最前面レイヤー
	_dialog_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_dialog_canvas)
	
	# 画面全体を覆うRoot Control（全解像度・リサイズに完全追従）
	var root_ctrl = Control.new()
	root_ctrl.name = "SettingsRoot"
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_canvas.add_child(root_ctrl)
	
	# 背景半透明ディマー（画面全体の暗転＋クリック遮断）
	var blocker = ColorRect.new()
	blocker.name = "Blocker"
	blocker.color = Color(0, 0, 0, 0.65)
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ctrl.add_child(blocker)
	
	# 中央モーダルパネル（カジノ風ダークゴールドフレーム）
	var panel_w = 860.0
	var panel_h = 860.0
	var modal = Control.new()
	modal.name = "ModalPanel"
	modal.size = Vector2(panel_w, panel_h)
	modal.custom_minimum_size = Vector2(panel_w, panel_h)
	root_ctrl.add_child(modal)
	
	var update_modal_pos = func():
		var vp_sz = root_ctrl.size
		if vp_sz.x <= 0 or vp_sz.y <= 0:
			var vp = root_ctrl.get_viewport()
			if vp: vp_sz = vp.get_visible_rect().size
		if vp_sz.x <= 0: vp_sz = Vector2(1920, 1080)
		modal.position = ((vp_sz - Vector2(panel_w, panel_h)) * 0.5).round()
	
	update_modal_pos.call()
	root_ctrl.resized.connect(update_modal_pos)
	
	var outer_border = ColorRect.new()
	outer_border.color = Color(0.96, 0.78, 0.1, 1.0) # ゴールド枠
	outer_border.position = Vector2(-4, -4)
	outer_border.size = Vector2(panel_w + 8, panel_h + 8)
	outer_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(outer_border)
	
	var inner_panel = ColorRect.new()
	inner_panel.color = Color(0.08, 0.08, 0.12, 0.96) # 高級感あるダークネイビー
	inner_panel.position = Vector2.ZERO
	inner_panel.size = Vector2(panel_w, panel_h)
	inner_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(inner_panel)
	
	# ダイアログタイトル
	var title_lbl = RichTextLabel.new()
	title_lbl.bbcode_enabled = true
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
	title_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
	title_lbl.add_theme_constant_override("outline_size", 10)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_lbl.add_theme_font_size_override("normal_font_size", 42)
	title_lbl.add_theme_font_size_override("bold_font_size", 42)
	title_lbl.position = Vector2(0, 20)
	title_lbl.size = Vector2(panel_w, 56)
	title_lbl.text = "[center][b][color=#FFD700]⚙ 設定 - SETTINGS ⚙[/color][/b][/center]"
	modal.add_child(title_lbl)
	
	# --- 1. BGM 音量 ---
	var cur_y = 96.0
	var bgm_title = Label.new()
	bgm_title.text = "🎵 BGM 音量"
	bgm_title.add_theme_font_override("font", CUSTOM_FONT)
	bgm_title.add_theme_font_size_override("font_size", 24)
	bgm_title.position = Vector2(50, cur_y)
	modal.add_child(bgm_title)
	
	var bgm_val_lbl = Label.new()
	bgm_val_lbl.text = "%d%%" % int(bgm_volume * 100)
	bgm_val_lbl.add_theme_font_override("font", CUSTOM_FONT)
	bgm_val_lbl.add_theme_font_size_override("font_size", 24)
	bgm_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_val_lbl.position = Vector2(panel_w - 180, cur_y)
	bgm_val_lbl.size = Vector2(130, 32)
	modal.add_child(bgm_val_lbl)
	
	var bgm_slider = HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 100.0
	bgm_slider.step = 1.0
	bgm_slider.value = bgm_volume * 100.0
	bgm_slider.position = Vector2(50, cur_y + 34)
	bgm_slider.size = Vector2(panel_w - 100, 30)
	bgm_slider.value_changed.connect(func(v):
		set_bgm_volume(v / 100.0)
		bgm_val_lbl.text = "%d%%" % int(v)
	)
	modal.add_child(bgm_slider)
	
	# --- 2. SE（効果音）音量 ---
	cur_y += 84.0
	var se_title = Label.new()
	se_title.text = "🔔 SE (効果音) 音量"
	se_title.add_theme_font_override("font", CUSTOM_FONT)
	se_title.add_theme_font_size_override("font_size", 24)
	se_title.position = Vector2(50, cur_y)
	modal.add_child(se_title)
	
	var se_val_lbl = Label.new()
	se_val_lbl.text = "%d%%" % int(se_volume * 100)
	se_val_lbl.add_theme_font_override("font", CUSTOM_FONT)
	se_val_lbl.add_theme_font_size_override("font_size", 24)
	se_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	se_val_lbl.position = Vector2(panel_w - 180, cur_y)
	se_val_lbl.size = Vector2(130, 32)
	modal.add_child(se_val_lbl)
	
	var se_slider = HSlider.new()
	se_slider.min_value = 0.0
	se_slider.max_value = 100.0
	se_slider.step = 1.0
	se_slider.value = se_volume * 100.0
	se_slider.position = Vector2(50, cur_y + 34)
	se_slider.size = Vector2(panel_w - 100, 30)
	se_slider.value_changed.connect(func(v):
		set_se_volume(v / 100.0)
		se_val_lbl.text = "%d%%" % int(v)
	)
	modal.add_child(se_slider)
	
	# --- 3. 画面表示モード (フルスクリーン / ウィンドウ) ---
	cur_y += 84.0
	var screen_title = Label.new()
	screen_title.text = "🖥 画面表示モード (F11 / Alt+Enter で即時切替可)"
	screen_title.add_theme_font_override("font", CUSTOM_FONT)
	screen_title.add_theme_font_size_override("font_size", 24)
	screen_title.position = Vector2(50, cur_y)
	modal.add_child(screen_title)
	
	var fs_btn_w = (panel_w - 100.0 - 24.0) / 2.0
	var fs_btn = Button.new()
	var win_btn = Button.new()
	
	var update_screen_btns_visual = func():
		var is_fs = is_fullscreen()
		fs_btn.text = "🖥 全画面 (フルスクリーン - 推奨)" if is_fs else "🖥 全画面にする"
		win_btn.text = "🪟 ウィンドウにする" if is_fs else "🪟 ウィンドウ (1600x900)"
		
		# スタイル適用
		var style_active = StyleBoxFlat.new()
		style_active.bg_color = Color(0.15, 0.28, 0.45, 0.96)
		style_active.border_color = Color(0.0, 0.9, 1.0, 1.0)
		style_active.set_border_width_all(3)
		style_active.set_corner_radius_all(10)
		
		var style_inactive = StyleBoxFlat.new()
		style_inactive.bg_color = Color(0.12, 0.14, 0.20, 0.85)
		style_inactive.border_color = Color(0.4, 0.45, 0.55, 0.8)
		style_inactive.set_border_width_all(2)
		style_inactive.set_corner_radius_all(10)
		
		fs_btn.add_theme_stylebox_override("normal", style_active if is_fs else style_inactive)
		win_btn.add_theme_stylebox_override("normal", style_inactive if is_fs else style_active)
	
	fs_btn.add_theme_font_override("font", CUSTOM_FONT)
	fs_btn.add_theme_font_size_override("font_size", 20)
	fs_btn.position = Vector2(50, cur_y + 36)
	fs_btn.size = Vector2(fs_btn_w, 44)
	fs_btn.pressed.connect(func():
		set_fullscreen(true)
		update_screen_btns_visual.call()
	)
	modal.add_child(fs_btn)
	
	win_btn.add_theme_font_override("font", CUSTOM_FONT)
	win_btn.add_theme_font_size_override("font_size", 20)
	win_btn.position = Vector2(50 + fs_btn_w + 24.0, cur_y + 36)
	win_btn.size = Vector2(fs_btn_w, 44)
	win_btn.pressed.connect(func():
		set_fullscreen(false)
		update_screen_btns_visual.call()
	)
	modal.add_child(win_btn)
	
	update_screen_btns_visual.call()
	
	# --- 4. ゲーム速度（全体速度 ＆ BGM/SE速度連動） ---
	cur_y += 100.0
	var spd_title = Label.new()
	spd_title.text = "⚡ ゲーム＆サウンド速度"
	spd_title.add_theme_font_override("font", CUSTOM_FONT)
	spd_title.add_theme_font_size_override("font_size", 24)
	spd_title.position = Vector2(50, cur_y)
	modal.add_child(spd_title)
	
	var spd_val_lbl = Label.new()
	spd_val_lbl.text = "%.1fx" % game_speed
	spd_val_lbl.add_theme_font_override("font", CUSTOM_FONT)
	spd_val_lbl.add_theme_font_size_override("font_size", 24)
	spd_val_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	spd_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spd_val_lbl.position = Vector2(panel_w - 180, cur_y)
	spd_val_lbl.size = Vector2(130, 32)
	modal.add_child(spd_val_lbl)
	
	var spd_slider = HSlider.new()
	spd_slider.min_value = 0.5
	spd_slider.max_value = 3.0
	spd_slider.step = 0.1
	spd_slider.value = game_speed
	spd_slider.position = Vector2(50, cur_y + 34)
	spd_slider.size = Vector2(panel_w - 100, 30)
	modal.add_child(spd_slider)
	
	# 速度プリセットボタン [0.5x] [1.0x] [1.5x] [2.0x] [3.0x]
	var presets = [0.5, 1.0, 1.5, 2.0, 3.0]
	var btn_w = 126.0
	var btn_pitch = (panel_w - 100.0 - btn_w * presets.size()) / (presets.size() - 1)
	for i in range(presets.size()):
		var p_val = presets[i]
		var p_btn = Button.new()
		p_btn.text = "%.1fx" % p_val
		p_btn.add_theme_font_override("font", CUSTOM_FONT)
		p_btn.add_theme_font_size_override("font_size", 20)
		p_btn.position = Vector2(50 + (btn_w + btn_pitch) * i, cur_y + 74)
		p_btn.size = Vector2(btn_w, 38)
		p_btn.pressed.connect(func():
			spd_slider.value = p_val
			set_game_speed(p_val)
			spd_val_lbl.text = "%.1fx" % p_val
		)
		modal.add_child(p_btn)
		
	spd_slider.value_changed.connect(func(v):
		set_game_speed(v)
		spd_val_lbl.text = "%.1fx" % v
	)
	
	# --- 5. 難易度設定 (DIFFICULTY) ---
	cur_y += 128.0
	var diff_title = Label.new()
	diff_title.text = "👑 ゲーム難易度 (DIFFICULTY)"
	diff_title.add_theme_font_override("font", CUSTOM_FONT)
	diff_title.add_theme_font_size_override("font_size", 24)
	diff_title.position = Vector2(50, cur_y)
	modal.add_child(diff_title)

	var diff_desc_modal = RichTextLabel.new()
	diff_desc_modal.bbcode_enabled = true
	diff_desc_modal.fit_content = false
	diff_desc_modal.scroll_active = false
	diff_desc_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diff_desc_modal.add_theme_font_override("normal_font", CUSTOM_FONT)
	diff_desc_modal.add_theme_font_size_override("normal_font_size", 18)
	diff_desc_modal.position = Vector2(50, cur_y + 80)
	diff_desc_modal.size = Vector2(panel_w - 100, 30)
	modal.add_child(diff_desc_modal)

	var diff_btn_w = (panel_w - 100.0 - 24.0) / 3.0
	var diff_btns: Array[Button] = []
	var diff_data = [
		{"name": "EASY", "diff": Difficulty.EASY, "color": Color(0.0, 0.95, 1.0)},
		{"name": "NORMAL", "diff": Difficulty.NORMAL, "color": Color(1.0, 0.84, 0.0)},
		{"name": "HARD", "diff": Difficulty.HARD, "color": Color(1.0, 0.28, 0.28)}
	]

	var update_diff_modal_visual = func():
		for i in range(diff_btns.size()):
			var b = diff_btns[i]
			var d_item = diff_data[i]
			var is_sel = (d_item["diff"] == difficulty)
			var st = StyleBoxFlat.new()
			st.set_corner_radius_all(10)
			if is_sel:
				st.set_border_width_all(3)
				st.border_color = d_item["color"]
				st.bg_color = d_item["color"].darkened(0.7)
				st.bg_color.a = 0.95
				b.text = "★ " + d_item["name"]
				b.add_theme_color_override("font_color", d_item["color"])
			else:
				st.set_border_width_all(2)
				st.border_color = Color(0.4, 0.45, 0.55, 0.8)
				st.bg_color = Color(0.12, 0.14, 0.20, 0.85)
				b.text = d_item["name"]
				b.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
			b.add_theme_stylebox_override("normal", st)
		diff_desc_modal.text = "[color=#E0E0E0]%s[/color]" % DIFFICULTY_DESCS.get(difficulty, "")

	for i in range(diff_data.size()):
		var d_info = diff_data[i]
		var d_btn = Button.new()
		d_btn.add_theme_font_override("font", CUSTOM_FONT)
		d_btn.add_theme_font_size_override("font_size", 22)
		d_btn.position = Vector2(50 + (diff_btn_w + 12.0) * i, cur_y + 36)
		d_btn.size = Vector2(diff_btn_w, 40)
		var target_diff = d_info["diff"]
		d_btn.pressed.connect(func():
			set_difficulty(target_diff)
			update_diff_modal_visual.call()
		)
		modal.add_child(d_btn)
		diff_btns.append(d_btn)

	update_diff_modal_visual.call()

	# --- 6. 「タイトルへ戻る」「ゲーム終了」「閉じる」ボタン ---
	var current_scene_name = ""
	var tree = _get_tree_safe()
	if tree and tree.current_scene:
		current_scene_name = tree.current_scene.name
	var is_on_title = (current_scene_name == "TitleScreen")

	var btn_y = panel_h - 80.0

	if is_on_title:
		# タイトル画面時: 「閉じる」ボタンのみ（中央配置）
		var t_btn_w = 400.0
		var t_start_x = (panel_w - t_btn_w) / 2.0

		var close_btn = Button.new()
		close_btn.text = "閉じる (CLOSE)"
		close_btn.add_theme_font_override("font", CUSTOM_FONT)
		close_btn.add_theme_font_size_override("font_size", 26)
		close_btn.add_theme_constant_override("outline_size", 6)
		close_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		close_btn.position = Vector2(t_start_x, btn_y)
		close_btn.size = Vector2(t_btn_w, 56)
		close_btn.pressed.connect(func():
			close_settings()
		)
		modal.add_child(close_btn)
	else:
		# インゲーム時: 「タイトルへ戻る」「閉じる」の2ボタン（中央配置）
		var g_btn_w = 340.0
		var g_gap = 36.0
		var g_start_x = (panel_w - (g_btn_w * 2.0 + g_gap)) / 2.0

		var title_btn = Button.new()
		title_btn.text = "タイトルへ戻る"
		title_btn.add_theme_font_override("font", CUSTOM_FONT)
		title_btn.add_theme_font_size_override("font_size", 24)
		title_btn.add_theme_constant_override("outline_size", 6)
		title_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		title_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		title_btn.position = Vector2(g_start_x, btn_y)
		title_btn.size = Vector2(g_btn_w, 56)
		title_btn.pressed.connect(func():
			close_settings()
			Engine.time_scale = 1.0
			var t = _get_tree_safe()
			if t:
				t.change_scene_to_file("res://title_screen.tscn")
		)
		modal.add_child(title_btn)

		var close_btn = Button.new()
		close_btn.text = "閉じる (CLOSE)"
		close_btn.add_theme_font_override("font", CUSTOM_FONT)
		close_btn.add_theme_font_size_override("font_size", 24)
		close_btn.add_theme_constant_override("outline_size", 6)
		close_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		close_btn.position = Vector2(g_start_x + g_btn_w + g_gap, btn_y)
		close_btn.size = Vector2(g_btn_w, 56)
		close_btn.pressed.connect(func():
			close_settings()
		)
		modal.add_child(close_btn)



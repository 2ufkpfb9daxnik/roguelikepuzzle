extends Node

## グローバル設定マネージャー（Autoload: SettingsManager）
## 音量調整（BGM・SE）、ゲーム速度調整（全体速度＆オーディオ速度連動）、共通設定画面UIを提供

const CUSTOM_FONT: Font = preload("res://font/g_comickoin_freeR.ttf")

# 設定値
var bgm_volume: float = 0.8   # 0.0 ~ 1.0
var se_volume: float = 0.8    # 0.0 ~ 1.0
var game_speed: float = 1.0   # 0.5 ~ 3.0

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
	
	# 日本語フォントフォールバックの設定
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	var t = _get_tree_safe()
	if t and not t.node_added.is_connected(_on_node_added):
		t.node_added.connect(_on_node_added)
		
	apply_all_settings()

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
	
	# 背景半透明ディマー（画面全体の暗転＋クリック遮断）
	var blocker = ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.65)
	blocker.position = Vector2.ZERO
	blocker.size = Vector2(1920, 1080)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_canvas.add_child(blocker)
	
	# 中央モーダルパネル（カジノ風ダークゴールドフレーム）
	var panel_w = 820.0
	var panel_h = 640.0
	var panel_x = (1920.0 - panel_w) / 2.0
	var panel_y = (1080.0 - panel_h) / 2.0
	
	var outer_border = ColorRect.new()
	outer_border.color = Color(0.96, 0.78, 0.1, 1.0) # ゴールド枠
	outer_border.position = Vector2(panel_x - 4, panel_y - 4)
	outer_border.size = Vector2(panel_w + 8, panel_h + 8)
	_dialog_canvas.add_child(outer_border)
	
	var inner_panel = ColorRect.new()
	inner_panel.color = Color(0.08, 0.08, 0.12, 0.96) # 高級感あるダークネイビー
	inner_panel.position = Vector2(panel_x, panel_y)
	inner_panel.size = Vector2(panel_w, panel_h)
	_dialog_canvas.add_child(inner_panel)
	
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
	title_lbl.position = Vector2(panel_x, panel_y + 24)
	title_lbl.size = Vector2(panel_w, 60)
	title_lbl.text = "[center][b][color=#FFD700]⚙ 設定 - SETTINGS ⚙[/color][/b][/center]"
	_dialog_canvas.add_child(title_lbl)
	
	# --- 1. BGM 音量 ---
	var cur_y = panel_y + 110.0
	var bgm_title = Label.new()
	bgm_title.text = "🎵 BGM 音量"
	bgm_title.add_theme_font_override("font", CUSTOM_FONT)
	bgm_title.add_theme_font_size_override("font_size", 26)
	bgm_title.position = Vector2(panel_x + 50, cur_y)
	_dialog_canvas.add_child(bgm_title)
	
	var bgm_val_lbl = Label.new()
	bgm_val_lbl.text = "%d%%" % int(bgm_volume * 100)
	bgm_val_lbl.add_theme_font_override("font", CUSTOM_FONT)
	bgm_val_lbl.add_theme_font_size_override("font_size", 26)
	bgm_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_val_lbl.position = Vector2(panel_x + panel_w - 180, cur_y)
	bgm_val_lbl.size = Vector2(130, 36)
	_dialog_canvas.add_child(bgm_val_lbl)
	
	var bgm_slider = HSlider.new()
	bgm_slider.min_value = 0.0
	bgm_slider.max_value = 100.0
	bgm_slider.step = 1.0
	bgm_slider.value = bgm_volume * 100.0
	bgm_slider.position = Vector2(panel_x + 50, cur_y + 38)
	bgm_slider.size = Vector2(panel_w - 100, 32)
	bgm_slider.value_changed.connect(func(v):
		set_bgm_volume(v / 100.0)
		bgm_val_lbl.text = "%d%%" % int(v)
	)
	_dialog_canvas.add_child(bgm_slider)
	
	# --- 2. SE（効果音）音量 ---
	cur_y += 95.0
	var se_title = Label.new()
	se_title.text = "🔔 SE (効果音) 音量"
	se_title.add_theme_font_override("font", CUSTOM_FONT)
	se_title.add_theme_font_size_override("font_size", 26)
	se_title.position = Vector2(panel_x + 50, cur_y)
	_dialog_canvas.add_child(se_title)
	
	var se_val_lbl = Label.new()
	se_val_lbl.text = "%d%%" % int(se_volume * 100)
	se_val_lbl.add_theme_font_override("font", CUSTOM_FONT)
	se_val_lbl.add_theme_font_size_override("font_size", 26)
	se_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	se_val_lbl.position = Vector2(panel_x + panel_w - 180, cur_y)
	se_val_lbl.size = Vector2(130, 36)
	_dialog_canvas.add_child(se_val_lbl)
	
	var se_slider = HSlider.new()
	se_slider.min_value = 0.0
	se_slider.max_value = 100.0
	se_slider.step = 1.0
	se_slider.value = se_volume * 100.0
	se_slider.position = Vector2(panel_x + 50, cur_y + 38)
	se_slider.size = Vector2(panel_w - 100, 32)
	se_slider.value_changed.connect(func(v):
		set_se_volume(v / 100.0)
		se_val_lbl.text = "%d%%" % int(v)
	)
	_dialog_canvas.add_child(se_slider)
	
	# --- 3. ゲーム速度（全体速度 ＆ BGM/SE速度連動） ---
	cur_y += 95.0
	var spd_title = Label.new()
	spd_title.text = "⚡ ゲーム＆サウンド速度"
	spd_title.add_theme_font_override("font", CUSTOM_FONT)
	spd_title.add_theme_font_size_override("font_size", 26)
	spd_title.position = Vector2(panel_x + 50, cur_y)
	_dialog_canvas.add_child(spd_title)
	
	var spd_val_lbl = Label.new()
	spd_val_lbl.text = "%.1fx" % game_speed
	spd_val_lbl.add_theme_font_override("font", CUSTOM_FONT)
	spd_val_lbl.add_theme_font_size_override("font_size", 26)
	spd_val_lbl.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	spd_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spd_val_lbl.position = Vector2(panel_x + panel_w - 180, cur_y)
	spd_val_lbl.size = Vector2(130, 36)
	_dialog_canvas.add_child(spd_val_lbl)
	
	var spd_slider = HSlider.new()
	spd_slider.min_value = 0.5
	spd_slider.max_value = 3.0
	spd_slider.step = 0.1
	spd_slider.value = game_speed
	spd_slider.position = Vector2(panel_x + 50, cur_y + 38)
	spd_slider.size = Vector2(panel_w - 100, 32)
	_dialog_canvas.add_child(spd_slider)
	
	# 速度プリセットボタン [0.5x] [1.0x] [1.5x] [2.0x] [3.0x]
	var presets = [0.5, 1.0, 1.5, 2.0, 3.0]
	var btn_w = 120.0
	var btn_pitch = (panel_w - 100.0 - btn_w * presets.size()) / (presets.size() - 1)
	for i in range(presets.size()):
		var p_val = presets[i]
		var p_btn = Button.new()
		p_btn.text = "%.1fx" % p_val
		p_btn.add_theme_font_override("font", CUSTOM_FONT)
		p_btn.add_theme_font_size_override("font_size", 20)
		p_btn.position = Vector2(panel_x + 50 + (btn_w + btn_pitch) * i, cur_y + 80)
		p_btn.size = Vector2(btn_w, 40)
		p_btn.pressed.connect(func():
			spd_slider.value = p_val
			set_game_speed(p_val)
			spd_val_lbl.text = "%.1fx" % p_val
		)
		_dialog_canvas.add_child(p_btn)
		
	spd_slider.value_changed.connect(func(v):
		set_game_speed(v)
		spd_val_lbl.text = "%.1fx" % v
	)
	
	# --- 4. 「閉じる」ボタン ---
	var close_btn = Button.new()
	close_btn.text = "閉じる (CLOSE)"
	close_btn.add_theme_font_override("font", CUSTOM_FONT)
	close_btn.add_theme_font_size_override("font_size", 30)
	close_btn.add_theme_constant_override("outline_size", 6)
	close_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	close_btn.position = Vector2(panel_x + (panel_w - 280) / 2.0, panel_y + panel_h - 85)
	close_btn.size = Vector2(280, 58)
	close_btn.pressed.connect(func():
		close_settings()
	)
	_dialog_canvas.add_child(close_btn)

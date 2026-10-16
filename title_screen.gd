extends Control

## タイトル画面シーン

var isclicked: bool = false
var interval: int = 0

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

@onready var title_bgm: AudioStreamPlayer2D = get_node_or_null("titlebgm")
@onready var click_se: AudioStreamPlayer2D = get_node_or_null("click")
@onready var anten_rect: ColorRect = get_node_or_null("anten")
@onready var title_label: RichTextLabel = get_node_or_null("RichTextLabel")
@onready var title_label2: RichTextLabel = get_node_or_null("RichTextLabel2")
@onready var desc_label: RichTextLabel = get_node_or_null("description")
@onready var desc_label2: RichTextLabel = get_node_or_null("description2")
@onready var start_btn: Button = get_node_or_null("Button")
var settings_btn: Button = null
var quit_btn: Button = null

func _ready() -> void:
	# ルートControlを確実に全画面（Full Rect）に初期化
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	if title_bgm:
		title_bgm.play()

	# 次のステージシーン（current_stage.tscn）をバックグラウンドで非同期先読み開始
	ResourceLoader.load_threaded_request("res://current_stage.tscn")

	_setup_ui_elements()
	_update_layout()

	# ウィンドウリサイズ・最大化・解像度変更時に即座にレイアウトを再計算
	if get_viewport():
		get_viewport().size_changed.connect(_update_layout)

func _setup_ui_elements() -> void:
	if anten_rect:
		anten_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if title_label != null:
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		title_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		title_label.add_theme_constant_override("outline_size", 16)
		title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		title_label.add_theme_font_size_override("normal_font_size", 136)
		title_label.add_theme_font_size_override("bold_font_size", 136)
		title_label.text = "[center][b][color=#FF1744]ROGUELIKE[/color] [color=#FFD700]PUZZLE[/color][/b][/center]"

	if title_label2 != null:
		title_label2.visible = false

	if desc_label != null:
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jp_font = SystemFont.new()
		jp_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		jp_font.font_weight = 700
		desc_label.add_theme_font_override("normal_font", jp_font)
		desc_label.add_theme_font_override("bold_font", jp_font)
		desc_label.add_theme_constant_override("outline_size", 10)
		desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		desc_label.add_theme_font_size_override("normal_font_size", 48)
		desc_label.add_theme_font_size_override("bold_font_size", 48)
		desc_label.text = "[center][b][color=#00E5FF]★ 3つ揃えて消そう!! ★[/color][/b][/center]"

	if desc_label2 != null:
		desc_label2.visible = false

	# 1. START ボタン
	var style_start_normal = StyleBoxFlat.new()
	style_start_normal.bg_color = Color(0.12, 0.12, 0.24, 0.94)
	style_start_normal.border_color = Color(1.0, 0.84, 0.0, 1.0)
	style_start_normal.set_border_width_all(3)
	style_start_normal.set_corner_radius_all(14)

	var style_start_hover = StyleBoxFlat.new()
	style_start_hover.bg_color = Color(0.22, 0.22, 0.40, 0.98)
	style_start_hover.border_color = Color(1.0, 0.96, 0.5, 1.0)
	style_start_hover.set_border_width_all(3)
	style_start_hover.set_corner_radius_all(14)

	if start_btn != null:
		start_btn.add_theme_font_override("font", CUSTOM_FONT)
		start_btn.add_theme_constant_override("outline_size", 6)
		start_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		start_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
		start_btn.add_theme_font_size_override("font_size", 44)
		start_btn.text = "START"
		start_btn.add_theme_stylebox_override("normal", style_start_normal)
		start_btn.add_theme_stylebox_override("hover", style_start_hover)

	# 2. 設定ボタン
	var style_set_normal = StyleBoxFlat.new()
	style_set_normal.bg_color = Color(0.12, 0.14, 0.22, 0.94)
	style_set_normal.border_color = Color(0.3, 0.75, 1.0, 1.0)
	style_set_normal.set_border_width_all(3)
	style_set_normal.set_corner_radius_all(14)

	var style_set_hover = StyleBoxFlat.new()
	style_set_hover.bg_color = Color(0.18, 0.24, 0.36, 0.98)
	style_set_hover.border_color = Color(0.6, 0.9, 1.0, 1.0)
	style_set_hover.set_border_width_all(3)
	style_set_hover.set_corner_radius_all(14)

	settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙ 設定 (SETTINGS)"
	settings_btn.add_theme_font_override("font", CUSTOM_FONT)
	settings_btn.add_theme_constant_override("outline_size", 6)
	settings_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	settings_btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1))
	settings_btn.add_theme_font_size_override("font_size", 34)
	settings_btn.add_theme_stylebox_override("normal", style_set_normal)
	settings_btn.add_theme_stylebox_override("hover", style_set_hover)
	settings_btn.pressed.connect(func():
		if click_se: click_se.play()
		var sm = get_node_or_null("/root/SettingsManager")
		if sm:
			sm.open_settings()
	)
	add_child(settings_btn)

	# 3. ゲーム終了ボタン
	var style_quit_normal = StyleBoxFlat.new()
	style_quit_normal.bg_color = Color(0.20, 0.10, 0.12, 0.94)
	style_quit_normal.border_color = Color(0.95, 0.35, 0.35, 1.0)
	style_quit_normal.set_border_width_all(3)
	style_quit_normal.set_corner_radius_all(14)

	var style_quit_hover = StyleBoxFlat.new()
	style_quit_hover.bg_color = Color(0.35, 0.14, 0.16, 0.98)
	style_quit_hover.border_color = Color(1.0, 0.55, 0.55, 1.0)
	style_quit_hover.set_border_width_all(3)
	style_quit_hover.set_corner_radius_all(14)

	quit_btn = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "✕ ゲーム終了 (QUIT)"
	quit_btn.add_theme_font_override("font", CUSTOM_FONT)
	quit_btn.add_theme_constant_override("outline_size", 6)
	quit_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	quit_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
	quit_btn.add_theme_font_size_override("font_size", 34)
	quit_btn.add_theme_stylebox_override("normal", style_quit_normal)
	quit_btn.add_theme_stylebox_override("hover", style_quit_hover)
	quit_btn.pressed.connect(func():
		if click_se: click_se.play()
		get_tree().quit()
	)
	add_child(quit_btn)

## 画面解像度・アスペクト比に応じた完璧な中央揃えレイアウト再計算
func _update_layout() -> void:
	var vp_rect = get_viewport_rect()
	var vp_w = maxf(vp_rect.size.x, 1920.0)
	var vp_h = maxf(vp_rect.size.y, 1080.0)

	# 背景スプライトを画面中心に配置し全画面カバー
	var bg_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if bg_sprite and bg_sprite.texture:
		var tex_size = bg_sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var scale_val = maxf(vp_w / tex_size.x, vp_h / tex_size.y)
			bg_sprite.scale = Vector2(scale_val, scale_val)
			bg_sprite.position = Vector2(vp_w * 0.5, vp_h * 0.5)

	if anten_rect:
		anten_rect.position = Vector2.ZERO
		anten_rect.size = Vector2(vp_w, vp_h)

	# タイトルロゴ
	if title_label != null:
		title_label.position = Vector2(0, vp_h * 0.15)
		title_label.size = Vector2(vp_w, 200)

	# サブタイトル
	if desc_label != null:
		desc_label.position = Vector2(0, vp_h * 0.38)
		desc_label.size = Vector2(vp_w, 80)

	# ボタン群（中央揃えでバランス良く縦並び）
	var btn_w: float = 480.0
	var btn_h: float = 84.0
	var btn_gap: float = 24.0
	var btn_x: float = (vp_w - btn_w) * 0.5
	var start_y: float = vp_h * 0.49

	if start_btn != null:
		start_btn.position = Vector2(btn_x, start_y)
		start_btn.size = Vector2(btn_w, btn_h)
		start_btn.custom_minimum_size = Vector2(btn_w, btn_h)

	if settings_btn != null:
		settings_btn.position = Vector2(btn_x, start_y + btn_h + btn_gap)
		settings_btn.size = Vector2(btn_w, btn_h)
		settings_btn.custom_minimum_size = Vector2(btn_w, btn_h)

	if quit_btn != null:
		quit_btn.position = Vector2(btn_x, start_y + (btn_h + btn_gap) * 2.0)
		quit_btn.size = Vector2(btn_w, btn_h)
		quit_btn.custom_minimum_size = Vector2(btn_w, btn_h)

## スタートボタン押下時
func _on_button_pressed() -> void:
	if isclicked:
		return
	if click_se:
		click_se.play()
	isclicked = true

func _process(_delta: float) -> void:
	if isclicked:
		if interval < 30:
			if anten_rect:
				anten_rect.color.a += 0.03
		elif interval >= 40:
			if anten_rect:
				anten_rect.color.a = 0.0
			isclicked = false
			var next_scene: PackedScene = null
			var status = ResourceLoader.load_threaded_get_status("res://current_stage.tscn")
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				next_scene = ResourceLoader.load_threaded_get("res://current_stage.tscn") as PackedScene
			else:
				next_scene = load("res://current_stage.tscn") as PackedScene
			if next_scene:
				get_tree().change_scene_to_packed(next_scene)
		interval += 1

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

func _ready() -> void:
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	if title_bgm:
		title_bgm.play()

	if title_label != null:
		title_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		title_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		title_label.add_theme_constant_override("outline_size", 16)
		title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		title_label.add_theme_font_size_override("normal_font_size", 140)
		title_label.add_theme_font_size_override("bold_font_size", 140)
		title_label.position = Vector2(0, 140)
		title_label.size = Vector2(1920, 240)
		title_label.text = "[center][b][color=#FF1744]ROGUELIKE[/color] [color=#FFD700]PUZZLE[/color][/b][/center]"

	if title_label2 != null:
		title_label2.visible = false

	if desc_label != null:
		var jp_font = SystemFont.new()
		jp_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		jp_font.font_weight = 700
		desc_label.add_theme_font_override("normal_font", jp_font)
		desc_label.add_theme_font_override("bold_font", jp_font)
		desc_label.add_theme_constant_override("outline_size", 10)
		desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		desc_label.add_theme_font_size_override("normal_font_size", 54)
		desc_label.add_theme_font_size_override("bold_font_size", 54)
		desc_label.position = Vector2(0, 420)
		desc_label.size = Vector2(1920, 100)
		desc_label.text = "[center][b][color=#00E5FF]★ 3つ揃えて消そう!! ★[/color][/b][/center]"

	if desc_label2 != null:
		desc_label2.visible = false

	var btn_width: float = 440.0
	var btn_height: float = 84.0
	var btn_x: float = (1920.0 - btn_width) / 2.0

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.12, 0.22, 0.92)
	style_normal.border_color = Color(1.0, 0.84, 0.0, 1.0)
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(12)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.35, 0.98)
	style_hover.border_color = Color(1.0, 0.95, 0.4, 1.0)
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(12)

	if start_btn != null:
		start_btn.add_theme_font_override("font", CUSTOM_FONT)
		start_btn.add_theme_constant_override("outline_size", 6)
		start_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		start_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
		start_btn.position = Vector2(btn_x, 580)
		start_btn.size = Vector2(btn_width, btn_height)
		start_btn.custom_minimum_size = Vector2(btn_width, btn_height)
		start_btn.add_theme_font_size_override("font_size", 44)
		start_btn.text = "START"
		start_btn.add_theme_stylebox_override("normal", style_normal)
		start_btn.add_theme_stylebox_override("hover", style_hover)

	# 設定ボタンの追加（スタートボタンと同サイズで直下に配置）
	var settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙ 設定 (SETTINGS)"
	settings_btn.add_theme_font_override("font", CUSTOM_FONT)
	settings_btn.add_theme_constant_override("outline_size", 6)
	settings_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	settings_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	settings_btn.position = Vector2(btn_x, 690)
	settings_btn.size = Vector2(btn_width, btn_height)
	settings_btn.custom_minimum_size = Vector2(btn_width, btn_height)
	settings_btn.add_theme_font_size_override("font_size", 34)
	settings_btn.add_theme_stylebox_override("normal", style_normal)
	settings_btn.add_theme_stylebox_override("hover", style_hover)
	settings_btn.pressed.connect(func():
		if click_se: click_se.play()
		var sm = get_node_or_null("/root/SettingsManager")
		if sm:
			sm.open_settings()
	)
	add_child(settings_btn)

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
			var next_scene = load("res://current_stage.tscn")
			if next_scene:
				get_tree().change_scene_to_packed(next_scene)
		interval += 1

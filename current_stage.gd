extends Node2D

## ステージ全体を保持する親シーンスクリプト

var isclicked: bool = false
var interval: int = 0

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

@onready var click_se: AudioStreamPlayer2D = get_node_or_null("click")
@onready var anten_rect: ColorRect = get_node_or_null("anten")
@onready var stage_manager: Node2D = get_node_or_null("StageManager")
@onready var return_title_btn: Button = get_node_or_null("returntitle")

func _ready() -> void:
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		var sys_font = SystemFont.new()
		sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
		CUSTOM_FONT.set_fallbacks([sys_font])

	if return_title_btn:
		return_title_btn.add_theme_font_override("font", CUSTOM_FONT)
		return_title_btn.add_theme_font_size_override("font_size", 64)
		return_title_btn.add_theme_constant_override("outline_size", 8)
		return_title_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))

	# ゲーム主背景（敵がいる欄以外の領域）を高級カジノ風背景に初期化
	var bg = get_node_or_null("sougen2D")
	if bg:
		var casino_tex = load("res://Texture/haikei/casino_bg.jpg") as Texture2D
		if casino_tex:
			bg.texture = casino_tex
			var tex_size = casino_tex.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_val = maxf(1920.0 / tex_size.x, 1080.0 / tex_size.y)
				bg.scale = Vector2(scale_val, scale_val)
				bg.position = Vector2(960, 540)

	# ゲーム画面左下に「⚙ 設定」ボタンを配置
	var settings_btn = Button.new()
	settings_btn.name = "InGameSettingsButton"
	settings_btn.text = "⚙ 設定"
	settings_btn.add_theme_font_override("font", CUSTOM_FONT)
	settings_btn.add_theme_font_size_override("font_size", 26)
	settings_btn.add_theme_constant_override("outline_size", 6)
	settings_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	settings_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	settings_btn.position = Vector2(38, 980)
	settings_btn.size = Vector2(160, 56)
	settings_btn.custom_minimum_size = Vector2(160, 56)
	settings_btn.z_index = 30

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.12, 0.22, 0.90)
	style_normal.border_color = Color(1.0, 0.84, 0.0, 0.85)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(10)
	settings_btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.35, 0.98)
	style_hover.border_color = Color(1.0, 0.95, 0.4, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(10)
	settings_btn.add_theme_stylebox_override("hover", style_hover)

	settings_btn.pressed.connect(func():
		if click_se: click_se.play()
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload:
			sm_autoload.open_settings()
	)
	add_child(settings_btn)

## タイトルへ戻るボタン押下時
func _on_returntitle_pressed() -> void:
	if isclicked:
		return
	if click_se: click_se.play()
	isclicked = true
	if stage_manager:
		stage_manager.stage = 0

## ゲームクリアボタン押下時
func _on_gameclearbutton_pressed() -> void:
	if isclicked:
		return
	if click_se: click_se.play()
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
			var next_scene = load("res://title_screen.tscn")
			if next_scene:
				get_tree().change_scene_to_packed(next_scene)
		interval += 1

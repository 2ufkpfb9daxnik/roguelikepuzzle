extends CanvasLayer
class_name RelicSelectionUI

signal selection_finished()

var panel: Panel
var title_label: Label
var hbox: HBoxContainer
var skip_btn: Button

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

func _ready() -> void:
	layer = 60
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1920, 1080)
	add_child(dim)
	
	panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.8, 0.6, 0.1, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.custom_minimum_size = Vector2(1400, 700)
	panel.size = Vector2(1400, 700)
	panel.position = Vector2((1920.0 - 1400.0) / 2.0, (1080.0 - 700.0) / 2.0)
	add_child(panel)
	
	title_label = Label.new()
	title_label.text = "レリックを選択"
	if CUSTOM_FONT:
		title_label.add_theme_font_override("font", CUSTOM_FONT)
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 40)
	title_label.size = Vector2(1400, 80)
	panel.add_child(title_label)
	
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	hbox.position = Vector2(0, 160)
	hbox.size = Vector2(1400, 380)
	panel.add_child(hbox)
	
	skip_btn = Button.new()
	skip_btn.text = "スキップ (Skip)"
	if CUSTOM_FONT:
		skip_btn.add_theme_font_override("font", CUSTOM_FONT)
	skip_btn.add_theme_font_size_override("font_size", 40)
	skip_btn.custom_minimum_size = Vector2(300, 80)
	skip_btn.size = Vector2(300, 80)
	skip_btn.position = Vector2((1400.0 - 300.0) / 2.0, 580)
	skip_btn.pressed.connect(_on_skip_pressed)
	panel.add_child(skip_btn)
	
	_populate_choices()

func _populate_choices() -> void:
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	if not rm:
		call_deferred("_on_skip_pressed")
		return
		
	var all_relics = RelicDatabase.RELICS.keys()
	var available = []
	for r in all_relics:
		if not rm.has_relic(r):
			available.append(r)
			
	available.shuffle()
	var choices = available.slice(0, 3)
	
	if choices.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "すべてのレリックを取得済みです"
		if CUSTOM_FONT: empty_lbl.add_theme_font_override("font", CUSTOM_FONT)
		empty_lbl.add_theme_font_size_override("font_size", 40)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(empty_lbl)
		return
		
	for c_id in choices:
		var c_data = RelicDatabase.get_relic(c_id)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(350, 350)
		btn.size = Vector2(350, 350)
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
		var rarity = c_data.get("rarity", "common")
		if rarity == "uncommon": b_style.border_color = Color(0.2, 0.8, 0.2, 1.0)
		elif rarity == "rare": b_style.border_color = Color(0.2, 0.4, 1.0, 1.0)
		else: b_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
		b_style.set_border_width_all(6)
		b_style.set_corner_radius_all(16)
		btn.add_theme_stylebox_override("normal", b_style)
		
		var h_style = b_style.duplicate()
		h_style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
		btn.add_theme_stylebox_override("hover", h_style)
		
		var vbox = VBoxContainer.new()
		vbox.position = Vector2(15, 15)
		vbox.size = Vector2(320, 320)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)
		
		var r_label = Label.new()
		r_label.text = c_data.get("name", "???")
		r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if CUSTOM_FONT:
			r_label.add_theme_font_override("font", CUSTOM_FONT)
		r_label.add_theme_font_size_override("font_size", 36)
		if rarity == "uncommon": r_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		elif rarity == "rare": r_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
		vbox.add_child(r_label)
		
		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 20)
		vbox.add_child(spacer)
		
		var d_label = RichTextLabel.new()
		d_label.bbcode_enabled = true
		d_label.text = "[center]" + c_data.get("description", "") + "[/center]"
		d_label.custom_minimum_size = Vector2(320, 150)
		if CUSTOM_FONT:
			d_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		d_label.add_theme_font_size_override("normal_font_size", 24)
		d_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(d_label)
		
		btn.pressed.connect(_on_choice_pressed.bind(c_id))
		hbox.add_child(btn)

func _on_choice_pressed(id: String) -> void:
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	if rm: rm.add_relic(id)
	
	emit_signal("selection_finished")
	queue_free()

func _on_skip_pressed() -> void:
	emit_signal("selection_finished")
	queue_free()

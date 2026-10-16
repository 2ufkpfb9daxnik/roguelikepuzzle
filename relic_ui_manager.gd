extends CanvasLayer
class_name RelicUIManager

var container: HFlowContainer
var info_panel: PanelContainer
var name_label: RichTextLabel
var desc_label: RichTextLabel
var icon_nodes: Dictionary = {}

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

func _ready() -> void:
	layer = 50 # High above board

	container = HFlowContainer.new()
	container.position = Vector2(220, 976)
	container.size = Vector2(1150, 90)
	container.add_theme_constant_override("h_separation", 8)
	container.add_theme_constant_override("v_separation", 8)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.position = Vector2(220, 790)
	info_panel.size = Vector2(440, 160)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.96)
	style.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	info_panel.add_theme_stylebox_override("panel", style)
	add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(vbox)
	
	name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var sys_font = SystemFont.new()
	sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "sans-serif"])
	
	if CUSTOM_FONT:
		name_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		name_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		name_label.add_theme_font_size_override("normal_font_size", 30)
		name_label.add_theme_font_size_override("bold_font_size", 30)
	else:
		name_label.add_theme_font_override("normal_font", sys_font)
		name_label.add_theme_font_override("bold_font", sys_font)
		name_label.add_theme_font_size_override("normal_font_size", 30)
		name_label.add_theme_font_size_override("bold_font_size", 30)
	vbox.add_child(name_label)
	
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CUSTOM_FONT:
		desc_label.add_theme_font_override("normal_font", CUSTOM_FONT)
		desc_label.add_theme_font_override("bold_font", CUSTOM_FONT)
	else:
		desc_label.add_theme_font_override("normal_font", sys_font)
	vbox.add_child(desc_label)
	
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	if rm:
		rm.connect("relic_added", _on_relic_added)
		rm.connect("relic_leveled_up", _on_relic_leveled_up)
		rm.connect("relic_triggered", _on_relic_triggered)
		for r_id in rm.get_relics():
			_on_relic_added(r_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		info_panel.visible = false

func _on_relic_added(id: String) -> void:
	if icon_nodes.has(id): return
	var r_data = RelicDatabase.get_relic(id)
	if r_data.is_empty(): return
	
	var rect = ColorRect.new()
	rect.custom_minimum_size = Vector2(64, 64)
	rect.size = Vector2(64, 64)
	
	var rarity = r_data.get("rarity", "common")
	if rarity == "common": rect.color = Color(0.6, 0.6, 0.6)
	elif rarity == "uncommon": rect.color = Color(0.2, 0.8, 0.2)
	elif rarity == "rare": rect.color = Color(0.2, 0.4, 1.0)
	
	# レリック頭文字ラベル
	var lbl = Label.new()
	lbl.text = r_data.get("name", "?").substr(0, 1)
	lbl.position = Vector2.ZERO
	lbl.size = Vector2(64, 64)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if CUSTOM_FONT:
		lbl.add_theme_font_override("font", CUSTOM_FONT)
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	rect.add_child(lbl)
	
	# レベルラベル (Lv1は非表示、Lv2以上で表示)
	var lvl_lbl = Label.new()
	lvl_lbl.name = "LevelLabel"
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	var cur_lvl = rm.get_level(id) if rm else 1
	lvl_lbl.text = ("Lv%d" % cur_lvl) if cur_lvl > 1 else ""
	lvl_lbl.position = Vector2(24, 38)
	lvl_lbl.size = Vector2(38, 24)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if CUSTOM_FONT:
		lvl_lbl.add_theme_font_override("font", CUSTOM_FONT)
	lvl_lbl.add_theme_font_size_override("font_size", 18)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	lvl_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lvl_lbl.add_theme_constant_override("outline_size", 4)
	rect.add_child(lvl_lbl)
	
	rect.gui_input.connect(_on_icon_gui_input.bind(id, rect))
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.pivot_offset = Vector2(32, 32)
	
	container.add_child(rect)
	icon_nodes[id] = rect

func _on_relic_leveled_up(id: String, new_level: int) -> void:
	if not icon_nodes.has(id):
		_on_relic_added(id)
	
	var rect = icon_nodes[id]
	var lvl_lbl = rect.get_node_or_null("LevelLabel") as Label
	if lvl_lbl:
		lvl_lbl.text = "Lv%d" % new_level
		
	# レベルアップ時の発光アニメーション
	if rect.has_meta("tw"):
		var old_tw = rect.get_meta("tw")
		if is_instance_valid(old_tw): old_tw.kill()
		
	var tw = create_tween()
	rect.set_meta("tw", tw)
	rect.modulate = Color(2.5, 2.5, 1.5, 1.0) # 黄金フラッシュ
	tw.tween_property(rect, "scale", Vector2(1.4, 1.4), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(rect, "modulate", Color.WHITE, 0.25)

func _on_icon_gui_input(event: InputEvent, id: String, rect: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if info_panel.visible and info_panel.get_meta("current_id", "") == id:
			info_panel.visible = false
		else:
			var rm = get_tree().get_root().find_child("RelicManager", true, false)
			var r_data = RelicDatabase.get_relic(id)
			var cur_lvl = rm.get_level(id) if rm else 1
			var max_lvl = RelicDatabase.get_max_level(id)
			var is_max = cur_lvl >= max_lvl
			
			var r_color = "#AAAAAA"
			var rarity = r_data.get("rarity", "common")
			if rarity == "uncommon": r_color = "#33CC33"
			elif rarity == "rare": r_color = "#3366FF"
			
			var level_str = " (Lv%d/MAX)" % cur_lvl if is_max else " (Lv%d)" % cur_lvl
			name_label.text = "[b][color=" + r_color + "]" + r_data.get("name", "Unknown") + level_str + "[/color][/b]"
			
			var desc_cur = RelicDatabase.get_description(id, cur_lvl)
			if is_max:
				desc_label.text = "[font_size=22][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % desc_cur
			else:
				var desc_next = RelicDatabase.get_description(id, cur_lvl + 1)
				desc_label.text = "[font_size=20][color=#FFFFFF]現在: %s[/color]\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [desc_cur, cur_lvl + 1, desc_next]
				
			info_panel.set_meta("current_id", id)
			var panel_x = clampf(rect.global_position.x, 20.0, 1920.0 - info_panel.size.x - 20.0)
			var panel_y = maxf(20.0, rect.global_position.y - info_panel.size.y - 12.0)
			info_panel.position = Vector2(panel_x, panel_y)
			info_panel.visible = true
			get_viewport().set_input_as_handled()

func _on_relic_triggered(id: String) -> void:
	if not icon_nodes.has(id): return
	var rect = icon_nodes[id]
	if rect.has_meta("tw"):
		var old_tw = rect.get_meta("tw")
		if is_instance_valid(old_tw): old_tw.kill()
		
	var tw = create_tween()
	rect.set_meta("tw", tw)
	
	rect.modulate = Color(2.0, 2.0, 2.0, 1.0)
	tw.tween_property(rect, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(rect, "modulate", Color.WHITE, 0.3)

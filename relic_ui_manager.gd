extends CanvasLayer
class_name RelicUIManager

var skill_container: HFlowContainer
var container: HFlowContainer
var info_panel: PanelContainer
var name_label: RichTextLabel
var desc_label: RichTextLabel
var icon_nodes: Dictionary = {}
var skill_icon_nodes: Dictionary = {}

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

func _get_sys_font() -> SystemFont:
	var sys_font = SystemFont.new()
	sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
	sys_font.font_weight = 700
	return sys_font

func _ready() -> void:
	layer = 50 # High above board

	var sys_font = _get_sys_font()
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		CUSTOM_FONT.set_fallbacks([sys_font])

	# --- 横並び配置: 左側 = 獲得スキル欄 (x: 220~930, y: 970), 右側 = 所持レリック欄 (x: 950~1880, y: 970) ---
	# 設定ボタン (x: 38..198, y: 980..1036) および盤面下端 (y=944) との被りを完全解消

	# 左側: 【スキル】
	var skill_tag = Label.new()
	skill_tag.text = "【スキル】"
	skill_tag.position = Vector2(220, 984)
	skill_tag.size = Vector2(104, 36)
	skill_tag.add_theme_font_override("font", sys_font)
	skill_tag.add_theme_font_size_override("font_size", 18)
	skill_tag.add_theme_color_override("font_color", Color(1.0, 0.55, 0.90))
	skill_tag.add_theme_constant_override("outline_size", 4)
	skill_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(skill_tag)

	skill_container = HFlowContainer.new()
	skill_container.position = Vector2(330, 970)
	skill_container.size = Vector2(600, 70)
	skill_container.add_theme_constant_override("h_separation", 8)
	skill_container.add_theme_constant_override("v_separation", 8)
	skill_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_container)

	# 右側: 【レリック】
	var relic_tag = Label.new()
	relic_tag.text = "【レリック】"
	relic_tag.position = Vector2(950, 984)
	relic_tag.size = Vector2(104, 36)
	relic_tag.add_theme_font_override("font", sys_font)
	relic_tag.add_theme_font_size_override("font_size", 18)
	relic_tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	relic_tag.add_theme_constant_override("outline_size", 4)
	relic_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(relic_tag)

	container = HFlowContainer.new()
	container.position = Vector2(1060, 970)
	container.size = Vector2(820, 70)
	container.add_theme_constant_override("h_separation", 8)
	container.add_theme_constant_override("v_separation", 8)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.position = Vector2(316, 710)
	info_panel.size = Vector2(460, 165)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.97)
	style.border_color = Color(0.9, 0.78, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	info_panel.add_theme_stylebox_override("panel", style)
	add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(vbox)
	
	name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_override("normal_font", sys_font)
	name_label.add_theme_font_override("bold_font", sys_font)
	name_label.add_theme_font_size_override("normal_font_size", 26)
	name_label.add_theme_font_size_override("bold_font_size", 26)
	vbox.add_child(name_label)
	
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_override("normal_font", sys_font)
	desc_label.add_theme_font_override("bold_font", sys_font)
	vbox.add_child(desc_label)
	
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	if rm:
		rm.connect("relic_added", _on_relic_added)
		rm.connect("relic_leveled_up", _on_relic_leveled_up)
		rm.connect("relic_triggered", _on_relic_triggered)
		for r_id in rm.get_relics():
			_on_relic_added(r_id)

	var sm = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	if sm == null:
		sm = get_tree().get_root().find_child("ScoreManager", true, false)
	if sm:
		if sm.has_signal("skill_upgraded") and not sm.is_connected("skill_upgraded", _on_skill_upgraded):
			sm.connect("skill_upgraded", _on_skill_upgraded)
		if sm.has_method("get_unlocked_skills"):
			for s_data in sm.get_unlocked_skills():
				_on_skill_upgraded(s_data.get("id", ""), int(s_data.get("sp_type", 0)), int(s_data.get("level", 1)))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		info_panel.visible = false

func _on_skill_upgraded(skill_id: String, _sp_type: int, new_level: int) -> void:
	var sm = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	if sm == null:
		sm = get_tree().get_root().find_child("ScoreManager", true, false)
	var s_data: Dictionary = sm.get_skill_by_id(skill_id) if (sm and sm.has_method("get_skill_by_id")) else {}
	if s_data.is_empty():
		return

	if not skill_icon_nodes.has(skill_id):
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(56, 56)
		rect.size = Vector2(56, 56)
		var base_col: Color = s_data.get("color", Color("#FF80CC"))
		rect.color = base_col.darkened(0.35)

		var border = ReferenceRect.new()
		border.size = Vector2(56, 56)
		border.border_color = base_col.lightened(0.25)
		border.border_width = 2.5
		border.editor_only = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(border)

		var sys_font = _get_sys_font()
		var lbl = Label.new()
		lbl.text = s_data.get("short_label", s_data.get("name", "?").substr(0, 1))
		lbl.position = Vector2.ZERO
		lbl.size = Vector2(56, 50)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", sys_font)
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		rect.add_child(lbl)

		var lvl_lbl = Label.new()
		lvl_lbl.name = "LevelLabel"
		lvl_lbl.text = "Lv%d" % new_level
		lvl_lbl.position = Vector2(14, 34)
		lvl_lbl.size = Vector2(40, 22)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lvl_lbl.add_theme_font_override("font", sys_font)
		lvl_lbl.add_theme_font_size_override("font_size", 15)
		lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
		lvl_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lvl_lbl.add_theme_constant_override("outline_size", 4)
		rect.add_child(lvl_lbl)

		rect.mouse_entered.connect(_show_skill_tooltip.bind(skill_id, rect))
		rect.mouse_exited.connect(_hide_tooltip_if_matching.bind("skill:" + skill_id))
		rect.gui_input.connect(_on_skill_icon_gui_input.bind(skill_id, rect))
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		rect.pivot_offset = Vector2(28, 28)

		skill_container.add_child(rect)
		skill_icon_nodes[skill_id] = rect

	var node_rect: ColorRect = skill_icon_nodes[skill_id]
	var l_lbl = node_rect.get_node_or_null("LevelLabel") as Label
	if l_lbl:
		l_lbl.text = "Lv%d" % new_level

	if info_panel.visible and info_panel.get_meta("current_id", "") == ("skill:" + skill_id):
		_show_skill_tooltip(skill_id, node_rect)

	if node_rect.has_meta("tw"):
		var old_tw = node_rect.get_meta("tw")
		if is_instance_valid(old_tw):
			old_tw.kill()

	var tw = create_tween()
	node_rect.set_meta("tw", tw)
	node_rect.modulate = Color(2.4, 2.0, 2.5, 1.0)
	tw.tween_property(node_rect, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node_rect, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(node_rect, "modulate", Color.WHITE, 0.22)

func _hide_tooltip_if_matching(meta_key: String) -> void:
	if info_panel.visible and info_panel.get_meta("current_id", "") == meta_key:
		info_panel.visible = false

func _show_skill_tooltip(skill_id: String, rect: ColorRect) -> void:
	var sm = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	if sm == null:
		sm = get_tree().get_root().find_child("ScoreManager", true, false)
	var s_data: Dictionary = sm.get_skill_by_id(skill_id) if (sm and sm.has_method("get_skill_by_id")) else {}
	if s_data.is_empty():
		return

	var cur_lvl: int = int(s_data.get("level", 1))
	var max_lvl: int = int(s_data.get("max_level", 3))
	var is_max: bool = (cur_lvl >= max_lvl)
	var col_hex: String = s_data.get("color", Color("#FF80CC")).to_html(false)
	var level_str = " (Lv%d/MAX)" % cur_lvl if is_max else " (Lv%d/%d)" % [cur_lvl, max_lvl]
	name_label.text = "[b][color=#%s]🌿 %s%s[/color][/b]" % [col_hex, s_data.get("name", "Skill"), level_str]

	var desc_arr: Array = s_data.get("desc_lv", [])
	var cur_desc: String = desc_arr[clampi(cur_lvl - 1, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else ""
	if is_max:
		desc_label.text = "[font_size=20][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % cur_desc
	else:
		var next_desc: String = desc_arr[clampi(cur_lvl, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else ""
		desc_label.text = "[font_size=19][color=#FFFFFF]現在: %s[/color]\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [cur_desc, cur_lvl + 1, next_desc]

	info_panel.set_meta("current_id", "skill:" + skill_id)
	var panel_x = clampf(rect.global_position.x, 20.0, 1920.0 - info_panel.size.x - 20.0)
	var panel_y = maxf(20.0, rect.global_position.y - info_panel.size.y - 12.0)
	info_panel.position = Vector2(panel_x, panel_y)
	info_panel.visible = true

func _on_skill_icon_gui_input(event: InputEvent, skill_id: String, rect: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_skill_tooltip(skill_id, rect)
		get_viewport().set_input_as_handled()

## 盤面上の効果マスやショップアイテム等、外部から呼び出し可能な汎用ツールチップ表示
func show_custom_tooltip(title: String, desc: String, screen_pos: Vector2, meta_key: String = "") -> void:
	if title.is_empty() and desc.is_empty():
		hide_custom_tooltip(meta_key)
		return
	if name_label: name_label.text = title
	if desc_label: desc_label.text = desc
	info_panel.set_meta("current_id", meta_key)

	var panel_w = maxf(420.0, info_panel.size.x)
	var panel_h = maxf(120.0, info_panel.size.y)
	var target_x = clampf(screen_pos.x + 24.0, 20.0, 1920.0 - panel_w - 20.0)
	var target_y = clampf(screen_pos.y - panel_h - 15.0, 20.0, 1080.0 - panel_h - 20.0)
	# 画面上部付近の場合はマウスの下側に配置
	if screen_pos.y - panel_h - 15.0 < 20.0:
		target_y = clampf(screen_pos.y + 30.0, 20.0, 1080.0 - panel_h - 20.0)

	info_panel.position = Vector2(target_x, target_y)
	info_panel.visible = true

## ツールチップ非表示
func hide_custom_tooltip(meta_key: String = "") -> void:
	if not info_panel: return
	if meta_key.is_empty() or info_panel.get_meta("current_id", "") == meta_key:
		info_panel.visible = false

func _on_relic_added(id: String) -> void:
	if icon_nodes.has(id): return
	var r_data = RelicDatabase.get_relic(id)
	if r_data.is_empty(): return
	
	var rect = ColorRect.new()
	rect.custom_minimum_size = Vector2(56, 56)
	rect.size = Vector2(56, 56)
	
	var rarity = r_data.get("rarity", "common")
	if rarity == "legendary": rect.color = Color(0.85, 0.65, 0.08)
	elif rarity == "epic": rect.color = Color(0.60, 0.18, 0.82)
	elif rarity == "rare": rect.color = Color(0.18, 0.45, 0.92)
	elif rarity == "uncommon": rect.color = Color(0.16, 0.68, 0.24)
	elif rarity == "cursed": rect.color = Color(0.55, 0.06, 0.16)
	else: rect.color = Color(0.48, 0.50, 0.54)

	var border = ReferenceRect.new()
	border.size = Vector2(56, 56)
	if rarity == "legendary": border.border_color = Color(1.0, 0.92, 0.35, 1.0); border.border_width = 3.0
	elif rarity == "epic": border.border_color = Color(0.9, 0.5, 1.0, 1.0); border.border_width = 2.5
	elif rarity == "rare": border.border_color = Color(0.45, 0.75, 1.0, 1.0); border.border_width = 2.0
	elif rarity == "uncommon": border.border_color = Color(0.4, 0.95, 0.5, 1.0); border.border_width = 2.0
	elif rarity == "cursed": border.border_color = Color(1.0, 0.20, 0.38, 1.0); border.border_width = 3.0
	else: border.border_color = Color(0.75, 0.78, 0.82, 0.8); border.border_width = 1.5
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.add_child(border)

	var sys_font = _get_sys_font()
	# レリック頭文字ラベル
	var lbl = Label.new()
	lbl.text = r_data.get("name", "?").substr(0, 1)
	lbl.position = Vector2.ZERO
	lbl.size = Vector2(56, 50)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", sys_font)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	rect.add_child(lbl)
	
	# レベルラベル (Lv1から常時わかりやすく表示)
	var lvl_lbl = Label.new()
	lvl_lbl.name = "LevelLabel"
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	var cur_lvl = rm.get_level(id) if rm else 1
	lvl_lbl.text = "Lv%d" % cur_lvl
	lvl_lbl.position = Vector2(14, 34)
	lvl_lbl.size = Vector2(40, 22)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_lbl.add_theme_font_override("font", sys_font)
	lvl_lbl.add_theme_font_size_override("font_size", 15)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	lvl_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lvl_lbl.add_theme_constant_override("outline_size", 4)
	rect.add_child(lvl_lbl)
	
	rect.mouse_entered.connect(_show_relic_tooltip.bind(id, rect))
	rect.mouse_exited.connect(_hide_tooltip_if_matching.bind(id))
	rect.gui_input.connect(_on_icon_gui_input.bind(id, rect))
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.pivot_offset = Vector2(28, 28)
	
	container.add_child(rect)
	icon_nodes[id] = rect

func _on_relic_leveled_up(id: String, new_level: int) -> void:
	if not icon_nodes.has(id):
		_on_relic_added(id)
	
	var rect = icon_nodes[id]
	var lvl_lbl = rect.get_node_or_null("LevelLabel") as Label
	if lvl_lbl:
		lvl_lbl.text = "Lv%d" % new_level

	if info_panel.visible and info_panel.get_meta("current_id", "") == id:
		_show_relic_tooltip(id, rect)
		
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

func _show_relic_tooltip(id: String, rect: ColorRect) -> void:
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	var r_data = RelicDatabase.get_relic(id)
	var cur_lvl = rm.get_level(id) if rm else 1
	var max_lvl = RelicDatabase.get_max_level(id)
	var is_max = cur_lvl >= max_lvl
	
	var r_color = "#B0BEC5"
	var rarity = r_data.get("rarity", "common")
	var rarity_tag = "COMMON"
	if rarity == "legendary":
		r_color = "#FFD700"
		rarity_tag = "★ LEGENDARY ★"
	elif rarity == "epic":
		r_color = "#E040FB"
		rarity_tag = "◆ EPIC ◆"
	elif rarity == "rare":
		r_color = "#29B6F6"
		rarity_tag = "RARE"
	elif rarity == "uncommon":
		r_color = "#4CAF50"
		rarity_tag = "UNCOMMON"
	elif rarity == "cursed":
		r_color = "#FF1744"
		rarity_tag = "☠ CURSED (呪い) ☠"
	
	var level_str = " (Lv%d/MAX)" % cur_lvl if is_max else " (Lv%d/%d)" % [cur_lvl, max_lvl]
	name_label.text = "[b][color=" + r_color + "]" + r_data.get("name", "Unknown") + " [" + rarity_tag + "]" + level_str + "[/color][/b]"
	
	var desc_cur = RelicDatabase.get_description(id, cur_lvl)
	if is_max:
		desc_label.text = "[font_size=20][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % desc_cur
	else:
		var desc_next = RelicDatabase.get_description(id, cur_lvl + 1)
		desc_label.text = "[font_size=19][color=#FFFFFF]現在: %s[/color]\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [desc_cur, cur_lvl + 1, desc_next]
		
	info_panel.set_meta("current_id", id)
	var panel_x = clampf(rect.global_position.x, 20.0, 1920.0 - info_panel.size.x - 20.0)
	var panel_y = maxf(20.0, rect.global_position.y - info_panel.size.y - 12.0)
	info_panel.position = Vector2(panel_x, panel_y)
	info_panel.visible = true

func _on_icon_gui_input(event: InputEvent, id: String, rect: ColorRect) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_relic_tooltip(id, rect)
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

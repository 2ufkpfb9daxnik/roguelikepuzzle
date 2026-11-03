extends CanvasLayer
class_name RelicUIManager
const GlossaryDatabase = preload("res://glossary_database.gd")

var skill_container: HFlowContainer
var container: HFlowContainer
var info_panel: PanelContainer
var name_label: RichTextLabel
var desc_label: RichTextLabel
var glossary_panel: PanelContainer
var glossary_title_label: RichTextLabel
var glossary_desc_label: RichTextLabel
var cell_tooltip_panel: PanelContainer
var cell_tooltip_vbox: VBoxContainer
var _cell_tooltip_rows: Array[PanelContainer] = []
var _tooltip_close_timer: Tween = null
var icon_nodes: Dictionary = {}
var skill_icon_nodes: Dictionary = {}
var _bottom_bar_nodes: Array[CanvasItem] = []

func set_bottom_bars_visible(vis: bool) -> void:
	for node in _bottom_bar_nodes:
		if node != null and is_instance_valid(node):
			node.visible = vis

func set_ui_visible(vis: bool) -> void:
	set_bottom_bars_visible(vis)

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

func _get_sys_font() -> SystemFont:
	var sys_font = SystemFont.new()
	sys_font.font_names = PackedStringArray(["Meiryo", "Yu Gothic", "Hiragino Sans", "Noto Sans CJK JP", "MS Gothic", "sans-serif"])
	sys_font.font_weight = 700
	var emoji_f = SystemFont.new()
	emoji_f.font_names = PackedStringArray(["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"])
	sys_font.set_fallbacks([emoji_f])
	return sys_font

func _ready() -> void:
	layer = 99 # High above board and all game UIs
	GlossaryDatabase.register_relic_terms()

	var sys_font = _get_sys_font()
	if CUSTOM_FONT is Font and CUSTOM_FONT.get_fallbacks().is_empty():
		CUSTOM_FONT.set_fallbacks([sys_font])

	# --- 横並び配置: 左側 = 獲得スキル欄 (最大4枠なのでコンパクト), 右側 = 所持レリック欄 (残り幅を拡張) ---
	# スキルの左端を盤面の外枠左端 (x=244.0) に一致させる
	var gold_border = Color(0.85, 0.72, 0.38, 1.0)
	var bg_dark = Color(0.02, 0.02, 0.03, 0.75)
	var div_color = Color(0.72, 0.60, 0.34, 0.5)
	var skill_panel_size = Vector2(460.0, 114.0)
	var skill_inner_size = Vector2(456.0, 110.0)
	var relic_panel_size = Vector2(1192.0, 114.0)
	var relic_inner_size = Vector2(1188.0, 110.0)

	# 1. スキル欄の外枠・内枠・区切り線
	var skill_rect = ColorRect.new()
	skill_rect.name = "skill_rect"
	skill_rect.position = Vector2(244.0, 952.0)
	skill_rect.size = skill_panel_size
	skill_rect.color = gold_border
	skill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_rect.z_index = -10
	add_child(skill_rect)

	var skill2_rect = ColorRect.new()
	skill2_rect.name = "skill2_rect"
	skill2_rect.position = Vector2(246.0, 954.0)
	skill2_rect.size = skill_inner_size
	skill2_rect.color = bg_dark
	skill2_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill2_rect.z_index = -9
	add_child(skill2_rect)

	# 左側: 【スキル】エンブレムプレート
	var skill_plate = Panel.new()
	skill_plate.name = "skill_plate"
	skill_plate.position = Vector2(250.0, 958.0)
	skill_plate.size = Vector2(118.0, 102.0)
	skill_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color = Color(0.01, 0.01, 0.02, 0.60)
	sp_style.border_color = Color(0.85, 0.72, 0.38, 0.75)
	sp_style.set_border_width_all(1)
	sp_style.set_corner_radius_all(8)
	skill_plate.add_theme_stylebox_override("panel", sp_style)
	add_child(skill_plate)

	var skill_tag = Label.new()
	skill_tag.name = "skill_tag"
	skill_tag.text = "◆ スキル ◆\nACTIVE"
	skill_tag.position = Vector2(250.0, 974.0)
	skill_tag.size = Vector2(118.0, 68.0)
	skill_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skill_tag.add_theme_font_override("font", sys_font)
	skill_tag.add_theme_font_size_override("font_size", 16)
	skill_tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	skill_tag.add_theme_constant_override("outline_size", 4)
	skill_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(skill_tag)

	var skill_vline = ColorRect.new()
	skill_vline.name = "skill_vline"
	skill_vline.position = Vector2(374.0, 954.0)
	skill_vline.size = Vector2(2.0, 110.0)
	skill_vline.color = div_color
	skill_vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_vline.z_index = -8
	add_child(skill_vline)

	skill_container = HFlowContainer.new()
	skill_container.name = "skill_container"
	skill_container.position = Vector2(382.0, 960.0)
	skill_container.size = Vector2(312.0, 98.0)
	skill_container.add_theme_constant_override("h_separation", 8)
	skill_container.add_theme_constant_override("v_separation", 8)
	skill_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_container)

	# 2. レリック欄の外枠・内枠・区切り線（スキル欄を縮めた分、右側へ大きく拡張）
	var relic_rect = ColorRect.new()
	relic_rect.name = "relic_rect"
	relic_rect.position = Vector2(722.0, 952.0)
	relic_rect.size = relic_panel_size
	relic_rect.color = gold_border
	relic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_rect.z_index = -10
	add_child(relic_rect)

	var relic2_rect = ColorRect.new()
	relic2_rect.name = "relic2_rect"
	relic2_rect.position = Vector2(724.0, 954.0)
	relic2_rect.size = relic_inner_size
	relic2_rect.color = bg_dark
	relic2_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic2_rect.z_index = -9
	add_child(relic2_rect)

	# 右側: 【レリック】エンブレムプレート
	var relic_plate = Panel.new()
	relic_plate.name = "relic_plate"
	relic_plate.position = Vector2(728.0, 958.0)
	relic_plate.size = Vector2(118.0, 102.0)
	relic_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rp_style = StyleBoxFlat.new()
	rp_style.bg_color = Color(0.01, 0.01, 0.02, 0.60)
	rp_style.border_color = Color(0.85, 0.72, 0.38, 0.75)
	rp_style.set_border_width_all(1)
	rp_style.set_corner_radius_all(8)
	relic_plate.add_theme_stylebox_override("panel", rp_style)
	add_child(relic_plate)

	var relic_tag = Label.new()
	relic_tag.name = "relic_tag"
	relic_tag.text = "◆ レリック ◆\nPASSIVE"
	relic_tag.position = Vector2(728.0, 974.0)
	relic_tag.size = Vector2(118.0, 68.0)
	relic_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	relic_tag.add_theme_font_override("font", sys_font)
	relic_tag.add_theme_font_size_override("font_size", 16)
	relic_tag.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	relic_tag.add_theme_constant_override("outline_size", 4)
	relic_tag.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(relic_tag)

	var relic_vline = ColorRect.new()
	relic_vline.name = "relic_vline"
	relic_vline.position = Vector2(852.0, 954.0)
	relic_vline.size = Vector2(2.0, 110.0)
	relic_vline.color = div_color
	relic_vline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_vline.z_index = -8
	add_child(relic_vline)

	container = HFlowContainer.new()
	container.name = "relic_container"
	container.position = Vector2(860.0, 960.0)
	container.size = Vector2(1044.0, 98.0)
	container.add_theme_constant_override("h_separation", 8)
	container.add_theme_constant_override("v_separation", 8)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_bottom_bar_nodes = [
		skill_rect, skill2_rect, skill_plate, skill_tag, skill_vline, skill_container,
		relic_rect, relic2_rect, relic_plate, relic_tag, relic_vline, container
	]
	
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.position = Vector2(316, 710)
	info_panel.size = Vector2(520, 180)
	info_panel.custom_minimum_size = Vector2(480, 110)
	info_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	info_panel.z_index = 100
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.01, 0.02, 0.75)
	style.border_color = Color(0.85, 0.72, 0.38, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	info_panel.add_theme_stylebox_override("panel", style)
	info_panel.mouse_exited.connect(func():
		var m_pos = info_panel.get_global_mouse_position() if info_panel else (get_viewport().get_mouse_position() if get_viewport() else Vector2.ZERO)
		if not info_panel.get_global_rect().has_point(m_pos):
			info_panel.visible = false
			hide_glossary_tooltip()
	)
	add_child(info_panel)
	
	var vbox = VBoxContainer.new()
	# PASS にしないと子の RichTextLabel が用語ホバーを受け取れない
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	info_panel.add_child(vbox)
	
	name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(480, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	GlossaryDatabase.bind_rich_text_label(name_label)
	name_label.add_theme_font_override("normal_font", sys_font)
	name_label.add_theme_font_override("bold_font", sys_font)
	name_label.add_theme_font_size_override("normal_font_size", 28)
	name_label.add_theme_font_size_override("bold_font_size", 28)
	vbox.add_child(name_label)
	
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(480, 0)
	desc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	GlossaryDatabase.bind_rich_text_label(desc_label)
	desc_label.add_theme_font_override("normal_font", sys_font)
	desc_label.add_theme_font_override("bold_font", sys_font)
	vbox.add_child(desc_label)

	# 盤面セルに重なっている全効果を、1件1パネルで上下に並べて表示するツールチップ
	cell_tooltip_panel = PanelContainer.new()
	cell_tooltip_panel.name = "BoardCellEffectsPanel"
	cell_tooltip_panel.visible = false
	cell_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	cell_tooltip_panel.z_index = 120
	var cell_style = StyleBoxFlat.new()
	cell_style.bg_color = Color(0.01, 0.01, 0.02, 0.86)
	cell_style.border_color = Color(0.85, 0.72, 0.38, 1.0)
	cell_style.set_border_width_all(2)
	cell_style.set_corner_radius_all(10)
	cell_style.shadow_color = Color(0, 0, 0, 0.75)
	cell_style.shadow_size = 12
	cell_style.content_margin_left = 8
	cell_style.content_margin_right = 8
	cell_style.content_margin_top = 8
	cell_style.content_margin_bottom = 8
	cell_tooltip_panel.add_theme_stylebox_override("panel", cell_style)
	cell_tooltip_panel.mouse_exited.connect(func():
		if cell_tooltip_panel == null:
			return
		var m_pos = cell_tooltip_panel.get_global_mouse_position()
		if cell_tooltip_panel.get_global_rect().has_point(m_pos):
			return
		var over_glossary = glossary_panel != null and glossary_panel.visible and glossary_panel.get_global_rect().has_point(m_pos)
		cell_tooltip_panel.visible = false
		if not over_glossary:
			hide_glossary_tooltip()
	)
	add_child(cell_tooltip_panel)

	cell_tooltip_vbox = VBoxContainer.new()
	cell_tooltip_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	cell_tooltip_vbox.add_theme_constant_override("separation", 6)
	cell_tooltip_panel.add_child(cell_tooltip_vbox)

	# Wikipedia風 固有名詞解説用ホバーカード (Wikipedia-style Glossary Hovercard)
	glossary_panel = PanelContainer.new()
	glossary_panel.name = "GlossaryHovercard"
	glossary_panel.visible = false
	glossary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glossary_panel.z_index = 250
	var g_style = StyleBoxFlat.new()
	g_style.bg_color = Color(0.01, 0.01, 0.02, 0.75)
	g_style.border_color = Color(0.31, 0.76, 0.97, 1.0)
	g_style.set_border_width_all(2)
	g_style.set_corner_radius_all(10)
	g_style.shadow_color = Color(0, 0, 0, 0.8)
	g_style.shadow_size = 14
	g_style.content_margin_left = 16
	g_style.content_margin_right = 16
	g_style.content_margin_top = 12
	g_style.content_margin_bottom = 12
	glossary_panel.add_theme_stylebox_override("panel", g_style)
	add_child(glossary_panel)

	var g_vbox = VBoxContainer.new()
	g_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glossary_panel.add_child(g_vbox)

	glossary_title_label = RichTextLabel.new()
	glossary_title_label.bbcode_enabled = true
	glossary_title_label.fit_content = true
	glossary_title_label.custom_minimum_size = Vector2(360, 0)
	glossary_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glossary_title_label.add_theme_font_override("normal_font", sys_font)
	glossary_title_label.add_theme_font_override("bold_font", sys_font)
	glossary_title_label.add_theme_font_size_override("normal_font_size", 22)
	glossary_title_label.add_theme_font_size_override("bold_font_size", 22)
	g_vbox.add_child(glossary_title_label)

	var g_div = ColorRect.new()
	g_div.custom_minimum_size = Vector2(440, 1)
	g_div.color = Color(0.31, 0.76, 0.97, 0.4)
	g_div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g_vbox.add_child(g_div)

	glossary_desc_label = RichTextLabel.new()
	glossary_desc_label.bbcode_enabled = true
	glossary_desc_label.fit_content = true
	glossary_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	glossary_desc_label.custom_minimum_size = Vector2(440, 0)
	glossary_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glossary_desc_label.add_theme_font_override("normal_font", sys_font)
	glossary_desc_label.add_theme_font_override("bold_font", sys_font)
	glossary_desc_label.add_theme_font_size_override("normal_font_size", 17)
	glossary_desc_label.add_theme_font_size_override("bold_font_size", 17)
	g_vbox.add_child(glossary_desc_label)
	
	var rm: Node = null
	if is_inside_tree() and get_tree() and get_tree().get_root():
		rm = get_tree().get_root().find_child("RelicManager", true, false)
	if not rm:
		var p = get_parent()
		while p:
			if p.name == "RelicManager":
				rm = p
				break
			var f = p.find_child("RelicManager", true, false)
			if f:
				rm = f
				break
			p = p.get_parent()
	if rm:
		if not rm.is_connected("relic_added", _on_relic_added):
			rm.connect("relic_added", _on_relic_added)
		if not rm.is_connected("relic_leveled_up", _on_relic_leveled_up):
			rm.connect("relic_leveled_up", _on_relic_leveled_up)
		if not rm.is_connected("relic_triggered", _on_relic_triggered):
			rm.connect("relic_triggered", _on_relic_triggered)
		for r_id in rm.get_relics():
			_on_relic_added(r_id)

	var sm = get_parent().get_node_or_null("ScoreManager") if get_parent() else null
	if sm == null and get_tree() and get_tree().get_root():
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
		hide_cell_effect_tooltips()

func update_skill_display(skill_id: String, new_level: int) -> void:
	_on_skill_upgraded(skill_id, 0, new_level)

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

		var skill_icon = TextureRect.new()
		skill_icon.name = "SkillIcon"
		skill_icon.position = Vector2(2, 2)
		skill_icon.size = Vector2(52, 52)
		skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.add_child(skill_icon)

		var sys_font = _get_sys_font()
		var lbl = Label.new()
		lbl.name = "ShortLabel"
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

	# スキル／選択中進化のアイコンを反映
	var icon_path: String = sm.get_skill_display_icon_path(skill_id) if (sm and sm.has_method("get_skill_display_icon_path")) else ""
	var icon_rect = node_rect.get_node_or_null("SkillIcon") as TextureRect
	if icon_rect:
		icon_rect.texture = load(icon_path) if icon_path != "" else null
		icon_rect.visible = icon_rect.texture != null
	var short_lbl = node_rect.get_node_or_null("ShortLabel") as Label
	if short_lbl:
		short_lbl.visible = (icon_path == "")

	var l_lbl = node_rect.get_node_or_null("LevelLabel") as Label
	if l_lbl:
		l_lbl.text = "Lv%d" % new_level

	var evo_mid = sm.get_chosen_evolution(skill_id, 10) if (sm and sm.has_method("get_chosen_evolution")) else ""
	if evo_mid == "" and sm and sm.has_method("get_chosen_evolution"):
		evo_mid = sm.get_chosen_evolution(skill_id, 5)
	var evo_final = sm.get_chosen_evolution(skill_id, 15) if (sm and sm.has_method("get_chosen_evolution")) else ""
	if evo_final == "" and sm and sm.has_method("get_chosen_evolution"): evo_final = sm.get_chosen_evolution(skill_id, 20)

	var mid_name = sm._get_evolution_name(skill_id, 10, evo_mid) if (evo_mid != "" and sm.has_method("_get_evolution_name")) else ""
	if mid_name == "" and evo_mid != "" and sm and sm.has_method("_get_evolution_name"):
		mid_name = sm._get_evolution_name(skill_id, 5, evo_mid)
	var final_name = sm._get_evolution_name(skill_id, 20, evo_final) if (evo_final != "" and sm.has_method("_get_evolution_name")) else ""
	if final_name == "" and evo_final != "" and sm and sm.has_method("_get_evolution_name"):
		final_name = sm._get_evolution_name(skill_id, 15, evo_final)

	var evo_lbl = node_rect.get_node_or_null("EvoLabel") as Label
	if final_name != "" or mid_name != "":
		if evo_lbl == null:
			evo_lbl = Label.new()
			evo_lbl.name = "EvoLabel"
			evo_lbl.position = Vector2(0, 0)
			evo_lbl.size = Vector2(56, 18)
			evo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			evo_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			evo_lbl.add_theme_font_override("font", _get_sys_font())
			evo_lbl.add_theme_font_size_override("font_size", 11)
			evo_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			evo_lbl.add_theme_constant_override("outline_size", 3)
			node_rect.add_child(evo_lbl)
		if final_name != "":
			evo_lbl.text = "👑%s" % final_name.substr(0, 3)
			evo_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			evo_lbl.text = "✨%s" % mid_name.substr(0, 3)
			evo_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	elif evo_lbl != null:
		evo_lbl.queue_free()

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
	if _tooltip_close_timer != null and _tooltip_close_timer.is_valid():
		_tooltip_close_timer.kill()
	_tooltip_close_timer = create_tween()
	_tooltip_close_timer.tween_interval(0.15)
	_tooltip_close_timer.tween_callback(func():
		if info_panel and info_panel.visible and info_panel.get_meta("current_id", "") == meta_key:
			var m_pos = info_panel.get_global_mouse_position() if info_panel else (get_viewport().get_mouse_position() if get_viewport() else Vector2.ZERO)
			if not info_panel.get_global_rect().has_point(m_pos):
				info_panel.visible = false
				hide_glossary_tooltip()
	)

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

	var evo_mid = sm.get_chosen_evolution(skill_id, 10) if (sm and sm.has_method("get_chosen_evolution")) else ""
	if evo_mid == "" and sm and sm.has_method("get_chosen_evolution"):
		evo_mid = sm.get_chosen_evolution(skill_id, 5)
	var evo_final = sm.get_chosen_evolution(skill_id, 15) if (sm and sm.has_method("get_chosen_evolution")) else ""
	if evo_final == "" and sm and sm.has_method("get_chosen_evolution"): evo_final = sm.get_chosen_evolution(skill_id, 20)

	var mid_name = sm._get_evolution_name(skill_id, 10, evo_mid) if (evo_mid != "" and sm.has_method("_get_evolution_name")) else ""
	var final_name = sm._get_evolution_name(skill_id, 20, evo_final) if (evo_final != "" and sm.has_method("_get_evolution_name")) else ""

	var title_evo_suffix = ""
	if final_name != "":
		title_evo_suffix = " 👑[%s]" % final_name
	elif mid_name != "":
		title_evo_suffix = " ✨[%s]" % mid_name

	name_label.text = GlossaryDatabase.format_text("[b][color=#%s]🌿 %s%s%s[/color][/b]" % [col_hex, s_data.get("name", "Skill"), level_str, title_evo_suffix])

	var desc_arr: Array = s_data.get("desc_lv", [])
	var cur_desc: String = desc_arr[clampi(cur_lvl - 1, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else ""
	var evo_desc_block: String = ""
	if evo_mid != "":
		var m_data = sm.get_evolution_data(skill_id, 10, evo_mid) if sm.has_method("get_evolution_data") else {}
		evo_desc_block += "\n\n[font_size=20][b][color=#80D8FF]✨【第1覚醒: %s】[/color][/b] [color=#B0BEC5](%s)[/color]\n[color=#E0F7FA]%s[/color][/font_size]" % [
			m_data.get("name", evo_mid), m_data.get("role", "覚醒"), m_data.get("desc", "")
		]
	if evo_final != "":
		var f_data = sm.get_evolution_data(skill_id, 20, evo_final) if sm.has_method("get_evolution_data") else {}
		evo_desc_block += "\n\n[font_size=20][b][color=#FFD700]👑【最終覚醒: %s】[/color][/b] [color=#FFE082](%s)[/color]\n[color=#FFF8E1]%s[/color][/font_size]" % [
			f_data.get("name", evo_final), f_data.get("role", "究極神格"), f_data.get("desc", "")
		]

	if is_max:
		desc_label.text = "[font_size=22][color=#FFD700]【最大レベル】[/color]\n%s%s[/font_size]" % [
			GlossaryDatabase.format_text(cur_desc), GlossaryDatabase.format_text(evo_desc_block)
		]
	else:
		var next_desc: String = desc_arr[clampi(cur_lvl, 0, desc_arr.size() - 1)] if not desc_arr.is_empty() else ""
		desc_label.text = "[font_size=22][color=#FFFFFF]現在: %s[/color]%s\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [
			GlossaryDatabase.format_text(cur_desc), GlossaryDatabase.format_text(evo_desc_block), cur_lvl + 1, GlossaryDatabase.format_text(next_desc)
		]

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
	hide_cell_effect_tooltips()
	if name_label: name_label.text = GlossaryDatabase.format_text(title)
	if desc_label: desc_label.text = GlossaryDatabase.format_text(desc)
	info_panel.set_meta("current_id", meta_key)
	info_panel.reset_size()

	var panel_w = maxf(480.0, info_panel.size.x)
	var panel_h = maxf(110.0, info_panel.size.y)
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
		hide_glossary_tooltip()

## 盤面セルに重なっている全効果を、1件1パネルで縦に積んで表示する。
## entries: [{"title": String, "desc": String, "color": String}, ...]
func show_cell_effect_tooltips(entries: Array, screen_pos: Vector2) -> void:
	if cell_tooltip_panel == null or cell_tooltip_vbox == null:
		return
	if entries.is_empty():
		hide_cell_effect_tooltips()
		return

	if info_panel:
		info_panel.visible = false
	hide_glossary_tooltip()

	for row in _cell_tooltip_rows:
		if row != null and is_instance_valid(row):
			cell_tooltip_vbox.remove_child(row)
			row.queue_free()
	_cell_tooltip_rows.clear()

	var font = _get_sys_font()
	for entry in entries:
		var row = PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = Color(0.025, 0.035, 0.055, 0.94)
		row_style.border_color = Color.from_string(str(entry.get("color", "#FFD54F")), Color(1.0, 0.84, 0.3))
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(8)
		row_style.content_margin_left = 12
		row_style.content_margin_right = 12
		row_style.content_margin_top = 8
		row_style.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", row_style)

		var row_box = VBoxContainer.new()
		row_box.mouse_filter = Control.MOUSE_FILTER_PASS
		row_box.add_theme_constant_override("separation", 3)
		row.add_child(row_box)

		var title_lbl = RichTextLabel.new()
		title_lbl.bbcode_enabled = true
		title_lbl.fit_content = true
		title_lbl.scroll_active = false
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.custom_minimum_size = Vector2(500, 0)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		title_lbl.add_theme_font_override("normal_font", font)
		title_lbl.add_theme_font_override("bold_font", font)
		title_lbl.add_theme_font_size_override("normal_font_size", 18)
		title_lbl.add_theme_font_size_override("bold_font_size", 18)
		title_lbl.text = GlossaryDatabase.format_text(str(entry.get("title", "")))
		GlossaryDatabase.bind_rich_text_label(title_lbl)
		row_box.add_child(title_lbl)

		var desc_lbl = RichTextLabel.new()
		desc_lbl.bbcode_enabled = true
		desc_lbl.fit_content = true
		desc_lbl.scroll_active = false
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(500, 0)
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		desc_lbl.add_theme_font_override("normal_font", font)
		desc_lbl.add_theme_font_override("bold_font", font)
		desc_lbl.add_theme_font_size_override("normal_font_size", 15)
		desc_lbl.add_theme_font_size_override("bold_font_size", 15)
		desc_lbl.text = GlossaryDatabase.format_text(str(entry.get("desc", "")))
		GlossaryDatabase.bind_rich_text_label(desc_lbl)
		row_box.add_child(desc_lbl)

		cell_tooltip_vbox.add_child(row)
		_cell_tooltip_rows.append(row)

	cell_tooltip_panel.reset_size()
	var panel_w = maxf(540.0, cell_tooltip_panel.size.x)
	var panel_h = maxf(120.0, cell_tooltip_panel.size.y)
	var target_x = clampf(screen_pos.x + 24.0, 20.0, 1920.0 - panel_w - 20.0)
	var target_y = clampf(screen_pos.y - panel_h - 15.0, 20.0, 1080.0 - panel_h - 20.0)
	if screen_pos.y - panel_h - 15.0 < 20.0:
		target_y = clampf(screen_pos.y + 30.0, 20.0, 1080.0 - panel_h - 20.0)
	cell_tooltip_panel.position = Vector2(target_x, target_y)
	cell_tooltip_panel.visible = true

func hide_cell_effect_tooltips() -> void:
	if cell_tooltip_panel:
		cell_tooltip_panel.visible = false
	hide_glossary_tooltip()

## 盤面セル用ツールチップの上にマウスがあるか（用語ホバー中に消さないため）
func is_cell_tooltip_under_mouse(global_pos: Vector2) -> bool:
	return cell_tooltip_panel != null and cell_tooltip_panel.visible and cell_tooltip_panel.get_global_rect().has_point(global_pos)

func _on_relic_added(id: String) -> void:
	if icon_nodes.has(id): return
	var r_data = RelicDatabase.get_relic(id)
	if r_data.is_empty(): return
	
	var rect = ColorRect.new()
	rect.custom_minimum_size = Vector2(56, 56)
	rect.size = Vector2(56, 56)
	
	var rarity = r_data.get("rarity", "common")
	var rarity_col: Color
	if rarity == "legendary": rarity_col = Color(0.85, 0.65, 0.08)
	elif rarity == "epic": rarity_col = Color(0.60, 0.18, 0.82)
	elif rarity == "rare": rarity_col = Color(0.18, 0.45, 0.92)
	elif rarity == "uncommon": rarity_col = Color(0.16, 0.68, 0.24)
	elif rarity == "cursed": rarity_col = Color(0.55, 0.06, 0.16)
	else: rarity_col = Color(0.48, 0.50, 0.54)

	# 背景透過済みのレリックアイコン
	var icon_texture := RelicDatabase.get_icon(id)

	# アイコンが存在する場合は重厚なオブシディアンガラス調の背景（透過画像が美しく映える）
	# アイコンが無い場合のみフォールバックとしてレアリティ色をベタ塗り
	if icon_texture != null:
		rect.color = Color(0.02, 0.02, 0.04, 0.85)
	else:
		rect.color = rarity_col

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

	if icon_texture != null:
		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(50, 50)
		icon_rect.size = Vector2(50, 50)
		icon_rect.position = Vector2(3, 3)
		icon_rect.texture = icon_texture
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.clip_contents = true
		rect.add_child(icon_rect)

	var sys_font = _get_sys_font()
	# レリック頭文字ラベル（アイコン未配置時のフォールバック）
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
	lbl.visible = icon_texture == null
	rect.add_child(lbl)
	
	# レベルラベル (Lv1から常時わかりやすく表示)
	var lvl_lbl = Label.new()
	lvl_lbl.name = "LevelLabel"
	var rm: Node = null
	if is_inside_tree() and get_tree() and get_tree().get_root():
		rm = get_tree().get_root().find_child("RelicManager", true, false)
	if not rm:
		var p = get_parent()
		while p:
			if p.name == "RelicManager": rm = p; break
			var f = p.find_child("RelicManager", true, false)
			if f: rm = f; break
			p = p.get_parent()
	var cur_lvl = rm.get_level(id) if (rm and rm.has_method("get_level")) else 1
	lvl_lbl.text = "Lv%d" % cur_lvl
	lvl_lbl.position = Vector2(14, 34)
	lvl_lbl.size = Vector2(40, 22)
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_lbl.add_theme_font_override("font", sys_font)
	lvl_lbl.add_theme_font_size_override("font_size", 14)
	lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25, 1.0))
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
	name_label.text = GlossaryDatabase.format_text("[b][color=" + r_color + "]" + r_data.get("name", "Unknown") + " [" + rarity_tag + "]" + level_str + "[/color][/b]")
	
	var desc_cur = RelicDatabase.get_description(id, cur_lvl)
	if is_max:
		desc_label.text = "[font_size=23][color=#FFD700]【最大レベル】[/color]\n%s[/font_size]" % GlossaryDatabase.format_text(desc_cur)
	else:
		var desc_next = RelicDatabase.get_description(id, cur_lvl + 1)
		desc_label.text = "[font_size=22][color=#FFFFFF]現在: %s[/color]\n\n[color=#FFD700]次 (Lv%d): %s[/color][/font_size]" % [
			GlossaryDatabase.format_text(desc_cur), cur_lvl + 1, GlossaryDatabase.format_text(desc_next)
		]
		
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


## Wikipedia風 固有名詞解説ホバーカードの表示
func show_glossary_tooltip(term_key: String, mouse_pos: Vector2) -> void:
	if not glossary_panel or not glossary_title_label or not glossary_desc_label:
		return
	var term_data = GlossaryDatabase.get_term(term_key)
	if term_data.is_empty():
		return

	var col = term_data.get("color", "#4FC3F7")
	var title = term_data.get("title", term_key)
	var desc = term_data.get("desc", "")

	glossary_title_label.text = "[b][color=%s]📖 %s[/color][/b]" % [col, title]
	glossary_desc_label.text = "[color=#ECEFF1]%s[/color]" % desc

	glossary_panel.reset_size()
	var pw = maxf(460.0, glossary_panel.size.x)
	var ph = maxf(120.0, glossary_panel.size.y)

	var tx = clampf(mouse_pos.x + 16.0, 20.0, 1920.0 - pw - 20.0)
	var ty = clampf(mouse_pos.y + 20.0, 20.0, 1080.0 - ph - 20.0)
	if mouse_pos.y + ph + 30.0 > 1080.0:
		ty = clampf(mouse_pos.y - ph - 16.0, 20.0, 1080.0 - ph - 20.0)

	glossary_panel.position = Vector2(tx, ty)
	glossary_panel.visible = true

## Wikipedia風 固有名詞解説ホバーカードの非表示
func hide_glossary_tooltip() -> void:
	if glossary_panel:
		glossary_panel.visible = false

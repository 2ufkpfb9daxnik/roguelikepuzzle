extends CanvasLayer
class_name RelicSelectionUI
const GlossaryDatabase = preload("res://glossary_database.gd")

signal selection_finished()

const RELIC_WEIGHT_COMMON: float = 42.0
const RELIC_WEIGHT_UNCOMMON: float = 28.0
const RELIC_WEIGHT_RARE: float = 16.0
const RELIC_WEIGHT_EPIC: float = 10.0
const RELIC_WEIGHT_LEGENDARY: float = 4.0
const RELIC_WEIGHT_CURSED: float = 8.0
const RELIC_OWNED_WEIGHT_MULT: float = 1.5

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
	style.bg_color = Color(0.01, 0.01, 0.02, 0.70)
	style.border_color = Color(0.8, 0.6, 0.1, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.custom_minimum_size = Vector2(1540, 760)
	panel.size = Vector2(1540, 760)
	panel.position = Vector2((1920.0 - 1540.0) / 2.0, (1080.0 - 760.0) / 2.0)
	add_child(panel)
	
	title_label = Label.new()
	title_label.text = "レリックを選択"
	if CUSTOM_FONT:
		title_label.add_theme_font_override("font", CUSTOM_FONT)
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.position = Vector2(0, 25)
	title_label.size = Vector2(1540, 75)
	panel.add_child(title_label)
	
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	hbox.position = Vector2(0, 110)
	hbox.size = Vector2(1540, 540)
	panel.add_child(hbox)
	
	skip_btn = Button.new()
	skip_btn.text = "スキップ (Skip)"
	if CUSTOM_FONT:
		skip_btn.add_theme_font_override("font", CUSTOM_FONT)
	skip_btn.add_theme_font_size_override("font_size", 32)
	skip_btn.custom_minimum_size = Vector2(280, 65)
	skip_btn.size = Vector2(280, 65)
	skip_btn.position = Vector2((1540.0 - 280.0) / 2.0, 670)
	skip_btn.pressed.connect(_on_skip_pressed)
	panel.add_child(skip_btn)
	
	_populate_choices()

func _populate_choices() -> void:
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

	if not rm:
		call_deferred("_on_skip_pressed")
		return

	if hbox == null:
		return
		
	for ch in hbox.get_children():
		hbox.remove_child(ch)
		ch.queue_free()
		
	var choices: Array[String] = []

	# 最初の敵撃破後（属性カテゴリー未選択の場合）：3つの属性系統スキル解放権から選択
	if not rm.has_chosen_element_category():
		title_label.text = "【スキル解放権（属性カテゴリー）選択】冒険で使用する属性系統のスキル解放権を選択してください"
		title_label.add_theme_font_size_override("font_size", 34)
		if skip_btn:
			skip_btn.visible = false # カテゴリー選択は必須選択
		choices = ["relic_cat_nature", "relic_cat_force", "relic_cat_mystic"]
	else:
		# 候補プール: 通常レリックのみ（カテゴリーレリック除外）、最大レベル未満
		var pool: Array[String] = []
		for r_id in RelicDatabase.RELICS.keys():
			if r_id.begins_with("relic_cat_"):
				continue
			if not rm.is_max_level(r_id):
				pool.append(r_id)
				
		if pool.is_empty():
			# 候補が0個なら画面を出さずに終了
			call_deferred("_on_skip_pressed")
			return
			
		var pool_copy = pool.duplicate()
		var pick_count = mini(3, pool_copy.size())
		
		for _i in range(pick_count):
			# 各候補の重みを計算
			var weights: Array[float] = []
			var total_weight: float = 0.0
			for r_id in pool_copy:
				var r_data = RelicDatabase.get_relic(r_id)
				var rarity = r_data.get("rarity", "common")
				var base_w = RELIC_WEIGHT_COMMON
				if rarity == "uncommon":
					base_w = RELIC_WEIGHT_UNCOMMON
				elif rarity == "rare":
					base_w = RELIC_WEIGHT_RARE
				elif rarity == "epic":
					base_w = RELIC_WEIGHT_EPIC
				elif rarity == "legendary":
					base_w = RELIC_WEIGHT_LEGENDARY
				elif rarity == "cursed":
					base_w = RELIC_WEIGHT_CURSED
					
				var w = base_w
				if rm.has_relic(r_id):
					w *= RELIC_OWNED_WEIGHT_MULT
				weights.append(w)
				total_weight += w
				
			var roll = randf() * total_weight
			var cumulative: float = 0.0
			var chosen_idx: int = 0
			for idx in range(pool_copy.size()):
				cumulative += weights[idx]
				if roll <= cumulative:
					chosen_idx = idx
					break
					
			choices.append(pool_copy[chosen_idx])
			pool_copy.remove_at(chosen_idx)
		
	for c_id in choices:
		var c_data = RelicDatabase.get_relic(c_id)
		var cur_lvl = rm.get_level(c_id)
		var next_lvl = cur_lvl + 1
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(450, 520)
		btn.size = Vector2(450, 520)
		
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.02, 0.02, 0.04, 0.65)
		var rarity = c_data.get("rarity", "common")
		if rarity == "legendary":
			b_style.border_color = Color(1.0, 0.84, 0.1, 1.0)
		elif rarity == "epic":
			b_style.border_color = Color(0.78, 0.28, 0.98, 1.0)
		elif rarity == "rare":
			b_style.border_color = Color(0.25, 0.65, 1.0, 1.0)
		elif rarity == "uncommon":
			b_style.border_color = Color(0.25, 0.85, 0.35, 1.0)
		elif rarity == "cursed":
			b_style.border_color = Color(1.0, 0.15, 0.35, 1.0)
			b_style.bg_color = Color(0.06, 0.01, 0.03, 0.65)
		else:
			b_style.border_color = Color(0.68, 0.72, 0.76, 1.0)
		b_style.set_border_width_all(5)
		b_style.set_corner_radius_all(16)
		btn.add_theme_stylebox_override("normal", b_style)
		
		var h_style = b_style.duplicate()
		h_style.bg_color = Color(0.06, 0.06, 0.10, 0.75)
		btn.add_theme_stylebox_override("hover", h_style)
		
		var vbox = VBoxContainer.new()
		vbox.position = Vector2(20, 16)
		vbox.size = Vector2(410, 488)
		vbox.custom_minimum_size = Vector2(410, 488)
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)
		
		# バッジ表示 (未所持: NEW, 所持中: LvX -> LvX+1)
		var badge_label = RichTextLabel.new()
		badge_label.bbcode_enabled = true
		badge_label.fit_content = true
		badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if CUSTOM_FONT:
			badge_label.add_theme_font_override("normal_font", CUSTOM_FONT)
			badge_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		badge_label.add_theme_font_size_override("normal_font_size", 22)
		badge_label.add_theme_font_size_override("bold_font_size", 22)
		
		if cur_lvl == 0:
			badge_label.text = "[center][b][color=#00E5FF]★ NEW ★[/color][/b][/center]"
		else:
			badge_label.text = "[center][b][color=#76FF03]強化: Lv%d → Lv%d[/color][/b][/center]" % [cur_lvl, next_lvl]
		vbox.add_child(badge_label)
		
		# レリック名
		var r_label = Label.new()
		r_label.text = c_data.get("name", "???")
		r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r_label.custom_minimum_size = Vector2(410, 56)
		if CUSTOM_FONT:
			r_label.add_theme_font_override("font", CUSTOM_FONT)
		r_label.add_theme_font_size_override("font_size", 22)
		if rarity == "legendary":
			r_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
		elif rarity == "epic":
			r_label.add_theme_color_override("font_color", Color(0.85, 0.45, 1.0))
		elif rarity == "rare":
			r_label.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
		elif rarity == "uncommon":
			r_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
		elif rarity == "cursed":
			r_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.45))
		else:
			r_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		vbox.add_child(r_label)
		
		# レアリティ表記
		var rarity_label = Label.new()
		if rarity == "legendary":
			rarity_label.text = "★ LEGENDARY ★"
			rarity_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.1))
		elif rarity == "epic":
			rarity_label.text = "◆ EPIC ◆"
			rarity_label.add_theme_color_override("font_color", Color(0.85, 0.45, 1.0))
		elif rarity == "rare":
			rarity_label.text = "RARE"
			rarity_label.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
		elif rarity == "uncommon":
			rarity_label.text = "UNCOMMON"
			rarity_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		elif rarity == "cursed":
			rarity_label.text = "☠ CURSED (呪い) ☠"
			rarity_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.35))
		else:
			rarity_label.text = "COMMON"
			rarity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if CUSTOM_FONT:
			rarity_label.add_theme_font_override("font", CUSTOM_FONT)
		rarity_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(rarity_label)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		vbox.add_child(spacer)
		
		# 説明文（未所持ならLv1説明、所持中なら現在値と強化後値の対比）
		var d_label = RichTextLabel.new()
		d_label.bbcode_enabled = true
		d_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_label.fit_content = true
		d_label.scroll_active = false
		d_label.custom_minimum_size = Vector2(410, 240)
		if CUSTOM_FONT:
			d_label.add_theme_font_override("normal_font", CUSTOM_FONT)
			d_label.add_theme_font_override("bold_font", CUSTOM_FONT)
		d_label.add_theme_font_size_override("normal_font_size", 18)
		d_label.add_theme_font_size_override("bold_font_size", 18)
		d_label.mouse_filter = Control.MOUSE_FILTER_PASS
		GlossaryDatabase.bind_rich_text_label(d_label)
		
		if cur_lvl == 0:
			var desc1 = RelicDatabase.get_description(c_id, 1)
			d_label.text = "[center]%s[/center]" % GlossaryDatabase.format_text(desc1)
		else:
			var desc_cur = RelicDatabase.get_description(c_id, cur_lvl)
			var desc_next = RelicDatabase.get_description(c_id, next_lvl)
			d_label.text = "[center][color=#888888]現在: %s[/color]\n\n[color=#FFD700]▼ 次のレベル ▼\n[b]%s[/b][/color][/center]" % [
				GlossaryDatabase.format_text(desc_cur), GlossaryDatabase.format_text(desc_next)
			]
		vbox.add_child(d_label)
		
		btn.pressed.connect(_on_choice_pressed.bind(c_id))
		hbox.add_child(btn)

func _on_choice_pressed(id: String) -> void:
	var rm = get_tree().get_root().find_child("RelicManager", true, false)
	if rm:
		rm.add_relic(id)
	
	emit_signal("selection_finished")
	queue_free()

func _on_skip_pressed() -> void:
	emit_signal("selection_finished")
	queue_free()

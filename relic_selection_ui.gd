extends CanvasLayer
class_name RelicSelectionUI
const GlossaryDatabase = preload("res://glossary_database.gd")

signal selection_finished()

const RELIC_WEIGHT_COMMON: float = 40.0
const RELIC_WEIGHT_UNCOMMON: float = 28.0
const RELIC_WEIGHT_RARE: float = 16.0
const RELIC_WEIGHT_EPIC: float = 8.0
const RELIC_WEIGHT_LEGENDARY: float = 3.0
const RELIC_WEIGHT_CURSED: float = 5.0
const RELIC_OWNED_WEIGHT_MULT: float = 1.5

var panel: Panel
var title_label: Label
var hbox: HBoxContainer
var skip_btn: Button
var current_choices: Array[String] = []

const CUSTOM_FONT = preload("res://font/g_comickoin_freeR.ttf")

func _init() -> void:
	name = "RelicSelectionUI"

func _get_settings_manager() -> Node:
	if is_inside_tree() and get_tree() and get_tree().get_root():
		var sm = get_tree().get_root().get_node_or_null("SettingsManager")
		if sm: return sm
		sm = get_tree().get_root().find_child("SettingsManager", true, false)
		if sm: return sm
	var p = get_parent()
	while p:
		if p.name == "SettingsManager":
			return p
		var f = p.find_child("SettingsManager", true, false)
		if f:
			return f
		p = p.get_parent()
	return null

func _play_ui_se(kind: String) -> void:
	var sm = _get_settings_manager()
	if sm and sm.has_method("play_ui_se"):
		sm.play_ui_se(kind)

func _is_tutorial_mode() -> bool:
	var sm = _get_settings_manager()
	return bool(sm and "is_tutorial_mode" in sm and sm.is_tutorial_mode)

func _ready() -> void:
	layer = 60
	if CUSTOM_FONT is Font:
		CUSTOM_FONT.set_fallbacks([load("res://font/NotoSansJP.ttf"), load("res://font/NotoEmoji.ttf")])
	
	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1920, 1080)
	add_child(dim)
	
	var is_tut := _is_tutorial_mode()

	panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.01, 0.02, 0.70)
	style.border_color = Color(0.8, 0.6, 0.1, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", style)
	
	if is_tut:
		panel.custom_minimum_size = Vector2(1540, 670)
		panel.size = Vector2(1540, 670)
		panel.position = Vector2((1920.0 - 1540.0) / 2.0, 25.0)
	else:
		panel.custom_minimum_size = Vector2(1540, 800)
		panel.size = Vector2(1540, 800)
		panel.position = Vector2((1920.0 - 1540.0) / 2.0, (1080.0 - 800.0) / 2.0)
	add_child(panel)
	
	title_label = Label.new()
	title_label.text = "レリックを選択"
	if CUSTOM_FONT:
		title_label.add_theme_font_override("font", CUSTOM_FONT)
	title_label.add_theme_font_size_override("font_size", 34 if is_tut else 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.position = Vector2(0, 12 if is_tut else 18)
	title_label.size = Vector2(1540, 50 if is_tut else 60)
	panel.add_child(title_label)
	
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	hbox.position = Vector2(0, 68 if is_tut else 85)
	hbox.size = Vector2(1540, 585 if is_tut else 620)
	panel.add_child(hbox)
	
	skip_btn = Button.new()
	skip_btn.text = "スキップ (Skip)"
	if CUSTOM_FONT:
		skip_btn.add_theme_font_override("font", CUSTOM_FONT)
	skip_btn.add_theme_font_size_override("font_size", 32)
	skip_btn.custom_minimum_size = Vector2(280, 65)
	skip_btn.size = Vector2(280, 65)
	skip_btn.position = Vector2((1540.0 - 280.0) / 2.0, 715)
	skip_btn.pressed.connect(func():
		_play_ui_se("select")
		_on_skip_pressed()
	)
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
		var is_tut := _is_tutorial_mode()
		if is_tut:
			if panel:
				panel.custom_minimum_size = Vector2(1540, 670)
				panel.size = Vector2(1540, 670)
				panel.position = Vector2((1920.0 - 1540.0) / 2.0, 25.0)
			if title_label:
				title_label.position = Vector2(0, 12)
				title_label.size = Vector2(1540, 50)
			if hbox:
				hbox.position = Vector2(0, 68)
				hbox.size = Vector2(1540, 585)
			# チュートリアル時は真ん中に「自然・生命系（水・清流）」を配置
			choices = ["relic_cat_force", "relic_cat_nature", "relic_cat_mystic"]
		else:
			choices = ["relic_cat_nature", "relic_cat_force", "relic_cat_mystic"]
	else:
		choices = _roll_candidates(rm)
		if choices.is_empty():
			call_deferred("_on_skip_pressed")
			return
		
	current_choices = choices.duplicate()
	for card_idx in range(choices.size()):
		var c_id = choices[card_idx]
		var c_data = RelicDatabase.get_relic(c_id)
		var cur_lvl = rm.get_level(c_id)
		var next_lvl = cur_lvl + 1
		
		var is_tut_card := _is_tutorial_mode()
		var card_h_size: float = 580.0 if is_tut_card else 615.0
		var card_vbox_h: float = 562.0 if is_tut_card else 595.0

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(450, card_h_size)
		btn.size = Vector2(450, card_h_size)
		
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
		vbox.position = Vector2(20, 8 if is_tut_card else 10)
		vbox.size = Vector2(410, card_vbox_h)
		vbox.custom_minimum_size = Vector2(410, card_vbox_h)
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		vbox.add_theme_constant_override("separation", 3)
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
		
		# レリックアイコン（背景透過PNG・超大型 250x250 プレート）
		var icon_plate = Panel.new()
		icon_plate.custom_minimum_size = Vector2(250, 250)
		icon_plate.size = Vector2(250, 250)
		icon_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_plate.clip_contents = true
		var icon_style = StyleBoxFlat.new()
		icon_style.bg_color = Color(0.01, 0.01, 0.02, 0.70)
		icon_style.border_color = Color(b_style.border_color.r, b_style.border_color.g, b_style.border_color.b, 0.85)
		icon_style.set_border_width_all(3)
		icon_style.set_corner_radius_all(18)
		icon_plate.add_theme_stylebox_override("panel", icon_style)
		
		var icon_rect = TextureRect.new()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(238, 238)
		icon_rect.size = Vector2(238, 238)
		icon_rect.position = Vector2(6, 6)
		icon_rect.texture = RelicDatabase.get_icon(c_id)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_plate.add_child(icon_rect)
		icon_plate.visible = icon_rect.texture != null
		vbox.add_child(icon_plate)
		
		# レリック名
		var r_label = Label.new()
		var relic_name := str(c_data.get("name", "???"))
		r_label.text = relic_name
		r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r_label.custom_minimum_size = Vector2(410, 52)
		if CUSTOM_FONT:
			r_label.add_theme_font_override("font", CUSTOM_FONT)
		r_label.add_theme_font_size_override("font_size", 22 if relic_name.length() > 24 else 24)
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
		rarity_label.add_theme_font_size_override("font_size", 18)
		vbox.add_child(rarity_label)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(spacer)
		
		# 説明文（スクロール可能・切れてもスクロールで全文閲覧可能）
		var d_label = RichTextLabel.new()
		d_label.bbcode_enabled = true
		d_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d_label.fit_content = false
		d_label.scroll_active = true
		d_label.custom_minimum_size = Vector2(410, 140 if is_tut_card else 165)
		d_label.size = Vector2(410, 140 if is_tut_card else 165)
		d_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if CUSTOM_FONT:
			d_label.add_theme_font_override("normal_font", CUSTOM_FONT)
			d_label.add_theme_font_override("bold_font", CUSTOM_FONT)
			d_label.add_theme_font_override("italics_font", CUSTOM_FONT)
			d_label.add_theme_font_override("bold_italics_font", CUSTOM_FONT)
			d_label.add_theme_font_override("mono_font", CUSTOM_FONT)
		d_label.add_theme_font_size_override("normal_font_size", 22)
		d_label.add_theme_font_size_override("bold_font_size", 22)
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
		
		var is_tut_btn := _is_tutorial_mode()
		if is_tut_btn and choices.size() >= 3:
			if card_idx == 1:
				b_style.border_color = Color(1.0, 0.88, 0.2, 1.0)
				b_style.set_border_width_all(7)
			else:
				btn.modulate = Color(0.65, 0.65, 0.65, 0.85)

		btn.mouse_entered.connect(func(): _play_ui_se("hover"))
		btn.pressed.connect(func():
			if is_tut_btn and choices.size() >= 3 and card_idx != 1:
				return
			_play_ui_se("select")
			_on_choice_pressed(c_id)
		)
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


## 属性IDを系統カテゴリーへ変換する（ElementData の enum と同順）
func _element_category_for_id(el_id: int) -> String:
	match el_id:
		1, 4, 10: # FIRE / THUNDER / EARTH
			return "force"
		2, 3, 8, 9: # WATER / WIND / ICE / WOOD
			return "nature"
		5, 6, 7: # LIGHT / DARK / POISON
			return "mystic"
	return ""

## 選択済みカテゴリーに専門特化したレリックだけを候補に残す。
## 汎用・全属性レリックは常に候補に残す。
func _relic_matches_category(r_data: Dictionary, chosen_cat: String) -> bool:
	var r_cat: String = str(r_data.get("element_category", ""))
	if r_cat == "all":
		return true
	if r_cat != "":
		return r_cat == chosen_cat
	var inferred_cats: Dictionary = {}
	for lv in r_data.get("levels", []):
		if lv is Dictionary and lv.has("element"):
			var cat: String = _element_category_for_id(int(lv["element"]))
			if cat != "":
				inferred_cats[cat] = true
	if inferred_cats.is_empty():
		return true
	return inferred_cats.has(chosen_cat)

func _roll_candidates(rm: Node) -> Array[String]:
	var pool: Array[String] = []
	for r_id in RelicDatabase.RELICS.keys():
		if r_id.begins_with("relic_cat_"):
			continue
		if not rm.is_max_level(r_id):
			pool.append(r_id)
			
	if pool.is_empty():
		return []
		
	var chosen_cat = rm.get_chosen_element_category() if rm.has_method("get_chosen_element_category") else ""
	if chosen_cat != "":
		# 他系統の専門レリックは候補から完全に除外する
		var filtered: Array[String] = []
		for r_id in pool:
			if _relic_matches_category(RelicDatabase.get_relic(r_id), chosen_cat):
				filtered.append(r_id)
		pool = filtered

	var pool_copy = pool.duplicate()
	var pick_count = mini(3, pool_copy.size())
	var picks: Array[String] = []
	
	for _i in range(pick_count):
		var weights: Array[float] = []
		var total_weight: float = 0.0
		for r_id in pool_copy:
			var r_data = RelicDatabase.get_relic(r_id)
			var rarity = r_data.get("rarity", "common")
			var base_w = float(RelicDatabase.RARITY_WEIGHTS.get(rarity, RELIC_WEIGHT_COMMON))
				
			var w = base_w
			if rm.has_relic(r_id):
				w *= RELIC_OWNED_WEIGHT_MULT
			
			if chosen_cat != "":
				var r_cat = str(r_data.get("element_category", ""))
				if r_cat == chosen_cat:
					w *= 4.0
				elif r_cat == "all":
					w *= 1.5
				elif r_cat != "":
					w *= 0.15
			
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
				
		picks.append(pool_copy[chosen_idx])
		pool_copy.remove_at(chosen_idx)
	return picks

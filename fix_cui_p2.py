import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

new_lines = '''func _show_player_damage(amount: float, element: String = "", blocked: float = 0.0) -> void:
	if amount <= 0 and blocked <= 0: return
	
	var start_pos = Vector2(1190 + 360, 412 - 40)
	var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect
	if hpbar1:
		start_pos = to_local(hpbar1.global_position)
		start_pos.x += hpbar1.size.x / 2.0
		
	if amount > 0:
		var lbl = _get_free_label()
		lbl.text = str(int(amount)) + " DMG"
		var c = Color(1.0, 0.3, 0.3)
		if ELEMENT_COLORS.has(element): c = ELEMENT_COLORS[element]
		lbl.add_theme_color_override("font_color", c)
		lbl.add_theme_font_size_override("font_size", 56)
		lbl.scale = Vector2.ONE
		lbl.modulate = Color.WHITE
		lbl.visible = true
		lbl.position = start_pos - lbl.size / 2 + Vector2(randf_range(-50, 50), 0)
		var tw = create_tween()
		lbl.set_meta("tw", tw)
		tw.tween_property(lbl, "position", lbl.position + Vector2(0, POPUP_FLOAT_DIST), POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, POPUP_DURATION * 0.5).set_delay(POPUP_DURATION * 0.5)
		tw.tween_callback(func(): lbl.visible = false)
		
	if blocked > 0:
		var blbl = _get_free_label()
		blbl.text = "BLOCKED " + str(int(blocked))
		blbl.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
		blbl.add_theme_font_size_override("font_size", 42)
		blbl.scale = Vector2.ONE
		blbl.modulate = Color.WHITE
		blbl.visible = true
		blbl.position = start_pos - blbl.size / 2 + Vector2(randf_range(-50, 50), -50)
		var btw = create_tween()
		blbl.set_meta("tw", btw)
		btw.tween_property(blbl, "position", blbl.position + Vector2(0, POPUP_FLOAT_DIST), POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		btw.parallel().tween_property(blbl, "modulate:a", 0.0, POPUP_DURATION * 0.5).set_delay(POPUP_DURATION * 0.5)
		btw.tween_callback(func(): blbl.visible = false)'''.split('\n')

lines = lines[:77] + new_lines + lines[105:]

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

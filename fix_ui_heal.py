import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'func _show_player_heal(amount: float) -> void:' in lines[i]:
        start = i
        break

if start != -1:
    replacement = '''func _show_player_heal(amount: float) -> void:
	if amount <= 0: return
	var lbl = _get_free_label()
	lbl.text = "+" + str(int(amount))
	lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	lbl.add_theme_font_size_override("font_size", 48)
	lbl.scale = Vector2.ONE
	lbl.modulate = Color.WHITE
	lbl.visible = true
	
	var start_pos = Vector2(1190 + 360, 412 - 40)
	start_pos.x += randf_range(-50, 50)
	lbl.position = start_pos - lbl.size / 2
	
	var tw = create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, POPUP_FLOAT_DIST), POPUP_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, POPUP_DURATION * 0.5).set_delay(POPUP_DURATION * 0.5)
	tw.tween_callback(func(): lbl.visible = false)
	
	if is_instance_valid(player_hp_delay_bar):
		var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect
		if hpbar1:
			var target_w = hpbar1.size.x
			player_hp_delay_bar.size.x = target_w
			
			if hpbar1.has_meta("tw"):
				var old_tw = hpbar1.get_meta("tw")
				if is_instance_valid(old_tw): old_tw.kill()
			hpbar1.color = Color(0.5, 1.0, 0.5, 1.0)
			var bar_tw = create_tween()
			hpbar1.set_meta("tw", bar_tw)
			bar_tw.tween_property(hpbar1, "color", Color(0, 0.9, 0.3, 1.0), 0.5)'''
			
    for i in range(start, len(lines)):
        if 'func _show_enemy_damage' in lines[i]:
            lines = lines[:start] + replacement.split('\n') + lines[i:]
            break

    with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
        f.write('\n'.join(lines))
    print("SUCCESS")

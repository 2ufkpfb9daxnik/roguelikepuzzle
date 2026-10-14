import codecs
import re

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    text = f.read()

old_on = r'(_show_player_damage\(event\.amount, event\.get\("element", ""\)\))'
new_on = r'_show_player_damage(event.amount, event.get("element", ""), event.get("blocked_amount", 0.0))'
text = re.sub(old_on, new_on, text)

old_show = r'(func _show_player_damage\(amount: float, element: String = ""\) -> void:\s*if amount <= 0: return\s*var lbl = _get_free_label\(\)\s*lbl\.text = str\(int\(amount\)\) \+ " DMG"\s*var c = Color\(1\.0, 0\.3, 0\.3\)\s*if ELEMENT_COLORS\.has\(element\):\s*c = ELEMENT_COLORS\[element\]\s*lbl\.add_theme_color_override\("font_color", c\)\s*lbl\.add_theme_font_size_override\("font_size", 56\)\s*lbl\.scale = Vector2\.ONE\s*lbl\.modulate = Color\.WHITE\s*lbl\.visible = true)'
new_show = r'''func _show_player_damage(amount: float, element: String = "", blocked: float = 0.0) -> void:
	if amount > 0:
		var lbl = _get_free_label()
		lbl.text = str(int(amount)) + " DMG"
		var c = Color(1.0, 0.3, 0.3)
		if ELEMENT_COLORS.has(element) and element != "none":
			c = ELEMENT_COLORS[element]
		lbl.add_theme_color_override("font_color", c)
		lbl.add_theme_font_size_override("font_size", 56)
		lbl.scale = Vector2.ONE
		lbl.modulate = Color.WHITE
		lbl.visible = true
		
		lbl.position = Vector2(924, 660) + Vector2(randf_range(-40, 40), randf_range(-20, 20))
		var tw = create_tween().set_parallel(true)
		lbl.set_meta("tw", tw)
		tw.tween_property(lbl, "position:y", lbl.position.y - 120, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.chain().tween_callback(func(): lbl.visible = false)
		
	if blocked > 0:
		var blbl = _get_free_label()
		blbl.text = "BLOCKED " + str(int(blocked))
		blbl.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
		blbl.add_theme_font_size_override("font_size", 40)
		blbl.scale = Vector2.ONE
		blbl.modulate = Color.WHITE
		blbl.visible = true
		
		blbl.position = Vector2(924, 720) + Vector2(randf_range(-40, 40), randf_range(20, 40))
		var btw = create_tween().set_parallel(true)
		blbl.set_meta("tw", btw)
		btw.tween_property(blbl, "position:y", blbl.position.y - 80, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		btw.tween_property(blbl, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		btw.chain().tween_callback(func(): blbl.visible = false)'''
text = re.sub(old_show, new_show, text, flags=re.DOTALL)

# Remove the old tween logic for lbl that was trailing outside my regex
# Wait, let's see how the old _show_player_damage was structured

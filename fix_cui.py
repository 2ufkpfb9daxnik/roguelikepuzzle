import codecs
import re

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    text = f.read()

# Update _on_combat_event
old_on = r'elif event\.target is Node:\s*_show_enemy_damage\(event\.amount, event\.target, event\.get\("is_critical", false\), event\.get\("element", ""\)\)'
new_on = r'''elif event.target is Node:
			_show_enemy_damage(event.amount, event.target, event.get("is_critical", false), event.get("element", ""), event.get("effectiveness", "normal"))'''
text = re.sub(old_on, new_on, text)

# Update _show_enemy_damage signature and logic
old_show = r'func _show_enemy_damage\(amount: float, enemy_node: Node, is_crit: bool, element: String\) -> void:.*?lbl\.text = str\(int\(amount\)\) \+ " DMG"\s*var c = Color\(1\.0, 1\.0, 1\.0\)\s*if ELEMENT_COLORS\.has\(element\):\s*c = ELEMENT_COLORS\[element\]\s*if is_crit: c = Color\(1\.0, 0\.8, 0\.2\)'
new_show = r'''func _show_enemy_damage(amount: float, enemy_node: Node, is_crit: bool, element: String, effectiveness: String = "normal") -> void:
	if amount <= 0 or not is_instance_valid(enemy_node): return

	var e_id = enemy_node.get_instance_id()
	if not enemy_popup_counts.has(e_id): enemy_popup_counts[e_id] = 0

	if enemy_popup_counts[e_id] >= MAX_ENEMY_POPUPS:
		return

	enemy_popup_counts[e_id] += 1

	var lbl = _get_free_label()
	lbl.text = str(int(amount)) + " DMG"

	var c = Color(1.0, 1.0, 1.0)
	
	if effectiveness == "weak":
		c = Color(1.0, 0.3, 0.3)
		lbl.text = "WEAK\n" + lbl.text
	elif effectiveness == "resist":
		c = Color(0.5, 0.5, 0.5)
		lbl.text = "RESIST\n" + lbl.text
	else:
		if ELEMENT_COLORS.has(element) and element != "none":
			c = ELEMENT_COLORS[element]
			
	if is_crit: c = Color(1.0, 0.8, 0.2)'''
text = re.sub(old_show, new_show, text, flags=re.DOTALL)

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")

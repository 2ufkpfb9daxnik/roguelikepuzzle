import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

insert_code = '''func _emit_combat_event(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false) -> void:
	var t_node = target
	if typeof(target) == TYPE_STRING and target == "enemy":
		var sm = _get_stage_manager()
		if sm and "active_enemies" in sm and sm.active_enemies.size() > 0:
			t_node = sm.active_enemies[randi() % sm.active_enemies.size()]["sprite"]
			
	var event = {
		"type": type,
		"source": source,
		"target": t_node,
		"amount": amount,
		"element": element,
		"is_critical": is_critical
	}
	emit_signal("combat_event", event)
	if DEBUG_COMBAT_EVENTS:
		print("[CombatEvent] ", event)'''

lines.insert(9, insert_code)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

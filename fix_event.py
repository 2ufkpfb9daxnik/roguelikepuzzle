import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'func _emit_combat_event' in lines[i]:
        start = i
        # Use the second one (around 4350)
        if start > 1000:
            break

if start != -1:
    replacement = '''func _emit_combat_event(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false) -> void:
	var t_node = target
	if typeof(target) == TYPE_STRING and target == "enemy":
		var sm = get_node_or_null("../ScoreManager")
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
        
    for i in range(start, start+15):
        if 'if DEBUG_COMBAT_EVENTS:' in lines[i]:
            # Replace lines[start:i+2] with replacement
            lines[start:i+2] = replacement.split('\n')
            break
            
    with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
        f.write('\n'.join(lines))
    print("SUCCESS")

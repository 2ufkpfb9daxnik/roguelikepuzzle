import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

insert_header = '''signal combat_event(event_data: Dictionary)

var turn_skill_log: Array = []
const DEBUG_COMBAT_EVENTS = true

func _emit_combat_event(type: String, source: String, target: Variant, amount: float, element: String = "", is_critical: bool = false) -> void:
	var event = {
		"type": type,
		"source": source,
		"target": target,
		"amount": amount,
		"element": element,
		"is_critical": is_critical
	}
	emit_signal("combat_event", event)
	if DEBUG_COMBAT_EVENTS:
		print("[CombatEvent] ", event)

'''

# Insert it right after extends Node2D
content = content.replace('extends Node2D\n', 'extends Node2D\n\n' + insert_header)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

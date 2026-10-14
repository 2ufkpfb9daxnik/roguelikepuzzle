import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Add signal and turn_skill_log at the top
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

# Find place to insert (after class_name or extends)
# In puzzle_board.gd, it just extends Node2D.
# Let's insert right before const GRID_ROWS
content = content.replace('const GRID_ROWS: int = 8', insert_header + 'const GRID_ROWS: int = 8')

# Now insert the event emitting.
# 1. Sword hit
# sm.calchp(dmg, 0)
# _spawn_hit_spark(s.position)
sword_hit = '''				sm.calchp(dmg, 0)
				_emit_combat_event("damage", "ally", "enemy", dmg)'''
content = content.replace('				sm.calchp(dmg, 0)\n', sword_hit + '\n')

# 2. Enemy hit
# sm.calchp(0, incoming_damage)
enemy_hit = '''			sm.calchp(0, incoming_damage)
			_emit_combat_event("damage", "enemy", "ally", incoming_damage)'''
content = content.replace('			sm.calchp(0, incoming_damage)\n', enemy_hit + '\n')

# 3. Heal (Food)
# sm.calchp(0, -heal_val)
heal_food = '''		sm.calchp(0, -heal_val)
		_emit_combat_event("heal", "ally", "ally", heal_val)'''
content = content.replace('		sm.calchp(0, -heal_val)\n', heal_food + '\n')

# Heal direct (Potion)
# sm.calchp(0.0, -total_heal)
heal_potion = '''		sm.calchp(0.0, -total_heal)
		_emit_combat_event("heal", "ally", "ally", total_heal)'''
content = content.replace('		sm.calchp(0.0, -total_heal)\n', heal_potion + '\n')

# 4. Enemy drain
# sm.calchp(-heal_enemy_amount, total_drain)
drain_hit = '''	sm.calchp(-heal_enemy_amount, total_drain)
	_emit_combat_event("damage", "enemy", "ally", total_drain, "drain")
	if heal_enemy_amount > 0.0:
		_emit_combat_event("heal", "enemy", "enemy", heal_enemy_amount, "drain")'''
content = content.replace('	sm.calchp(-heal_enemy_amount, total_drain)\n', drain_hit + '\n')

# 5. Clear turn_skill_log
# if interval == 0:
# 	has_enemy_attacked = false
clear_log = '''	if interval == 0:
		turn_skill_log.clear()
		has_enemy_attacked = false'''
content = content.replace('	if interval == 0:\n		has_enemy_attacked = false', clear_log)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")

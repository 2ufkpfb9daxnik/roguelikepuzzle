import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Fix heal_potion:
bad_heal_potion = '''		sm.calchp(0.0, -total_heal)
		_emit_combat_event("heal", "ally", "ally", total_heal)'''
good_heal_potion = '''			sm.calchp(0.0, -total_heal)
			_emit_combat_event("heal", "ally", "ally", total_heal)'''
content = content.replace(bad_heal_potion, good_heal_potion)

# Check heal_food:
bad_heal_food = '''		sm.calchp(0, -heal_val)
		_emit_combat_event("heal", "ally", "ally", heal_val)'''
good_heal_food = '''			sm.calchp(0, -heal_val)
			_emit_combat_event("heal", "ally", "ally", heal_val)'''
# wait let's just make sure
content = content.replace(bad_heal_food, good_heal_food)

# Also sword_hit was:
# 				sm.calchp(dmg, 0)
# 				_emit_combat_event("damage", "ally", "enemy", dmg)
# Let's check line 3855 or whatever

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

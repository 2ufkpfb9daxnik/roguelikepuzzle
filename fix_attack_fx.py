import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re

old_func_regex = r'func _play_ally_attack_phase_effects\(sm: Node2D\) -> void:.*?turn_skill_log\.clear\(\)'
new_func = '''func _play_ally_attack_phase_effects(sm: Node2D) -> void:
	if not is_instance_valid(sm): return
	var active_en = sm.active_enemies if "active_enemies" in sm else []
	if active_en.is_empty(): return
	
	var counts = sm.turn_element_counts if "turn_element_counts" in sm else {}
	var elements_to_play = []
	for el_enum in counts.keys():
		if counts[el_enum] > 0:
			elements_to_play.append(ElementDataScript.get_element_name(el_enum))
			
	if elements_to_play.is_empty(): return
	
	var delay = 0.45
	for el in elements_to_play:
		for e in active_en:
			var spr = e.get("sprite")
			if not is_instance_valid(spr): continue
			_spawn_ally_elemental_vfx(spr.global_position, el, delay)
		delay += 0.15
'''

text = re.sub(old_func_regex, new_func, text, flags=re.DOTALL)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")

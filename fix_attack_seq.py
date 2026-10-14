import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

import re
old_func_regex = r'func _play_ally_attack_phase_effects\(sm: Node2D\) -> void:.*?turn_skill_log\.clear\(\)\n'

# Find start and end of _play_ally_attack_phase_effects
lines = text.split('\n')
start = -1
end = -1
for i, line in enumerate(lines):
    if 'func _play_ally_attack_phase_effects' in line:
        start = i
    elif start != -1 and 'func _spawn_ally_elemental_vfx' in line:
        end = i
        break

new_func = '''func _play_ally_attack_phase_effects(sm: Node2D) -> void:
	if not is_instance_valid(sm):
		turn_skill_log.clear()
		return
	var active_en = sm.active_enemies if "active_enemies" in sm else []
	if active_en.is_empty():
		turn_skill_log.clear()
		return
	
	var score_mgr = _get_score_manager()
	var counts = score_mgr.turn_element_counts if score_mgr and "turn_element_counts" in score_mgr else {}
	
	var elements_present = false
	for el_enum in counts.keys():
		if counts[el_enum] > 0:
			elements_present = true
			break
			
	if not elements_present:
		turn_skill_log.clear()
		return
	
	await get_tree().create_timer(0.45, false).timeout
	
	for el_enum in counts.keys():
		var count = counts[el_enum]
		if count <= 0: continue
		var el_name = ElementDataScript.get_element_name(el_enum)
		await _spawn_elemental_bombs(el_name, count, active_en)
		
	turn_skill_log.clear()

func _spawn_elemental_bombs(elem: String, count: int, active_en: Array) -> void:
	var num_large = count / 10
	var remainder = count % 10
	var num_medium = remainder / 5
	var num_small = remainder % 5
	
	for i in range(num_large):
		for e in active_en:
			var spr = e.get("sprite")
			if not is_instance_valid(spr): continue
			_play_elemental_size(elem, 3, spr.global_position)
		await get_tree().create_timer(0.4, false).timeout
		
	for i in range(num_medium):
		for e in active_en:
			var spr = e.get("sprite")
			if not is_instance_valid(spr): continue
			_play_elemental_size(elem, 2, spr.global_position)
		await get_tree().create_timer(0.3, false).timeout
		
	for i in range(num_small):
		for e in active_en:
			var spr = e.get("sprite")
			if not is_instance_valid(spr): continue
			_play_elemental_size(elem, 1, spr.global_position)
		await get_tree().create_timer(0.2, false).timeout

func _play_elemental_size(elem: String, size: int, target_global_pos: Vector2) -> void:
	var p = get_parent()
	var root_node = p if p != null else self
	var local_pos = root_node.to_local(target_global_pos)
	match elem:
		"fire":
			if size == 3: _spawn_mega_explosion_effect(local_pos, 2)
			elif size == 2: _spawn_mega_explosion_effect(local_pos, 0)
			else: _spawn_explosion_effect(local_pos)
		"water":
			if size == 3: _spawn_aqua_splash_effect(local_pos, 5)
			elif size == 2: _spawn_aqua_splash_effect(local_pos, 3)
			else: _spawn_aqua_splash_effect(local_pos, 1)
		"wind":
			if size == 3: _spawn_tornado_effect(local_pos, 3, 300)
			elif size == 2: _spawn_tornado_effect(local_pos, 2, 150)
			else: _spawn_tornado_effect(local_pos, 1, 50)
		"thunder":
			if size == 3:
				for dx in [-200, -100, 0, 100, 200]:
					_spawn_vertical_lightning_bolt(local_pos + Vector2(dx, 0), randf() * 0.2)
				_spawn_screen_flash(Color(1.0, 1.0, 0.4, 0.5), 0.1)
			elif size == 2:
				for dx in [-100, 0, 100]:
					_spawn_vertical_lightning_bolt(local_pos + Vector2(dx, 0), randf() * 0.1)
			else:
				_spawn_vertical_lightning_bolt(local_pos, 0.0)
		"light":
			if size == 3: _spawn_disco_effect(local_pos)
			elif size == 2: _spawn_shockwave_ring(local_pos, Color(1.0, 1.0, 0.5, 0.9), 600.0, 0.4)
			else: _spawn_shockwave_ring(local_pos, Color(1.0, 1.0, 0.5, 0.9), 300.0, 0.2)
		"dark":
			if size == 3: _spawn_black_hole_effect(local_pos, 3)
			elif size == 2: _spawn_black_hole_effect(local_pos, 2)
			else: _spawn_black_hole_effect(local_pos, 1)

'''

lines = lines[:start] + new_func.split('\n') + lines[end:]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

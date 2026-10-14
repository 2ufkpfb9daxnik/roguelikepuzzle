import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

old_cb = '''		seq_tw.tween_callback(func():
				if sm == null or sm.isdeadf or sm.ehp <= 0:
					return
				_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, elem_color, is_boss)
				_apply_enemy_elemental_skill_effect(elem, is_boss)
			)'''
new_cb = '''		seq_tw.tween_callback(func():
				if sm == null or sm.isdeadf or sm.ehp <= 0:
					return
				var targets = _apply_enemy_elemental_skill_effect(elem, is_boss)
				_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, elem_color, is_boss, targets)
			)'''
content = content.replace(old_cb, new_cb)

old_cb2 = '''		tw_cast.tween_callback(func():
			if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
				return
			_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, elem_color, is_boss)
			_apply_enemy_elemental_skill_effect(elem, is_boss)
		)'''
new_cb2 = '''		tw_cast.tween_callback(func():
			if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
				return
			var targets = _apply_enemy_elemental_skill_effect(elem, is_boss)
			_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, elem_color, is_boss, targets)
		)'''
content = content.replace(old_cb2, new_cb2)

old_spawn = '''func _spawn_enemy_skill_beam_and_burst(sm: Node2D, enemy_sp: Sprite2D, elem_color_hex: String, is_boss: bool) -> void:
	if sm == null or enemy_sp == null:
		return

	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var p = get_parent()
	var root_node = p if p != null else self

	var target_board_center = Vector2(780, 480)
	var beam_node = SkillVFXNode.new(SkillVFXNode.VFXMode.SPELL_BEAM, elem_col, 0.35)
	beam_node.start_pos = enemy_sp.global_position
	beam_node.target_pos = target_board_center
	root_node.add_child(beam_node)
	_play_spell_beam_se()

	var tw_burst = create_tween()
	tw_burst.tween_interval(0.30)
	tw_burst.tween_callback(func():
		if not is_instance_valid(root_node): return
		var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, elem_col, 0.50)
		burst_node.position = target_board_center
		burst_node.max_radius = 340.0 if is_boss else 260.0
		root_node.add_child(burst_node)
	)'''
new_spawn = '''func _spawn_enemy_skill_beam_and_burst(sm: Node2D, enemy_sp: Sprite2D, elem_color_hex: String, is_boss: bool, targets: Array[Vector2] = []) -> void:
	if sm == null or enemy_sp == null:
		return

	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var p = get_parent()
	var root_node = p if p != null else self

	if targets.is_empty():
		targets.append(Vector2(7500.0 / 2.0, 7500.0 / 2.0)) # Board center local approx

	_play_spell_beam_se()
	
	# To prevent massive lag if a skill affects 25 cells, we can cap the number of visual beams to 8
	var visual_targets = targets.duplicate()
	visual_targets.shuffle()
	var max_beams = mini(8, visual_targets.size())
	
	for i in range(max_beams):
		var target_local = visual_targets[i]
		var target_global = to_global(target_local)
		
		var beam_node = SkillVFXNode.new(SkillVFXNode.VFXMode.SPELL_BEAM, elem_col, 0.35)
		beam_node.start_pos = enemy_sp.global_position
		beam_node.target_pos = target_global
		root_node.add_child(beam_node)

	var tw_burst = create_tween()
	tw_burst.tween_interval(0.30)
	tw_burst.tween_callback(func():
		if not is_instance_valid(root_node): return
		for i in range(max_beams):
			var target_local = visual_targets[i]
			var target_global = to_global(target_local)
			var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, elem_col, 0.40)
			burst_node.position = target_global
			burst_node.max_radius = 180.0 if is_boss else 140.0
			root_node.add_child(burst_node)
	)'''
content = content.replace(old_spawn, new_spawn)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _spawn_ally_elemental_vfx' in lines[i]:
        # replace the function body
        new_func = '''func _spawn_ally_elemental_vfx(target_global_pos: Vector2, elem: String) -> void:
	var p = get_parent()
	var root_node = p if p != null else self
	var vc = root_node.get_node_or_null("VFXContainer")
	if not vc: vc = root_node
	
	var color = Color.WHITE
	match elem:
		"fire": 
			color = Color(1.0, 0.4, 0.2)
			_spawn_mega_explosion_effect(to_local(target_global_pos), 1)
		"water": 
			color = Color(0.3, 0.6, 1.0)
			_spawn_aqua_splash_effect(to_local(target_global_pos), 3)
		"wind": 
			color = Color(0.4, 0.9, 0.4)
			_spawn_tornado_effect(to_local(target_global_pos), 3, 200)
		"thunder": 
			color = Color(0.9, 0.9, 0.2)
			for dx in [-200, 0, 200]:
				_spawn_vertical_lightning_bolt(to_local(target_global_pos) + Vector2(dx, 0), randf() * 0.2)
		"ice": 
			color = Color(0.6, 0.9, 1.0)
			_spawn_ice_break_effect(to_local(target_global_pos))
		"light": 
			color = Color(1.0, 0.9, 0.6)
			_spawn_disco_effect(to_local(target_global_pos))
		"dark": 
			color = Color(0.7, 0.3, 0.9)
			_spawn_black_hole_effect(to_local(target_global_pos), 2)
	
	# Also spawn a huge flash to make it feel like a screen-wide attack
	var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, color, 0.60)
	burst_node.position = root_node.to_local(target_global_pos)
	burst_node.max_radius = 800.0
	Profiler.add_child_count += 1; vc.add_child(burst_node)
'''
        # we need to remove old function body
        end = i
        while end < len(lines) and (lines[end].strip() != '' or end < i + 10):
            if 'Profiler.add_child_count += 1; vc.add_child(burst_node)' in lines[end]:
                end += 1
                break
            end += 1
        
        lines = lines[:i] + new_func.split('\n') + lines[end:]
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

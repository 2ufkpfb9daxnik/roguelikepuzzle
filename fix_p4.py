import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'if s_cnt > 0 or (f_cnt > 0 and sm and sm.myhp < sm.myhpmax)' in lines[i]:
        lines[i] = lines[i].replace(') or (', ') or (').replace('):', ') or turn_skill_log.size() > 0:')
        break

for i in range(len(lines)):
    if 'elif interval == base_time + 1 and isattack:' in lines[i]:
        insert = '''		elif interval == base_time + 1 and isattack:
			_play_ally_attack_phase_effects(sm)'''
        lines[i] = insert
        break

# Append the function
func_code = '''
const SKILL_EFFECT_STAGGER = 0.15

func _play_ally_attack_phase_effects(sm: Node2D) -> void:
	if turn_skill_log.is_empty() or not is_instance_valid(sm):
		return
		
	var active_en = sm.active_enemies if "active_enemies" in sm else []
	if active_en.is_empty():
		return
		
	var skills_to_play = []
	if turn_skill_log.size() > 6:
		var grouped = {}
		for s in turn_skill_log:
			var el = s.get("element", "fire")
			if not grouped.has(el): grouped[el] = []
			grouped[el].append(s)
		
		for el in grouped.keys():
			skills_to_play.append(grouped[el][0])
			if skills_to_play.size() >= 6:
				break
	else:
		skills_to_play = turn_skill_log.duplicate()
		
	var delay = 0.45 # Wait for swords to almost hit
	for s in skills_to_play:
		var el = s.get("element", "fire")
		for e in active_en:
			var spr = e.get("sprite")
			if not is_instance_valid(spr): continue
			
			var tw = create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func():
				if not is_instance_valid(spr): return
				_spawn_ally_elemental_vfx(spr.global_position, el)
			)
		delay += SKILL_EFFECT_STAGGER

func _spawn_ally_elemental_vfx(target_global_pos: Vector2, elem: String) -> void:
	var p = get_parent()
	var root_node = p if p != null else self
	var vc = root_node.get_node_or_null("VFXContainer")
	if not vc: vc = root_node
	
	var color = Color.WHITE
	match elem:
		"fire": color = Color(1.0, 0.4, 0.2)
		"water": color = Color(0.3, 0.6, 1.0)
		"wind": color = Color(0.4, 0.9, 0.4)
		"thunder": color = Color(0.9, 0.9, 0.2)
		"ice": color = Color(0.6, 0.9, 1.0)
		"light": color = Color(1.0, 0.9, 0.6)
		"dark": color = Color(0.7, 0.3, 0.9)
		
	var burst_node = SkillVFXNode.new(SkillVFXNode.VFXMode.BURST_RING, color, 0.40)
	burst_node.position = root_node.to_local(target_global_pos)
	burst_node.max_radius = 140.0
	Profiler.add_child_count += 1; vc.add_child(burst_node)
'''
lines.append(func_code)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

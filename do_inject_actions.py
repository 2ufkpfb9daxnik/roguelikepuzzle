import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

def replace_func(content, func_name, new_body):
    pattern = r'(func ' + func_name + r'\b.*?\n)(?:(?:[ \t].*\n)|(?:^\s*\n))*'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[:match.start()] + new_body + '\n' + content[match.end():]
    return content

# 1. 敵の行動を決定する配列と関数を追加
new_decide_func = '''var _enemy_turn_actions: Array = []

func _decide_enemy_actions(sm: Node2D) -> bool:
	_enemy_turn_actions.clear()
	var has_skill = false
	if sm and "active_enemies" in sm:
		for e in sm.active_enemies:
			if randf() < 0.5:
				_enemy_turn_actions.append("skill")
				has_skill = true
			else:
				_enemy_turn_actions.append("attack")
	return has_skill

func _spawn_slash_effect(pos: Vector2) -> void:
	var root_node = get_parent() if get_parent() != null else self
	var node = Node2D.new()
	node.position = pos
	var script_src = """
extends Node2D
var life_time = 0.0
func _process(delta: float):
	life_time += delta
	if life_time > 0.25:
		queue_free()
	queue_redraw()
func _draw():
	var p = clampf(1.0 - (life_time / 0.25), 0.0, 1.0)
	var col = Color(1.0, 1.0, 1.0, p)
	draw_line(Vector2(-60, -60), Vector2(60, 60), col, 12.0 * p)
	draw_line(Vector2(-60, 60), Vector2(60, -60), col, 6.0 * p)
"""
	var script = GDScript.new()
	script.source_code = script_src
	script.reload()
	node.set_script(script)
	root_node.add_child(node)

func _spawn_enemy_skill_chant_vfx_at(pos: Vector2, elem_color_hex: String, is_boss: bool) -> void:
	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var root_node = get_parent() if get_parent() != null else self
	var target_radius: float = 140.0 if is_boss else 90.0
	var chant_node = SkillVFXNode.new(SkillVFXNode.VFXMode.CHANT_AURA, elem_col, 0.70)
	chant_node.position = pos
	chant_node.max_radius = target_radius
	root_node.add_child(chant_node)

func _spawn_enemy_skill_beam_and_burst_at(pos: Vector2, elem_color_hex: String, is_boss: bool) -> void:
	var elem_col = Color.from_string(elem_color_hex, Color(1, 0.8, 0.2))
	var root_node = get_parent() if get_parent() != null else self
	var target_board_center = Vector2(780, 480)
	var beam_node = SkillVFXNode.new(SkillVFXNode.VFXMode.SPELL_BEAM, elem_col, 0.35)
	beam_node.start_pos = pos
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
	)

func _execute_enemy_turn_actions(sm: Node2D) -> void:
	if has_enemy_attacked: return
	has_enemy_attacked = true
	if sm == null or sm.isdeadf or sm.ehp <= 0: return

	var se_vol: float = 1.0
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume, 0.001, 1.0)

	var enemy_atk_se = get_node_or_null("enemy_attack_se") as AudioStreamPlayer
	if enemy_atk_se == null:
		enemy_atk_se = AudioStreamPlayer.new()
		enemy_atk_se.name = "enemy_attack_se"
		add_child(enemy_atk_se)

	var hit_se = get_node_or_null("enemy_hit_se") as AudioStreamPlayer
	if hit_se == null:
		hit_se = AudioStreamPlayer.new()
		hit_se.name = "enemy_hit_se"
		add_child(hit_se)

	if not ("active_enemies" in sm) or sm.active_enemies.size() == 0:
		return

	var seq_tw = create_tween()
	
	for i in range(sm.active_enemies.size()):
		var e = sm.active_enemies[i]
		var action = _enemy_turn_actions[i] if i < _enemy_turn_actions.size() else "attack"
		var spr = e["sprite"]
		var atk = e["atk"]
		
		if action == "attack":
			seq_tw.tween_callback(func():
				if not is_instance_valid(spr): return
				var orig_pos = spr.position
				var atk_tw = create_tween()
				atk_tw.tween_property(spr, "position", orig_pos + Vector2(-60, 0), 0.1)
				atk_tw.tween_property(spr, "position", orig_pos, 0.2).set_delay(0.1)
				
				if enemy_atk_se:
					enemy_atk_se.stream = ENEMY_ATTACK_SE
					enemy_atk_se.volume_db = linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5))
					enemy_atk_se.play(0.0)
					
				_spawn_slash_effect(spr.global_position + Vector2(-80, 0))
					
				var effective_shield_cnt: int = max(current_total_shields, active_shields.size())
				var incoming_damage = atk / float(effective_shield_cnt + 1)
				
				if incoming_damage > 0.0:
					if hit_se:
						hit_se.stream = UTU2_SE
						hit_se.volume_db = linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5))
						hit_se.play(0.0)
					_spawn_screen_flash(Color(0.8, 0.1, 0.1, 0.35), 0.3)
					_trigger_screen_shake(20.0 + minf(incoming_damage * 0.05, 30.0))
				
				sm.calchp(0, incoming_damage)
			)
			seq_tw.tween_interval(0.3)
		else:
			var key = e.get("key", "slime")
			var is_boss = false
			if sm.has_method("is_boss_monster"): is_boss = sm.is_boss_monster()
			else: is_boss = sm.is_current_boss if "is_current_boss" in sm else false
			var sp_data = {}
			if "ENEMY_SPECIES" in sm: sp_data = sm.ENEMY_SPECIES.get(key, {})
			var elem = sp_data.get("element", sp_data.get("race", "???"))
			if typeof(elem) == TYPE_ARRAY: elem = elem[randi() % elem.size()]
			var s_info = _get_enemy_skill_info(elem, is_boss)
			var s_name = s_info["name"]
			var elem_color = s_info["color"]
			
			seq_tw.tween_callback(func():
				_play_enemy_skill_se(is_boss)
				_show_enemy_skill_banner(s_name, elem_color, is_boss)
				_spawn_enemy_skill_chant_vfx_at(spr.global_position, elem_color, is_boss)
				if is_instance_valid(spr):
					var tw = create_tween()
					tw.tween_property(spr, "scale", spr.scale * 1.1, 0.2)
					tw.tween_property(spr, "scale", spr.scale, 0.2)
			)
			seq_tw.tween_interval(0.7)
			seq_tw.tween_callback(func():
				if sm == null or sm.isdeadf or sm.ehp <= 0: return
				_spawn_enemy_skill_beam_and_burst_at(spr.global_position, elem_color, is_boss)
				_apply_enemy_elemental_skill_effect(elem, is_boss)
			)
			seq_tw.tween_interval(0.5)

	seq_tw.tween_callback(func():
		for item in active_shields:
			if is_instance_valid(item["node"]): item["node"].queue_free()
		active_shields.clear()
		current_total_shields = 0
		if sm and sm.myhp <= 0:
			var go_node = sm.get_node_or_null("gameover")
			if go_node: go_node.position = Vector2.ZERO
			isgameover = true
			interval = 0
	)
'''

# この新しい関数群を unc _execute_enemy_attack の前に挿入する
pattern = r'func _execute_enemy_attack\(sm: Node2D\) -> void:'
match = re.search(pattern, content)
if match:
    content = content[:match.start()] + new_decide_func + '\n' + content[match.start():]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

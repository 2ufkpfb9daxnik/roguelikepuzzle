import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
end = -1
for i in range(len(lines)):
    if 'if action == "attack":' in lines[i]:
        start = i
        break

if start != -1:
    for i in range(start, start + 40):
        if 'else:' in lines[i] and 'key = e.get' in lines[i+1]:
            end = i
            break

if start != -1 and end != -1:
    replacement = '''		if action == "attack":
			seq_tw.tween_callback(func():
				if not is_instance_valid(spr): return
				
				var has_anim = false
				if sm.has_method("play_single_enemy_animation"):
					has_anim = sm.play_single_enemy_animation(i, "attack")
					
				if not has_anim:
					var orig_pos = spr.position
					var atk_tw = create_tween()
					# モーション：前に踏み込む（0.3倍の時間）→戻る（0.7倍の時間）
					atk_tw.tween_property(spr, "position", orig_pos + Vector2(-80, 0), ENEMY_ATTACK_MOTION_DURATION * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					atk_tw.tween_property(spr, "position", orig_pos, ENEMY_ATTACK_MOTION_DURATION * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
					atk_tw.tween_callback(func(): if is_instance_valid(spr): spr.position = orig_pos)
			)
			
			var effect_delay = ENEMY_ATTACK_MOTION_DURATION * ENEMY_ATTACK_EFFECT_TIMING
			seq_tw.tween_interval(effect_delay)
			
			seq_tw.tween_callback(func():
				if not is_instance_valid(spr) or sm == null or sm.isdeadf or sm.ehp <= 0: return
				
				_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5)), 1.0)
				_spawn_slash_effect(spr.global_position + Vector2(-80, 0))
				
				var effective_shield_cnt: int = max(current_total_shields, active_shields.size())
				var incoming_damage = atk / float(effective_shield_cnt + 1)
				
				if incoming_damage > 0.0:
					_play_pooled_se(UTU2_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)
					_spawn_screen_flash(Color(0.8, 0.1, 0.1, 0.35), 0.3)
					_trigger_screen_shake(20.0 + minf(incoming_damage * 0.05, 30.0))
				
				sm.calchp(0, incoming_damage)
				_emit_combat_event("damage", "enemy", "ally", incoming_damage)
			)
			
			seq_tw.tween_interval(ENEMY_ATTACK_MOTION_DURATION * (1.0 - ENEMY_ATTACK_EFFECT_TIMING) + 0.1)
'''
    new_lines = lines[:start] + replacement.split('\n') + lines[end:]
    
    # insert constants
    for i in range(len(new_lines)):
        if 'const MAX_COMBAT_PROJECTILES: int = 24' in new_lines[i]:
            new_lines.insert(i+1, 'const ENEMY_ATTACK_MOTION_DURATION: float = 0.4')
            new_lines.insert(i+2, 'const ENEMY_ATTACK_EFFECT_TIMING: float = 0.75')
            break
            
    with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
        f.write('\n'.join(new_lines))
    print("SUCCESS")
else:
    print("NOT FOUND")

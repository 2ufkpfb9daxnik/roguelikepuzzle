import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# プレイヤーが行動しなかったパターンの置換
old_no_action = '''		var has_custom_atk = sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")
		var skill_trigger_fast = 8
		var end_wait_fast = (105 if has_custom_atk else 95) if is_casting_skill_turn else (75 if has_custom_atk else 14)
		if interval == 0:
			is_casting_skill_turn = _should_cast_enemy_elemental_skill(sm)
			has_enemy_attacked = false
			has_enemy_skilled = false
			var anten = get_node_or_null("anten")
			if anten: anten.play()
			if not is_casting_skill_turn:
				_set_enemy_attack_motion(sm, true)
		elif interval == 4:
			if not is_casting_skill_turn:
				_execute_enemy_attack(sm)
		elif interval == skill_trigger_fast and is_casting_skill_turn:
			_execute_enemy_elemental_skill(sm)
		elif interval == 10:
			if not is_casting_skill_turn:
				_set_enemy_attack_motion(sm, false)
		elif interval == end_wait_fast:'''

new_no_action = '''		var has_custom_atk = sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")
		if interval == 0:
			is_casting_skill_turn = _decide_enemy_actions(sm)
			has_enemy_attacked = false
			has_enemy_skilled = false
			var anten = get_node_or_null("anten")
			if anten: anten.play()
		
		# 敵全員がアクションを実行し終えるまでの十分な待機時間を計算 (最大 115)
		var end_wait_fast = (105 if has_custom_atk else 95) if is_casting_skill_turn else (75 if has_custom_atk else 14)
		if sm and "active_enemies" in sm:
			end_wait_fast = max(end_wait_fast, sm.active_enemies.size() * 50)
			
		if interval == 4:
			_execute_enemy_turn_actions(sm)
			
		elif interval == end_wait_fast:'''

content = content.replace(old_no_action, new_no_action)

# プレイヤーが行動したパターンの置換
old_action = '''	elif interval == base_time + 1 + 144 * isattack + 128 * isblock:
		is_casting_skill_turn = _should_cast_enemy_elemental_skill(sm)
		has_enemy_attacked = false
		has_enemy_skilled = false
		if not is_casting_skill_turn:
			_set_enemy_attack_motion(sm, true)

	elif interval == base_time + 13 + 144 * isattack + 128 * isblock:
		if not is_casting_skill_turn:
			_execute_enemy_attack(sm)

	elif interval == base_time + 18 + 144 * isattack + 128 * isblock:
		if is_casting_skill_turn:
			_execute_enemy_elemental_skill(sm)

	elif interval == base_time + 30 + 144 * isattack + 128 * isblock:
		if not is_casting_skill_turn:
			_set_enemy_attack_motion(sm, false)

	elif interval == base_time + ((115 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 105) if is_casting_skill_turn else (75 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 52)) + 144 * isattack + 128 * isblock:
		if sm and not sm.isfevertime:
			sm.fevertime()'''

new_action = '''	elif interval == base_time + 1 + 144 * isattack + 128 * isblock:
		is_casting_skill_turn = _decide_enemy_actions(sm)
		has_enemy_attacked = false
		has_enemy_skilled = false

	elif interval == base_time + 13 + 144 * isattack + 128 * isblock:
		_execute_enemy_turn_actions(sm)

	elif interval == base_time + ((115 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 105) if is_casting_skill_turn else (75 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 52)) + 144 * isattack + 128 * isblock:
		if sm and not sm.isfevertime:
			sm.fevertime()'''
content = content.replace(old_action, new_action)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

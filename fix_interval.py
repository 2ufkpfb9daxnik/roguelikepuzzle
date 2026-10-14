import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

old_logic = '''	elif interval == base_time + 13 + 144 * isattack + 128 * isblock:
		_execute_enemy_turn_actions(sm)

	elif interval == base_time + ((115 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 105) if is_casting_skill_turn else (75 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 52)) + 144 * isattack + 128 * isblock:
		if sm and not sm.isfevertime:
			sm.fevertime()

	elif interval > base_time + ((115 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 105) if is_casting_skill_turn else (75 if (sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")) else 52)) + 144 * isattack + 128 * isblock:
		# ????????????????????????????????????????????
		if sm and sm.is_playing_custom_animation:
			return
		_reset_turn(sm, score_mgr)
		current_state = BoardState.IDLE
		return'''

new_logic = '''	elif interval == base_time + 13 + 144 * isattack + 128 * isblock:
		_execute_enemy_turn_actions(sm)

	else:
		var has_custom_atk = sm and sm.has_method("has_enemy_animation") and sm.has_enemy_animation("attack")
		var turn_wait = (115 if has_custom_atk else 105) if is_casting_skill_turn else (75 if has_custom_atk else 52)
		if sm and "active_enemies" in sm:
			turn_wait = max(turn_wait, sm.active_enemies.size() * 50)
		var end_time = base_time + turn_wait + 144 * isattack + 128 * isblock

		if interval == end_time:
			if sm and not sm.isfevertime:
				sm.fevertime()

		elif interval > end_time:
			if sm and sm.is_playing_custom_animation:
				return
			_reset_turn(sm, score_mgr)
			current_state = BoardState.IDLE
			return'''
content = content.replace(old_logic, new_logic)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

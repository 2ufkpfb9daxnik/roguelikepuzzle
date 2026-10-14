import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Replace block in _handle_turn_sequence and others
old_block1 = '''	var enemy_atk_se = get_node_or_null("enemy_attack_se") as AudioStreamPlayer
	if enemy_atk_se == null:
		enemy_atk_se = AudioStreamPlayer.new()
		enemy_atk_se.name = "enemy_attack_se"
		add_child(enemy_atk_se)

	var hit_se = get_node_or_null("enemy_hit_se") as AudioStreamPlayer
	if hit_se == null:
		hit_se = AudioStreamPlayer.new()
		hit_se.name = "enemy_hit_se"
		add_child(hit_se)'''
content = content.replace(old_block1, '')

# Now replace where they play:
old_play1 = '''			if enemy_atk_se:
				enemy_atk_se.stream = ENEMY_ATTACK_SE
				enemy_atk_se.volume_db = linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5))
				enemy_atk_se.play(0.0)'''
new_play1 = '''			_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5)), 1.0)'''
content = content.replace(old_play1, new_play1)

old_play2 = '''				if hit_se:
					hit_se.stream = UTU2_SE
					hit_se.volume_db = linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5))
					hit_se.play(0.0)'''
new_play2 = '''				_play_pooled_se(UTU2_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)'''
content = content.replace(old_play2, new_play2)

old_play3 = '''			if enemy_atk_se:
				enemy_atk_se.stream = ENEMY_ATTACK_SE
				enemy_atk_se.volume_db = linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5))
				enemy_atk_se.play(0.0)'''
new_play3 = '''			_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)'''
content = content.replace(old_play3, new_play3)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

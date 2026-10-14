import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Delete the pre-instantiation in _ready
block_ready = '''	# GUpSEvC[̎OCX^X
	var enemy_atk_se = AudioStreamPlayer.new()
	enemy_atk_se.name = "enemy_attack_se"
	enemy_atk_se.stream = ENEMY_ATTACK_SE
	add_child(enemy_atk_se)

	var enemy_hit_se = AudioStreamPlayer.new()
	enemy_hit_se.name = "enemy_hit_se"
	enemy_hit_se.stream = UTU2_SE
	add_child(enemy_hit_se)'''
content = content.replace(block_ready, '')

# Replace in _handle_turn_sequence
old_atk = '''			if enemy_atk_se:
				enemy_atk_se.stream = ENEMY_ATTACK_SE
				enemy_atk_se.volume_db = linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5))
				enemy_atk_se.play(0.0)'''
new_atk = '''			_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5)), 1.0)'''
content = content.replace(old_atk, new_atk)

old_hit = '''				if hit_se:
					hit_se.stream = UTU2_SE
					hit_se.volume_db = linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5))
					hit_se.play(0.0)'''
new_hit = '''				_play_pooled_se(UTU2_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)'''
content = content.replace(old_hit, new_hit)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")

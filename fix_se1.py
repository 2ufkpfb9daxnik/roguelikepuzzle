import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# _play_enemy_skill_se
old_se1 = '''func _play_enemy_skill_se(is_boss: bool) -> void:
	var se_stream = BUFF2_SE if is_boss else BUFF1_SE
	if se_stream:
		var asp = AudioStreamPlayer.new()
		asp.stream = se_stream
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			asp.volume_db = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		else:
			asp.volume_db = 0.0
		var p = get_parent()
		var target_parent = p if p != null else self
		target_parent.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)'''
new_se1 = '''func _play_enemy_skill_se(is_boss: bool) -> void:
	var se_stream = BUFF2_SE if is_boss else BUFF1_SE
	if se_stream:
		var vol = 0.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		_play_pooled_se(se_stream, vol, 1.0)'''
content = content.replace(old_se1, new_se1)

# _play_spell_beam_se
old_se2 = '''func _play_spell_beam_se() -> void:
	if ACCEL_SE:
		var asp = AudioStreamPlayer.new()
		asp.stream = ACCEL_SE
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			asp.volume_db = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		else:
			asp.volume_db = 0.0
		var p = get_parent()
		var target_parent = p if p != null else self
		target_parent.add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)'''
new_se2 = '''func _play_spell_beam_se() -> void:
	if ACCEL_SE:
		var vol = 0.0
		var sm_autoload = get_node_or_null("/root/SettingsManager")
		if sm_autoload and "se_volume" in sm_autoload:
			vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0))
		_play_pooled_se(ACCEL_SE, vol, 1.0)'''
content = content.replace(old_se2, new_se2)

# enemy_attack_se and enemy_hit_se in _handle_turn_sequence
# Instead of replacing large blocks, let's just regex for AudioStreamPlayer.new() -> _play_pooled_se
# Wait, in _handle_turn_sequence it creates hit_se and enemy_atk_se and caches them inside the scene tree!
# "var enemy_atk_se = get_node_or_null("enemy_attack_se") as AudioStreamPlayer"
# "if enemy_atk_se == null: enemy_atk_se = AudioStreamPlayer.new()"
# This is technically already pooled because it reuses the same node.
# The user might be referring to sp_i and sp_d in _spawn_heal_number_effect and _spawn_drain_number_effect!
# Let's check those!
with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")

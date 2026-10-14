import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

old_wood = '''func _play_wood_drain_se() -> void:
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	var vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0)) if (sm_autoload and "se_volume" in sm_autoload) else 0.0
	var p = get_parent()
	var target_parent = p if p != null else self

	# ŌzCpNg
	if UTU2_SE:
		var asp_i = AudioStreamPlayer.new()
		asp_i.stream = UTU2_SE
		asp_i.volume_db = vol
		target_parent.add_child(asp_i)
		asp_i.play()
		asp_i.finished.connect(asp_i.queue_free)

	# _Iz[v
	if GAGE_HEAL_SE:
		var asp_d = AudioStreamPlayer.new()
		asp_d.stream = GAGE_HEAL_SE
		asp_d.volume_db = vol
		asp_d.pitch_scale = 0.95
		target_parent.add_child(asp_d)
		asp_d.play()
		asp_d.finished.connect(asp_d.queue_free)'''

new_wood = '''func _play_wood_drain_se() -> void:
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	var vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0)) if (sm_autoload and "se_volume" in sm_autoload) else 0.0
	
	if UTU2_SE: _play_pooled_se(UTU2_SE, vol, 1.0)
	if GAGE_HEAL_SE: _play_pooled_se(GAGE_HEAL_SE, vol, 0.95)'''

content = content.replace(old_wood, new_wood)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

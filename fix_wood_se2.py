import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

start = content.find('func _play_wood_drain_se() -> void:')
end = content.find('func ', start + 10)
if end == -1: end = len(content)

old_body = content[start:end]

new_body = '''func _play_wood_drain_se() -> void:
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	var vol = linear_to_db(clampf(sm_autoload.se_volume, 0.001, 1.0)) if (sm_autoload and "se_volume" in sm_autoload) else 0.0
	
	if UTU2_SE: _play_pooled_se(UTU2_SE, vol, 1.0)
	if GAGE_HEAL_SE: _play_pooled_se(GAGE_HEAL_SE, vol, 0.95)

'''

content = content[:start] + new_body + content[end:]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

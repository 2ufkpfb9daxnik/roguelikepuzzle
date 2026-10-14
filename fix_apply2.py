import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# find _apply_enemy_elemental_skill_effect body
start = content.find('func _apply_enemy_elemental_skill_effect')
end = content.find('func _play_enemy_skill_se', start)
body = content[start:end]

# replace _cast_enemy_* with return _cast_enemy_* where not already returning
body = re.sub(r'(?<!return )_cast_enemy_', 'return _cast_enemy_', body)
content = content[:start] + body + content[end:]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

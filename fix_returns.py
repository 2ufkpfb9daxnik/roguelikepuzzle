import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _play_ally_attack_phase_effects(sm: Node2D) -> void:' in lines[i]:
        for j in range(i, i+30):
            if 'if active_en.is_empty(): return' in lines[j]:
                lines[j] = '\tif active_en.is_empty():\n\t\tturn_skill_log.clear()\n\t\treturn'
            elif 'if elements_to_play.is_empty(): return' in lines[j]:
                lines[j] = '\tif elements_to_play.is_empty():\n\t\tturn_skill_log.clear()\n\t\treturn'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

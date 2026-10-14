import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _play_ally_attack_phase_effects' in lines[i]:
        for j in range(i, i+30):
            if 'delay += 0.15' in lines[j]:
                lines.insert(j+1, '\tturn_skill_log.clear()')
                break
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

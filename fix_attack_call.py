import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'if interval == base_time + 1 and isattack:' in lines[i]:
        lines.insert(i+2, '\t\t_play_ally_attack_phase_effects(sm)')
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

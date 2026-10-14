import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if '_spawn_enemy_skill_beam_and_burst(sm, spr, elem_color, is_boss)' in lines[i]:
        lines[i] = '\t\t\t\t\tvar tgs = _apply_enemy_elemental_skill_effect(elem, is_boss)\n\t\t\t\t\t_spawn_enemy_skill_beam_and_burst(sm, spr, elem_color, is_boss, tgs)'
        lines[i+1] = ''
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

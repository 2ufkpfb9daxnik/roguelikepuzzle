import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _play_elemental_size' in lines[i]:
        lines[i+1] = '\tvar local_pos = self.to_local(target_global_pos)'
        lines[i+2] = '\t'
        lines[i+3] = '\t'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

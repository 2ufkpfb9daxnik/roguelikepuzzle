import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'await get_tree().create_timer(0.45, false).timeout' in lines[i]:
        lines[i] = '\tawait get_tree().create_timer(0.85, false).timeout'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

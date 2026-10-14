import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if '_add_element_mark_to_sprite(new_sprite)' in lines[i]:
        lines[i] = '\t\t_add_element_mark_to_sprite(new_sprite)'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

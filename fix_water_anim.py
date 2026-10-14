import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'if is_stone or is_animated or is_water:' in lines[i]:
        lines[i] = '\t\t\t\tif is_stone or is_animated or is_water:\n\t\t\t\t\thas_board_hazards = true'
        lines[i+1] = ''
    if 'if is_animated:' in lines[i]:
        lines[i] = '\t\t\t\tif is_animated or is_water:\n\t\t\t\t\thas_animated_board_hazards = true'
        lines[i+1] = ''

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

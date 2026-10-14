import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'var is_stone: bool = grid_stones.size() == GRID_ROWS and grid_stones[r][c] > 0' in lines[i]:
        lines.insert(i, '\t\t\t\tvar is_water: bool = grid_water.size() == GRID_ROWS and grid_water[r][c]')
        break

for i in range(len(lines)):
    if 'if is_stone or is_animated:' in lines[i]:
        lines[i] = '\t\t\t\tif is_stone or is_animated or is_water:\n\t\t\t\t\thas_board_hazards = true'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

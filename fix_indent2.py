import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'grid_element[r][c] = final_cell.get("element"' in lines[i]:
        lines[i] = '\t\t\tif grid_element.size() == GRID_ROWS: grid_element[r][c] = final_cell.get("element", ElementData.Element.NONE)'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

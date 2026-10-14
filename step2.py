import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if '"att": (grid_att[r][c]' in lines[i]:
        lines.insert(i+1, '\t\t\t\t\t"element": grid_element[r][c] if grid_element.size() == GRID_ROWS and p_idx != -1 else ElementData.Element.NONE,')
        break

for i in range(len(lines)):
    if '"att": nval % 5,' in lines[i]:
        lines.insert(i+1, '\t\t\t\t\t"element": ElementData.Element.NONE,')
        break

for i in range(len(lines)):
    if 'if grid_att.size() == GRID_ROWS: grid_att[r][c] = final_cell.att' in lines[i]:
        lines.insert(i+1, '\t\t\t\t\tif grid_element.size() == GRID_ROWS: grid_element[r][c] = final_cell.get("element", ElementData.Element.NONE)')
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

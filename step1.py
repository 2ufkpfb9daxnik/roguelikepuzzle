import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

# 1. Add grid_element
for i in range(len(lines)):
    if 'var grid_att: Array = []' in lines[i]:
        lines.insert(i+1, 'var grid_element: Array = []')
        break

# 2. Add row_element in init
for i in range(len(lines)):
    if 'var row_gold_statue: Array[int] = []' in lines[i]:
        lines.insert(i+1, '\t\tvar row_element: Array[int] = []')
        break
for i in range(len(lines)):
    if 'row_att.append(chosen_kind % 5)' in lines[i]:
        lines.insert(i+1, '\t\t\trow_element.append(ElementData.Element.NONE)')
        break
for i in range(len(lines)):
    if 'grid_att.append(row_att)' in lines[i]:
        lines.insert(i+1, '\t\tgrid_element.append(row_element)')
        break

# 3. Swap in _swap_grid_data
for i in range(len(lines)):
    if 'var tmp_att = grid_att[r1][c1]' in lines[i]:
        swap_code = '''	if grid_element.size() == GRID_ROWS:
		var tmp_el = grid_element[r1][c1]
		grid_element[r1][c1] = grid_element[r2][c2]
		grid_element[r2][c2] = tmp_el
'''
        lines.insert(i-1, swap_code)
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

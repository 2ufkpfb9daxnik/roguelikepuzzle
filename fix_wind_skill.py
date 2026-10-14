import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'func _cast_enemy_wind_skill' in lines[i]:
        start = i
        break

if start != -1:
    for i in range(start, start + 50):
        if 'active_wind_tornadoes.append({' in lines[i]:
            # Next few lines define the tornado dict
            for j in range(i, i+10):
                if '})' in lines[j]:
                    lines[j] = '\t\t})\n\t\t_targets.append(get_cell_position(GRID_ROWS / 2, col))\n\t\tvar clear_cells: Array[Vector2i] = []'
                    break
        elif 'for r in range(GRID_ROWS):' in lines[i]:
            # we inject clear_cells.append
            lines[i] = '\t\tfor r in range(GRID_ROWS):\n\t\t\tclear_cells.append(Vector2i(r, col))'
        elif 'grid_water[r][col] = false' in lines[i]:
            # after this we call _clear_pieces_in_cells
            lines[i] = '\t\t\t\tgrid_water[r][col] = false\n\n\t\t_clear_pieces_in_cells(clear_cells)'
            break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

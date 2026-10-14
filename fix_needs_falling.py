import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _handle_turn_sequence' in lines[i]:
        # find the end where current_state = BoardState.IDLE
        for j in range(i, min(len(lines), i + 200)):
            if 'current_state = BoardState.IDLE' in lines[j] and '_reset_turn(sm, score_mgr)' in lines[j-1]:
                # Insert _needs_falling check
                lines[j] = '\t\tcurrent_state = BoardState.IDLE\n\t\tif _needs_falling():\n\t\t\t_start_continuous_falling()'
                break
        break

# Insert _needs_falling helper
needs_falling_func = '''
func _needs_falling() -> bool:
	if grid_i.size() != GRID_ROWS: return false
	for c in range(GRID_COLUMNS):
		for r in range(GRID_ROWS):
			if not _is_plant_cell(r, c) and grid_i[r][c] == -1:
				return true
	return false
'''

# insert before _handle_turn_sequence
for i in range(len(lines)):
    if 'func _handle_turn_sequence' in lines[i]:
        lines.insert(i, needs_falling_func)
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

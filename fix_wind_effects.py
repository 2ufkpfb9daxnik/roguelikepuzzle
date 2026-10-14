import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'func _cast_enemy_wind_skill' in lines[i]:
        start = i
        break

if start != -1:
    for i in range(start, start + 70):
        if 'var clear_cells: Array[Vector2i] = []' in lines[i]:
            lines[i] = ''
        if 'clear_cells.append(Vector2i(r, col))' in lines[i]:
            lines[i] = ''
        if '_clear_pieces_in_cells(clear_cells)' in lines[i]:
            lines[i] = ''
        if 'grid_water[r][col] = false' in lines[i]:
            # Inject the other effect clears here
            additions = '''				grid_water[r][col] = false
			if grid_ice.size() == GRID_ROWS:
				grid_ice[r][col] = 0
			if grid_cursed.size() == GRID_ROWS:
				grid_cursed[r][col] = false
			if grid_electrified.size() == GRID_ROWS:
				grid_electrified[r][col] = false
			if grid_gold_statue.size() == GRID_ROWS:
				grid_gold_statue[r][col] = 0'''
            lines[i] = additions

# Remove _needs_falling calls from _handle_turn_sequence
for i in range(len(lines)):
    if 'current_state = BoardState.IDLE' in lines[i] and 'if _needs_falling():' in lines[i+1]:
        lines[i+1] = ''
        lines[i+2] = ''

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

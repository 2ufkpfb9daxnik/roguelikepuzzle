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
            for j in range(i, i+10):
                if '})' in lines[j]:
                    lines[j] = '\t\t})\n\t\t_targets.append(get_cell_position(GRID_ROWS / 2, col))'
                    break
        elif 'grid_water[r][col] = false' in lines[i]:
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
            break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

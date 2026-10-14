import codecs

with codecs.open('board_overlay.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start_rm = -1
for i in range(len(lines)):
    if '# [復元] 水マス' in lines[i]:
        start_rm = i
        break

if start_rm != -1:
    for i in range(10):
        lines.pop(start_rm)

insert_code = '''	# [復元] 水マス (grid_water: 美麗水面・波紋)
	if "grid_water" in board and board.grid_water.size() == GRID_ROWS:
		var water_pulse = 0.85 + 0.15 * sin(now * 0.005)
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_water[r][c]:
					_draw_water_tile(r, c, water_pulse)'''

for i in range(len(lines)):
    if 'func _draw() -> void:' in lines[i]:
        for j in range(i, len(lines)):
            if 'if "grid_fog" in board' in lines[j]:
                lines.insert(j, insert_code)
                break
        break

with codecs.open('board_overlay.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

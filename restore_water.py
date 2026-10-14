import codecs

with codecs.open('board_overlay.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

insert_code = '''
	# [復元] 水マス (grid_water: 美麗水面・波紋)
	if "grid_water" in board and board.grid_water.size() == GRID_ROWS:
		var water_pulse = 0.85 + 0.15 * sin(now * 0.005)
		for r in range(GRID_ROWS):
			for c in range(GRID_COLS):
				if board.grid_water[r][c]:
					_draw_water_tile(r, c, water_pulse)
'''

func_code = '''
func _draw_water_tile(r: int, c: int, pulse: float) -> void:
	var cell_rect = Rect2(BOARD_LEFT + c * CELL_PITCH, BOARD_TOP + r * CELL_PITCH, CELL_PITCH, CELL_PITCH)
	# 深いアクアブルーの水たまり
	draw_rect(cell_rect, Color(0.10, 0.45, 0.85, 0.38 * pulse), true)
	draw_rect(cell_rect.grow(-4.0), Color(0.30, 0.80, 1.0, 0.55), false, 8.0)
	var center = cell_rect.get_center()
	# 水滴・水面ハイライト
	draw_circle(center + Vector2(-40.0, -40.0), 35.0, Color(1.0, 1.0, 1.0, 0.35))
	draw_arc(center, 90.0 * pulse, 0.0, TAU, 20, Color(0.4, 0.85, 1.0, 0.65), 5.0)
'''

# insert inside _draw
for i in range(len(lines)):
    if 'if "active_wind_tornadoes" in board' in lines[i]:
        lines.insert(i, insert_code)
        break

lines.append(func_code)

with codecs.open('board_overlay.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

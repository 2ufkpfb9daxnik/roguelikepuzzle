import codecs
new_func = '''
func _draw_poison_tile(r: int, c: int, pulse: float) -> void:
	var pos = _get_cell_pos(r, c)
	var m = CELL_PITCH / 2.0
	var rect = Rect2(pos - Vector2(m, m), Vector2(CELL_PITCH, CELL_PITCH))
	var bg_col = Color(0.4, 0.0, 0.8, 0.65 + 0.15 * pulse)
	draw_rect(rect, bg_col, true)
	draw_rect(rect, Color(0.6, 0.0, 1.0, 0.9), false, 18.0)
	for i in range(5):
		var p_x = pos.x + sin(i * 1.5 + pulse * TAU) * (m * 0.5)
		var p_y = pos.y + cos(i * 2.1 - pulse * TAU) * (m * 0.5)
		draw_circle(Vector2(p_x, p_y), 30.0 + 10.0 * pulse, Color(0.7, 0.2, 1.0, 0.8))
		draw_circle(Vector2(p_x - 5, p_y - 5), 10.0, Color(0.9, 0.6, 1.0, 0.9))
	var label = \"POISON\"
	draw_string(CUSTOM_FONT, Vector2(pos.x - 200, pos.y + 195), label, HORIZONTAL_ALIGNMENT_CENTER, 400, 100, Color(0.9, 0.5, 1.0, 0.95))
'''
with codecs.open('board_overlay.gd', 'a', 'utf-8') as f:
    f.write('\n' + new_func + '\n')

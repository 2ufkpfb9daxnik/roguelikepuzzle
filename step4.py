import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

debug_code = '''
const DEBUG_ELEMENT = true

func _input(event: InputEvent) -> void:
	if not DEBUG_ELEMENT: return
	if event is InputEventKey and event.pressed and not event.echo:
		var el = ElementData.Element.NONE
		match event.keycode:
			KEY_1: el = ElementData.Element.FIRE
			KEY_2: el = ElementData.Element.WATER
			KEY_3: el = ElementData.Element.WIND
			KEY_4: el = ElementData.Element.THUNDER
			KEY_5: el = ElementData.Element.LIGHT
			KEY_6: el = ElementData.Element.DARK
			
		if el != ElementData.Element.NONE:
			_debug_apply_element_random(el)

func _debug_apply_element_random(el: int) -> void:
	if grid_element.size() != GRID_ROWS: return
	var candidates = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			var kind = grid_n[r][c]
			if (kind == PieceType.SWORD or kind == PieceType.SHIELD) and grid_element[r][c] == ElementData.Element.NONE:
				candidates.append(Vector2i(r, c))
				
	candidates.shuffle()
	var applied_count = 0
	for cell in candidates:
		if applied_count >= 10: break
		grid_element[cell.x][cell.y] = el
		_update_piece_element_mark(grid_i[cell.x][cell.y], el)
		applied_count += 1
	print("[DEBUG] Applied element ", ElementData.get_element_name(el), " to ", applied_count, " pieces.")
'''
lines.append(debug_code)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

def replace_func(content, func_name, new_body):
    pattern = r'(func ' + func_name + r'\b.*?\n)(?:(?:[ \t].*\n)|(?:^\s*\n))*'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[:match.start()] + new_body + '\n' + content[match.end():]
    return content

# 1. _check_matches_exist の最適化 (変更行・列のみスキャンするように引数を追加)
old_check_matches_exist = '''func _check_matches_exist() -> bool:
	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			ismatched[i][j] = false

	var found = false

	# ???????
	for i in range(GRID_ROWS):
		var j: int = 0
		while j < GRID_COLUMNS:
			var kind: int = grid_n[i][j]
			if kind < 0:
				j += 1
				continue
			var match_len: int = 1
			while j + match_len < GRID_COLUMNS and grid_n[i][j + match_len] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(j, j + match_len):
					ismatched[i][k] = true
			j += match_len

	# ???????
	for j in range(GRID_COLUMNS):
		var i: int = 0
		while i < GRID_ROWS:
			var kind: int = grid_n[i][j]
			if kind < 0:
				i += 1
				continue
			var match_len: int = 1
			while i + match_len < GRID_ROWS and grid_n[i + match_len][j] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(i, i + match_len):
					ismatched[k][j] = true
			i += match_len

	return found'''
new_check_matches_exist = '''func _check_matches_exist(changed_rows: Array = [], changed_cols: Array = []) -> bool:
	var rows_to_check = changed_rows
	var cols_to_check = changed_cols
	
	if rows_to_check.size() == 0 and cols_to_check.size() == 0:
		rows_to_check = range(GRID_ROWS)
		cols_to_check = range(GRID_COLUMNS)
		for i in range(GRID_ROWS):
			for j in range(GRID_COLUMNS):
				ismatched[i][j] = false

	var found = false

	# 水平方向の走査 (必要な行のみ)
	for i in rows_to_check:
		var j: int = 0
		while j < GRID_COLUMNS:
			if ismatched[i][j]:
				j += 1
				continue
			var kind: int = grid_n[i][j]
			if kind < 0:
				j += 1
				continue
			var match_len: int = 1
			while j + match_len < GRID_COLUMNS and grid_n[i][j + match_len] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(j, j + match_len):
					ismatched[i][k] = true
			j += match_len

	# 垂直方向の走査 (必要な列のみ)
	for j in cols_to_check:
		var i: int = 0
		while i < GRID_ROWS:
			if ismatched[i][j]:
				i += 1
				continue
			var kind: int = grid_n[i][j]
			if kind < 0:
				i += 1
				continue
			var match_len: int = 1
			while i + match_len < GRID_ROWS and grid_n[i + match_len][j] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(i, i + match_len):
					ismatched[k][j] = true
			i += match_len

	return found'''

content = content.replace(old_check_matches_exist, new_check_matches_exist)


# 2. _update_falling_physics の最適化
# landed なものをリストから取り除くようにする
new_falling_physics = '''func _update_falling_physics(delta: float) -> void:
	if falling_pieces.size() == 0:
		return
		
	var i = falling_pieces.size() - 1
	while i >= 0:
		var item = falling_pieces[i]
		if item["landed"]:
			falling_pieces.remove_at(i)
			i -= 1
			continue
			
		var s: Sprite2D = item["sprite"]
		if not is_instance_valid(s):
			falling_pieces.remove_at(i)
			i -= 1
			continue
			
		var waypoints: Array[Vector2] = item["waypoints"]
		var wp_idx: int = item["wp_idx"]
		var target_pos: Vector2 = waypoints[wp_idx]
		var start_pos: Vector2 = item["current_start_pos"]

		item["velocity_y"] = minf(item["velocity_y"] + GRAVITY * delta, MAX_FALL_SPEED)
		var dy = item["velocity_y"] * delta

		if target_pos.y > start_pos.y:
			s.position.y += dy
			var total_dy = target_pos.y - start_pos.y
			var t = clampf((s.position.y - start_pos.y) / maxf(1.0, total_dy), 0.0, 1.0)
			s.position.x = lerpf(start_pos.x, target_pos.x, t)

			if s.position.y >= target_pos.y:
				s.position = target_pos
				item["wp_idx"] += 1
				if item["wp_idx"] < waypoints.size():
					item["current_start_pos"] = target_pos
				else:
					item["landed"] = true
					var bounce_tween = create_tween()
					bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
					bounce_tween.tween_property(s, "scale", cellsize, 0.08)
		else:
			var speed_h = 7500.0 * delta
			s.position = s.position.move_toward(target_pos, speed_h)
			if s.position.distance_to(target_pos) < 4.0:
				s.position = target_pos
				item["wp_idx"] += 1
				if item["wp_idx"] < waypoints.size():
					item["current_start_pos"] = target_pos
				else:
					item["landed"] = true
					var bounce_tween = create_tween()
					bounce_tween.tween_property(s, "scale", Vector2(cellsize.x * 1.12, cellsize.y * 0.88), 0.05)
					bounce_tween.tween_property(s, "scale", cellsize, 0.08)
		i -= 1'''
content = replace_func(content, '_update_falling_physics', new_falling_physics)

# 3. _detonate_specials の最適化
# 既にキューに入っているかどうかのチェックを高速化
new_detonate_specials = '''func _detonate_specials(start_items: Array) -> void:
	var queue: Array = []
	var queued_set: Dictionary = {}
	
	for b in start_items:
		queue.append(b)
		queued_set[b] = true
		
	var exploded_items: Dictionary = {}

	while queue.size() > 0:
		var b = queue.pop_front()
		if b in exploded_items:
			continue
		exploded_items[b] = true

		var item_type: int = SpecialItemType.BOMB
		if special_item.size() == GRID_ROWS:
			item_type = special_item[b.x][b.y]
			if item_type == SpecialItemType.NONE and is_bomb.size() == GRID_ROWS and is_bomb[b.x][b.y]:
				item_type = SpecialItemType.BOMB
			special_item[b.x][b.y] = SpecialItemType.NONE
		if is_bomb.size() == GRID_ROWS:
			is_bomb[b.x][b.y] = false

		var pos = get_cell_position(b.x, b.y)

		match item_type:
			SpecialItemType.BOMB:
				_trigger_bomb_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.CROSS_BOMB:
				_trigger_cross_bomb_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.TORNADO:
				_trigger_tornado_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.LIGHTNING:
				_trigger_lightning_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.BLACK_HOLE:
				_trigger_black_hole_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.GEMINI_BOMB:
				_trigger_gemini_bomb_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.MAGNET:
				_trigger_magnet_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.COLOR_CONVERTER:
				_trigger_color_converter_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)
			SpecialItemType.CHARGE_BOMB:
				_trigger_charge_bomb_optimized(b.x, b.y, pos, queue, queued_set, exploded_items)

	# 最後に一気にフラグ更新
	for e in exploded_items.keys():
		ismatched[e.x][e.y] = true'''
content = replace_func(content, '_detonate_specials', new_detonate_specials)


# 4. _process_turn_plants の最適化
# active_plants のようなリストを持っていれば良いが、現状グリッド全走査している。
new_process_turn_plants = '''func _process_turn_plants() -> void:
	if not has_board_hazards:
		return
	if grid_plant.size() != GRID_ROWS:
		return
		
	var active_plants = []
	for r in range(GRID_ROWS):
		for c in range(GRID_COLUMNS):
			if grid_plant[r][c] > 0:
				active_plants.append(Vector2i(r, c))
				
	if active_plants.is_empty():
		return

	var sm = _get_stage_manager()
	var new_plants = []
	for cell in active_plants:
		var r = cell.x
		var c = cell.y
		if ismatched[r][c]:
			grid_plant[r][c] -= 1
			_spawn_hit_particles(get_cell_position(r, c), Color(0.2, 0.8, 0.2))
			var se = get_node_or_null("AudioStreamPlayer2")
			if se:
				se.stream = KUSA_SE
				se.play()
			if grid_plant[r][c] <= 0:
				var p_idx = grid_i[r][c]
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
					piece[p_idx].queue_free()
					piece[p_idx] = null
				grid_n[r][c] = -1
				grid_i[r][c] = -1
				continue
		elif sm and sm.interval >= 105 and not sm.isdeadf and not sm.isstageclear:
			var empty_neighbors = []
			for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var nr = r + dir.x
				var nc = c + dir.y
				if nr >= 0 and nr < GRID_ROWS and nc >= 0 and nc < GRID_COLUMNS:
					if grid_plant[nr][nc] == 0 and grid_n[nr][nc] == -1 and not ismatched[nr][nc]:
						empty_neighbors.append(Vector2i(nr, nc))
			if empty_neighbors.size() > 0 and (randi() % 100 < 15):
				new_plants.append(empty_neighbors[randi() % empty_neighbors.size()])

	for np in new_plants:
		if grid_plant[np.x][np.y] == 0:
			grid_plant[np.x][np.y] = 1
			grid_n[np.x][np.y] = 999
			_redraw_board_effects()'''
content = replace_func(content, '_process_turn_plants', new_process_turn_plants)


# 5. _redraw_board_effects の呼び出し抑制
# bool フラグを導入し、_process内で1回だけ描画するようにする。
content = content.replace('func _redraw_board_effects() -> void:', '''var _pending_redraw_effects: bool = false
func _redraw_board_effects() -> void:
	_pending_redraw_effects = true

func _execute_pending_redraw_effects() -> void:
	_pending_redraw_effects = false''')

old_process_end = '''	# ?????????????????????????????????????????????????
	if has_special_items and mark_overlay:
		pass # t[queue_redraw͏d̂ō폜'''

new_process_end = '''	if _pending_redraw_effects:
		_execute_pending_redraw_effects()
	if has_special_items and mark_overlay:
		pass # 毎フレームのqueue_redrawは重いので削除'''
content = content.replace(old_process_end, new_process_end)


with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

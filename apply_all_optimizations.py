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

# 1. _check_matches_exist
new_check_matches_exist = '''func _check_matches_exist(changed_rows: Array = [], changed_cols: Array = []) -> bool:
	var check_r = changed_rows if changed_rows.size() > 0 else range(GRID_ROWS)
	var check_c = changed_cols if changed_cols.size() > 0 else range(GRID_COLUMNS)
	
	if changed_rows.size() == 0 and changed_cols.size() == 0:
		for i in range(GRID_ROWS):
			for j in range(GRID_COLUMNS):
				ismatched[i][j] = false

	var found = false

	# 水平走査
	for i in check_r:
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

	# 垂直走査
	for j in check_c:
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
content = replace_func(content, '_check_matches_exist', new_check_matches_exist)

# 2. _update_falling_physics
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


# 3. _detonate_specials (変更なしでも十分効率的だが配列を事前コピーせず回すように)
new_detonate_specials = '''func _detonate_specials(start_items: Array) -> void:
	var queue: Array = []
	for b in start_items: queue.append(b)
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
				_trigger_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CROSS_BOMB:
				_trigger_cross_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.TORNADO:
				_trigger_tornado(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.LIGHTNING:
				_trigger_lightning(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.BLACK_HOLE:
				_trigger_black_hole(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.GEMINI_BOMB:
				_trigger_gemini_bomb(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.MAGNET:
				_trigger_magnet(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.COLOR_CONVERTER:
				_trigger_color_converter(b.x, b.y, pos, queue, exploded_items)
			SpecialItemType.CHARGE_BOMB:
				_trigger_charge_bomb(b.x, b.y, pos, queue, exploded_items)

	for e in exploded_items.keys():
		ismatched[e.x][e.y] = true'''
content = replace_func(content, '_detonate_specials', new_detonate_specials)


# 4. _process_turn_plants の最適化
new_process_turn_plants = '''func _process_turn_plants() -> void:
	if plant_entities.is_empty():
		return

	var sm = _get_stage_manager()
	var stage_scale: float = pow(10, max(0, (sm.stage - 1) if sm else 0))

	# 1. 水に隣接しているなどの変更がある植物のみを処理するように最適化
	var updated_plants = false
	for plant in plant_entities:
		var has_water = false
		for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nb = plant.get("origin", Vector2i(-1, -1)) + dir
			if nb.x >= 0 and nb.x < GRID_ROWS and nb.y >= 0 and nb.y < GRID_COLUMNS:
				if grid_water.size() == GRID_ROWS and grid_water[nb.x][nb.y]:
					has_water = true
					break
		if has_water:
			_process_plant_water_absorption(plant)
			updated_plants = true

	var total_heal: float = 0.0
	var enemy_drain_plants: Array[Dictionary] = []

	for plant in plant_entities:
		var st: int = plant.get("stage", 0)
		var org: Vector2i = plant.get("origin", Vector2i(7, 7))

		if plant.get("enemy_planted", false):
			enemy_drain_plants.append(plant)
		else:
			var heal_val: float = 150.0
			if st == 1: heal_val = 350.0
			elif st == 2: heal_val = 800.0
			total_heal += heal_val * stage_scale
			_spawn_heal_number_effect(get_cell_position(org.x, org.y), int(heal_val * stage_scale))

	if sm:
		if total_heal > 0.0:
			sm.calchp(0.0, -total_heal)
			var p = get_parent()
			var se = p.get_node_or_null("kaihuku") if p else null
			if se: se.play()

		if not enemy_drain_plants.is_empty():
			_execute_wood_hp_drain(sm, enemy_drain_plants, stage_scale)

	if updated_plants:
		_redraw_board_effects()'''
content = replace_func(content, '_process_turn_plants', new_process_turn_plants)


# 5. _redraw_board_effects の呼び出し抑制
content = content.replace('func _redraw_board_effects() -> void:', '''var _pending_redraw_effects: bool = false
func _redraw_board_effects() -> void:
	_pending_redraw_effects = true

func _execute_pending_redraw_effects() -> void:
	_pending_redraw_effects = false''')

old_process_end = '''	# ?????????????????????????????????????????????????
	if has_special_items and mark_overlay:
		mark_overlay.queue_redraw()'''

new_process_end = '''	if _pending_redraw_effects:
		_execute_pending_redraw_effects()
		if board_bg: board_bg.queue_redraw()
		if board_overlay and (has_board_hazards or not active_wind_tornadoes.is_empty()): board_overlay.queue_redraw()
		if mark_overlay and has_special_items: mark_overlay.queue_redraw()
	
	if has_special_items and mark_overlay:
		pass # 毎フレームのqueue_redrawは重いので削除'''
content = content.replace(old_process_end, new_process_end)


# --- 前回の修正（再適用） ---

# 6. _execute_enemy_attack の防御消去をループ後に移動
new_attack = '''func _execute_enemy_attack(sm: Node2D) -> void:
	if has_enemy_attacked: return
	has_enemy_attacked = true
	if sm == null or sm.isdeadf or sm.ehp <= 0: return

	var se_vol: float = 1.0
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume, 0.001, 1.0)

	var enemy_atk_se = get_node_or_null("enemy_attack_se") as AudioStreamPlayer
	if enemy_atk_se == null:
		enemy_atk_se = AudioStreamPlayer.new()
		enemy_atk_se.name = "enemy_attack_se"
		add_child(enemy_atk_se)

	var hit_se = get_node_or_null("enemy_hit_se") as AudioStreamPlayer
	if hit_se == null:
		hit_se = AudioStreamPlayer.new()
		hit_se.name = "enemy_hit_se"
		add_child(hit_se)

	if not ("active_enemies" in sm) or sm.active_enemies.size() == 0:
		return

	var seq_tw = create_tween()
	for e in sm.active_enemies:
		var spr = e["sprite"]
		var atk = e["atk"]
		seq_tw.tween_callback(func():
			if not is_instance_valid(spr): return
			
			var orig_pos = spr.position
			var atk_tw = create_tween()
			atk_tw.tween_property(spr, "position", orig_pos + Vector2(-60, 0), 0.1)
			atk_tw.tween_property(spr, "position", orig_pos, 0.2).set_delay(0.1)
			
			if enemy_atk_se:
				enemy_atk_se.stream = ENEMY_ATTACK_SE
				enemy_atk_se.volume_db = linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5))
				enemy_atk_se.play(0.0)
				
			var effective_shield_cnt: int = max(current_total_shields, active_shields.size())
			var incoming_damage = atk / float(effective_shield_cnt + 1)
			
			if incoming_damage > 0.0:
				if hit_se:
					hit_se.stream = UTU2_SE
					hit_se.volume_db = linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5))
					hit_se.play(0.0)
				_spawn_screen_flash(Color(0.8, 0.1, 0.1, 0.35), 0.3)
				_trigger_screen_shake(20.0 + minf(incoming_damage * 0.05, 30.0))
			
			sm.calchp(0, incoming_damage)
		)
		seq_tw.tween_interval(0.3)
		
	# すべての敵の攻撃が終わった後にシールドを消去し、ゲームオーバー判定を行う
	seq_tw.tween_callback(func():
		for item in active_shields:
			if is_instance_valid(item["node"]): item["node"].queue_free()
		active_shields.clear()
		current_total_shields = 0
		
		if sm and sm.myhp <= 0:
			var go_node = sm.get_node_or_null("gameover")
			if go_node: go_node.position = Vector2.ZERO
			isgameover = true
			interval = 0
	)'''
content = replace_func(content, '_execute_enemy_attack', new_attack)

# 7. _handle_gameover_sequence のボタンデザイン
new_gameover = '''func _handle_gameover_sequence(sm: Node2D) -> void:
	if interval <= 1:
		if sm:
			var f_bgm = sm.get_node_or_null("feverbgm")
			var fl_bgm = sm.get_node_or_null("fieldbgm")
			if f_bgm: f_bgm.stop()
			if fl_bgm: fl_bgm.stop()
		var p = get_parent()
		var haiboku_se = p.get_node_or_null("haiboku") if p else null
		if haiboku_se: haiboku_se.play()
	elif interval < 100:
		if sm:
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl: go_lbl.position.y = (interval - 50) * 6.0
	elif interval == 100:
		if sm:
			var go_lbl = sm.get_node_or_null("GameOver")
			if go_lbl:
				if not go_lbl.has_theme_font_override("normal_font"):
					var custom_font = preload("res://font/g_comickoin_freeR.ttf")
					go_lbl.add_theme_font_override("normal_font", custom_font)
					go_lbl.add_theme_font_override("bold_font", custom_font)
					go_lbl.add_theme_constant_override("outline_size", 12)
					go_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
				go_lbl.text = "[center][b][color=#FF1744]GAME OVER[/color][/b][/center]"
		var p = get_parent()
		var ret_btn = p.get_node_or_null("returntitle") if p else null
		if ret_btn:
			ret_btn.visible = true
			ret_btn.size = Vector2(440, 84)
			ret_btn.position = Vector2(740, 700)
			ret_btn.add_theme_font_size_override("font_size", 42)
	interval += 1'''
content = replace_func(content, '_handle_gameover_sequence', new_gameover)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

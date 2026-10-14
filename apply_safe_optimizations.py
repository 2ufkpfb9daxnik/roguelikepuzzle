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

# 1. _clear_all_combat_projectiles に flying_cells のクリアを追加
new_clear = '''func _clear_all_combat_projectiles() -> void:
	for item in flying_swords:
		if is_instance_valid(item.get("node")):
			item["node"].queue_free()
	flying_swords.clear()

	for item in active_shields:
		if is_instance_valid(item.get("node")):
			item["node"].queue_free()
	active_shields.clear()
	current_total_shields = 0

	for item in flying_foods:
		if is_instance_valid(item.get("node")):
			item["node"].queue_free()
	flying_foods.clear()
	
	for item in flying_potions:
		if is_instance_valid(item.get("node")):
			item["node"].queue_free()
	flying_potions.clear()
	
	for item in flying_cells:
		if is_instance_valid(item.get("node")):
			item["node"].queue_free()
	flying_cells.clear()'''
content = replace_func(content, '_clear_all_combat_projectiles', new_clear)


# 2. _execute_enemy_attack の防御消去をループ後に移動
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


# 3. _handle_gameover_sequence のボタンデザイン
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


# 4. _redraw_board_effects の呼び出し抑制
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


with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

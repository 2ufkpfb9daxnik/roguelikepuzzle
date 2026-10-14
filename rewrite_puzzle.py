import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

old_atk = '''func _execute_enemy_attack(sm: Node2D) -> void:
	# 既に攻撃済みならスキップ
	if has_enemy_attacked:
		return
	has_enemy_attacked = true

	# 敵が存在しない、またはHP0なら何もしない
	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return

	# オプションからSE音量を取得して反映（少し大きめに補正）
	var se_vol: float = 1.0
	var sm_autoload = get_node_or_null("/root/SettingsManager")
	if sm_autoload and "se_volume" in sm_autoload:
		se_vol = clampf(sm_autoload.se_volume, 0.001, 1.0)

	var enemy_atk_se = get_node_or_null("enemy_attack_se") as AudioStreamPlayer
	if enemy_atk_se == null:
		enemy_atk_se = AudioStreamPlayer.new()
		enemy_atk_se.name = "enemy_attack_se"
		enemy_atk_se.stream = ENEMY_ATTACK_SE
		add_child(enemy_atk_se)

	if enemy_atk_se:
		enemy_atk_se.stream = ENEMY_ATTACK_SE
		enemy_atk_se.volume_db = linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5))
		enemy_atk_se.play(0.0)

	if sm:
		var effective_shield_cnt: int = max(current_total_shields, active_shields.size())
		var incoming_damage = sm.enemyat / float(effective_shield_cnt + 1)
		
		# シールド破壊とダメージ処理
		if incoming_damage > 0.0:
			var hit_se = get_node_or_null("enemy_hit_se") as AudioStreamPlayer
			if hit_se == null:
				hit_se = AudioStreamPlayer.new()
				hit_se.name = "enemy_hit_se"
				hit_se.stream = UTU2_SE
				add_child(hit_se)
			if hit_se:
				hit_se.stream = UTU2_SE
				hit_se.volume_db = linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5))
				hit_se.play(0.0)
			_spawn_screen_flash(Color(0.8, 0.1, 0.1, 0.35), 0.3)
			_trigger_screen_shake(20.0 + minf(incoming_damage * 0.05, 30.0))

		sm.calchp(0, incoming_damage)

	for item in active_shields:
		item["node"].queue_free()
	active_shields.clear()
	current_total_shields = 0

	if sm and sm.myhp <= 0:
		var go_node = sm.get_node_or_null("gameover")
		if go_node: go_node.position = Vector2.ZERO
		isgameover = true
		interval = 0'''

new_atk = '''func _execute_enemy_attack(sm: Node2D) -> void:
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

	if not "active_enemies" in sm or sm.active_enemies.size() == 0:
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
			
			for item in active_shields:
				if is_instance_valid(item["node"]): item["node"].queue_free()
			active_shields.clear()
			current_total_shields = 0
			
			if sm and sm.myhp <= 0:
				var go_node = sm.get_node_or_null("gameover")
				if go_node: go_node.position = Vector2.ZERO
				isgameover = true
				interval = 0
		)
		seq_tw.tween_interval(0.3)'''
content = content.replace(old_atk, new_atk)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

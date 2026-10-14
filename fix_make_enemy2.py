import codecs

old_block = '''	# 敵スプライトの生成（キャッシュ利用でディスクI/O負荷をゼロに）
	if enemy_name in ENEMY_TEXTURES:
		var tex: Texture2D = _cached_enemy_textures.get(enemy_name)
		if tex == null:
			tex = load(ENEMY_TEXTURES[enemy_name]) as Texture2D
			_cached_enemy_textures[enemy_name] = tex
		enemy = Sprite2D.new()
		enemy.name = "Enemy"
		enemy.texture = tex
		enemy.scale = Vector2(0.5, 0.5)
	else:
		# フォールバック
		var template_enemy = get_parent().get_child(0).get_node_or_null(enemy_name)
		if template_enemy:
			enemy = template_enemy.duplicate()

	# 出現敵のアニメーションシートを即座に事前ロードしてメモリキャッシュ（戦闘中のフレーム落ちを完全防止）
	if ENEMY_ANIMATION_SHEETS.has(enemy_name):
		var anims = ENEMY_ANIMATION_SHEETS[enemy_name]
		for a_key in anims:
			var a_info = anims[a_key]
			var s_path = a_info.get("path", "")
			_get_anim_texture(s_path)

	if enemy:
		enemy.set_meta("base_scale", enemy.scale)
		enemy.position = Vector2(1550, 250)
		add_child(enemy)
		
		var pb = _get_puzzle_board()
		if pb:
			pb.set("encolor", enemy.modulate.r)

		# 敵の待機（Idle）アニメーションを開始
		start_enemy_idle_animation()

	# HPバーの生成
	var sm = _get_score_manager()
	if sm:
		var bar_template = sm.get_node_or_null("ehpbar")
		var bar1_template = sm.get_node_or_null("ehpbar1")
		if bar_template and bar1_template:
			ehpbar = bar_template.duplicate()
			ehpbar1 = bar1_template.duplicate()
			ehpbar.visible = true
			ehpbar1.visible = true
			ehpbar.position = Vector2(1475, 145)
			ehpbar1.position = Vector2(1475, 145)
			add_child(ehpbar)
			add_child(ehpbar1)

	ehppar = 1.0
	var stage_mult: float = pow(10.0, max(0, stage - 1))
	ehp = raw_hp * stage_mult
	enemyat = raw_atk * stage_mult
	ehpmax = ehp

	enemycount += 1'''

new_block = '''	initial_spawn_count = 1 if is_boss else randi_range(1, 3)
	enemy_sprites.clear()
	
	for i in range(initial_spawn_count):
		var en: Sprite2D = null
		if enemy_name in ENEMY_TEXTURES:
			var tex: Texture2D = _cached_enemy_textures.get(enemy_name)
			if tex == null:
				tex = load(ENEMY_TEXTURES[enemy_name]) as Texture2D
				_cached_enemy_textures[enemy_name] = tex
			en = Sprite2D.new()
			en.name = "Enemy_" + str(i)
			en.texture = tex
			en.scale = Vector2(0.5, 0.5)
		else:
			var template_enemy = get_parent().get_child(0).get_node_or_null(enemy_name)
			if template_enemy:
				en = template_enemy.duplicate()
		if en:
			en.set_meta("base_scale", en.scale)
			var base_x = 1550
			if initial_spawn_count == 2: base_x = 1450 + i * 200
			if initial_spawn_count == 3: base_x = 1350 + i * 200
			en.position = Vector2(base_x, 250)
			add_child(en)
			enemy_sprites.append(en)
			
	if ENEMY_ANIMATION_SHEETS.has(enemy_name):
		var anims = ENEMY_ANIMATION_SHEETS[enemy_name]
		for a_key in anims:
			var a_info = anims[a_key]
			var s_path = a_info.get("path", "")
			_get_anim_texture(s_path)
			
	if enemy_sprites.size() > 0:
		enemy = enemy_sprites[0]
		var pb = _get_puzzle_board()
		if pb:
			pb.set("encolor", enemy.modulate.r)
		start_enemy_idle_animation()

	var sm = _get_score_manager()
	if sm:
		var bar_template = sm.get_node_or_null("ehpbar")
		var bar1_template = sm.get_node_or_null("ehpbar1")
		if bar_template and bar1_template:
			ehpbar = bar_template.duplicate()
			ehpbar1 = bar1_template.duplicate()
			ehpbar.visible = true
			ehpbar1.visible = true
			ehpbar.position = Vector2(1475, 145)
			ehpbar1.position = Vector2(1475, 145)
			add_child(ehpbar)
			add_child(ehpbar1)

	ehppar = 1.0
	var stage_mult: float = pow(10.0, max(0, stage - 1))
	ehp = raw_hp * stage_mult * initial_spawn_count
	enemyat = raw_atk * stage_mult * initial_spawn_count
	ehpmax = ehp

	enemycount += 1'''

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(old_block, new_block)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

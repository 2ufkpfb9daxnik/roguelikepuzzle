import codecs

old_block = '''func calchp(damage_to_enemy: float, damage_to_player: float) -> void:
	ehp = maxf(0.0, ehp - damage_to_enemy)
	myhp = clampf(myhp - damage_to_player, 0.0, myhpmax)
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0
	myhppar = myhp / myhpmax if myhpmax > 0 else 0.0

	if damage_to_enemy > 0.0 and not isdeadf and enemy != null and is_instance_valid(enemy):
		# 敵ダメージフラッシュ（純白に一瞬光る）
		var flash_tw = create_tween()
		enemy.modulate = Color(2.0, 1.8, 1.8, 1.0)
		flash_tw.tween_property(enemy, "modulate", Color.WHITE, 0.12)
		# 「被弾（damaged）」アニメーションの再生（連打防止のインターバル付き）
		if _damaged_anim_timer <= 0.0:
			if _current_custom_anim != "attack" and _current_custom_anim != "skill" and has_enemy_animation("damaged"):
				play_enemy_animation("damaged")
				_damaged_anim_timer = DAMAGED_ANIM_INTERVAL

	if ehp <= 0 and not isdeadf:
		isdead()'''

new_block = '''func calchp(damage_to_enemy: float, damage_to_player: float) -> void:
	ehp = maxf(0.0, ehp - damage_to_enemy)
	myhp = clampf(myhp - damage_to_player, 0.0, myhpmax)
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0
	myhppar = myhp / myhpmax if myhpmax > 0 else 0.0

	if initial_spawn_count > 1 and ehpmax > 0.0:
		var alive_count = ceil(ehppar * initial_spawn_count)
		if alive_count < 1 and ehp > 0: alive_count = 1
		elif ehp <= 0: alive_count = 0
		while enemy_sprites.size() > alive_count:
			var popped = enemy_sprites.pop_back()
			if popped and is_instance_valid(popped):
				popped.queue_free()
		if enemy_sprites.size() > 0:
			enemy = enemy_sprites[0]
		else:
			enemy = null

	if damage_to_enemy > 0.0 and not isdeadf and enemy != null and is_instance_valid(enemy):
		var flash_tw = create_tween()
		enemy.modulate = Color(2.0, 1.8, 1.8, 1.0)
		flash_tw.tween_property(enemy, "modulate", Color.WHITE, 0.12)
		if _damaged_anim_timer <= 0.0:
			if _current_custom_anim != "attack" and _current_custom_anim != "skill" and has_enemy_animation("damaged"):
				play_enemy_animation("damaged")
				_damaged_anim_timer = DAMAGED_ANIM_INTERVAL

	if ehp <= 0 and not isdeadf:
		isdead()'''

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(old_block, new_block)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

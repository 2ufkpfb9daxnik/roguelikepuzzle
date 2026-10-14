import codecs

old_calchp = '''func calchp(damage_to_enemy: float, damage_to_player: float) -> void:
	myhp = clampf(myhp - damage_to_player, 0.0, myhpmax)
	myhppar = myhp / myhpmax if myhpmax > 0 else 0.0
	
	if damage_to_enemy > 0.0 and active_enemies.size() > 0:
		var d = damage_to_enemy
		var idx = 0
		while d > 0.0 and idx < active_enemies.size():
			var e_data = active_enemies[idx]
			if e_data["hp"] > 0:
				var dmg = min(e_data["hp"], d)
				e_data["hp"] -= dmg
				d -= dmg
				
				if is_instance_valid(e_data["sprite"]):
					var tw = create_tween()
					e_data["sprite"].modulate = Color(2.0, 1.8, 1.8, 1.0)
					tw.tween_property(e_data["sprite"], "modulate", Color.WHITE, 0.12)
					
				if e_data["hp"] <= 0:
					if is_instance_valid(e_data["sprite"]):
						var die_tw = create_tween()
						die_tw.tween_property(e_data["sprite"], "scale", Vector2.ZERO, 0.2)
						die_tw.tween_callback(e_data["sprite"].queue_free)
					if is_instance_valid(e_data["bar_bg"]): e_data["bar_bg"].queue_free()
					if is_instance_valid(e_data["bar_fg"]): e_data["bar_fg"].queue_free()
					if is_instance_valid(e_data["lbl"]): e_data["lbl"].queue_free()
					if is_instance_valid(e_data["hp_lbl"]): e_data["hp_lbl"].queue_free()
					active_enemies.remove_at(idx)
					continue
			idx += 1
			
		if active_enemies.size() > 0:
			enemy = active_enemies[0]["sprite"]
		else:
			enemy = null
			
		if _damaged_anim_timer <= 0.0 and has_enemy_animation("damaged") and _current_custom_anim != "attack" and _current_custom_anim != "skill":
			play_enemy_animation("damaged")
			_damaged_anim_timer = DAMAGED_ANIM_INTERVAL

	var sum_hp = 0.0
	for e in active_enemies: sum_hp += e["hp"]
	ehp = sum_hp
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0

	if ehp <= 0 and not isdeadf:
		isdead()'''

new_calchp = '''func calchp(damage_to_enemy: float, damage_to_player: float) -> void:
	myhp = clampf(myhp - damage_to_player, 0.0, myhpmax)
	myhppar = myhp / myhpmax if myhpmax > 0 else 0.0
	
	if damage_to_enemy > 0.0 and active_enemies.size() > 0:
		# ランダムな生存敵を1体選ぶ（貫通しない仕様）
		var target_idx = randi() % active_enemies.size()
		var e_data = active_enemies[target_idx]
		
		if e_data["hp"] > 0:
			e_data["hp"] -= damage_to_enemy
			
			if is_instance_valid(e_data["sprite"]):
				var spr = e_data["sprite"]
				if spr.has_meta("dmg_tw"):
					var old_tw = spr.get_meta("dmg_tw")
					if is_instance_valid(old_tw) and old_tw is Tween:
						old_tw.kill()
				var tw = create_tween()
				spr.set_meta("dmg_tw", tw)
				spr.modulate = Color(2.0, 1.8, 1.8, 1.0)
				tw.tween_property(spr, "modulate", Color.WHITE, 0.12)
				
			if e_data["hp"] <= 0:
				if is_instance_valid(e_data["sprite"]):
					var die_tw = create_tween()
					die_tw.tween_property(e_data["sprite"], "scale", Vector2.ZERO, 0.2)
					die_tw.tween_callback(e_data["sprite"].queue_free)
				if is_instance_valid(e_data["bar_bg"]): e_data["bar_bg"].queue_free()
				if is_instance_valid(e_data["bar_fg"]): e_data["bar_fg"].queue_free()
				if is_instance_valid(e_data["lbl"]): e_data["lbl"].queue_free()
				if is_instance_valid(e_data["hp_lbl"]): e_data["hp_lbl"].queue_free()
				active_enemies.remove_at(target_idx)
		
		if active_enemies.size() > 0:
			enemy = active_enemies[0]["sprite"]
		else:
			enemy = null
			
		if _damaged_anim_timer <= 0.0 and has_enemy_animation("damaged") and _current_custom_anim != "attack" and _current_custom_anim != "skill":
			play_enemy_animation("damaged")
			_damaged_anim_timer = DAMAGED_ANIM_INTERVAL

	var sum_hp = 0.0
	for e in active_enemies:
		if e["hp"] > 0: sum_hp += e["hp"]
	ehp = sum_hp
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0

	if ehp <= 0 and not isdeadf:
		isdead()'''

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(old_calchp, new_calchp)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

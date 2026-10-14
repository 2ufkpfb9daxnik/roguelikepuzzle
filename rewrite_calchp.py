import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if 'func calchp(' in line:
        start_idx = i
    if 'func calcgage(' in line:
        end_idx = i
        break

new_calchp = '''func calchp(damage_to_enemy: float, damage_to_player: float) -> void:
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
				
				# ヒット演出
				if is_instance_valid(e_data["sprite"]):
					var tw = create_tween()
					e_data["sprite"].modulate = Color(2.0, 1.8, 1.8, 1.0)
					tw.tween_property(e_data["sprite"], "modulate", Color.WHITE, 0.12)
					
				# 死んだ場合
				if e_data["hp"] <= 0:
					if is_instance_valid(e_data["sprite"]):
						var die_tw = create_tween()
						die_tw.tween_property(e_data["sprite"], "scale", Vector2.ZERO, 0.2)
						die_tw.tween_callback(e_data["sprite"].queue_free)
					if is_instance_valid(e_data["bar_bg"]): e_data["bar_bg"].queue_free()
					if is_instance_valid(e_data["bar_fg"]): e_data["bar_fg"].queue_free()
					if is_instance_valid(e_data["lbl"]): e_data["lbl"].queue_free()
					
					active_enemies.remove_at(idx)
					# indexは進めない
					continue
			idx += 1
			
		# 生きている敵が残っていればenemy更新
		if active_enemies.size() > 0:
			enemy = active_enemies[0]["sprite"]
		else:
			enemy = null
			
		if _damaged_anim_timer <= 0.0 and has_enemy_animation("damaged") and _current_custom_anim != "attack" and _current_custom_anim != "skill":
			play_enemy_animation("damaged")
			_damaged_anim_timer = DAMAGED_ANIM_INTERVAL

	# 全体HP再計算
	var sum_hp = 0.0
	for e in active_enemies: sum_hp += e["hp"]
	ehp = sum_hp
	ehppar = ehp / ehpmax if ehpmax > 0 else 0.0

	if ehp <= 0 and not isdeadf:
		isdead()
'''

new_lines = lines[:start_idx] + [new_calchp] + lines[end_idx:]

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.writelines(new_lines)

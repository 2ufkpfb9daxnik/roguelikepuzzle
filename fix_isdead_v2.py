import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old_isdead = '''func isdead() -> void:
	stop_enemy_animation()
	var gekiha = get_parent().get_node_or_null("gekiha")
	if gekiha: gekiha.play()
	if get_tree(): get_tree().call_group("enemy_skill_vfx", "queue_free")
	for bgm_name in ["fieldbgm", "bossbgm", "maoubgm"]:
		var b = get_node_or_null(bgm_name)
		if b and b.playing: b.stop()
	for e in active_enemies:
		if is_instance_valid(e["sprite"]):
			if e["sprite"].has_meta("active_skill_tween"):
				var tw = e["sprite"].get_meta("active_skill_tween")
				if is_instance_valid(tw) and tw is Tween: tw.kill()
			e["sprite"].queue_free()
		if is_instance_valid(e["bar_bg"]): e["bar_bg"].queue_free()
		if is_instance_valid(e["bar_fg"]): e["bar_fg"].queue_free()
		if is_instance_valid(e["lbl"]): e["lbl"].queue_free()
		if is_instance_valid(e["hp_lbl"]): e["hp_lbl"].queue_free()
	active_enemies.clear()
	enemy = null
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_clear_board_hazards"): pb._clear_board_hazards()
	if ehpbar: ehpbar.queue_free(); ehpbar = null
	if ehpbar1: ehpbar1.queue_free(); ehpbar1 = null
	var itemb = get_node_or_null("itemb")
	if itemb: itemb.visible = false
	var scorelbl = get_node_or_null("scorelbl")
	if scorelbl: scorelbl.visible = false
	isdeadf = true
	fevertime = false
	if pb: pb.set("isgameover", true)'''

new_isdead = '''func isdead() -> void:
	stop_enemy_animation()
	var gekiha = get_parent().get_node_or_null("gekiha")
	if gekiha: gekiha.play()
	
	if get_tree():
		get_tree().call_group("enemy_skill_vfx", "queue_free")
	
	for bgm_name in ["fieldbgm", "bossbgm", "maoubgm"]:
		var b = get_node_or_null(bgm_name)
		if b and b.playing:
			b.stop()
			
	for e in active_enemies:
		if is_instance_valid(e["sprite"]):
			if e["sprite"].has_meta("active_skill_tween"):
				var tw = e["sprite"].get_meta("active_skill_tween")
				if is_instance_valid(tw) and tw is Tween: tw.kill()
			e["sprite"].queue_free()
		if is_instance_valid(e["bar_bg"]): e["bar_bg"].queue_free()
		if is_instance_valid(e["bar_fg"]): e["bar_fg"].queue_free()
		if is_instance_valid(e["lbl"]): e["lbl"].queue_free()
		if is_instance_valid(e["hp_lbl"]): e["hp_lbl"].queue_free()
	active_enemies.clear()
	enemy = null
		
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_clear_board_hazards"):
		pb._clear_board_hazards()
		
	if ehpbar: ehpbar.queue_free(); ehpbar = null
	if ehpbar1: ehpbar1.queue_free(); ehpbar1 = null
	if enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl): enemy_hp_lbl.visible = false
	if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl): enemy_race_lbl.visible = false
	
	enemycount = 0
	isdeadf = true
	
	if (is_current_boss or stage_enemy == 5) and stage == 5:
		islastboss = true
		lastbossinterval = 0
	elif is_current_boss or stage_enemy == 5:
		isstageclear = true
		clearinterval = 0'''

content = content.replace(old_isdead, new_isdead)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

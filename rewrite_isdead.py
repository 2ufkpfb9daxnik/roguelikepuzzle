import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if 'func isdead() -> void:' in line:
        start_idx = i
    if 'func _set_buff_buttons_visible' in line:
        end_idx = i
        break

new_isdead = '''func isdead() -> void:
	stop_enemy_animation()
	var gekiha = get_parent().get_node_or_null("gekiha")
	if gekiha: gekiha.play()
	
	if get_tree():
		get_tree().call_group("enemy_skill_vfx", "queue_free")
	
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
	active_enemies.clear()
	enemy = null
	
	var pb = _get_puzzle_board()
	if pb and pb.has_method("_clear_board_hazards"):
		pb._clear_board_hazards()
		
	# 既存の全体のHPバーがあれば消す（念のため）
	if ehpbar: ehpbar.queue_free(); ehpbar = null
	if ehpbar1: ehpbar1.queue_free(); ehpbar1 = null
	
	var itemb = get_node_or_null("itemb")
	if itemb: itemb.visible = false
	var scorelbl = get_node_or_null("scorelbl")
	if scorelbl: scorelbl.visible = false
	
	isdeadf = true
	fevertime = false
	
	# パズルボードに死亡フラグを同期
	if pb: pb.set("isgameover", true)
'''

new_lines = lines[:start_idx] + [new_isdead] + lines[end_idx:]

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.writelines(new_lines)

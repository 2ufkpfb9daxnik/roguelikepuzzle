import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

def replace_func(content, func_name, new_body):
    pattern = r'(func ' + func_name + r'\b.*?\n)(?:(?:[ \t].*\n)|(?:^\s*\n))*'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[:match.start()] + new_body + '\n' + content[match.end():]
    return content

new_displayhp = '''func displayhp() -> void:
	for e in active_enemies:
		var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
		var target_w = p * 100.0
		
		if is_instance_valid(e["bar_green"]):
			e["bar_green"].size = Vector2(target_w, 10.0)
			
		if is_instance_valid(e["bar_red"]):
			var cur_w = e["bar_red"].size.x
			if cur_w > target_w:
				e["bar_red"].size.x = max(target_w, cur_w - 0.75)
			else:
				e["bar_red"].size.x = target_w
				
		if is_instance_valid(e["hp_lbl"]):
			var cur_hp_int = int(e["hp"])
			var last_hp = e.get("last_hp_int", -1)
			if cur_hp_int != last_hp:
				e["last_hp_int"] = cur_hp_int
				e["hp_lbl"].text = "[center][color=#FFFFFF]" + str(cur_hp_int) + " / " + str(int(e["max_hp"])) + "[/color][/center]"
				
	if enemy_race_lbl != null and is_instance_valid(enemy_race_lbl):
		enemy_race_lbl.visible = false
	if enemy_hp_lbl != null and is_instance_valid(enemy_hp_lbl):
		enemy_hp_lbl.visible = false
	if ehpbar != null and is_instance_valid(ehpbar):
		ehpbar.visible = false
	if ehpbar1 != null and is_instance_valid(ehpbar1):
		ehpbar1.visible = false

	# プレイヤーHPの更新処理（復元）
	if _cached_hp_bar == null or not is_instance_valid(_cached_hp_bar):
		_cached_hp_bar = get_parent().get_node_or_null("ScoreManager/hpbar1") as ColorRect if get_parent() else null
	if _cached_hp_bar:
		_cached_hp_bar.size = Vector2(min(int(myhppar * 725.0), 725), 26.0)
		
		if player_hp_lbl == null or not is_instance_valid(player_hp_lbl):
			player_hp_lbl = RichTextLabel.new()
			player_hp_lbl.bbcode_enabled = true
			player_hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			player_hp_lbl.fit_content = false
			player_hp_lbl.scroll_active = false
			player_hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			player_hp_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			player_hp_lbl.add_theme_constant_override("outline_size", 5)
			player_hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			player_hp_lbl.add_theme_font_size_override("normal_font_size", 16)
			player_hp_lbl.add_theme_font_size_override("bold_font_size", 16)
			player_hp_lbl.position = Vector2(1190, 412)
			player_hp_lbl.size = Vector2(725, 26)
			player_hp_lbl.z_index = 10
			var sm_node = _get_score_manager()
			if sm_node:
				sm_node.add_child(player_hp_lbl)
			else:
				add_child(player_hp_lbl)
		
		var cur_myhp_int: int = int(myhp)
		var cur_myhpmax_int: int = int(myhpmax)
		if cur_myhp_int != _last_myhp or cur_myhpmax_int != _last_myhpmax:
			_last_myhp = cur_myhp_int
			_last_myhpmax = cur_myhpmax_int
			
			var s_hp = str(absi(cur_myhp_int))
			var res_hp = ""
			for i in range(s_hp.length() - 1, -1, -1):
				res_hp = s_hp[i] + res_hp
				if (s_hp.length() - i) % 3 == 0 and i != 0: res_hp = "," + res_hp
				
			var s_max = str(absi(cur_myhpmax_int))
			var res_max = ""
			for i in range(s_max.length() - 1, -1, -1):
				res_max = s_max[i] + res_max
				if (s_max.length() - i) % 3 == 0 and i != 0: res_max = "," + res_max
				
			player_hp_lbl.text = "[center][b][color=#FFFF00]PLAYER HP[/color] [color=#FFFFFF]%s / %s[/color][/b][/center]" % [res_hp, res_max]
'''

content = replace_func(content, 'displayhp', new_displayhp)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

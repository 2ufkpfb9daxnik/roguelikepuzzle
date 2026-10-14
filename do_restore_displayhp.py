import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old_displayhp = '''func displayhp() -> void:
	for e in active_enemies:
		if is_instance_valid(e["bar_fg"]):
			var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
			e["bar_fg"].size = Vector2(p * 100.0, 10.0)
		if is_instance_valid(e["hp_lbl"]):
			var cur_hp_int = int(e["hp"])
			var last_hp = e.get("last_hp_int", -1)
			if cur_hp_int != last_hp:
				e["last_hp_int"] = cur_hp_int
				e["hp_lbl"].text = "[center][color=#FFFFFF]" + str(cur_hp_int) + "[/color][/center]"
	if ehpbar1 != null and is_instance_valid(ehpbar1):
		ehpbar1.size = Vector2(ehppar * 150.0, 10.0)'''

new_displayhp = '''func displayhp() -> void:
	for e in active_enemies:
		if is_instance_valid(e["bar_fg"]):
			var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
			e["bar_fg"].size = Vector2(p * 100.0, 10.0)
		if is_instance_valid(e["hp_lbl"]):
			var cur_hp_int = int(e["hp"])
			var last_hp = e.get("last_hp_int", -1)
			if cur_hp_int != last_hp:
				e["last_hp_int"] = cur_hp_int
				e["hp_lbl"].text = "[center][color=#FFFFFF]" + str(cur_hp_int) + "[/color][/center]"

	if ehpbar1 != null and is_instance_valid(ehpbar1):
		ehpbar1.size = Vector2(ehppar * 150.0, 10.0)
		
		# 敵種族・名称ラベル（全体HPバー上部）の復元
		if enemy_race_lbl == null or not is_instance_valid(enemy_race_lbl):
			enemy_race_lbl = RichTextLabel.new()
			enemy_race_lbl.bbcode_enabled = true
			enemy_race_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_race_lbl.fit_content = false
			enemy_race_lbl.scroll_active = false
			enemy_race_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			enemy_race_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			enemy_race_lbl.add_theme_constant_override("outline_size", 8)
			enemy_race_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			enemy_race_lbl.add_theme_font_size_override("normal_font_size", 18)
			enemy_race_lbl.add_theme_font_size_override("bold_font_size", 18)
			enemy_race_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			enemy_race_lbl.position = Vector2(1250, 95)
			enemy_race_lbl.size = Vector2(600, 28)
			enemy_race_lbl.z_index = 13
			add_child(enemy_race_lbl)
			
		var is_boss_enemy: bool = is_current_boss or (stage_enemy == 5)
		if active_enemies.size() > 0:
			var target_ename = active_enemies[0]["key"]
			var multi_tag = "たち" if active_enemies.size() > 1 else ""
			if target_ename != _last_displayed_enemy_key or is_boss_enemy != _last_is_boss:
				_last_displayed_enemy_key = target_ename
				_last_is_boss = is_boss_enemy
				var sp_data = ENEMY_SPECIES.get(target_ename, {"name": "モンスター", "element": "無属性", "race": "無属性", "color": "#FFD700"})
				var boss_tag = "[color=#FF1744]☠ BOSS ☠[/color] " if is_boss_enemy else ""
				var name_str: String = sp_data["name"] + multi_tag
				var font_sz: int = 15 if name_str.length() > 10 else 18
				enemy_race_lbl.add_theme_font_size_override("normal_font_size", font_sz)
				enemy_race_lbl.add_theme_font_size_override("bold_font_size", font_sz)
				var elem_raw = sp_data.get("element", sp_data.get("race", "無属性"))
				var elem_name = "/".join(elem_raw) if typeof(elem_raw) == TYPE_ARRAY else elem_raw
				enemy_race_lbl.text = "[center][b]%s[color=%s]【%s】[/color] [color=#FFFFFF]%s[/color][/b][/center]" % [boss_tag, sp_data["color"], elem_name, name_str]
		else:
			enemy_race_lbl.text = ""
		enemy_race_lbl.visible = true

		if enemy_hp_lbl == null or not is_instance_valid(enemy_hp_lbl):
			enemy_hp_lbl = RichTextLabel.new()
			enemy_hp_lbl.bbcode_enabled = true
			enemy_hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			enemy_hp_lbl.fit_content = false
			enemy_hp_lbl.scroll_active = false
			enemy_hp_lbl.add_theme_font_override("normal_font", CUSTOM_FONT)
			enemy_hp_lbl.add_theme_font_override("bold_font", CUSTOM_FONT)
			enemy_hp_lbl.add_theme_constant_override("outline_size", 6)
			enemy_hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			enemy_hp_lbl.add_theme_font_size_override("normal_font_size", 16)
			enemy_hp_lbl.add_theme_font_size_override("bold_font_size", 16)
			enemy_hp_lbl.position = Vector2(1475, 122)
			enemy_hp_lbl.size = Vector2(250, 22)
			enemy_hp_lbl.z_index = 12
			add_child(enemy_hp_lbl)
			
		var cur_ehp_int: int = int(ehp)
		var cur_ehpmax_int: int = int(ehpmax)
		if cur_ehp_int != _last_ehp or cur_ehpmax_int != _last_ehpmax:
			_last_ehp = cur_ehp_int
			_last_ehpmax = cur_ehpmax_int
			enemy_hp_lbl.text = "[right][color=#FFFFFF]%d / %d[/color][/right]" % [cur_ehp_int, cur_ehpmax_int]
		enemy_hp_lbl.visible = true'''
content = content.replace(old_displayhp, new_displayhp)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

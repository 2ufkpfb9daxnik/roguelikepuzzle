import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old_displayhp = '''func displayhp() -> void:
	for e in active_enemies:
		if is_instance_valid(e["bar_fg"]):
			var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
			e["bar_fg"].size = Vector2(p * 100.0, 10.0)
		if is_instance_valid(e["hp_lbl"]):
			e["hp_lbl"].text = "[center][color=#FFFFFF]" + str(int(e["hp"])) + "[/color][/center]"
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
		ehpbar1.size = Vector2(ehppar * 150.0, 10.0)'''

content = content.replace(old_displayhp, new_displayhp)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

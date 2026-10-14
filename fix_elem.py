import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old_elem = '''func get_current_enemy_element() -> String:
	var sp_data = ENEMY_SPECIES.get(current_enemy_key, {})
	return sp_data.get("element", sp_data.get("race", "無属性"))'''

new_elem = '''func get_current_enemy_element() -> String:
	var sp_data = ENEMY_SPECIES.get(current_enemy_key, {})
	var elem = sp_data.get("element", sp_data.get("race", "無属性"))
	if typeof(elem) == TYPE_ARRAY:
		if elem.size() > 0:
			return elem[randi() % elem.size()]
		else:
			return "無属性"
	return str(elem)'''

content = content.replace(old_elem, new_elem)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

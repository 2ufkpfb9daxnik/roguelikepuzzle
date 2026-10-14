import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

old_code = '''	if anim_name == "attack":
		_rush_tween = create_tween()
		var first = true

	for e in active_enemies:'''

new_code = '''	var first = true
	if anim_name == "attack":
		_rush_tween = create_tween()

	for e in active_enemies:'''

content = content.replace(old_code, new_code)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

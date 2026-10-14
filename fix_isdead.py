import codecs

old_block = '''	if enemy:
		if enemy.has_meta("active_skill_tween"):
			var tw = enemy.get_meta("active_skill_tween")
			if is_instance_valid(tw) and tw is Tween:
				tw.kill()
		enemy.queue_free()
		enemy = null'''

new_block = '''	for en in enemy_sprites:
		if is_instance_valid(en):
			if en.has_meta("active_skill_tween"):
				var tw = en.get_meta("active_skill_tween")
				if is_instance_valid(tw) and tw is Tween:
					tw.kill()
			en.queue_free()
	enemy_sprites.clear()
	enemy = null'''

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(old_block, new_block)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

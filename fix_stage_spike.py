import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

# Replace make_enemy inside _step_process
old_make = '	make_enemy(stage_enemy == 5)'
new_make = '''	var _t_me = Time.get_ticks_usec()
	make_enemy(stage_enemy == 5)
	var _d_me = Time.get_ticks_usec() - _t_me
	if _d_me > 1000: print("[SPIKE] make_enemy took %.2f ms" % (_d_me / 1000.0))'''

content = content.replace(old_make, new_make)

# Also check resourceLoader inside make_enemy
old_load = '			tex = ResourceLoader.load_threaded_get(path) as Texture2D'
new_load = '''			var _t_load = Time.get_ticks_usec()
			tex = ResourceLoader.load_threaded_get(path) as Texture2D
			var _d_load = Time.get_ticks_usec() - _t_load
			if _d_load > 1000: print("[SPIKE] load_threaded_get blocked for %.2f ms" % (_d_load / 1000.0))'''

content = content.replace(old_load, new_load)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")

import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

old_func = '''func _apply_enemy_elemental_skill_effect(elem: String, is_boss: bool) -> Array[Vector2]:
	match elem:
		"水":
			return _cast_enemy_water_skill(is_boss, false)
		"氷":
			_cast_enemy_ice_skill(is_boss, false)
		"風":
			_cast_enemy_wind_skill(is_boss, false)
		"木":
			_cast_enemy_wood_skill(is_boss, false)
		"地":
			_cast_enemy_earth_skill(is_boss, false)
		"雷":
			_cast_enemy_lightning_skill(is_boss, false)
		"闇":
			_cast_enemy_dark_skill(is_boss, false)
		"光":
			_cast_enemy_light_skill(is_boss, false)
		"火":
			_cast_enemy_fire_skill(is_boss, false)
		_:
			_cast_enemy_earth_skill(is_boss, false)'''

new_func = '''func _apply_enemy_elemental_skill_effect(elem: String, is_boss: bool) -> Array[Vector2]:
	match elem:
		"水":
			return _cast_enemy_water_skill(is_boss, false)
		"氷":
			return _cast_enemy_ice_skill(is_boss, false)
		"風":
			return _cast_enemy_wind_skill(is_boss, false)
		"木":
			return _cast_enemy_wood_skill(is_boss, false)
		"地":
			return _cast_enemy_earth_skill(is_boss, false)
		"雷":
			return _cast_enemy_lightning_skill(is_boss, false)
		"闇":
			return _cast_enemy_dark_skill(is_boss, false)
		"光":
			return _cast_enemy_light_skill(is_boss, false)
		"火":
			return _cast_enemy_fire_skill(is_boss, false)
		_:
			return _cast_enemy_earth_skill(is_boss, false)'''

content = content.replace(old_func, new_func)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

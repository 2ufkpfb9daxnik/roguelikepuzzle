import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# Replace return types of _cast_enemy_*_skill from -> void to -> Array[Vector2]
content = re.sub(r'(func _cast_enemy_[a-z_]+_skill\(is_boss: bool, show_banner: bool = true\)) -> void:', r'\1 -> Array[Vector2]:\n\tvar _targets: Array[Vector2] = []', content)

# Modify each _cast_enemy_*_skill to populate and return _targets
def patch_water(m):
    return m.group(0).replace('_spawn_aqua_splash_effect(get_cell_position(p.x, p.y), 1)', '_spawn_aqua_splash_effect(get_cell_position(p.x, p.y), 1)\n\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_redraw_board_effects()', '_redraw_board_effects()\n\treturn _targets')
content = re.sub(r'func _cast_enemy_water_skill.*?_redraw_board_effects\(\)', patch_water, content, flags=re.S)

def patch_ice(m):
    return m.group(0).replace('_spawn_ice_break_effect(get_cell_position(p.x, p.y))', '_spawn_ice_break_effect(get_cell_position(p.x, p.y))\n\t\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_freeze_connected_water(p, ice_dur)', '_freeze_connected_water(p, ice_dur)\n\t\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_redraw_board_effects()', '_redraw_board_effects()\n\treturn _targets')
content = re.sub(r'func _cast_enemy_ice_skill.*?_redraw_board_effects\(\)', patch_ice, content, flags=re.S)

def patch_wood(m):
    return m.group(0).replace('_spawn_growth_effect(get_cell_position(p.x, p.y), st_val)', '_spawn_growth_effect(get_cell_position(p.x, p.y), st_val)\n\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_execute_wood_hp_drain(sm, newly_planted, stage_scale)', '_execute_wood_hp_drain(sm, newly_planted, stage_scale)\n\treturn _targets')
content = re.sub(r'func _cast_enemy_wood_skill.*?_execute_wood_hp_drain\(sm, newly_planted, stage_scale\)', patch_wood, content, flags=re.S)

def patch_earth(m):
    return m.group(0).replace('_spawn_stone_break_effect(get_cell_position(p.x, p.y))', '_spawn_stone_break_effect(get_cell_position(p.x, p.y))\n\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_redraw_board_effects()', '_redraw_board_effects()\n\treturn _targets')
content = re.sub(r'func _cast_enemy_earth_skill.*?_redraw_board_effects\(\)', patch_earth, content, flags=re.S)

def patch_lightning(m):
    return m.group(0).replace('_spawn_vertical_lightning_bolt(pos, delay)', '_spawn_vertical_lightning_bolt(pos, delay)\n\t\t_targets.append(pos)').replace('			_redraw_board_effects()\n		)', '			_redraw_board_effects()\n		)\n\treturn _targets')
content = re.sub(r'func _cast_enemy_lightning_skill.*?_redraw_board_effects\(\)\n\t\t\)', patch_lightning, content, flags=re.S)

def patch_dark(m):
    return m.group(0).replace('grid_cursed[p.x][p.y] = true', 'grid_cursed[p.x][p.y] = true\n\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_redraw_board_effects()', '_redraw_board_effects()\n\treturn _targets')
content = re.sub(r'func _cast_enemy_dark_skill.*?_redraw_board_effects\(\)', patch_dark, content, flags=re.S)

def patch_light(m):
    return m.group(0).replace('_spawn_gold_shatter_effect(get_cell_position(p.x, p.y))', '_spawn_gold_shatter_effect(get_cell_position(p.x, p.y))\n\t\t_targets.append(get_cell_position(p.x, p.y))').replace('grid_gold_statue[p2.x][p2.y] = statue_dur', 'grid_gold_statue[p2.x][p2.y] = statue_dur\n\t\t\t_targets.append(get_cell_position(p2.x, p2.y))').replace('_redraw_board_effects()', '_redraw_board_effects()\n\treturn _targets')
content = re.sub(r'func _cast_enemy_light_skill.*?_redraw_board_effects\(\)', patch_light, content, flags=re.S)

def patch_fire(m):
    return m.group(0).replace('grid_fire[p.x][p.y] = fire_dur', 'grid_fire[p.x][p.y] = fire_dur\n\t\t_targets.append(get_cell_position(p.x, p.y))').replace('_redraw_board_effects()', '_redraw_board_effects()\n\treturn _targets')
content = re.sub(r'func _cast_enemy_fire_skill.*?_redraw_board_effects\(\)', patch_fire, content, flags=re.S)

def patch_wind(m):
    return m.group(0).replace('_spawn_tornado_effect(pos)', '_spawn_tornado_effect(pos)\n\t\t_targets.append(pos)').replace('			_redraw_board_effects()\n		)', '			_redraw_board_effects()\n		)\n\treturn _targets')
content = re.sub(r'func _cast_enemy_wind_skill.*?_redraw_board_effects\(\)\n\t\t\)', patch_wind, content, flags=re.S)

content = content.replace('func _apply_enemy_elemental_skill_effect(elem: String, is_boss: bool) -> void:', 'func _apply_enemy_elemental_skill_effect(elem: String, is_boss: bool) -> Array[Vector2]:')
content = re.sub(r'(match elem:[\s\S]*?)_cast_enemy_([a-z_]+)_skill\(is_boss, false\)', r'\1return _cast_enemy_\2_skill(is_boss, false)', content)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

print("SUCCESS")

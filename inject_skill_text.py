import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    # Water
    if 'grid_water[p.x][p.y] = true' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(p.x, p.y), "水没", Color(0.2, 0.8, 1.0))'
    
    # Ice
    elif 'grid_ice[p.x][p.y] = ice_dur' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(p.x, p.y), "氷結", Color(0.7, 0.9, 1.0))'
        
    # Wind (inside active_wind_tornadoes.append...)
    elif '_targets.append(get_cell_position(GRID_ROWS / 2, col))' in lines[i] and 'func _cast_enemy_wind_skill' in ''.join(lines[i-20:i]):
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(7, col), "浄化", Color(0.5, 1.0, 0.8))'
        
    # Wood (plant)
    elif '_plant_enemy_seed(p)' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(p.x, p.y), "茨", Color(0.4, 0.9, 0.3))'
        
    # Earth (stones)
    elif 'grid_stones[p.x][p.y] = stone_dur' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(p.x, p.y), "石化", Color(0.7, 0.7, 0.6))'
        
    # Dark (curse)
    elif 'grid_cursed[p.x][p.y] = true' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(p.x, p.y), "呪い", Color(0.8, 0.3, 0.9))'
        
    # Light (gold statue)
    elif 'grid_gold_statue[p.x][p.y] = statue_dur' in lines[i] or 'grid_gold_statue[p2.x][p2.y] = statue_dur' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        var_name = 'p.x, p.y' if 'p.x' in lines[i] else 'p2.x, p2.y'
        lines[i] = lines[i] + '\n' + '\t'*tabs + f'_spawn_floating_text(get_cell_position({var_name}), "黄金化", Color(1.0, 0.9, 0.2))'
        
    # Fire (fire)
    elif 'grid_fire[p.x][p.y] = ' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(p.x, p.y), "炎上", Color(1.0, 0.4, 0.1))'
        
    # Lightning (electrified)
    elif 'grid_electrified[r][c] = true' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = lines[i] + '\n' + '\t'*tabs + '_spawn_floating_text(get_cell_position(r, c), "帯電", Color(0.9, 1.0, 0.2))'
        
with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

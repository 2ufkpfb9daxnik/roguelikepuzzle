import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'var fly_sprite: Sprite2D = Sprite2D.new()' in line:
        lines[i] = line.replace('Sprite2D.new()', '_get_sprite_from_pool()')
        # Also remove add_child since get_sprite_from_pool already adds it
        # I need to find the add_child(fly_sprite)
    elif 'var s: Sprite2D = Sprite2D.new()' in line:
        lines[i] = line.replace('Sprite2D.new()', '_get_sprite_from_pool()')
    elif 'add_child(fly_sprite)' in line:
        lines[i] = ''
    elif 'add_child(s)' in line:
        # Check context, only remove if inside spawn_projectiles
        if i > 4000:
            lines[i] = ''

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.writelines(lines)
print("SUCCESS")

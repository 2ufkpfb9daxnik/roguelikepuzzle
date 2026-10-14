import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
end = -1
for i, line in enumerate(lines):
    if 'func _spawn_ally_elemental_vfx' in line:
        start = i
        break

if start != -1:
    end = start
    while end < len(lines):
        if 'func _add_element_mark_to_sprite' in lines[end]:
            break
        end += 1
    
    del lines[start:end]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

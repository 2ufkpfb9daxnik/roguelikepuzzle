import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

text = text.replace('_spawn_ally_elemental_vfx(spr.global_position, el, delay)', '_spawn_ally_elemental_vfx(spr.global_position, el)')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")

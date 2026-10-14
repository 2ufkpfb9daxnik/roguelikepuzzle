import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('sm.stage_enemy == 3', 'sm.stage_enemy == 5')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

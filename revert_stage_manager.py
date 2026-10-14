import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('stage_enemy == 3', 'stage_enemy == 5')
content = content.replace('stage_enemy = 3', 'stage_enemy = 5')
content = content.replace('stage_enemy >= 2', 'stage_enemy >= 4')

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

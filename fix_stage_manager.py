import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('stage_enemy == 5', 'stage_enemy == 3')
content = content.replace('stage_enemy = 5', 'stage_enemy = 3')
content = content.replace('stage_enemy >= 4', 'stage_enemy >= 2')

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

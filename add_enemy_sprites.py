import codecs
with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace(
    'var enemy: Sprite2D = null',
    'var enemy: Sprite2D = null\nvar enemy_sprites: Array = []\nvar initial_spawn_count: int = 1'
)

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.write(content)

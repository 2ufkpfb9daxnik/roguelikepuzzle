import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('item["node"].queue_free()', '_return_sprite_to_pool(item["node"])')
# for the one-liners:
content = content.replace('if is_instance_valid(item["node"]): item["node"].queue_free()', 'if is_instance_valid(item["node"]): _return_sprite_to_pool(item["node"])')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

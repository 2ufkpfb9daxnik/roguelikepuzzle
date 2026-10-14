import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('var target_global = to_global(target_local)', 'var target_global = to_global(target_local)\n\t\tvar target_root_local = root_node.to_local(target_global)')
content = content.replace('beam_node.target_pos = target_global', 'beam_node.target_pos = target_root_local')
content = content.replace('burst_node.position = target_global', 'burst_node.position = target_root_local')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

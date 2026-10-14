import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

content = content.replace('root_node.add_child(chant_node)', 'var vc = root_node.get_node_or_null("VFXContainer")\n\tif vc: vc.add_child(chant_node)\n\telse: root_node.add_child(chant_node)')
content = content.replace('root_node.add_child(beam_node)', 'var vc = root_node.get_node_or_null("VFXContainer")\n\t\tif vc: vc.add_child(beam_node)\n\t\telse: root_node.add_child(beam_node)')
content = content.replace('root_node.add_child(burst_node)', 'var vc = root_node.get_node_or_null("VFXContainer")\n\t\t\tif vc: vc.add_child(burst_node)\n\t\t\telse: root_node.add_child(burst_node)')

# Also replace skill_vfx_node.gd call_group removal!
with codecs.open('skill_vfx_node.gd', 'r', 'utf-8') as f:
    vfx_content = f.read()
vfx_content = vfx_content.replace('add_to_group("enemy_skill_vfx")', '# add_to_group("enemy_skill_vfx")')
with codecs.open('skill_vfx_node.gd', 'w', 'utf-8') as f:
    f.write(vfx_content)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)
print("SUCCESS")

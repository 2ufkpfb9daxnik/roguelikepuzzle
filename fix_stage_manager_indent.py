import codecs
import re

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'for child in _vfx_container.get_children():' in line and not line.startswith('\t\t\t'):
        lines[i] = '\t\t\tfor child in _vfx_container.get_children():\n'
    if 'child.queue_free()' in line and lines[i-1].strip() == 'for child in _vfx_container.get_children():':
        lines[i] = '\t\t\t\tchild.queue_free()\n'

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.writelines(lines)
print("SUCCESS")

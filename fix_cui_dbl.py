import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

lines.pop(76)

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

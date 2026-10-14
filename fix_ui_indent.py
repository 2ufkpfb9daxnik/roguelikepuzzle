import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if '\t\tlbl.set_meta("tw", tw)' in lines[i]:
        lines[i] = '\tlbl.set_meta("tw", tw)'

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

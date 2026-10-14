import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

# Convert spaces to tabs in the function body
start = -1
for i in range(len(lines)):
    if 'func _show_player_damage' in lines[i]:
        start = i
        break
for i in range(start+1, start+50):
    if lines[i].startswith('func '): break
    # Count spaces at beginning
    s = lines[i]
    spaces = len(s) - len(s.lstrip(' '))
    if spaces > 0:
        tabs = spaces // 4
        lines[i] = ('\t' * tabs) + s.lstrip(' ')

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

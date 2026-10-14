import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'typeof(event.target) == TYPE_STRING and event.target == "ally":' in lines[i] and '_show_player_damage' in lines[i+1]:
        lines[i+1] = '\t\t\t_show_player_damage(event.amount, event.get("element", ""), event.get("blocked_amount", 0.0))'
        break

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

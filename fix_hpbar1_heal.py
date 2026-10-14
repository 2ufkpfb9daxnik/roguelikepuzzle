import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _show_player_heal' in lines[i]:
        for j in range(i, len(lines)):
            if 'var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect' in lines[j]:
                # find the second one in this function
                for k in range(j+1, len(lines)):
                    if 'func _show' in lines[k]: break
                    if 'var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect' in lines[k]:
                        lines[k] = '\t\t# hpbar1 already declared'
                        break
                break
        break

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

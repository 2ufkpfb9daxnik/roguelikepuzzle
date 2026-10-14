import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect' in lines[i]:
        # We will change the second declaration to just use it if already there.
        # But wait, in the same function!
        for j in range(i+1, len(lines)):
            if 'var hpbar1 = get_node_or_null("../../ScoreManager/hpbar1") as ColorRect' in lines[j]:
                lines[j] = '\t\t# hpbar1 already declared'
                break
        break

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

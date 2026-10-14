import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'lbl.text = str(int(amount))' in lines[i]:
        lines[i] = lines[i].replace('str(int(amount))', 'str(int(amount))')
    if 'lbl.text = "+" + str(int(amount))' in lines[i]:
        pass

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

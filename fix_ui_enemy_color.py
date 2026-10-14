import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _show_enemy_damage' in lines[i]:
        for j in range(i, i+20):
            if 'if is_crit: c = Color(1.0, 0.8, 0.2)' in lines[j]:
                lines[j] = '\tif ELEMENT_COLORS.has(element):\n\t\tc = ELEMENT_COLORS[element]\n\tif is_crit: c = Color(1.0, 0.8, 0.2)'
                break
        break

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

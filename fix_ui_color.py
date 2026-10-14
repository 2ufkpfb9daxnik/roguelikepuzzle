import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

start = -1
for i in range(len(lines)):
    if 'func _show_player_damage(amount: float) -> void:' in lines[i]:
        start = i
        break

if start != -1:
    # Need to change signature to accept element
    replacement = '''const ELEMENT_COLORS = {
	"fire": Color(1.0, 0.4, 0.2),
	"water": Color(0.3, 0.6, 1.0),
	"wind": Color(0.4, 0.9, 0.4),
	"thunder": Color(0.9, 0.9, 0.2),
	"ice": Color(0.6, 0.9, 1.0),
	"light": Color(1.0, 0.9, 0.6),
	"dark": Color(0.7, 0.3, 0.9)
}

func _show_player_damage(amount: float, element: String = "") -> void:
	if amount <= 0: return
	var lbl = _get_free_label()
	lbl.text = str(int(amount))
	
	var c = Color(1.0, 0.3, 0.3)
	if ELEMENT_COLORS.has(element):
		c = ELEMENT_COLORS[element]
		
	lbl.add_theme_color_override("font_color", c)
	lbl.add_theme_font_size_override("font_size", 56)'''
	
    for i in range(start, start + 15):
        if 'lbl.add_theme_font_size_override("font_size", 56)' in lines[i]:
            lines = lines[:start] + replacement.split('\n') + lines[i+1:]
            break

for i in range(len(lines)):
    if '_show_player_damage(event.amount)' in lines[i]:
        lines[i] = lines[i].replace('_show_player_damage(event.amount)', '_show_player_damage(event.amount, event.get("element", ""))')
        break

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

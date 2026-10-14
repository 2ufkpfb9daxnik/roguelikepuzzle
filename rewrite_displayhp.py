import codecs

with codecs.open('stage_manager.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if 'func displayhp() -> void:' in line:
        start_idx = i
    if 'func _format_comma' in line:
        end_idx = i
        break

new_displayhp = '''func displayhp() -> void:
	for e in active_enemies:
		if is_instance_valid(e["bar_fg"]):
			var p = e["hp"] / e["max_hp"] if e["max_hp"] > 0 else 0
			e["bar_fg"].size = Vector2(p * 100.0, 10.0)
'''

new_lines = lines[:start_idx] + [new_displayhp] + lines[end_idx:]

with codecs.open('stage_manager.gd', 'w', 'utf-8') as f:
    f.writelines(new_lines)

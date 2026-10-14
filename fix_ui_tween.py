import codecs

with codecs.open('combat_ui_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _get_free_label() -> Label:' in lines[i]:
        insert = '''	var fallback = popup_pool[0]
	for lbl in popup_pool:
		if not lbl.visible:
			fallback = lbl
			break
	if fallback.has_meta("tw"):
		var old_tw = fallback.get_meta("tw")
		if is_instance_valid(old_tw): old_tw.kill()
	return fallback'''
        lines = lines[:i+1] + insert.split('\n') + lines[i+6:]
        break

for i in range(len(lines)):
    if 'var tw = create_tween()' in lines[i]:
        lines.insert(i+1, '\t\tlbl.set_meta("tw", tw)')

with codecs.open('combat_ui_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

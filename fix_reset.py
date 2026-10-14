import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _reset_turn' in lines[i]:
        insert_code = '''	turn_skill_log.clear()
	var _sm_for_reset = _get_score_manager()
	if _sm_for_reset and _sm_for_reset.has_method("reset_turn_elements"):
		_sm_for_reset.reset_turn_elements()'''
        lines.insert(i+1, insert_code)
        break

# And delete it from interval == 0
to_delete_start = -1
for i in range(len(lines)):
    if 'if interval == 0:' in lines[i] and 'turn_skill_log.clear()' in lines[i+1]:
        to_delete_start = i + 1
        break

if to_delete_start != -1:
    del lines[to_delete_start:to_delete_start+4]

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

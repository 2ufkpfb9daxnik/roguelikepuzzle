import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'sm.calcscore(copy_matched, grid_att)' in lines[i]:
        lines[i] = '\t\tsm.calcscore(copy_matched, grid_att, grid_element)'
        break

for i in range(len(lines)):
    if 'turn_skill_log.clear()' in lines[i]:
        insert_code = '''			var _sm_for_reset = _get_score_manager()
			if _sm_for_reset and _sm_for_reset.has_method("reset_turn_elements"):
				_sm_for_reset.reset_turn_elements()'''
        lines.insert(i+1, insert_code)
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

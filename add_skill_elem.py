import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'turn_skill_log.append({' in lines[i]:
        insert_code = '''					var sm_for_log = _get_score_manager()
					if sm_for_log and sm_for_log.has_method("add_turn_element"):
						var e_enum = ElementDataScript.get_element_from_name(s_elem)
						if e_enum != ElementDataScript.Element.NONE:
							sm_for_log.add_turn_element(e_enum, 1)'''
        lines.insert(i, insert_code)
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

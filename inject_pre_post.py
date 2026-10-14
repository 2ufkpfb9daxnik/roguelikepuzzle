import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(1130, 1150):
    if 'match item_type:' in lines[i]:
        lines.insert(i, '\t\tvar pre_matched = ismatched.duplicate(true)')
        break

for i in range(1150, 1200):
    if '\t\t\t_:' in lines[i]:
        # skip to end of match
        for j in range(i, i+15):
            if '\t\t\t\t_trigger_bomb(b.x, b.y, pos, queue, exploded_items)' in lines[j]:
                post_check = '''
		var e_enum = ElementDataScript.get_element_from_name(s_elem)
		if e_enum != ElementDataScript.Element.NONE and grid_element.size() == GRID_ROWS:
			for nr in range(GRID_ROWS):
				for nc in range(GRID_COLUMNS):
					if ismatched[nr][nc] and not pre_matched[nr][nc]:
						if grid_i[nr][nc] != -1:
							grid_element[nr][nc] = e_enum
'''
                lines.insert(j+1, post_check)
                break
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

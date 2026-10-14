import codecs

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if '_spawn_score_popup(component_cells, att_type, earned_score, count, is_fever)' in lines[i]:
        count_code = '''
				for cell in component_cells:
					if grid_element.size() > cell.x and grid_element[cell.x].size() > cell.y:
						var el = grid_element[cell.x][cell.y]
						if el != 0:
							turn_element_counts[el] = turn_element_counts.get(el, 0) + 1
				update_elem_labels()
'''
        lines.insert(i, count_code)
        break

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

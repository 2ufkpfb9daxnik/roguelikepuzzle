import codecs

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

# 1. Add vars
for i in range(len(lines)):
    if 'var divscorelabel: Array[RichTextLabel] = []' in lines[i]:
        lines.insert(i+1, 'var turn_element_counts: Dictionary = {}')
        lines.insert(i+2, 'var elem_labels: Array[RichTextLabel] = []')
        break

# 2. Add labels creation in _ready()
for i in range(len(lines)):
    if 'divscorelabel.append(score_lbl)' in lines[i]:
        insert_code = '''
		for j in range(1, 7):
			var el_lbl = score_lbl.duplicate()
			el_lbl.name = "elem_score" + str(j)
			el_lbl.offset_left += 450.0
			el_lbl.offset_top += (j - 1) * 75.0 - (i * 50.0) # adjust base pos
			add_child(el_lbl)
			elem_labels.append(el_lbl)
		update_elem_labels()
'''
        # wait, if I put it in the loop or i in range(5):, it will be added 5 times!
        # I should put it AFTER the loop!
        pass

for i in range(len(lines)):
    if 'divscorelabel.append(score_lbl)' in lines[i]:
        for j in range(i, i+15):
            if 'var pb = _get_puzzle_board()' in lines[j]:
                insert_code = '''
	if divscorelabel.size() > 0:
		for k in range(1, 7):
			var el_lbl = divscorelabel[0].duplicate()
			el_lbl.name = "elem_score" + str(k)
			el_lbl.offset_left += 450.0
			el_lbl.offset_top += (k - 1) * 60.0
			el_lbl.text = ""
			add_child(el_lbl)
			elem_labels.append(el_lbl)
		update_elem_labels()
'''
                lines.insert(j, insert_code)
                break
        break

# 3. Add calcscore parameter and counting
for i in range(len(lines)):
    if 'func calcscore(match_index: Array, grid_att: Array)' in lines[i]:
        lines[i] = 'func calcscore(match_index: Array, grid_att: Array, grid_element: Array = []) -> void:'
        break

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

# 4. Add methods
methods_code = '''
func update_elem_labels() -> void:
	if elem_labels.size() == 0: return
	for k in range(1, 7):
		var count = turn_element_counts.get(k, 0)
		var c = "FFFFFF"
		var ename = ""
		match k:
			1: c = "FF6633"; ename = "FIRE"
			2: c = "4C99FF"; ename = "WATER"
			3: c = "66E666"; ename = "WIND"
			4: c = "E6E633"; ename = "THUNDER"
			5: c = "FFE699"; ename = "LIGHT"
			6: c = "B34CE6"; ename = "DARK"
		elem_labels[k-1].text = "[b][color=#%s]%s: %d[/color][/b]" % [c, ename, count]

func reset_turn_elements() -> void:
	turn_element_counts.clear()
	update_elem_labels()
'''
lines.append(methods_code)

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

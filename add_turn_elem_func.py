import codecs

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

code_to_add = '''
func add_turn_element(el: int, amount: int) -> void:
	turn_element_counts[el] = turn_element_counts.get(el, 0) + amount
	update_elem_labels()
'''
lines.append(code_to_add)

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

import codecs
import re

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    text = f.read()

# Add turn_element_gain
text = text.replace('var turn_element_counts: Dictionary = {}', 'var turn_element_counts: Dictionary = {}\nvar turn_element_gain: Dictionary = {}')

# Add to calcscore
calc_old = r'(var gain: int = int\(earned_score \* fv_rate\)\s*if att_type < divscore\.size\(\):\s*divscore\[att_type\] \+= gain)'
calc_new = r'''\1
		
		if not turn_element_gain.has(att_type):
			turn_element_gain[att_type] = {}
			
		var total_pieces = component_cells.size()
		var element_piece_counts = {}
		var has_element = false
		
		for cell in component_cells:
			if grid_element.size() > cell.x and grid_element[cell.x].size() > cell.y:
				var el = grid_element[cell.x][cell.y]
				if el != 0:
					element_piece_counts[el] = element_piece_counts.get(el, 0) + 1
					has_element = true
					
		if has_element:
			for el in element_piece_counts:
				var ratio = float(element_piece_counts[el]) / float(total_pieces)
				var el_gain = int(gain * ratio)
				turn_element_gain[att_type][el] = turn_element_gain[att_type].get(el, 0) + el_gain'''

text = re.sub(calc_old, calc_new, text)

# Add to reset_turn_elements
reset_old = r'func reset_turn_elements\(\) -> void:\s*turn_element_counts\.clear\(\)'
reset_new = r'''func reset_turn_elements() -> void:
	turn_element_counts.clear()
	turn_element_gain.clear()'''
text = re.sub(reset_old, reset_new, text)

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write(text)
print("SUCCESS")

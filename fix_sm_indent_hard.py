import codecs

with codecs.open('score_manager.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

lines[655] = '\t\t\t\tif not turn_element_gain.has(att_type):'
lines[656] = '\t\t\t\t\tturn_element_gain[att_type] = {}'
lines[657] = ''
lines[658] = '\t\t\t\tvar total_pieces = component_cells.size()'
lines[659] = '\t\t\t\tvar element_piece_counts = {}'
lines[660] = '\t\t\t\tvar has_element = false'
lines[661] = ''
lines[662] = '\t\t\t\tfor cell in component_cells:'
lines[663] = '\t\t\t\t\tif grid_element.size() > cell.x and grid_element[cell.x].size() > cell.y:'
lines[664] = '\t\t\t\t\t\tvar el = grid_element[cell.x][cell.y]'
lines[665] = '\t\t\t\t\t\tif el != 0:'
lines[666] = '\t\t\t\t\t\t\telement_piece_counts[el] = element_piece_counts.get(el, 0) + 1'
lines[667] = '\t\t\t\t\t\t\thas_element = true'
lines[668] = ''
lines[669] = '\t\t\t\tif has_element:'
lines[670] = '\t\t\t\t\tfor el in element_piece_counts:'
lines[671] = '\t\t\t\t\t\tvar ratio = float(element_piece_counts[el]) / float(total_pieces)'
lines[672] = '\t\t\t\t\t\tvar el_gain = int(gain * ratio)'
lines[673] = '\t\t\t\t\t\tturn_element_gain[att_type][el] = turn_element_gain[att_type].get(el, 0) + el_gain'

with codecs.open('score_manager.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

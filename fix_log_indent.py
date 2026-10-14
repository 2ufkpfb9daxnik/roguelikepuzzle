import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(1120, 1135):
    if 'var sm_for_log =' in lines[i]:
        lines[i] = '\t\t\tvar sm_for_log = _get_score_manager()'
        lines[i+1] = '\t\t\tif sm_for_log and sm_for_log.has_method("add_turn_element"):'
        lines[i+2] = '\t\t\t\tvar e_enum = ElementDataScript.get_element_from_name(s_elem)'
        lines[i+3] = '\t\t\t\tif e_enum != ElementDataScript.Element.NONE:'
        lines[i+4] = '\t\t\t\t\tsm_for_log.add_turn_element(e_enum, 1)'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

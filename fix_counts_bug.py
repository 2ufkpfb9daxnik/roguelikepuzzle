import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'var counts = sm.turn_element_counts if "turn_element_counts" in sm else {}' in lines[i]:
        lines[i] = '\tvar score_mgr = _get_score_manager()\n\tvar counts = score_mgr.turn_element_counts if score_mgr and "turn_element_counts" in score_mgr else {}'
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

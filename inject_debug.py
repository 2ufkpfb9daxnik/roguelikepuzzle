import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'beam_node.target_pos = target_root_local' in lines[i]:
        lines.insert(i+1, '\t\tprint("[DEBUG] Enemy global: ", enemy_sp.global_position, " Target local: ", target_local, " Target global: ", target_global, " Target root local: ", target_root_local)')
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

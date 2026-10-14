import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _emit_combat_event' in lines[i]:
        for j in range(i, i+15):
            if 'var sm = _get_score_manager()' in lines[j]:
                lines[j] = '\t\tvar sm = _get_stage_manager()'
                break
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

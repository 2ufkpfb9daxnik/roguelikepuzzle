import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

# Find first definition and remove it (lines 9 to 20)
start_first = -1
for i in range(20):
    if 'func _emit_combat_event' in lines[i]:
        start_first = i
        break

if start_first != -1:
    end_first = -1
    for i in range(start_first, start_first + 20):
        if 'print("[CombatEvent] ", event)' in lines[i]:
            end_first = i
            break
    if end_first != -1:
        del lines[start_first:end_first+1]

# Find second definition and fix sm
for i in range(len(lines)):
    if 'func _emit_combat_event' in lines[i]:
        for j in range(i, i+15):
            if 'var sm = get_node_or_null("../ScoreManager")' in lines[j]:
                lines[j] = '\t\tvar sm = _get_score_manager()'
                break
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

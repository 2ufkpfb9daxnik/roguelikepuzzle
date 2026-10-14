import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if '_emit_combat_event("damage", "enemy", "ally", incoming_damage)' in lines[i]:
        # Force 4 tabs
        lines[i] = '\t\t\t\t_emit_combat_event("damage", "enemy", "ally", incoming_damage)'
        
        # Check if the prev line is sm.calchp
        if 'sm.calchp(0, incoming_damage)' in lines[i-1]:
            lines[i-1] = '\t\t\t\tsm.calchp(0, incoming_damage)'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

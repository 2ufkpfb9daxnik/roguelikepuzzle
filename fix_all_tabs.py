import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'sm.calchp(0.0, -total_heal)' in lines[i]:
        lines[i] = '\t\t\tsm.calchp(0.0, -total_heal)'
        lines[i+1] = '\t\t\t_emit_combat_event("heal", "ally", "ally", total_heal)'
    if 'sm.calchp(0, -heal_val)' in lines[i]:
        lines[i] = '\t\t\t\tsm.calchp(0, -heal_val)'
        lines[i+1] = '\t\t\t\t_emit_combat_event("heal", "ally", "ally", heal_val)'
    if '_emit_combat_event("damage", "enemy", "ally", incoming_damage)' in lines[i]:
        lines[i] = '\t\t\t\t_emit_combat_event("damage", "enemy", "ally", incoming_damage)'
        if 'sm.calchp(0, incoming_damage)' in lines[i-1]:
            lines[i-1] = '\t\t\t\tsm.calchp(0, incoming_damage)'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))

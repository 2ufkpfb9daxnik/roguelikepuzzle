import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'sm.calchp(0.0, -total_heal)' in lines[i]:
        lines[i] = '\t\t\tsm.calchp(0.0, -total_heal)'
        lines[i+1] = '\t\t\t_emit_combat_event("heal", "ally", "ally", total_heal)'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

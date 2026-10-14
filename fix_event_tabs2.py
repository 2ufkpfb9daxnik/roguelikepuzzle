import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'sm.calchp(0.0, -total_heal)' in lines[i]:
        # Count tabs
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = '\t'*tabs + 'sm.calchp(0.0, -total_heal)'
        lines[i+1] = '\t'*tabs + '_emit_combat_event("heal", "ally", "ally", total_heal)'
    elif 'sm.calchp(0, -heal_val)' in lines[i]:
        tabs = len(lines[i]) - len(lines[i].lstrip('\t'))
        lines[i] = '\t'*tabs + 'sm.calchp(0, -heal_val)'
        lines[i+1] = '\t'*tabs + '_emit_combat_event("heal", "ally", "ally", heal_val)'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

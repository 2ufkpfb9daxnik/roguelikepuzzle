import codecs

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.read().split('\n')

for i in range(len(lines)):
    if 'func _play_ally_attack_phase_effects' in lines[i]:
        # find the end of the function and add turn_skill_log.clear()
        for j in range(i, len(lines)):
            if 'delay += SKILL_EFFECT_STAGGER' in lines[j]:
                lines.insert(j+1, '\tturn_skill_log.clear()')
                break
        
        # also add to the early returns
        for j in range(i, i+15):
            if 'if active_en.is_empty():' in lines[j]:
                lines.insert(j+1, '\t\tturn_skill_log.clear()')
                break
            if 'if turn_skill_log.is_empty() or not is_instance_valid(sm):' in lines[j]:
                lines.insert(j+1, '\t\tturn_skill_log.clear()')
                break
        break

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write('\n'.join(lines))
print("SUCCESS")

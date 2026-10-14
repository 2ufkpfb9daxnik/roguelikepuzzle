import codecs, re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    text = f.read()

# match from func _play_ally_attack_phase_effects(sm: Node2D) to the end of the function (before next func)
old_func_regex = r'func _play_ally_attack_phase_effects\(sm: Node2D\) -> void:.*?turn_skill_log\.clear\(\)'

# Wait! The previous re.sub might have matched only a part!
# Let's just find the start of the function and the start of the NEXT function!

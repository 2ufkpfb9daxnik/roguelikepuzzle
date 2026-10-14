import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'enemy_atk_se.stream = ENEMY_ATTACK_SE' in line:
        lines[i] = ''
    elif 'enemy_atk_se.volume_db = linear_to_db' in line:
        lines[i] = ''
    elif 'enemy_atk_se.play(0.0)' in line:
        lines[i] = '\t\t\t\t_play_pooled_se(ENEMY_ATTACK_SE, linear_to_db(clampf(se_vol * 1.2, 0.001, 1.5)), 1.0)\n'
    elif 'if enemy_atk_se:' in line:
        lines[i] = ''

    if 'hit_se.stream = UTU2_SE' in line:
        lines[i] = ''
    elif 'hit_se.volume_db = linear_to_db' in line:
        lines[i] = ''
    elif 'hit_se.play(0.0)' in line:
        lines[i] = '\t\t\t\t\t_play_pooled_se(UTU2_SE, linear_to_db(clampf(se_vol * 1.0, 0.001, 1.5)), 1.0)\n'
    elif 'if hit_se:' in line:
        lines[i] = ''

    if 'if p and "vfx_container" in p:' in line:
        # It's at 5414
        lines[i-1] = '\t\tvar p = get_parent()\n'
        lines[i] = '\t\tif p != null:\n'
        lines[i+1] = '\t\t\tvar vc = p.get_node_or_null("VFXContainer")\n'
        lines[i+2] = '\t\t\tif vc:\n'
        lines[i+3] = '\t\t\t\tfor child in vc.get_children():\n'
        lines[i+4] = '\t\t\t\t\tchild.queue_free()\n'

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.writelines(lines)
print("SUCCESS")

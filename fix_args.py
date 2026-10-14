import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# _spawn_enemy_skill_activation_vfx 自体を削除するか修正する
content = re.sub(r'func _spawn_enemy_skill_activation_vfx\b.*?(?=func )', '', content, flags=re.DOTALL)

# 古い _spawn_enemy_skill_chant_vfx 呼び出しを検索して修正
# 古い引数: (sm, elem_color_hex, is_boss)
# 新しい引数: (sm, enemy_sp, elem_color_hex, is_boss)
# ただし _execute_enemy_turn_actions の中では正しく (sm, spr, elem_color, is_boss) で呼べているはず
# 正規表現で一括置換 (sm, elem, is_boss) -> (sm, sm.enemy, elem, is_boss)
content = re.sub(r'_spawn_enemy_skill_chant_vfx\(sm, (.*?), (.*?)\)', r'_spawn_enemy_skill_chant_vfx(sm, sm.enemy, \1, \2)', content)
content = re.sub(r'_spawn_enemy_skill_beam_and_burst\(sm, (.*?), (.*?)\)', r'_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, \1, \2)', content)

# _execute_enemy_turn_actions 内での呼び出しが sm, sm.enemy, spr, ... になってしまっているかもしれないので直す
content = content.replace('_spawn_enemy_skill_chant_vfx(sm, sm.enemy, spr,', '_spawn_enemy_skill_chant_vfx(sm, spr,')
content = content.replace('_spawn_enemy_skill_beam_and_burst(sm, sm.enemy, spr,', '_spawn_enemy_skill_beam_and_burst(sm, spr,')

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

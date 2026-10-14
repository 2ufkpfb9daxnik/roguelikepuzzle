import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

def replace_func(content, func_name, new_body):
    pattern = r'(func ' + func_name + r'\b.*?\n)(?:(?:[ \t].*\n)|(?:^\s*\n))*'
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[:match.start()] + new_body + '\n' + content[match.end():]
    return content

# 1. フリーズの完全修正 (_check_matches_exist の安全な再実装)
new_check_matches_exist = '''func _check_matches_exist(changed_rows: Array = [], changed_cols: Array = []) -> bool:
	# 安全のため、常に全セルを走査し ismatched を更新する
	for i in range(GRID_ROWS):
		for j in range(GRID_COLUMNS):
			ismatched[i][j] = false

	var found = false

	# 水平走査
	for i in range(GRID_ROWS):
		var j: int = 0
		while j < GRID_COLUMNS:
			var kind: int = grid_n[i][j]
			if kind < 0:
				j += 1
				continue
			var match_len: int = 1
			while j + match_len < GRID_COLUMNS and grid_n[i][j + match_len] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(j, j + match_len):
					ismatched[i][k] = true
			j += match_len

	# 垂直走査
	for j in range(GRID_COLUMNS):
		var i: int = 0
		while i < GRID_ROWS:
			var kind: int = grid_n[i][j]
			if kind < 0:
				i += 1
				continue
			var match_len: int = 1
			while i + match_len < GRID_ROWS and grid_n[i + match_len][j] == kind:
				match_len += 1
			if match_len >= 3:
				found = true
				for k in range(i, i + match_len):
					ismatched[k][j] = true
			i += match_len

	return found'''
content = replace_func(content, '_check_matches_exist', new_check_matches_exist)

# 2. スキル反映の修正 (_execute_pending_redraw_effects)
new_redraw = '''var _pending_redraw_effects: bool = false
func _redraw_board_effects() -> void:
	_pending_redraw_effects = true

func _execute_pending_redraw_effects() -> void:
	_pending_redraw_effects = false
	_update_board_element_flags()'''
content = content.replace('''var _pending_redraw_effects: bool = false
func _redraw_board_effects() -> void:
	_pending_redraw_effects = true

func _execute_pending_redraw_effects() -> void:
	_pending_redraw_effects = false''', new_redraw)

# 3. 複数敵のスキルの個別発動 (_execute_enemy_elemental_skill)
new_enemy_skill = '''func _execute_enemy_elemental_skill(sm: Node2D) -> void:
	if has_enemy_skilled:
		return
	has_enemy_skilled = true

	if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
		return

	if sm.get("active_enemies") and sm.active_enemies.size() > 0:
		var seq_tw = create_tween()
		for e in sm.active_enemies:
			var key = e.get("key", "slime")
			var is_boss = false
			if sm.has_method("is_boss_monster"):
				is_boss = sm.is_boss_monster()
			else:
				is_boss = sm.is_current_boss if "is_current_boss" in sm else false
				
			var sp_data = {}
			if "ENEMY_SPECIES" in sm:
				sp_data = sm.ENEMY_SPECIES.get(key, {})
				
			var elem = sp_data.get("element", sp_data.get("race", "???"))
			if typeof(elem) == TYPE_ARRAY:
				elem = elem[randi() % elem.size()]
				
			var s_info = _get_enemy_skill_info(elem, is_boss)
			var s_name = s_info["name"]
			var elem_color = s_info["color"]
			var spr = e.get("sprite")
			
			seq_tw.tween_callback(func():
				_play_enemy_skill_se(is_boss)
				_show_enemy_skill_banner(s_name, elem_color, is_boss)
				_spawn_enemy_skill_chant_vfx(sm, elem_color, is_boss)
				if is_instance_valid(spr):
					# 簡単なアニメーション
					var tw = create_tween()
					tw.tween_property(spr, "scale", spr.scale * 1.1, 0.2)
					tw.tween_property(spr, "scale", spr.scale, 0.2)
			)
			seq_tw.tween_interval(0.70)
			seq_tw.tween_callback(func():
				if sm == null or sm.isdeadf or sm.ehp <= 0:
					return
				_spawn_enemy_skill_beam_and_burst(sm, elem_color, is_boss)
				_apply_enemy_elemental_skill_effect(elem, is_boss)
			)
			seq_tw.tween_interval(0.5)
	else:
		var is_boss: bool = sm.is_boss_monster() if sm.has_method("is_boss_monster") else (sm.is_current_boss or sm.stage_enemy == 5)
		var elem = sm.get_current_enemy_element() if sm.has_method("get_current_enemy_element") else "???"
		var s_info = _get_enemy_skill_info(elem, is_boss)
		var s_name: String = s_info["name"]
		var elem_color: String = s_info["color"]

		_play_enemy_skill_se(is_boss)
		_show_enemy_skill_banner(s_name, elem_color, is_boss)
		if sm.has_method("play_enemy_animation") and sm.has_enemy_animation("skill"):
			sm.play_enemy_animation("skill")
		_spawn_enemy_skill_chant_vfx(sm, elem_color, is_boss)

		var tw_cast = create_tween()
		tw_cast.tween_interval(0.70)
		tw_cast.tween_callback(func():
			if sm == null or sm.isdeadf or sm.enemy == null or sm.ehp <= 0:
				return
			_spawn_enemy_skill_beam_and_burst(sm, elem_color, is_boss)
			_apply_enemy_elemental_skill_effect(elem, is_boss)
		)'''
content = replace_func(content, '_execute_enemy_elemental_skill', new_enemy_skill)

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

import codecs
import re

with codecs.open('board_overlay.gd', 'r', 'utf-8') as f:
    content = f.read()

# _processを修正
old_process = '''func _process(delta: float) -> void:
	if board == null:
		return

	var needs_redraw = false

	# ???????
	if "active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty():
		var removed = false
		var i = board.active_wind_tornadoes.size() - 1
		while i >= 0:
			var tor = board.active_wind_tornadoes[i]
			tor["y"] += tor.get("speed", 4500.0) * delta
			if tor["y"] > BOARD_TOP + BOARD_HEIGHT + 600.0:
				board.active_wind_tornadoes.remove_at(i)
				removed = true
			i -= 1
		if removed and board.active_wind_tornadoes.is_empty() and board.has_method("_update_board_element_flags"):
			board._update_board_element_flags()
		needs_redraw = true

	# ???????????????????????has_board_hazards ??????????????2D??????????
	if not needs_redraw:
		if "has_board_hazards" in board:
			needs_redraw = board.has_board_hazards
		else:
			if ("grid_electrified" in board and _has_any_in_2d(board.grid_electrified)) or \\
			   ("grid_fog" in board and not board.grid_fog.is_empty()) or \\
			   ("grid_ice" in board and _has_any_in_2d(board.grid_ice)) or \\
			   ("grid_stones" in board and _has_any_int_in_2d(board.grid_stones)) or \\
			   ("grid_gold_statue" in board and _has_any_int_in_2d(board.grid_gold_statue)) or \\
			   ("grid_cursed" in board and _has_any_in_2d(board.grid_cursed)) or \\
			   ("grid_poison" in board and _has_any_in_2d(board.grid_poison)) or \\
			   ("grid_fire" in board and _has_any_int_in_2d(board.grid_fire)) or \\
			   ("plant_entities" in board and not board.plant_entities.is_empty()):
				needs_redraw = true

	if needs_redraw:
		queue_redraw()'''

new_process = '''func _process(delta: float) -> void:
	if board == null:
		return

	var needs_redraw = false

	# 竜巻がある場合のみ、アニメーションのために毎フレーム再描画する
	if "active_wind_tornadoes" in board and not board.active_wind_tornadoes.is_empty():
		var removed = false
		var i = board.active_wind_tornadoes.size() - 1
		while i >= 0:
			var tor = board.active_wind_tornadoes[i]
			tor["y"] += tor.get("speed", 4500.0) * delta
			if tor["y"] > 11500.0: # BOARD_TOP + BOARD_HEIGHT + 600.0
				board.active_wind_tornadoes.remove_at(i)
				removed = true
			i -= 1
		if removed and board.active_wind_tornadoes.is_empty() and board.has_method("_update_board_element_flags"):
			board._update_board_element_flags()
		needs_redraw = true

	if needs_redraw:
		queue_redraw()'''

if old_process in content:
    content = content.replace(old_process, new_process)
else:
    # try replacing via regex
    content = re.sub(r'func _process\(delta: float\) -> void:.*?if needs_redraw:\s+queue_redraw\(\)', new_process, content, flags=re.DOTALL)

with codecs.open('board_overlay.gd', 'w', 'utf-8') as f:
    f.write(content)

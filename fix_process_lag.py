import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# _process 内の mark_overlay.queue_redraw() と modulateループを、_pending_redraw 処理に置き換える
# 正規表現で _process の最後の方を置き換えます
old_pattern = r'# \?+[\r\n\s]+if has_special_items and mark_overlay:[\r\n\s]+mark_overlay\.queue_redraw\(\).*?(?=\n\n|\Z)'
# ファイル末尾までマッチさせてしまうかもしれないので注意。実際は EOF 近くにあります。

# より安全な置換:
target_code = '''	if flying_swords.size() == 0 and sm and sm.enemy != null and msisvalid:
		sm.enemy.modulate.r = encolor
		msisvalid = false

	# ?????????????????????????????????????????????????
	if has_special_items and mark_overlay:
		mark_overlay.queue_redraw()

	# ????????????????
	if has_special_items and (is_bomb.size() == GRID_ROWS or special_item.size() == GRID_ROWS):
		var time_pulse = 0.80 + 0.30 * sin(Time.get_ticks_msec() * 0.008)
		for r in range(GRID_ROWS):
			for c in range(GRID_COLUMNS):
				var p_idx = grid_i[r][c]
				if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
					var sp_type = special_item[r][c] if special_item.size() == GRID_ROWS else SpecialItemType.NONE
					var is_b = is_bomb[r][c] if is_bomb.size() == GRID_ROWS else false
					
					if sp_type != SpecialItemType.NONE or is_b:
						var glow_color = Color(1.8, 0.4, 0.2, 1.0) # ???????
						match sp_type:
							SpecialItemType.CROSS_BOMB: glow_color = Color(0.2, 1.4, 1.8, 1.0)
							SpecialItemType.DISCO_BALL: glow_color = Color(1.8, 0.3, 1.8, 1.0)
							SpecialItemType.COLOR_CONVERTER: glow_color = Color(0.2, 1.8, 0.6, 1.0)
							SpecialItemType.LIGHTNING: glow_color = Color(1.8, 1.8, 0.2, 1.0)
							SpecialItemType.BLACK_HOLE: glow_color = Color(0.8, 0.2, 1.8, 1.0)
							SpecialItemType.MAGNET: glow_color = Color(1.8, 0.6, 0.2, 1.0)
							SpecialItemType.CHARGE_BOMB: glow_color = Color(2.0, 0.3, 0.1, 1.0)
							SpecialItemType.GEMINI_BOMB: glow_color = Color(1.8, 0.8, 0.2, 1.0)
						piece[p_idx].modulate = glow_color * time_pulse
					elif not ismatched[r][c] and (selected_piece_idx != p_idx):
						if piece[p_idx].modulate != Color.WHITE:
							piece[p_idx].modulate = Color.WHITE'''

new_code = '''	if flying_swords.size() == 0 and sm and sm.enemy != null and msisvalid:
		sm.enemy.modulate.r = encolor
		msisvalid = false

	# 保留されていた再描画をここで一括実行する（毎フレームではなく必要な時だけ）
	if _pending_redraw_effects:
		_execute_pending_redraw_effects()
		if board_bg: board_bg.queue_redraw()
		if board_overlay and (has_board_hazards or not active_wind_tornadoes.is_empty()): board_overlay.queue_redraw()
		if mark_overlay and has_special_items: mark_overlay.queue_redraw()
		
		# アイテムの色を固定で設定（毎フレーム脈打つ処理は重いので削除）
		if has_special_items and (is_bomb.size() == GRID_ROWS or special_item.size() == GRID_ROWS):
			for r in range(GRID_ROWS):
				for c in range(GRID_COLUMNS):
					var p_idx = grid_i[r][c]
					if p_idx >= 0 and p_idx < piece.size() and piece[p_idx] != null:
						var sp_type = special_item[r][c] if special_item.size() == GRID_ROWS else SpecialItemType.NONE
						var is_b = is_bomb[r][c] if is_bomb.size() == GRID_ROWS else false
						
						if sp_type != SpecialItemType.NONE or is_b:
							var glow_color = Color(1.8, 0.4, 0.2, 1.0)
							match sp_type:
								SpecialItemType.CROSS_BOMB: glow_color = Color(0.2, 1.4, 1.8, 1.0)
								SpecialItemType.DISCO_BALL: glow_color = Color(1.8, 0.3, 1.8, 1.0)
								SpecialItemType.COLOR_CONVERTER: glow_color = Color(0.2, 1.8, 0.6, 1.0)
								SpecialItemType.LIGHTNING: glow_color = Color(1.8, 1.8, 0.2, 1.0)
								SpecialItemType.BLACK_HOLE: glow_color = Color(0.8, 0.2, 1.8, 1.0)
								SpecialItemType.MAGNET: glow_color = Color(1.8, 0.6, 0.2, 1.0)
								SpecialItemType.CHARGE_BOMB: glow_color = Color(2.0, 0.3, 0.1, 1.0)
								SpecialItemType.GEMINI_BOMB: glow_color = Color(1.8, 0.8, 0.2, 1.0)
							piece[p_idx].modulate = glow_color
						elif not ismatched[r][c] and (selected_piece_idx != p_idx):
							if piece[p_idx].modulate != Color.WHITE:
								piece[p_idx].modulate = Color.WHITE'''

if target_code in content:
    content = content.replace(target_code, new_code)
else:
    print("Target code not found!")

with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
    f.write(content)

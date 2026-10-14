import codecs
import re

with codecs.open('puzzle_board.gd', 'r', 'utf-8') as f:
    content = f.read()

# 確実に見つけるために一部のコードだけを検索
start_marker = "if flying_swords.size() == 0 and sm and sm.enemy != null and msisvalid:"
end_marker = "func _draw_special_item_marks_on_overlay(overlay: Node2D) -> void:"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

if start_idx != -1 and end_idx != -1:
    # 間のコードを取り出す
    sub = content[start_idx:end_idx]
    
    # クラス定義などを消さないように調整（SpecialMarkOverlayNode クラス定義がある）
    class_marker = "class SpecialMarkOverlayNode extends Node2D:"
    class_idx = content.find(class_marker, start_idx)
    
    if class_idx != -1:
        # start_idx から class_idx までのコードを置換
        old_part = content[start_idx:class_idx]
        
        new_part = '''if flying_swords.size() == 0 and sm and sm.enemy != null and msisvalid:
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
								piece[p_idx].modulate = Color.WHITE

'''
        content = content[:start_idx] + new_part + content[class_idx:]
        
        with codecs.open('puzzle_board.gd', 'w', 'utf-8') as f:
            f.write(content)
        print("Success")
    else:
        print("Class marker not found")
else:
    print("Start or end marker not found")

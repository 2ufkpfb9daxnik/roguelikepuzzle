extends SceneTree
func _count(pb) -> int:
	var n = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: n += 1
	return n
func _initialize() -> void:
	change_scene_to_file("res://current_stage.tscn")
	for i in range(30): await process_frame
	var cs = current_scene
	var pb = cs.get_node_or_null("PuzzleBoard")
	var sc = cs.get_node_or_null("ScoreManager")
	var sm = cs.get_node_or_null("StageManager")
	sm.myhp = 1.0e12; sm.myhpmax = 1.0e12; sm.ehp = 1.0e12; sm.ehpmax = 1.0e12
	sc.set_skill_level("poison_1", 5)
	# 毒配置 → 1回マッチで消えないか
	pb.current_state = pb.BoardState.IDLE
	pb.cast_player_skill("poison", true, 1, true, pb.get_cell_position(6,6))
	print("poison_after_skill=", _count(pb))
	# 毒マス上で駒をマッチ消去
	var target = Vector2i(-1,-1)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: target = Vector2i(r,c); break
		if target.x >= 0: break
	if target.x >= 0:
		print("target=", target, " stage=", pb.grid_poison_stage[target.x][target.y])
		pb._process_piece_cleared_benefits([], "ally")
	for i in range(10): await process_frame
	print("poison_after_match=", _count(pb))
	# ツールチップ2枠組み立て
	var entries = pb._collect_cell_effect_entries(6, 6)
	var rich = pb._build_cell_tooltip_rich_text(entries, pb._cell_object_split)
	print("tooltip_has_effect_hdr=", rich.find("マスに付与されている効果") != -1, " has_object_hdr=", rich.find("コマ・オブジェクト") != -1, " entries=", entries.size(), " split=", pb._cell_object_split)
	quit()

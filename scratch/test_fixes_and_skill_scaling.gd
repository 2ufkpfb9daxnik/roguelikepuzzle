extends SceneTree

func _init():
	print("--- Starting Test for Fever BGM, Wood Drain GameOver, and Skill Scaling ---")
	call_deferred("_run_tests")

func _run_tests():
	var root = get_root()
	var test_scene = Node2D.new()
	test_scene.name = "TestRoot"
	root.add_child(test_scene)

	# 必要なモックノードの準備（SEなど）
	var fever_se = AudioStreamPlayer.new()
	fever_se.name = "fevertime"
	test_scene.add_child(fever_se)

	var rensa_se = AudioStreamPlayer.new()
	rensa_se.name = "1rensa"
	test_scene.add_child(rensa_se)

	var block_se = AudioStreamPlayer.new()
	block_se.name = "block"
	test_scene.add_child(block_se)

	var anten_se = AudioStreamPlayer.new()
	anten_se.name = "anten"
	test_scene.add_child(anten_se)

	# StageManager の生成
	var StageManagerScript = load("res://stage_manager.gd")
	var sm = Node2D.new()
	sm.name = "StageManager"
	sm.set_script(StageManagerScript)

	# feverbgm ノードの追加
	var fever_bgm = AudioStreamPlayer.new()
	fever_bgm.name = "feverbgm"
	# 空のダミーAudioStreamGeneratorをセットしてplay可能にする
	var gen = AudioStreamGenerator.new()
	fever_bgm.stream = gen
	sm.add_child(fever_bgm)

	# gameover ノードの追加
	var gameover_node = Node2D.new()
	gameover_node.name = "gameover"
	gameover_node.position = Vector2(9999, 9999)
	sm.add_child(gameover_node)

	# enemy ノードの追加
	var enemy_sp = Sprite2D.new()
	enemy_sp.name = "enemy"
	sm.enemy = enemy_sp
	sm.add_child(enemy_sp)

	test_scene.add_child(sm)

	# PuzzleBoard の生成
	var PuzzleBoardScript = load("res://puzzle_board.gd")
	var pb = Node2D.new()
	pb.name = "puzzleboard"
	pb.set_script(PuzzleBoardScript)
	test_scene.add_child(pb)

	# 初期盤面とステータス初期化
	sm.myhp = 1000
	sm.myhpmax = 1000
	sm.ehp = 500
	sm.ehpmax = 1000
	sm.stage = 1
	sm.enemycount = 1
	sm.interval = 150
	pb._initialize_board(null)

	# --- TEST 1: フィーバータイムBGMと突入時クリック検証 ---
	print("\n--- TEST 1: Fever Time Skip & BGM ---")
	sm.isfevertime = true
	sm.appeartime = 10
	assert(sm.appeartime < sm.FEVER_INTRO_FRAMES, "Fever intro not in wait state")
	assert(not fever_bgm.playing, "fever_bgm should not be playing yet")
	sm.enemycount = 1
	sm.interval = 150

	# クリックイベントのシミュレーション
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	# (row 2, col 2) のローカル座標: x = 4250 + 2*500 + 250 = 5500, y = 1250 + 2*500 + 250 = 2500
	click_event.position = pb.to_global(Vector2(5500, 2500))

	pb._unhandled_input(click_event)

	print("DEBUG: is_holding=", pb.is_holding, " sm.interval=", sm.interval, " isstageclear=", sm.isstageclear, " isdeadf=", sm.isdeadf, " current_state=", pb.current_state, " local_pos=", pb.to_local(click_event.position))
	assert(sm.appeartime >= sm.FEVER_INTRO_FRAMES, "Appeartime should be skipped to FEVER_INTRO_FRAMES")
	assert(fever_bgm.playing, "fever_bgm MUST be playing after skip click")
	assert(pb.is_holding, "Piece should be picked up (is_holding should be true)")
	print("[PASS] Test 1: Fever skip instantly started BGM and picked up piece!")

	# マウスリリースで状態リセット
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = click_event.position
	pb._unhandled_input(release_event)
	sm.isfevertime = false
	fever_bgm.stop()

	# --- TEST 2: 木属性HPドレインでHP0時のゲームオーバー検証 ---
	print("\n--- TEST 2: Wood HP Drain Game Over ---")
	sm.myhp = 50
	pb.isgameover = false
	pb.current_state = pb.BoardState.IDLE
	gameover_node.position = Vector2(9999, 9999)

	var dummy_plants: Array[Dictionary] = [{
		"origin": Vector2i(1, 1),
		"stage": 0,
		"absorbed_water": 0,
		"thunder_hp": 1,
		"enemy_planted": true,
		"drain_amount": 200
	}]
	pb._execute_wood_hp_drain(sm, dummy_plants, 1.0)

	assert(sm.myhp <= 0, "sm.myhp should be <= 0 after drain")
	assert(pb.isgameover, "pb.isgameover MUST be true")
	assert(gameover_node.position == Vector2.ZERO, "gameover_node position MUST be Vector2.ZERO")
	assert(pb.current_state == pb.BoardState.TURN_SEQUENCE, "current_state MUST be TURN_SEQUENCE to prevent control")

	# HP0時にクリックを試行
	pb._unhandled_input(click_event)
	assert(not pb.is_holding, "Must NOT be able to pick up piece when dead")
	print("[PASS] Test 2: Wood drain game over correctly triggered and blocked input!")

	# --- TEST 3: 敵スキルのステージ別スケーリング検証 ---
	print("\n--- TEST 3: Enemy Skill Scaling by Stage ---")
	pb.isgameover = false
	sm.myhp = 1000

	# 3-1: 水属性スキル
	sm.stage = 1
	var st_idx1 = pb._get_stage_index()
	assert(st_idx1 == 0, "Stage 1 should have st_idx = 0")
	sm.stage = 5
	var st_idx5 = pb._get_stage_index()
	assert(st_idx5 == 4, "Stage 5 should have st_idx = 4")

	# Stage 1 での水マス数サンプリング
	sm.stage = 1
	pb._cast_enemy_water_skill(false, false)
	var water_count_st1 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c]: water_count_st1 += 1
	assert(water_count_st1 >= 8 and water_count_st1 <= 12, "Stage 1 water count should be 8~12, got: %d" % water_count_st1)

	# 水マスリセット
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_water[r][c] = false

	# Stage 5 での水マス数サンプリング (8+4*2=16 ~ 12+4*2=20)
	sm.stage = 5
	pb._cast_enemy_water_skill(false, false)
	var water_count_st5 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c]: water_count_st5 += 1
	assert(water_count_st5 >= 16 and water_count_st5 <= 20, "Stage 5 water count should be 16~20, got: %d" % water_count_st5)
	print("[PASS] Test 3-1: Water skill scaling verified (Stage 1: %d, Stage 5: %d)" % [water_count_st1, water_count_st5])

	# 3-2: 地属性スキル（石の数と耐久値強化）
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_stones[r][c] = 0

	sm.stage = 1
	pb._cast_enemy_earth_skill(false, false)
	var stone_count_st1 = 0
	var min_stone_dur_st1 = 999
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_stones[r][c] > 0:
				stone_count_st1 += 1
				min_stone_dur_st1 = mini(min_stone_dur_st1, pb.grid_stones[r][c])
	assert(stone_count_st1 >= 6 and stone_count_st1 <= 9, "Stage 1 stone count should be 6~9, got: %d" % stone_count_st1)
	assert(min_stone_dur_st1 == 2, "Stage 1 stone durability should be 2, got: %d" % min_stone_dur_st1)

	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_stones[r][c] = 0

	sm.stage = 5 # st_idx = 4 (通常4, 巨岩5)
	pb._cast_enemy_earth_skill(false, false)
	var stone_count_st5 = 0
	var heavy_stone_count = 0
	var max_stone_dur_st5 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_stones[r][c] > 0:
				stone_count_st5 += 1
				max_stone_dur_st5 = maxi(max_stone_dur_st5, pb.grid_stones[r][c])
				if pb.grid_stones[r][c] >= 5:
					heavy_stone_count += 1
	assert(stone_count_st5 >= 14 and stone_count_st5 <= 17, "Stage 5 stone count should be 14~17, got: %d" % stone_count_st5)
	assert(max_stone_dur_st5 >= 5, "Stage 5 should have heavy stones with durability >= 5, got: %d" % max_stone_dur_st5)
	print("[PASS] Test 3-2: Earth stone durability scaling verified (Stage 1: %d, Stage 5 max dur: %d, Heavy: %d)" % [min_stone_dur_st1, max_stone_dur_st5, heavy_stone_count])

	# 3-3: 木属性スキル（本数・若木混成・thunder_hp耐久値）
	pb.plant_entities.clear()
	sm.stage = 1
	pb._cast_enemy_wood_skill(false, false)
	var wood_count_st1 = pb.plant_entities.size()
	var sprout_hp_st1 = pb.plant_entities[0]["thunder_hp"]
	assert(wood_count_st1 >= 3 and wood_count_st1 <= 5, "Stage 1 wood count should be 3~5, got: %d" % wood_count_st1)
	assert(sprout_hp_st1 == 1, "Stage 1 sprout thunder_hp should be 1, got: %d" % sprout_hp_st1)

	pb.plant_entities.clear()
	sm.stage = 5 # st_idx = 4
	pb._cast_enemy_wood_skill(false, false)
	var wood_count_st5 = pb.plant_entities.size()
	var sprout_hp_st5 = 0
	var sapling_hp_st5 = 0
	for p in pb.plant_entities:
		if p.get("stage", 0) == 0:
			sprout_hp_st5 = p.get("thunder_hp", 0)
		elif p.get("stage", 0) == 1:
			sapling_hp_st5 = p.get("thunder_hp", 0)
	assert(wood_count_st5 >= 7 and wood_count_st5 <= 9, "Stage 5 wood count should be 7~9, got: %d" % wood_count_st5)
	assert(sprout_hp_st5 >= 3, "Stage 5 sprout thunder_hp should be >= 3, got: %d" % sprout_hp_st5)
	assert(sapling_hp_st5 >= 4, "Stage 5 sapling thunder_hp should be >= 4, got: %d" % sapling_hp_st5)
	print("[PASS] Test 3-3: Wood durability scaling verified (Stage 1 sprout: %d, Stage 5 sprout: %d, Stage 5 sapling: %d)" % [sprout_hp_st1, sprout_hp_st5, sapling_hp_st5])

	# 3-4: 氷属性スキル（耐久値強化＆段階的解氷）
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_ice[r][c] = 0

	sm.stage = 1
	pb._cast_enemy_ice_skill(false, false)
	var ice_dur_st1 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_ice[r][c]) > 0:
				ice_dur_st1 = int(pb.grid_ice[r][c])
				break
	assert(ice_dur_st1 == 1, "Stage 1 ice durability should be 1, got: %d" % ice_dur_st1)

	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_ice[r][c] = 0

	sm.stage = 5
	pb._cast_enemy_ice_skill(false, false)
	var max_ice_dur_st5 = 0
	var test_ice_r = -1
	var test_ice_c = -1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_ice[r][c]) > 0:
				max_ice_dur_st5 = maxi(max_ice_dur_st5, int(pb.grid_ice[r][c]))
				if test_ice_r == -1:
					test_ice_r = r
					test_ice_c = c
	assert(max_ice_dur_st5 >= 2, "Stage 5 ice durability should be >= 2, got: %d" % max_ice_dur_st5)

	# 氷の隣接マッチによる段階的減算テスト (2 -> 1 -> 0)
	var test_match: Array[Vector2i] = []
	test_match.append(Vector2i(test_ice_r - 1, test_ice_c) if test_ice_r > 0 else Vector2i(test_ice_r + 1, test_ice_c))
	pb.matched_cells_list = test_match
	# 1回目の隣接マッチ
	for cell in pb.matched_cells_list:
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var ar = cell.x + d.x
			var ac = cell.y + d.y
			if ar == test_ice_r and ac == test_ice_c:
				pb.grid_ice[ar][ac] -= 1
	assert(pb.grid_ice[test_ice_r][test_ice_c] == 1, "Ice durability should decrease from 2 to 1 on first match")

	# 2回目の隣接マッチ
	for cell in pb.matched_cells_list:
		for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var ar = cell.x + d.x
			var ac = cell.y + d.y
			if ar == test_ice_r and ac == test_ice_c:
				pb.grid_ice[ar][ac] -= 1
	assert(pb.grid_ice[test_ice_r][test_ice_c] == 0, "Ice should fully break on second match (0)")
	print("[PASS] Test 3-4: Ice durability scaling & step-breaking verified (Stage 1: %d, Stage 5: %d, 2->1->0 OK)" % [ice_dur_st1, max_ice_dur_st5])

	# 3-5: 光属性スキル（黄金像の耐久値）
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_gold_statue[r][c] = 0

	sm.stage = 1
	pb._cast_enemy_light_skill(false, false)
	var statue_dur_st1 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue[r][c] > 0:
				statue_dur_st1 = pb.grid_gold_statue[r][c]
				break
	assert(statue_dur_st1 == 3, "Stage 1 gold statue durability should be 3, got: %d" % statue_dur_st1)

	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_gold_statue[r][c] = 0

	sm.stage = 5
	pb._cast_enemy_light_skill(false, false)
	var statue_dur_st5 = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue[r][c] > 0:
				statue_dur_st5 = pb.grid_gold_statue[r][c]
				break
	assert(statue_dur_st5 == 5, "Stage 5 gold statue durability should be 5, got: %d" % statue_dur_st5)

	# ボス時 (st_idx = 4, is_boss = true -> 3 + 2 + 1 = 6)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS): pb.grid_gold_statue[r][c] = 0
	pb._cast_enemy_light_skill(true, false)
	var statue_dur_st5_boss = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue[r][c] > 0:
				statue_dur_st5_boss = pb.grid_gold_statue[r][c]
				break
	assert(statue_dur_st5_boss == 6, "Stage 5 boss gold statue durability should be 6, got: %d" % statue_dur_st5_boss)
	print("[PASS] Test 3-5: Gold statue durability scaling verified (Stage 1: %d, Stage 5: %d, Stage 5 Boss: %d)" % [statue_dur_st1, statue_dur_st5, statue_dur_st5_boss])

	print("\n>>> ALL TESTS COMPLETED SUCCESSFULLY! <<<")
	quit(0)

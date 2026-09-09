extends SceneTree

func _init():
	print("=== RUNNING ELEMENTAL CHEMISTRY & BUFF VERIFICATION TEST ===")

	# 1. バフ仕様・価格上昇率テスト
	test_buff_system()

	# 2. 元素化学反応・植物システムテスト
	test_elemental_chemistry()

	print("=== ALL TESTS PASSED SUCCESSFULLY! ===")
	quit(0)

func test_buff_system():
	print("\n--- Testing Buff System & 1.3x Price Scaling ---")
	var sm_script = load("res://score_manager.gd")
	assert(sm_script != null, "Failed to load score_manager.gd")
	var sm = Node2D.new()
	sm.set_script(sm_script)

	# カタログの存在チェック
	assert("shop_items" in sm, "shop_items missing")
	var shield_item = null
	for itm in sm.shop_items:
		if itm.get("id") == "shield":
			shield_item = itm
			break
	assert(shield_item != null, "shield buff missing from catalog")
	var base_cost = shield_item["cost"]
	print("Initial Shield buff cost: ", base_cost)

	# 1.3倍価格上昇の計算テスト
	var next_cost = int(base_cost * 1.3)
	var next_cost2 = int(next_cost * 1.3)
	print("Expected next costs: ", next_cost, " -> ", next_cost2)
	assert(next_cost > base_cost, "Cost must increase")
	assert(abs(float(next_cost) / float(base_cost) - 1.3) < 0.05, "Cost multiplier must be ~1.3")

	# スコア加算計算テスト（レベルに応じて+〇）
	sm.stat_levels[0] = 3 # 盾 Lv3 (+300)
	sm.divscore[0] = 0
	sm.divscore[1] = 0
	sm.divscore[2] = 9999999 # コイン保有量
	sm.divscore[3] = 0
	sm.divscore[4] = 0

	# calcscore を呼び出し
	var match_index = [
		[true, true, true],
		[false, false, false],
		[false, false, false]
	]
	var grid_att = [
		[0, 0, 0], # 盾 (PieceType.SHIELD = 0)
		[1, 1, 1],
		[2, 2, 2]
	]
	sm.totalScore = 0
	sm.calcscore(match_index, grid_att)
	# 基本: 3 * (3 - 2) * 100 = 300, レベルボーナス: 3 * 100 * 3 = 900 -> 合計 1200
	print("Calculated totalScore for 3 shields at Lv3: ", sm.totalScore)
	assert(sm.totalScore >= 1200, "Bonus add (stat_levels * 100 * count) should be applied")

	# 購入テスト（_purchase_buff(0) で盾バフ購入）
	var pre_cost = shield_item["cost"]
	var pre_lvl = shield_item["level"]
	sm._purchase_buff(0)
	assert(shield_item["level"] == pre_lvl + 1, "Shield item level should increase by 1")
	assert(shield_item["cost"] == int(pre_cost * 1.3), "Shield item cost should scale by 1.3x")
	print("Purchased Shield buff: new level = ", shield_item["level"], ", new cost = ", shield_item["cost"])

	print("Buff system test: OK!")
	sm.free()

func test_elemental_chemistry():
	print("\n--- Testing Elemental Chemistry & Plant System ---")
	var pb_script = load("res://puzzle_board.gd")
	assert(pb_script != null, "Failed to load puzzle_board.gd")

	var pb = pb_script.new()

	# 盤面配列の初期化
	var rows = pb.GRID_ROWS
	var cols = pb.GRID_COLUMNS
	pb.grid_i.clear()
	pb.grid_water.clear()
	pb.ismatched.clear()
	pb.special_item.clear()
	pb.special_charge.clear()
	pb.plant_entities.clear()

	for r in range(rows):
		var row_i: Array[int] = []
		var row_water: Array[bool] = []
		var row_matched: Array[bool] = []
		var row_sp: Array[int] = []
		var row_ch: Array[int] = []
		for c in range(cols):
			row_i.append(r * cols + c)
			row_water.append(false)
			row_matched.append(false)
			row_sp.append(0)
			row_ch.append(0)
		pb.grid_i.append(row_i)
		pb.grid_water.append(row_water)
		pb.ismatched.append(row_matched)
		pb.special_item.append(row_sp)
		pb.special_charge.append(row_ch)

	# A. 苗木の植樹テスト
	print("[A] Plant Sprout Placement")
	var planted = pb._plant_sprout_at(5, 5)
	assert(planted, "Failed to plant sprout at (5,5)")
	assert(pb.plant_entities.size() == 1, "Plant entities count should be 1")
	var plant = pb.plant_entities[0]
	assert(plant["origin"] == Vector2i(5, 5), "Sprout origin mismatch")
	assert(plant["stage"] == 0, "Initial stage should be 0 (苗木)")
	assert(plant["thunder_hp"] == 1, "Initial thunder_hp should be 1")
	print("Sprout placement: OK!")

	# B. 水浸し展開 ＆ 苗木の吸水成長テスト
	print("[B] Water Splash & Sprout Absorption / Evolution")
	# (5, 6) に水たまりを配置
	pb.grid_water[5][6] = true
	assert(pb.grid_water[5][6], "Water grid setup failed")
	# 吸水処理
	var absorbed = pb._process_plant_water_absorption(plant)
	assert(absorbed, "Plant should have absorbed water from (5,6)")
	assert(not pb.grid_water[5][6], "Water should be consumed after absorption")
	assert(plant["stage"] == 1, "Sprout should have evolved to stage 1 (若木)")
	assert(plant["thunder_hp"] == 2, "Stage 1 (若木) should have thunder_hp = 2")
	print("Sprout evolved to Young Tree (若木, hp=2): OK!")

	# さらに2回吸水させて 3x3大木 へ進化
	pb.grid_water[4][5] = true
	pb.grid_water[6][5] = true
	pb._process_plant_water_absorption(plant)
	assert(plant["stage"] == 2, "Plant should have evolved to stage 2 (3x3大木)")
	assert(plant["thunder_hp"] == 3, "Stage 2 (3x3大木) should have thunder_hp = 3")
	var occupied = pb._get_plant_occupied_cells(plant)
	assert(occupied.size() == 9, "3x3 tree must occupy 9 cells")
	print("Young tree evolved to 3x3 Big Tree (大木, hp=3, 9 cells): OK!")

	# C. 風属性（つむじ風 -1、竜巻 -2）の木耐久値減算テスト
	print("[C] Wind (Whirlwind -1 / Tornado -2) Plant Damage")
	# 竜巻 Lv2（-2ダメージ）
	pb.special_levels[pb.SpecialItemType.TORNADO] = 2
	var queue: Array = []
	var exploded: Dictionary = {}
	# (10, 5) から上方向へ直進発動（(5,5)の大木を通過）
	pb._trigger_tornado(10, 5, Vector2.ZERO, queue, exploded)
	assert(plant["thunder_hp"] == 1, "Tornado Lv2 should deal -2 damage to tree (hp 3 -> 1), actual: " + str(plant["thunder_hp"]))
	print("Tornado Lv2 damage (-2): OK (hp now 1)")

	# つむじ風 Lv1（-1ダメージで耐久値0となり木消滅）
	pb.special_levels[pb.SpecialItemType.TORNADO] = 1
	pb._trigger_tornado(10, 5, Vector2.ZERO, queue, exploded)
	assert(pb.plant_entities.is_empty(), "Tree should be destroyed when hp reaches 0")
	print("Whirlwind Lv1 damage (-1) & Tree destruction: OK!")

	# D. 水伝導（雷の感電拡散 BFS）テスト
	print("[D] Lightning & Water Puddle BFS Conduction")
	# L字型に水たまりを接続: (2,2)-(2,3)-(2,4)-(3,4)-(4,4)
	var puddle_cells = [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]
	for c in puddle_cells:
		pb.grid_water[c.x][c.y] = true
	# (2, 2) に落雷
	var start_hits: Array[Vector2i] = [Vector2i(2, 2)]
	pb._trigger_water_conduction(start_hits, queue, exploded)
	for c in puddle_cells:
		assert(not pb.grid_water[c.x][c.y], "All connected water cells should be cleared/shocked")
		assert(pb.ismatched[c.x][c.y], "All connected water cells should be matched/destroyed")
	print("Lightning water conduction BFS: OK!")

	# E. 火炎延焼爆発テスト
	print("[E] Fire Spread & Tree Explosion")
	# 新たに (7, 7) に苗木を配置
	pb._plant_sprout_at(7, 7)
	assert(pb.plant_entities.size() == 1, "New sprout should be planted")
	# (7, 6) でフレイムボム Lv1（3x3）起爆 -> (7, 7) の木に延焼
	pb.special_levels[pb.SpecialItemType.BOMB] = 1
	pb._trigger_bomb(7, 6, Vector2.ZERO, queue, exploded)
	assert(pb.plant_entities.is_empty(), "Tree should burn down and disappear")
	# 木の周囲マス (6..8, 6..8) が延焼消滅
	for r in range(6, 9):
		for c in range(6, 9):
			assert(pb.ismatched[r][c], "Burn cells around tree must be matched")
	print("Fire spread tree explosion: OK!")

	# F. 水に濡れたコマの耐火性テスト（火炎で水は蒸発するがコマは燃えない）
	print("[F] Water-soaked Piece Fire Resistance")
	# (10, 10) に水たまりを配置し、コマを置く
	pb.grid_water[10][10] = true
	pb.ismatched[10][10] = false
	pb.grid_i[10][10] = 100
	# (10, 11) は水なしの通常コマ
	pb.grid_water[10][11] = false
	pb.ismatched[10][11] = false
	pb.grid_i[10][11] = 101

	# (10, 10) の隣 (10, 9) でボム起爆
	pb.special_levels[pb.SpecialItemType.BOMB] = 1
	pb._trigger_bomb(10, 9, Vector2.ZERO, queue, exploded)
	# 水マス (10, 10) は水蒸発のみでコマは燃えない（ismatched は false のまま！）
	assert(not pb.grid_water[10][10], "Water must evaporate on fire hit")
	assert(not pb.ismatched[10][10], "Water-soaked piece must NOT be destroyed by fire!")
	# 水なしマス (10, 9) は燃える
	assert(pb.ismatched[10][9], "Non-water piece in bomb radius should be matched")
	print("Water fire resistance: OK (water evaporated, piece protected)!")

	# G. 水に濡れたコマの重力不動化 ＆ 遮蔽物の斜め落下カスケードテスト
	print("[G] Diagonal Falling Cascade & Obstacle Avoidance")
	# 盤面をクリア
	for r in range(rows):
		for c in range(cols):
			pb.grid_i[r][c] = -1
			pb.grid_water[r][c] = false
			pb.ismatched[r][c] = false

	# (2, 2) に苗木を配置（(2, 2) が木として塞がれる）
	pb._plant_sprout_at(2, 2)
	assert(pb._is_plant_cell(2, 2), "(2, 2) must be recognized as plant cell")
	assert(pb.grid_i[2][2] == -1, "Tree cell must have grid_i == -1")

	# (8, 8) に水浸しコマを配置 -> 重力で落下せず固定されることを確認
	pb.grid_water[8][8] = true
	pb.grid_i[8][8] = 999
	# 直下の (9, 8) を空きマスにする
	pb.grid_i[9][8] = -1

	# (1, 1) と (1, 3) にコマを配置
	pb.grid_i[1][1] = 111
	pb.grid_i[1][3] = 113

	# 落下シミュレーションを実行
	pb._start_continuous_falling()

	# 1. 水コマは (8, 8) に固定されていること
	assert(pb.grid_water[8][8], "Water tile should still be wet")
	assert(pb.grid_i[8][8] == 999, "Water-soaked piece must remain anchored at (8, 8) and not fall!")

	# 2. 木のあるマス (2, 2) にはコマが侵入していないこと
	assert(pb.grid_i[2][2] == -1, "Tree cell (2, 2) must NOT contain any piece!")

	# 3. 木の下のマス (3, 2) に斜め落下によってコマが充填されていること
	assert(pb.grid_i[3][2] != -1, "Cell beneath tree (3, 2) must be filled via diagonal slide cascade!")

	print("Diagonal cascade & obstacle avoidance: OK!")


	print("Elemental chemistry & plant system test: OK!")
	pb.free()

	# H. ステージマネージャーのボス戦時ショップ非表示 ＆ 敵種族判定テスト
	print("\n--- Testing Stage Manager Boss Battle & Enemy Species ---")
	var sm_script = load("res://stage_manager.gd")
	assert(sm_script != null, "Failed to load stage_manager.gd")
	var stage_mgr = Node2D.new()
	stage_mgr.set_script(sm_script)

	# 敵種族マスター辞書の存在チェック
	assert("ENEMY_SPECIES" in stage_mgr, "ENEMY_SPECIES dictionary missing")
	assert(stage_mgr.ENEMY_SPECIES.size() >= 24, "All 24 enemies must be cataloged in ENEMY_SPECIES")
	assert(stage_mgr.ENEMY_SPECIES["enemy1"]["element"] == "闇属性" and stage_mgr.ENEMY_SPECIES["enemy1"]["name"] == "グリムリーパー", "Enemy 1 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy2"]["element"] == "地属性" and stage_mgr.ENEMY_SPECIES["enemy2"]["name"] == "カースドマミー", "Enemy 2 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy3"]["element"] == "水属性" and stage_mgr.ENEMY_SPECIES["enemy3"]["name"] == "ポイズントード", "Enemy 3 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy4"]["element"] == "地属性" and stage_mgr.ENEMY_SPECIES["enemy4"]["name"] == "マグマゴーレム", "Enemy 4 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy5"]["element"] == "水属性" and stage_mgr.ENEMY_SPECIES["enemy5"]["name"] == "ディープサハギン", "Enemy 5 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy6"]["element"] == "地属性" and stage_mgr.ENEMY_SPECIES["enemy6"]["name"] == "ファンガスロード", "Enemy 6 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy7"]["element"] == "闇属性" and stage_mgr.ENEMY_SPECIES["enemy7"]["name"] == "スケルトンナイト", "Enemy 7 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy8"]["element"] == "風属性" and stage_mgr.ENEMY_SPECIES["enemy8"]["name"] == "キラーホーネット", "Enemy 8 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy9"]["element"] == "火属性" and stage_mgr.ENEMY_SPECIES["enemy9"]["name"] == "クリムゾンウォーロック", "Enemy 9 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy10"]["element"] == "闇属性" and stage_mgr.ENEMY_SPECIES["enemy10"]["name"] == "ジュエルアラクネ", "Enemy 10 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy11"]["element"] == "火属性" and stage_mgr.ENEMY_SPECIES["enemy11"]["name"] == "グランドラゴン", "Enemy 11 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy17"]["element"] == "水属性" and stage_mgr.ENEMY_SPECIES["enemy17"]["name"] == "フロストドラゴン", "Enemy 17 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy18"]["element"] == "闇属性" and stage_mgr.ENEMY_SPECIES["enemy18"]["name"] == "冥王デモニアス", "Enemy 18 mismatch")
	assert(stage_mgr.ENEMY_SPECIES["enemy24"]["element"] == "雷属性" and stage_mgr.ENEMY_SPECIES["enemy24"]["name"] == "冥狼フェンリル", "Enemy 24 mismatch")


	# ボス戦判定ヘルパーのテスト
	stage_mgr.stage = 1
	stage_mgr.stage_enemy = 1
	assert(not stage_mgr.is_boss_battle(), "Enemy 1 should not be boss battle")
	stage_mgr.stage_enemy = 5
	assert(stage_mgr.is_boss_battle(), "Enemy 5 should be boss battle")

	stage_mgr.stage = 3
	stage_mgr.stage_enemy = 5
	assert(stage_mgr.is_boss_battle(), "Stage 3 Enemy 5 should be boss battle")

	print("Stage Manager boss battle & enemy species: OK!")
	stage_mgr.free()

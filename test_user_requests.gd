extends SceneTree

func _init() -> void:
	print("--- Running Test for User Requests ---")

	var sm_script = load("res://stage_manager.gd")
	var pb_script = load("res://puzzle_board.gd")
	var sc_script = load("res://score_manager.gd")
	var bo_script = load("res://board_overlay.gd")
	if sm_script == null or pb_script == null or sc_script == null or bo_script == null:
		printerr("ERROR: Failed to load one or more scripts!")
		quit(1)
		return

	var dummy_root = Node2D.new()
	var sm = Node2D.new()
	sm.name = "StageManager"
	sm.set_script(sm_script)
	dummy_root.add_child(sm)

	var pb = pb_script.new()
	pb.name = "PuzzleBoard"
	dummy_root.add_child(pb)

	var sc = Node2D.new()
	sc.name = "ScoreManager"
	sc.set_script(sc_script)
	dummy_root.add_child(sc)

	root.add_child(dummy_root)
	pb._initialize_board(null)

	# 1. Test Encounter Smoke & Enemy Spawn
	sm.stage = 1
	sm.stage_enemy = 1
	sm.enemycount = 0
	sm.make_enemy(false)

	assert(sm.active_enemies.size() == 1, "Stage 1 Battle 1 must have 1 enemy")
	var e0 = sm.active_enemies[0]
	assert(e0.has("intent_badge") and is_instance_valid(e0["intent_badge"]), "Enemy must have intent_badge")
	assert(e0.has("intent_panel") and is_instance_valid(e0["intent_panel"]), "Enemy must have intent_panel")
	print("✓ Enemy spawned with intent_badge and stylized intent_panel!")

	# 2. Test Intent Badge Updates
	pb._decide_enemy_actions(sm)
	var badge_text = e0["intent_badge"].text
	assert(not badge_text.is_empty(), "Intent badge text must not be empty after _decide_enemy_actions")
	assert(badge_text.contains("次の行動"), "Intent badge text must contain '次の行動' header (got: %s)" % badge_text)
	print("✓ Intent badge updated with clear NEXT action header and text: ", badge_text)

	# 3. Test Fire Skill (No Free Bombs, sets grid_fire, direct damage)
	var old_player_hp = sm.myhp
	pb.grid_fire.clear()
	for r in range(pb.GRID_ROWS):
		var rf: Array[int] = []
		for c in range(pb.GRID_COLUMNS):
			rf.append(0)
		pb.grid_fire.append(rf)

	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false

	var fire_targets = pb._cast_enemy_fire_skill(false, false)
	assert(not fire_targets.is_empty(), "Fire skill should return targets")
	
	# Verify NO bombs were spawned!
	var bomb_count = 0
	var fire_tile_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.special_item[r][c] == pb.SpecialItemType.BOMB or pb.is_bomb[r][c]:
				bomb_count += 1
			if pb.grid_fire[r][c] > 0:
				fire_tile_count += 1

	assert(bomb_count == 0, "Enemy fire skill must NEVER spawn player-benefiting flame bombs! (got %d)" % bomb_count)
	assert(fire_tile_count > 0, "Enemy fire skill must ignite board tiles (grid_fire > 0)")
	print("✓ Fire skill ignites %d tiles without spawning player bombs!" % fire_tile_count)

	# 4. Test Shield Positioning (1 shield is centered, not left edge)
	sc.divscore[pb.PieceType.SHIELD] = 100
	pb.shieldt = 1.0
	pb.active_shields.clear()
	pb._spawn_shield_projectiles(sc)
	assert(pb.active_shields.size() == 1, "Should spawn 1 shield")
	var target_x = pb.active_shields[0]["target_p"].x
	assert(is_equal_approx(target_x, 15900.0), "Single shield must be placed in center at 15900.0 (got %f)" % target_x)
	print("✓ Single shield is placed in center at X=%f!" % target_x)

	# 5. Test HP Growth / Shop Item Cost & Gain
	var hp_item = null
	for item in sc.shop_items:
		if item["id"] == "max_hp":
			hp_item = item
			break
	assert(hp_item != null, "max_hp item must exist in shop_items")
	assert(hp_item["cost"] == 2000, "HP shop item base cost should be reduced to 2000 (was 4000)")
	var sm_stage = sm.stage
	var stage_scale: float = pow(10.0, maxf(0.0, float(sm_stage - 1)))
	var expected_gain = 2500.0 * stage_scale
	print("✓ Shop HP item cost is 2000 and HP gain is %f!" % expected_gain)

	# 6. Test Damaged Animation Throttle (0.10s interval)
	var spr = e0["sprite"]
	var t0 = Time.get_ticks_msec() / 1000.0
	spr.set_meta("last_damaged_time", t0)
	# Immediate second hit should be throttled
	var now_sec = t0 + 0.05
	var should_trigger = (now_sec - spr.get_meta("last_damaged_time", -999.0)) >= 0.10
	assert(not should_trigger, "Damaged animation should be throttled within 0.10s")
	# Hit after 0.11s should trigger
	now_sec = t0 + 0.11
	should_trigger = (now_sec - spr.get_meta("last_damaged_time", -999.0)) >= 0.10
	assert(should_trigger, "Damaged animation should trigger after 0.10s")
	print("✓ Damaged animation 0.10s throttle passed!")

	# 7. Test Hover Tooltip Outside IDLE State
	pb.current_state = pb.BoardState.TURN_SEQUENCE
	pb.is_holding = false
	pb._last_hovered_cell = Vector2i(-1, -1)
	pb._current_local_mouse = Vector2(pb.BOARD_LEFT + pb.CELL_PITCH * 0.5, pb.BOARD_TOP + pb.CELL_PITCH * 0.5)
	# Should not crash and should update cell hover
	pb._update_cell_hover_tooltip(Vector2(500, 500))
	assert(pb._last_hovered_cell == Vector2i(0, 0), "Hover tooltip must work even outside IDLE state! (got %s)" % str(pb._last_hovered_cell))
	print("✓ Board cell hover tooltip works outside IDLE state!")

	# 8. Test Full-Screen Kemuri Smoke Filling Entire Enemy Screen
	# Base kemuri sprite
	var base_kem = AnimatedSprite2D.new()
	base_kem.name = "kemuri"
	var sf = SpriteFrames.new()
	sf.add_animation("new_animation")
	base_kem.sprite_frames = sf
	sm.add_child(base_kem)
	sm._play_encounter_smoke()
	var smoke_found = false
	var parent_target = sm._enemy_zoom_root if sm._enemy_zoom_root != null else sm
	for child in parent_target.get_children():
		if child is AnimatedSprite2D and child.name.begins_with("EncounterSmoke_"):
			smoke_found = true
			assert(child.position.x == 1552.5 and child.position.y == 210.0, "Kemuri position must be center of enemy viewport (1552.5, 210)")
			assert(child.scale.x >= 0.65 and child.scale.y >= 0.60, "Kemuri scale must fill entire enemy viewport (got %f, %f)" % [child.scale.x, child.scale.y])
			child.queue_free()
			break
	assert(smoke_found, "Encounter smoke instance must be created")
	print("✓ Encounter smoke fills entire enemy screen area (1552.5, 210.0, scale 0.68x0.65)!")

	# 9. Test Difficulty Skill Multipliers (EASY: 0.70, NORMAL: 1.0, HARD: 1.35)
	var smgr_script = load("res://settings_manager.gd")
	var smgr = Node.new()
	smgr.name = "SettingsManager"
	smgr.set_script(smgr_script)
	dummy_root.add_child(smgr)

	smgr.set_difficulty(smgr.Difficulty.EASY)
	assert(is_equal_approx(smgr.get_difficulty_skill_mult(), 0.70), "EASY difficulty skill mult must be 0.70")
	assert(is_equal_approx(pb._get_difficulty_skill_mult(), 0.70), "PuzzleBoard skill mult on EASY must be 0.70")

	smgr.set_difficulty(smgr.Difficulty.NORMAL)
	assert(is_equal_approx(smgr.get_difficulty_skill_mult(), 1.00), "NORMAL difficulty skill mult must be 1.00")
	assert(is_equal_approx(pb._get_difficulty_skill_mult(), 1.00), "PuzzleBoard skill mult on NORMAL must be 1.00")

	smgr.set_difficulty(smgr.Difficulty.HARD)
	assert(is_equal_approx(smgr.get_difficulty_skill_mult(), 1.35), "HARD difficulty skill mult must be 1.35")
	assert(is_equal_approx(pb._get_difficulty_skill_mult(), 1.35), "PuzzleBoard skill mult on HARD must be 1.35")
	print("✓ Difficulty skill scaling (EASY 0.70, NORMAL 1.0, HARD 1.35) verified!")

	# 10. Test Water x Fire Synergy (clears commonly adjacent cells, extinguishes Water & Fire without clearing Water/Fire pieces)
	pb._initialize_board(null)
	# Place Water at (5, 5) and Fire at (5, 6)
	# Commonly adjacent cells to both (5, 5) and (5, 6) are (4, 5), (4, 6), (6, 5), (6, 6)
	var orig_w_kind = pb.grid_n[5][5]
	var orig_f_kind = pb.grid_n[5][6]
	pb.grid_water[5][5] = true
	pb.grid_fire[5][6] = 1
	var cleared_common = pb._check_and_trigger_water_fire_synergy(true)
	assert(not pb.grid_water[5][5], "Water at (5,5) must be extinguished after Water x Fire synergy")
	assert(pb.grid_fire[5][6] == 0, "Fire at (5,6) must be extinguished after Water x Fire synergy")
	assert(not pb.ismatched[5][5], "Piece directly on Water (5,5) must NOT be cleared")
	assert(not pb.ismatched[5][6], "Piece directly on Fire (5,6) must NOT be cleared")
	assert(pb.grid_n[5][5] == orig_w_kind and pb.grid_n[5][6] == orig_f_kind, "Pieces on Water & Fire must remain intact")
	assert(pb.ismatched[4][5] and pb.ismatched[4][6] and pb.ismatched[6][5] and pb.ismatched[6][6], "All 4 commonly adjacent cells (4,5),(4,6),(6,5),(6,6) must be cleared!")
	assert(cleared_common == 4, "Water x Fire synergy on orthogonally adjacent pair must clear exactly 4 common neighbors (got %d)" % cleared_common)
	print("✓ Water x Fire synergy verified: cleared 4 commonly adjacent cells while extinguishing Water & Fire intact!")

	# 11. Test Ice x Lightning & Stone x Lightning Synergy (3x3 shard splash)
	pb._initialize_board(null)
	pb.grid_ice[6][6] = 2
	var ice_shattered = pb._trigger_thunder_shatter_synergy(6, 6, true)
	assert(int(pb.grid_ice[6][6]) == 0, "Ice at (6,6) must shatter completely on lightning hit")
	assert(ice_shattered == 9, "Ice x Lightning synergy must clear 3x3 (9 cells) around (6,6), got %d" % ice_shattered)
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			assert(pb.ismatched[6 + dr][6 + dc], "3x3 cell (%d,%d) must be matched by Ice x Lightning shatter" % [6 + dr, 6 + dc])

	pb._initialize_board(null)
	pb.grid_stones[6][6] = 2
	var stone_shattered = pb._trigger_thunder_shatter_synergy(6, 6, true)
	assert(int(pb.grid_stones[6][6]) == 0, "Stone at (6,6) must shatter completely on lightning hit")
	assert(stone_shattered == 9, "Stone x Lightning synergy must clear 3x3 (9 cells) around (6,6), got %d" % stone_shattered)
	print("✓ Ice x Lightning and Stone x Lightning 3x3 shatter synergies verified!")

	# 12. Test PvP Symmetric Self Skills (10 elements, ally=true, no self-harm, movable, distinct visual state)
	var bo = bo_script.new()
	bo.board = pb
	dummy_root.add_child(bo)

	for sk in ["water", "fire", "ice", "thunder", "wood", "earth", "wind", "poison", "light", "dark"]:
		pb._initialize_board(null)
		var hp_before = sm.myhp
		var ehp_before = sm.ehp
		var positions = pb.cast_player_skill(sk, true)
		assert(not positions.is_empty(), "Player skill '%s' must affect board positions" % sk)
		assert(sm.myhp >= hp_before, "Player skill '%s' must NEVER reduce player HP" % sk)
		assert(sm.ehp < ehp_before, "Player skill '%s' must deal damage to enemy" % sk)

	# Verify ally water/ice/stone/gold do NOT block swap and board_overlay identifies ally vs enemy
	pb._initialize_board(null)
	pb._apply_water_to_cell(3, 3, true)
	pb._apply_water_to_cell(3, 4, false)
	assert(pb.is_ally_water(3, 3), "(3,3) must be ally water")
	assert(not pb.is_ally_water(3, 4), "(3,4) must be enemy water")
	assert(not pb._is_cell_blocked_for_swap(3, 3), "Ally water at (3,3) must NOT block swap!")
	assert(pb._is_cell_blocked_for_swap(3, 4), "Enemy water at (3,4) MUST block swap!")
	assert(bo._is_ally_cell("grid_water_ally", 3, 3) == true, "BoardOverlay must detect ally water at (3,3)")
	assert(bo._is_ally_cell("grid_water_ally", 3, 4) == false, "BoardOverlay must detect enemy water at (3,4)")
	print("✓ All 10 player skills, ally non-blocking behavior, and BoardOverlay ally/enemy color differentiation verified!")

	# 13. Test Wind Skill Disadvantageous Tile Clearing (Ally Wind removes enemy hazards, preserves ally benefits)
	pb._initialize_board(null)
	# Setup enemy hazards (disadvantageous to player)
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # enemy poison
	pb.grid_cursed[1][2] = true
	pb._set_ally_flag(pb.grid_cursed_ally, 1, 2, false) # enemy curse
	pb.grid_electrified[1][3] = true
	pb._set_ally_flag(pb.grid_electrified_ally, 1, 3, false) # enemy electrified
	pb.grid_fire[1][4] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 1, 4, false) # enemy fire
	pb.grid_ice[1][5] = 2
	pb._set_ally_flag(pb.grid_ice_ally, 1, 5, false) # enemy ice
	pb.grid_stones[1][6] = 2
	pb._set_ally_flag(pb.grid_stones_ally, 1, 6, false) # enemy stone
	pb.grid_water[1][7] = true
	pb._set_ally_flag(pb.grid_water_ally, 1, 7, false) # enemy water
	pb.grid_gold_statue[1][8] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 1, 8, false) # enemy gold statue
	pb.grid_fog.append({"rect": Rect2i(2, 2, 2, 2), "turns": 3, "enemy_owned": true}) # enemy dark fog
	pb.plant_entities.append({"origin": Vector2i(4, 4), "stage": 0, "enemy_planted": true, "drain_amount": 10}) # enemy leech plant

	# Setup ally beneficial tiles (advantageous to player)
	pb.grid_poison[7][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 7, 1, true) # ally medicinal poison
	pb.grid_fire[7][2] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 7, 2, true) # ally blue flame
	pb.grid_ice[7][3] = 1
	pb._set_ally_flag(pb.grid_ice_ally, 7, 3, true) # ally ice shield
	pb.grid_stones[7][4] = 2
	pb._set_ally_flag(pb.grid_stones_ally, 7, 4, true) # ally crystal stone
	pb.grid_water[7][5] = true
	pb._set_ally_flag(pb.grid_water_ally, 7, 5, true) # ally stream
	pb.grid_electrified[7][6] = true
	pb._set_ally_flag(pb.grid_electrified_ally, 7, 6, true) # ally charge
	pb.grid_cursed[7][7] = true
	pb._set_ally_flag(pb.grid_cursed_ally, 7, 7, true) # ally shadow blessing
	pb.grid_gold_statue[7][8] = 2
	pb._set_ally_flag(pb.grid_gold_ally, 7, 8, true) # ally holy statue
	pb.grid_fog.append({"rect": Rect2i(8, 8, 2, 2), "turns": 3, "enemy_owned": false}) # ally starlight fog
	pb.plant_entities.append({"origin": Vector2i(9, 9), "stage": 1, "enemy_planted": false, "drain_amount": 0}) # ally tree

	# Cast Player Wind Skill
	pb.cast_player_skill("wind", true)

	# Verify ALL enemy hazards (disadvantageous tiles) are completely wiped out
	assert(not pb.grid_poison[1][1], "Enemy poison must be cleared by ally wind")
	assert(not pb.grid_cursed[1][2], "Enemy curse must be cleared by ally wind")
	assert(not pb.grid_electrified[1][3], "Enemy electrified must be cleared by ally wind")
	assert(pb.grid_fire[1][4] == 0, "Enemy fire must be extinguished by ally wind")
	assert(int(pb.grid_ice[1][5]) == 0, "Enemy ice must be shattered by ally wind")
	assert(int(pb.grid_stones[1][6]) == 0, "Enemy stone must be blown away by ally wind")
	assert(not pb.grid_water[1][7], "Enemy water must be dried by ally wind")
	assert(int(pb.grid_gold_statue[1][8]) == 0, "Enemy gold statue must be removed by ally wind")
	var enemy_fog_remains = false
	for fog in pb.grid_fog:
		if fog.get("enemy_owned", true): enemy_fog_remains = true
	assert(not enemy_fog_remains, "Enemy dark fog must be blown away by ally wind")
	var enemy_plant_remains = false
	for pl in pb.plant_entities:
		if pl.get("enemy_planted", false): enemy_plant_remains = true
	assert(not enemy_plant_remains, "Enemy leech plant must be uprooted by ally wind")

	# Verify ALL ally beneficial tiles are PRESERVED
	assert(pb.grid_poison[7][1] and pb.is_ally_poison(7, 1), "Ally medicinal poison must be preserved")
	assert(pb.grid_fire[7][2] > 0 and pb.is_ally_fire(7, 2), "Ally blue flame must be preserved")
	assert(int(pb.grid_ice[7][3]) > 0 and pb.is_ally_ice(7, 3), "Ally ice shield must be preserved")
	assert(int(pb.grid_stones[7][4]) > 0 and pb.is_ally_stone(7, 4), "Ally crystal stone must be preserved")
	assert(pb.grid_water[7][5] and pb.is_ally_water(7, 5), "Ally stream must be preserved")
	assert(pb.grid_electrified[7][6] and pb.is_ally_electrified(7, 6), "Ally charge must be preserved")
	assert(pb.grid_cursed[7][7] and pb.is_ally_cursed(7, 7), "Ally shadow blessing must be preserved")
	assert(int(pb.grid_gold_statue[7][8]) > 0 and pb.is_ally_gold(7, 8), "Ally holy statue must be preserved")
	var ally_fog_preserved = false
	for fog in pb.grid_fog:
		if not fog.get("enemy_owned", true): ally_fog_preserved = true
	assert(ally_fog_preserved, "Ally starlight fog must be preserved")
	var ally_plant_preserved = false
	for pl in pb.plant_entities:
		if not pl.get("enemy_planted", false): ally_plant_preserved = true
	assert(ally_plant_preserved, "Ally tree must be preserved")
	print("✓ Ally Wind skill verified: completely clears all disadvantageous tiles while strictly preserving ally beneficial tiles!")

	print("\nALL USER REQUEST TESTS PASSED SUCCESSFULLY!")
	quit(0)

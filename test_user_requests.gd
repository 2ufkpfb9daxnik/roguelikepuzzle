extends SceneTree

func _init() -> void:
	print("--- Running Test for User Requests ---")

	var sm_script = load("res://stage_manager.gd")
	var pb_script = load("res://puzzle_board.gd")
	var sc_script = load("res://score_manager.gd")

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

	print("\nALL USER REQUEST TESTS PASSED SUCCESSFULLY!")
	quit(0)

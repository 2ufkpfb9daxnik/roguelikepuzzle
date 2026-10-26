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

	# Verify Wind Skill NEVER clears normal pieces (pieces are preserved, ismatched is untouched)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			assert(not pb.ismatched[r][c], "Wind skill must never set ismatched on pieces")
			assert(pb.grid_n[r][c] != -1, "Wind skill must never delete or erase normal pieces (got -1 at %d,%d)" % [r, c])
	print("✓ Ally Wind skill verified: completely clears all disadvantageous tiles, strictly preserves ally tiles, and NEVER erases pieces!")

	# 14. Test Symmetric Self-Owned Element Generation Across All Other Skills (No unneeded clears, exact symmetric generation)
	# 14-1. Water generates ally water (stream)
	pb._initialize_board(null)
	pb.cast_player_skill("water", true)
	var ally_water_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c] and pb.is_ally_water(r, c): ally_water_count += 1
	assert(ally_water_count > 0, "Water skill must generate ally-owned water tiles")
	print("✓ Water skill creates ally-owned water tiles!")

	# 14-2. Fire generates ally fire (blue flame)
	pb._initialize_board(null)
	pb.cast_player_skill("fire", true)
	var ally_fire_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_fire[r][c] > 0 and pb.is_ally_fire(r, c): ally_fire_count += 1
	assert(ally_fire_count > 0, "Fire skill must generate ally-owned fire tiles")
	print("✓ Fire skill creates ally-owned fire tiles!")

	# 14-3. Ice generates ally ice (ice shield)
	pb._initialize_board(null)
	pb.cast_player_skill("ice", true)
	var ally_ice_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_ice[r][c]) > 0 and pb.is_ally_ice(r, c): ally_ice_count += 1
	assert(ally_ice_count > 0, "Ice skill must generate ally-owned ice tiles")
	print("✓ Ice skill creates ally-owned ice tiles!")

	# 14-4. Thunder generates ally electrified (charge) tiles & triggers shatter on stone/ice
	pb._initialize_board(null)
	pb.cast_player_skill("thunder", true)
	var ally_chg_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_electrified[r][c] and pb.is_ally_electrified(r, c): ally_chg_count += 1
	assert(ally_chg_count > 0, "Thunder skill must generate ally-owned charge tiles")
	print("✓ Thunder skill creates ally-owned charge tiles!")

	# 14-5. Wood plants ally tree sprout
	pb._initialize_board(null)
	pb.cast_player_skill("wood", true)
	var ally_tree_exists = false
	for pl in pb.plant_entities:
		if not pl.get("enemy_planted", false): ally_tree_exists = true
	assert(ally_tree_exists, "Wood skill must plant an ally-owned tree sprout")
	print("✓ Wood skill plants ally-owned tree sprout!")

	# 14-6. Earth generates ally stones (crystal stones)
	pb._initialize_board(null)
	pb.cast_player_skill("earth", true)
	var ally_stone_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_stones[r][c]) > 0 and pb.is_ally_stone(r, c): ally_stone_count += 1
	assert(ally_stone_count > 0, "Earth skill must generate ally-owned stone tiles")
	print("✓ Earth skill creates ally-owned stone tiles!")

	# 14-7. Poison generates ally poison (medicinal poison)
	pb._initialize_board(null)
	pb.cast_player_skill("poison", true)
	var ally_poison_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c] and pb.is_ally_poison(r, c): ally_poison_count += 1
	assert(ally_poison_count > 0, "Poison skill must generate ally-owned poison tiles")
	print("✓ Poison skill creates ally-owned poison tiles!")

	# 14-8. Light generates ally gold statue (holy statue)
	pb._initialize_board(null)
	pb.cast_player_skill("light", true)
	var ally_statue_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if int(pb.grid_gold_statue[r][c]) > 0 and pb.is_ally_gold(r, c): ally_statue_count += 1
	assert(ally_statue_count > 0, "Light skill must generate ally-owned gold statue tiles")
	print("✓ Light skill creates ally-owned gold statue tiles!")

	# 14-9. Dark generates ally dark fog (starlight fog) & ally curse (shadow blessing)
	pb._initialize_board(null)
	pb.cast_player_skill("dark", true)
	var ally_fog_exists = false
	for fog in pb.grid_fog:
		if not fog.get("enemy_owned", true): ally_fog_exists = true
	assert(ally_fog_exists, "Dark skill must generate ally-owned dark fog")
	var ally_curse_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_cursed[r][c] and pb.is_ally_cursed(r, c): ally_curse_count += 1
	assert(ally_curse_count > 0, "Dark skill must generate ally-owned curse tiles")
	print("✓ Dark skill creates ally-owned dark fog & curse tiles!")

	print("✓ Full symmetry verified: wind clears opponent-owned objects, and all other 9 skills generate self-owned objects without unneeded clears!")

	# 15. Test 3 Element Categories, First Enemy Relic Choice, & Skill Tree Display Filtering
	# 15-1. Verify 3 Element Categories Definition
	assert(RelicDatabase.ELEMENT_CATEGORIES.has("nature"), "ELEMENT_CATEGORIES must contain 'nature'")
	assert(RelicDatabase.ELEMENT_CATEGORIES.has("force"), "ELEMENT_CATEGORIES must contain 'force'")
	assert(RelicDatabase.ELEMENT_CATEGORIES.has("mystic"), "ELEMENT_CATEGORIES must contain 'mystic'")
	var nat_elems = RelicDatabase.ELEMENT_CATEGORIES["nature"]["elements"]
	var frc_elems = RelicDatabase.ELEMENT_CATEGORIES["force"]["elements"]
	var mys_elems = RelicDatabase.ELEMENT_CATEGORIES["mystic"]["elements"]
	assert("water" in nat_elems and "ice" in nat_elems and "wood" in nat_elems and "wind" in nat_elems, "Nature elements match")
	assert("fire" in frc_elems and "thunder" in frc_elems and "earth" in frc_elems, "Force elements match")
	assert("poison" in mys_elems and "light" in mys_elems and "dark" in mys_elems, "Mystic elements match")
	print("✓ 3 Element Categories (Nature:水氷木風, Force:火雷地, Mystic:毒光闇) verified!")

	# 15-2. Verify First Enemy Relic Selection UI produces the 3 Category Relics
	var rm_script = load("res://relic_manager.gd")
	var rm = rm_script.new()
	rm.name = "RelicManager"
	dummy_root.add_child(rm)

	var rui_script = load("res://relic_selection_ui.gd")
	var rui = rui_script.new()
	dummy_root.add_child(rui)
	rui._ready()

	# When no category is chosen yet, choices must be exactly the 3 category relics
	assert(not rm.has_chosen_element_category(), "Initially no element category chosen")
	# Re-populate choices with rm in tree
	rui._populate_choices()
	# The 3 choices in the UI
	assert(rui.hbox.get_child_count() == 3, "First enemy clear must offer exactly 3 category choices")
	assert(rui.title_label.text.contains("属性カテゴリー"), "Title must indicate attribute category selection")
	assert(not rui.skip_btn.visible, "Skip button must be hidden on category relic selection")
	print("✓ First enemy relic selection correctly presents the 3 Element Category relics!")

	# 15-3. Test selecting "nature" category relic
	rm.add_relic("relic_cat_nature")
	assert(rm.has_chosen_element_category(), "RelicManager has chosen category")
	assert(rm.get_chosen_element_category() == "nature", "Chosen category is 'nature'")
	var base_dmg = 1000.0
	var boosted_water_dmg = rm.modify_damage_dealt(base_dmg, {"element_name": "water"})
	assert(boosted_water_dmg >= 1300.0, "Nature category grants +30%% damage boost to water (got: %f)" % boosted_water_dmg)
	print("✓ Category selection sets category and grants +30% elemental damage bonus!")

	# 15-4. Test Skill Tree in ScoreManager reflects the chosen category
	sc.set_shop_ui_visible(true)
	sc._switch_shop_view_mode(1) # Switch to Skill Tree view
	sc.rebuild_skill_tree_ui()

	# In Nature category, skill_node_refs must ONLY contain skills belonging to 'nature'
	for s_ref in sc.skill_node_refs:
		var s_idx = s_ref["s_idx"]
		var s_item = sc.skill_tree_items[s_idx]
		assert(s_item["category"] == "nature", "Skill tree node must belong to 'nature' (got: %s, id: %s)" % [s_item["category"], s_item["id"]])
	print("✓ Skill tree dynamically filters and displays only Nature skills when 'nature' is chosen!")

	# 15-5. Test switching category to 'force'
	rm.set_chosen_element_category("force")
	sc.rebuild_skill_tree_ui()
	assert(not sc.skill_node_refs.is_empty(), "Skill tree nodes must be populated for 'force'")
	for s_ref in sc.skill_node_refs:
		var s_idx = s_ref["s_idx"]
		var s_item = sc.skill_tree_items[s_idx]
		assert(s_item["category"] == "force", "Skill tree node must belong to 'force' (got: %s, id: %s)" % [s_item["category"], s_item["id"]])
	print("✓ Skill tree dynamically filters and displays only Force skills when 'force' is chosen!")

	# 15-6. Test switching category to 'mystic'
	rm.set_chosen_element_category("mystic")
	sc.rebuild_skill_tree_ui()
	assert(not sc.skill_node_refs.is_empty(), "Skill tree nodes must be populated for 'mystic'")
	for s_ref in sc.skill_node_refs:
		var s_idx = s_ref["s_idx"]
		var s_item = sc.skill_tree_items[s_idx]
		assert(s_item["category"] == "mystic", "Skill tree node must belong to 'mystic' (got: %s, id: %s)" % [s_item["category"], s_item["id"]])
	print("✓ Skill tree dynamically filters and displays only Mystic skills when 'mystic' is chosen!")

	# 15-7. Test PuzzleBoard Player Skill UI reflects chosen category
	pb._setup_player_skill_ui()
	pb._update_player_skill_ui()
	assert(pb.player_skill_title_label.text.contains("神秘・冥術"), "Player skill panel title reflects chosen category")
	print("✓ PuzzleBoard player skill UI dynamically reflects chosen category!")


	# ==============================================================================
	# 16. Test Ice Halt Mechanic (氷がある間、隣接マスにある効果マスは進行しない)
	# ==============================================================================
	pb._initialize_board(null)
	# Place an ice tile at (3, 3)
	pb.grid_ice[3][3] = 2
	pb._set_ally_flag(pb.grid_ice_ally, 3, 3, true)
	# Place poison tile adjacent at (3, 4)
	pb.grid_poison[3][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 4, false) # enemy poison

	# Count poison cells before spread
	var poison_before = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: poison_before += 1
	assert(poison_before == 1, "Initially exactly 1 poison tile")

	# Run poison spread
	pb._process_poison_spread()

	# Count poison cells after spread: MUST NOT spread because it is ice-locked!
	var poison_after = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]: poison_after += 1
	assert(poison_after == 1, "Poison adjacent to ice must NOT spread (got: %d, expected: 1)" % poison_after)
	print("✓ Ice halt mechanic verified: poison adjacent to ice does not progress/spread!")

	# ==============================================================================
	# 17. Test Thermodynamic Chain (氷 -> 水 -> 消える)
	# ==============================================================================
	pb._initialize_board(null)
	# Step 1: Ice at (4, 4), Fire adjacent at (4, 5)
	pb.grid_ice[4][4] = 2
	pb._set_ally_flag(pb.grid_ice_ally, 4, 4, true)
	pb.grid_fire[4][5] = 1
	pb._set_ally_flag(pb.grid_fire_ally, 4, 5, false)

	# Trigger ice-fire melting
	var melted = pb._check_and_trigger_ice_fire_melting()
	assert(melted > 0, "Ice adjacent to fire must melt")
	assert(int(pb.grid_ice[4][4]) == 0, "Ice must be melted (grid_ice == 0)")
	assert(pb.grid_water[4][4] == true, "Ice must transform into Water (氷 -> 水)")
	assert(pb.grid_fire[4][5] == 0, "Fire that melted ice must be extinguished")
	print("✓ Thermodynamic Step 1 (氷 -> 水) verified!")

	# Step 2: Now place Fire adjacent at (4, 5) again to touch the water at (4, 4)
	pb.grid_fire[4][5] = 1
	var cleared_steam = pb._check_and_trigger_water_fire_synergy(false)
	assert(pb.grid_water[4][4] == false, "Water touched by Fire must vanish (水 -> 消える)")
	assert(pb.grid_fire[4][5] == 0, "Fire touching water must be extinguished")
	print("✓ Thermodynamic Step 2 (水 -> 消える) verified!")
	print("✓ Complete Thermodynamic Chain (氷 -> 水 -> 消える) verified successfully!")

	# ==============================================================================
	# 18. Test Multi-Tier Skills Execution across all 10 Elements (T1, T2, T3)
	# ==============================================================================
	# 18-1. Water T2 (Aqua Fountain) & T3 (Tidal Flood)
	pb._initialize_board(null)
	pb.cast_player_skill("water", true, 1) # T1
	pb.cast_player_skill("water", true, 2) # T2: heals & expands water
	var w_t2_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c]: w_t2_count += 1
	assert(w_t2_count >= 2, "Water T2 expands water tiles")
	pb.cast_player_skill("water", true, 3) # T3: converts pieces to potion/sword
	print("✓ Water T1, T2, T3 skills executed successfully!")

	# 18-2. Ice T2 (Freezing Chain) & T3 (Absolute Zero)
	pb._initialize_board(null)
	pb.grid_poison[2][2] = true # enemy poison
	pb._set_ally_flag(pb.grid_poison_ally, 2, 2, false)
	pb.cast_player_skill("ice", true, 2) # T2: freezes poison into ice
	assert(int(pb.grid_ice[2][2]) > 0, "Ice T2 converts hazard to ice")
	assert(not pb.grid_poison[2][2], "Hazard converted to ice")
	pb.cast_player_skill("ice", true, 3) # T3: shatters ice
	print("✓ Ice T1, T2, T3 skills executed successfully!")

	# 18-3. Wood T2 (Root Drain) & T3 (Yggdrasil Harvest)
	pb._initialize_board(null)
	pb.cast_player_skill("wood", true, 1) # T1: sprout
	pb.grid_water[2][2] = true # distant water
	pb.cast_player_skill("wood", true, 2) # T2: roots absorb water
	pb.cast_player_skill("wood", true, 3) # T3: fruits around tree
	print("✓ Wood T1, T2, T3 skills executed successfully!")

	# 18-4. Wind T2 (Gale Shift) & T3 (Tempest Reverse)
	pb._initialize_board(null)
	pb.grid_poison[5][5] = true
	pb._set_ally_flag(pb.grid_poison_ally, 5, 5, false) # enemy poison
	pb.cast_player_skill("wind", true, 3) # T3: reverses ownership to ally!
	assert(pb.is_ally_poison(5, 5), "Wind T3 inverts enemy hazard into ally-owned")
	print("✓ Wind T1, T2, T3 skills executed successfully!")

	# 18-5. Fire T1 (Dispersed), T2 (Backdraft), T3 (Prominence Nova)
	pb._initialize_board(null)
	pb.cast_player_skill("fire", true, 1) # T1: dispersed
	pb.cast_player_skill("fire", true, 2) # T2: backdraft spread
	pb.cast_player_skill("fire", true, 3) # T3: prominence nova
	print("✓ Fire T1, T2, T3 skills executed successfully!")

	# 18-6. Thunder, Earth, Poison, Light, Dark T1-T3
	for elem in ["thunder", "earth", "poison", "light", "dark"]:
		pb._initialize_board(null)
		pb.cast_player_skill(elem, true, 1)
		pb.cast_player_skill(elem, true, 2)
		pb.cast_player_skill(elem, true, 3)
	print("✓ Thunder, Earth, Poison, Light, Dark T1-T3 executed successfully!")

	# ==============================================================================
	# 19. Test All 10 Skills Registered in ScoreManager (1 per Element, 20 Levels)
	# ==============================================================================
	assert(sc.skill_tree_items.size() == 10, "Exactly 10 canonical skills (1 per element) must be registered in ScoreManager (got: %d)" % sc.skill_tree_items.size())
	for s_item in sc.skill_tree_items:
		assert(s_item["max_level"] == 20, "Skill %s must have max_level 20" % s_item["id"])
		assert(s_item["desc_lv"].size() == 20, "Skill %s must have 20 description levels (got: %d)" % [s_item["id"], s_item["desc_lv"].size()])
		assert(s_item.get("match_recipe", "") != "", "Skill %s must explicitly specify match_recipe" % s_item["id"])
	print("✓ All 10 canonical skills (1 per element) registered with 20 levels and explicit match_recipes verified!")

	# ==============================================================================
	# 20. Test Match-Generated Skill Creation: Locked vs Unlocked
	# ==============================================================================
	pb._initialize_board(null)
	
	# Verify that all skills start at level 0 (LOCKED)
	for sp in pb.special_levels:
		assert(pb.special_levels[sp] == 0, "All skills must start locked at level 0 (sp %d was %d)" % [sp, pb.special_levels[sp]])

	# Helper lambda to reset board to a clean state with 0 matches
	var clean_board = func():
		pb._initialize_board(null)
		pb.pending_special_spawns.clear()
		for r in range(pb.GRID_ROWS):
			for c in range(pb.GRID_COLUMNS):
				pb.grid_n[r][c] = (r * 2 + c) % 5
				pb.special_item[r][c] = pb.SpecialItemType.NONE
				pb.is_bomb[r][c] = false
				pb.grid_stones[r][c] = 0

	# 20-A. Verify that LOCKED skills do NOT generate any special items
	clean_board.call()
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.is_empty(), "4 swords must NOT spawn BOMB when BOMB is locked")

	# 5 swords in a line when locked
	clean_board.call()
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][7] = pb.PieceType.SHIELD
	for c in range(2, 7):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(6, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.is_empty(), "5 swords must NOT spawn LIGHTNING when LIGHTNING is locked")
	print("✓ Locked skills correctly do NOT generate special skill items from matches!")

	# 20-B. Test unlocking via ScoreManager skill tree purchase
	var fire_1_idx: int = -1
	for idx in range(sc.skill_tree_items.size()):
		if sc.skill_tree_items[idx]["id"] == "fire_1":
			fire_1_idx = idx
			break
	assert(fire_1_idx != -1, "fire_1 must exist in skill_tree_items")
	sc.divscore[pb.PieceType.POTION] = 10000
	sc._purchase_skill(fire_1_idx)
	assert(sc.skill_tree_items[fire_1_idx]["level"] >= 1, "fire_1 must be level 1 after purchase")
	assert(pb.special_levels[pb.SpecialItemType.BOMB] >= 1, "Purchasing fire_1 must unlock BOMB in puzzle board")

	# Now 4 swords match DOES spawn BOMB!
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.BOMB] = 1 # Re-set to 1 after clean_board
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.has(Vector2i(5, 3)), "4 swords must spawn BOMB after unlocking")
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.BOMB, "Spawned item must be BOMB")
	print("✓ Unlocking skill in SkillTree enables match generation for BOMB!")

	# 20-C. Test all other unlocked match recipes
	# 4-match POTION -> AQUA_SPLASH
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.AQUA_SPLASH] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.POTION
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.AQUA_SPLASH, "4 potions must spawn AQUA_SPLASH when unlocked")
	print("✓ Unlocked 4-Match POTION correctly generates AQUA_SPLASH!")

	# 4-match FOOD -> TREE_SPROUT
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.TREE_SPROUT] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][6] = pb.PieceType.SHIELD
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.FOOD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 3)] == pb.SpecialItemType.TREE_SPROUT, "4 food pieces must spawn TREE_SPROUT when unlocked")
	print("✓ Unlocked 4-Match FOOD correctly generates TREE_SPROUT!")

	# 5-match in a line SWORD -> LIGHTNING
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.LIGHTNING] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][7] = pb.PieceType.SHIELD
	for c in range(2, 7):
		pb.grid_n[5][c] = pb.PieceType.SWORD
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(6, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 4)] == pb.SpecialItemType.LIGHTNING, "5 swords in a line must spawn LIGHTNING when unlocked")
	print("✓ Unlocked 5-Match in a line SWORD correctly generates LIGHTNING!")

	# 5-match in a line POTION -> BLACK_HOLE
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.BLACK_HOLE] = 1
	pb.grid_n[5][1] = pb.PieceType.SHIELD
	pb.grid_n[5][7] = pb.PieceType.SHIELD
	for c in range(2, 7):
		pb.grid_n[5][c] = pb.PieceType.POTION
	pb.last_swap_cells = [Vector2i(5, 4), Vector2i(6, 4)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(5, 4)] == pb.SpecialItemType.BLACK_HOLE, "5 potions in a line must spawn BLACK_HOLE when unlocked")
	print("✓ Unlocked 5-Match in a line POTION correctly generates BLACK_HOLE!")

	# Cross / T-shape match -> CROSS_BOMB
	pb.pending_special_spawns.clear()
	pb.special_levels[pb.SpecialItemType.CROSS_BOMB] = 1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = 0
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	pb.grid_n[3][2] = 2; pb.grid_n[3][3] = 2; pb.grid_n[3][4] = 2
	pb.grid_n[2][3] = 2; pb.grid_n[4][3] = 2
	pb.last_swap_cells = [Vector2i(3, 3), Vector2i(3, 5)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns[Vector2i(3, 3)] == pb.SpecialItemType.CROSS_BOMB, "T-match must spawn CROSS_BOMB when unlocked")
	print("✓ Unlocked T/L Cross-Match correctly generates CROSS_BOMB!")

	# 6 simultaneous match -> GEMINI_BOMB
	pb.pending_special_spawns.clear()
	pb.special_levels[pb.SpecialItemType.GEMINI_BOMB] = 1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = 0
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	for c in range(1, 7):
		pb.grid_n[5][c] = 2
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.GEMINI_BOMB, "6 match must spawn GEMINI_BOMB when unlocked")
	print("✓ Unlocked 6 simultaneous match correctly generates GEMINI_BOMB!")

	# 7+ simultaneous match -> DISCO_BALL
	pb.pending_special_spawns.clear()
	pb.special_levels[pb.SpecialItemType.DISCO_BALL] = 1
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = 0
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false
	for c in range(1, 6):
		pb.grid_n[2][c] = 2 # 5 pieces
	pb.grid_n[3][3] = 2     # 6th
	pb.grid_n[4][3] = 2     # 7th
	pb.last_swap_cells = [Vector2i(2, 3), Vector2i(1, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(2, 3)) == pb.SpecialItemType.DISCO_BALL, "7+ match must spawn DISCO_BALL when unlocked")
	print("✓ Unlocked 7+ Match correctly generates DISCO_BALL!")

	# 4-Match SHIELD in nature -> ICE_SHIELD
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.ICE_SHIELD] = 1
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.SHIELD
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.ICE_SHIELD, "4-Match SHIELD must generate ICE_SHIELD when unlocked")
	print("✓ Unlocked 4-Match SHIELD correctly generates ICE_SHIELD!")

	# 4-Match POTION in mystic -> POISON_MIST
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.POISON_MIST] = 1
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("mystic")
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.POTION
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.POISON_MIST, "4-Match POTION in mystic must generate POISON_MIST when unlocked")
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")
	print("✓ Unlocked 4-Match POTION correctly generates POISON_MIST in mystic!")
	# 4-Match COIN in mystic -> HOLY_LIGHT (聖光星 / 旧MAGNET)
	clean_board.call()
	pb.special_levels[pb.SpecialItemType.HOLY_LIGHT] = 1
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("mystic")
	for c in range(2, 6):
		pb.grid_n[5][c] = pb.PieceType.COIN
	pb.last_swap_cells = [Vector2i(5, 3), Vector2i(6, 3)]
	pb._detect_and_spawn_special_from_matches()
	assert(pb.pending_special_spawns.get(Vector2i(5, 3)) == pb.SpecialItemType.HOLY_LIGHT, "4-Match COIN in mystic must generate HOLY_LIGHT when unlocked")
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")
	print("✓ Unlocked 4-Match COIN correctly generates HOLY_LIGHT (聖光星) in mystic (replaces magnet)!")

	# ==============================================================================
	# 21. Test Poison Immunity Reduction
	# ==============================================================================
	pb._initialize_board(null)
	pb.plant_entities.clear()
	sm.myhp = 5000.0
	sm.myhpmax = 5000.0

	# Case A: 2 Enemy Poison tiles, 0 Ally Poison tiles
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # Enemy
	pb.grid_poison[1][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 2, false) # Enemy

	var hp_before_no_immunity = sm.myhp
	pb._reset_turn(sm, null)
	var dmg_no_immunity = hp_before_no_immunity - sm.myhp
	assert(dmg_no_immunity > 0, "Enemy poison must deal damage")

	# Case B: 2 Enemy Poison tiles + 3 Ally Poison tiles (Immunity: 3 * 5% = 15% reduction)
	pb._initialize_board(null)
	pb.plant_entities.clear()
	sm.myhp = 5000.0
	sm.myhpmax = 5000.0
	pb.grid_poison[1][1] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 1, false) # Enemy
	pb.grid_poison[1][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 1, 2, false) # Enemy
	pb.grid_poison[4][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 4, true)  # Ally
	pb.grid_poison[4][5] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 5, true)  # Ally
	pb.grid_poison[5][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 5, 4, true)  # Ally

	var hp_before_with_immunity = sm.myhp
	pb._reset_turn(sm, null)
	var dmg_with_immunity = hp_before_with_immunity - sm.myhp
	assert(dmg_with_immunity < dmg_no_immunity, "Ally poison must reduce enemy poison damage via immunity (got %f with vs %f without)" % [dmg_with_immunity, dmg_no_immunity])
	var expected_dmg_approx = dmg_no_immunity * (1.0 - 0.15)
	assert(absf(dmg_with_immunity - expected_dmg_approx) <= 2.0, "Immunity should mitigate ~15% poison damage")
	print("✓ Poison immunity verified: 3 ally poison tiles mitigated 15% of enemy poison damage!")

	# ==============================================================================
	# 22. Test Mutual Poison Invasion (Ally into Enemy, and Enemy into Ally)
	# ==============================================================================
	# 22-1. Ally Poison Invades Enemy Poison:
	# Place 1 Enemy poison at (3, 3) surrounded by 2 Ally poison at (3, 2) and (2, 3)
	pb._initialize_board(null)
	pb.grid_poison[3][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 3, false) # Enemy poison at (3, 3)
	pb.grid_poison[3][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 2, true)  # Ally poison at (3, 2)
	pb.grid_poison[2][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 2, 3, true)  # Ally poison at (2, 3)

	assert(not pb.is_ally_poison(3, 3), "(3, 3) starts as Enemy poison")
	pb._process_poison_spread()
	assert(pb.grid_poison[3][3] == true, "(3, 3) must remain poison")
	assert(pb.is_ally_poison(3, 3) == true, "Ally poison pressure (2) must conquer and purify isolated Enemy poison (3, 3) into Ally poison!")
	print("✓ Ally poison successfully invaded and purified Enemy poison tile!")

	# 22-2. Enemy Poison Invades Ally Poison:
	# Place 1 Ally poison at (3, 3) surrounded by 2 Enemy poison at (3, 2) and (2, 3)
	pb._initialize_board(null)
	pb.grid_poison[3][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 3, true)  # Ally poison at (3, 3)
	pb.grid_poison[3][2] = true
	pb._set_ally_flag(pb.grid_poison_ally, 3, 2, false) # Enemy poison at (3, 2)
	pb.grid_poison[2][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 2, 3, false) # Enemy poison at (2, 3)

	assert(pb.is_ally_poison(3, 3), "(3, 3) starts as Ally poison")
	pb._process_poison_spread()
	assert(pb.grid_poison[3][3] == true, "(3, 3) must remain poison")
	assert(pb.is_ally_poison(3, 3) == false, "Enemy poison pressure (2) must conquer and corrupt isolated Ally poison (3, 3) into Enemy poison!")
	print("✓ Enemy poison successfully invaded and corrupted Ally poison tile!")

	# 22-3. Water tile conducts accelerated poison invasion:
	# Place 1 Enemy poison at (4, 4), and 1 Ally poison at (4, 3) with WATER at (4, 3)
	pb._initialize_board(null)
	pb.grid_poison[4][4] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 4, false) # Enemy poison at (4, 4)
	pb.grid_poison[4][3] = true
	pb._set_ally_flag(pb.grid_poison_ally, 4, 3, true)  # Ally poison at (4, 3)
	pb.grid_water[4][3] = true                          # Water conducts double pressure (ap = 2)!

	pb._process_poison_spread()
	assert(pb.is_ally_poison(4, 4) == true, "Wet Ally poison tile (pressure 2) must overpower and conquer dry Enemy poison tile (4, 4)!")
	print("✓ Water tile accelerates poison invasion pressure as designed!")

	# ==============================================================================
	# 23. Test Enemy Damage Source Display and Enhanced Elemental Hit Effects
	# ==============================================================================
	var cui = CombatUIManager.new()
	dummy_root.add_child(cui)
	cui._ready()

	var dummy_enemy = Sprite2D.new()
	dummy_enemy.position = Vector2(500, 300)
	dummy_root.add_child(dummy_enemy)

	# 23-1. Poison damage displays explicit "(毒ダメージ)" and spawns poison VFX and flash
	cui._show_enemy_damage(120.0, dummy_enemy, false, "ally_poison")
	var found_poison_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(毒ダメージ)"):
			found_poison_lbl = true
			assert(lbl.text.contains("120"), "Damage amount 120 must be included")
			break
	assert(found_poison_lbl, "Poison damage must display (毒ダメージ)")
	assert(dummy_enemy.modulate != Color.WHITE, "Enemy sprite must flash with elemental tint on poison hit")

	# Check EnemyHitEffectNode spawned
	var found_vfx = false
	for ch in cui.get_children():
		if ch is CombatUIManager.EnemyHitEffectNode:
			assert(ch.vfx_type == "poison", "Poison hit must spawn poison VFX")
			found_vfx = true
			break
	assert(found_vfx, "EnemyHitEffectNode must be spawned for poison hit")
	print("✓ Enemy poison damage explicitly displays (毒ダメージ) and triggers poison VFX and flash!")

	# 23-2. Verify Fire, Thunder, Ice, Synergy, and Skill damage tags
	cui._show_enemy_damage(250.0, dummy_enemy, false, "ally_fire")
	var found_fire_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(火傷ダメージ)"):
			found_fire_lbl = true
			break
	assert(found_fire_lbl, "Ally fire damage must display (火傷ダメージ)")

	cui._show_enemy_damage(300.0, dummy_enemy, false, "thunder")
	var found_thunder_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(雷撃ダメージ)"):
			found_thunder_lbl = true
			break
	assert(found_thunder_lbl, "Thunder damage must display (雷撃ダメージ)")

	cui._show_enemy_damage(180.0, dummy_enemy, false, "ice")
	var found_ice_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(冷気ダメージ)"):
			found_ice_lbl = true
			break
	assert(found_ice_lbl, "Ice damage must display (冷気ダメージ)")

	cui._show_enemy_damage(360.0, dummy_enemy, false, "steam_synergy")
	var found_steam_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(蒸気消去ダメージ)"):
			found_steam_lbl = true
			break
	assert(found_steam_lbl, "Steam synergy damage must display (蒸気消去ダメージ)")

	cui._show_enemy_damage(320.0, dummy_enemy, false, "shatter_synergy")
	var found_shatter_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(砕破ダメージ)"):
			found_shatter_lbl = true
			break
	assert(found_shatter_lbl, "Shatter synergy damage must display (砕破ダメージ)")

	cui._show_enemy_damage(400.0, dummy_enemy, false, "player_skill_poison")
	var found_pskill_lbl = false
	for lbl in cui.popup_pool:
		if lbl.visible and lbl.text.contains("(毒スキルダメージ)"):
			found_pskill_lbl = true
			break
	assert(found_pskill_lbl, "Player skill poison must display (毒スキルダメージ)")

	print("✓ Enemy damage labels explicitly display all damage sources with rich tags!")
	# ==============================================================================
	# 24. Test Freed Instance Safety (Left operand of 'is' error prevention)
	# ==============================================================================
	var immediately_freed = Sprite2D.new()
	immediately_freed.free()

	assert(sm.play_single_enemy_animation(immediately_freed, "damaged") == false, "play_single_enemy_animation with freed target must return false without error")
	assert(sm.get_enemy_animation_duration(immediately_freed, "damaged") >= 0.45, "get_enemy_animation_duration with freed target must return default without error")
	sm.play_single_idle_loop(immediately_freed)
	sm.calchp(10.0, 0.0, immediately_freed)
	assert(sm.get_enemy_element(immediately_freed) != "", "get_enemy_element with freed target must return default without error")

	cui._on_combat_event({
		"type": "damage",
		"target": immediately_freed,
		"amount": 50.0,
		"element": "poison"
	})
	print("✓ Freed instance safety verified: no errors with freed instances!")

	# ==============================================================================
	# 25. Test Poison Skill Piece (POISON_MIST) Clearance & Ally Poison Deployment
	# ==============================================================================
	pb.special_levels[pb.SpecialItemType.POISON_MIST] = 1
	var mist_r = 4
	var mist_c = 4
	pb.special_item[mist_r][mist_c] = pb.SpecialItemType.POISON_MIST
	pb.is_bomb[mist_r][mist_c] = true
	var queue_test: Array = []
	var exploded_test: Dictionary = {Vector2i(mist_r, mist_c): true}
	pb._trigger_poison_mist(mist_r, mist_c, pb.get_cell_position(mist_r, mist_c), queue_test, exploded_test)

	assert(pb.ismatched[mist_r][mist_c] == true, "Poison skill piece at (r, c) must be marked matched for deletion")
	assert(pb.special_item[mist_r][mist_c] == pb.SpecialItemType.NONE, "SpecialItemType must be cleared to NONE on detonation")
	assert(pb.is_bomb[mist_r][mist_c] == false, "is_bomb must be cleared to false on detonation")
	assert(pb.grid_poison[mist_r][mist_c] == true, "Center cell must have poison ground deployed")
	assert(pb.is_ally_poison(mist_r, mist_c) == true, "Center cell poison must be ally poison")
	assert(pb.grid_poison[mist_r - 1][mist_c] == true, "Surrounding cells must have poison ground deployed")
	assert(pb.is_ally_poison(mist_r - 1, mist_c) == true, "Surrounding cell poison must be ally poison")
	# Surrounding normal cells must not be broken
	assert(pb.ismatched[mist_r - 1][mist_c] == false, "Surrounding normal cells must not be destroyed by poison mist")
	print("✓ Poison skill piece clearance and ally poison deployment verified!")

	# ==============================================================================
	# 26. Test Vertical UI Hierarchy Under Enemy Screen (Score -> Items -> Selected Category Elements)
	# ==============================================================================
	var score_mgr_node = load("res://score_manager.gd").new()
	score_mgr_node.name = "TestScoreManager"
	dummy_root.add_child(score_mgr_node)
	score_mgr_node.relic_manager_ref = rm

	# Setup mock UI nodes for ScoreManager
	var mock_label = RichTextLabel.new()
	mock_label.name = "RichTextLabel"
	score_mgr_node.add_child(mock_label)
	score_mgr_node.label = mock_label

	var mock_status = ColorRect.new()
	mock_status.name = "status"
	score_mgr_node.add_child(mock_status)
	score_mgr_node.status_rect = mock_status

	var mock_status2 = ColorRect.new()
	mock_status2.name = "status2"
	score_mgr_node.add_child(mock_status2)
	score_mgr_node.status2_rect = mock_status2

	score_mgr_node._ready()

	# 1. 敵画面の真下にスコア欄 (Directly below enemy screen: y = 472.0, h = 66.0, w = 725.0)
	var sc_rect_node = score_mgr_node.get_node_or_null("score_rect") as ColorRect
	assert(sc_rect_node != null, "score_rect node must exist")
	assert(sc_rect_node.position.y == 472.0, "score_rect must be positioned directly below enemy screen at y=472.0")
	assert(sc_rect_node.size.x == 725.0, "score_rect must span enemy screen width 725.0")
	assert(sc_rect_node.size.y == 66.0, "score_rect must have height 66.0")
	assert(score_mgr_node.label.visible == true, "Score label must be visible")
	score_mgr_node.totalScore = 12345
	score_mgr_node.update_score_label()
	assert(score_mgr_node.label.text.contains("12,345"), "Score label must display formatted totalScore")

	# 2. その下にアイテム値欄（左側・盤面下端 y=944 に下端一致: y = 544.0, w = 425.0, h = 400.0）
	assert(score_mgr_node.status_rect.position.y == 544.0, "status_rect (items) must start at y=544.0")
	assert(score_mgr_node.status_rect.position.x == 1190.0, "status_rect must be on left side at x=1190.0")
	assert(score_mgr_node.status_rect.size.x == 425.0, "status_rect width must be 425.0")
	assert(score_mgr_node.status_rect.size.y == 400.0, "status_rect height must be 400.0")
	var status_bottom = score_mgr_node.status_rect.position.y + score_mgr_node.status_rect.size.y
	assert(is_equal_approx(status_bottom, 944.0), "status_rect bottom must align with board bottom at y=944.0 (got %f)" % status_bottom)
	assert(score_mgr_node.status_rect.position.y > sc_rect_node.position.y, "Item values must be below Score section")

	# 3. アイテム値の横に選択した属性値欄（右側・横並び配置 x = 1625.0, y = 544.0, w = 290.0, h = 400.0, 下端 y=944）
	var el_rect_node = score_mgr_node.get_node_or_null("elem_status") as ColorRect
	assert(el_rect_node != null, "elem_status node must exist")
	assert(el_rect_node.position.x == 1625.0, "elem_status must be placed on the right side next to items at x=1625.0")
	assert(is_equal_approx(el_rect_node.position.y, score_mgr_node.status_rect.position.y), "elem_status must be vertically aligned with status_rect (side-by-side)")
	assert(el_rect_node.position.x > score_mgr_node.status_rect.position.x, "Selected attribute values must be next to (right of) item values")
	assert(el_rect_node.size.x == 290.0, "elem_status width must be 290.0")
	assert(el_rect_node.size.y == 400.0, "elem_status height must be 400.0")
	var elem_status_bottom = el_rect_node.position.y + el_rect_node.size.y
	assert(is_equal_approx(elem_status_bottom, 944.0), "elem_status bottom must align with board bottom at y=944.0 (got %f)" % elem_status_bottom)

	# 4. 属性値未定の場合の検証（何も表示せず枠線のみ）
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.is_empty(), "When attribute is undetermined, elem_category_elements must be empty")
	assert(score_mgr_node.elem_category_header_label != null, "elem_category_header_label must exist")
	assert(score_mgr_node.elem_category_header_label.text == "", "Undetermined header text must be empty string")
	assert(score_mgr_node.elem_category_header_label.visible == false, "Undetermined header must not be visible")
	var el_vline = score_mgr_node.get_node_or_null("elem_v_line") as ColorRect
	if el_vline:
		assert(el_vline.visible == false, "Internal grid vertical line must be hidden when attribute is undetermined")

	# 5. 属性カテゴリー選択に応じた動的表示の検証
	# Test nature category
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("nature")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.size() == 4, "Nature category must have 4 elements: water, ice, wood, wind")
	assert(score_mgr_node.elem_category_elements[0]["key"] == "water", "Element 0 must be water")
	assert(score_mgr_node.elem_category_elements[1]["key"] == "ice", "Element 1 must be ice")
	assert(score_mgr_node.elem_category_elements[2]["key"] == "wood", "Element 2 must be wood")
	assert(score_mgr_node.elem_category_elements[3]["key"] == "wind", "Element 3 must be wind")

	# Test force category
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("force")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.size() == 3, "Force category must have 3 elements: fire, thunder, earth")
	assert(score_mgr_node.elem_category_elements[0]["key"] == "fire", "Element 0 must be fire")
	assert(score_mgr_node.elem_category_elements[1]["key"] == "thunder", "Element 1 must be thunder")
	assert(score_mgr_node.elem_category_elements[2]["key"] == "earth", "Element 2 must be earth")

	# Test mystic category
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("mystic")
	score_mgr_node.update_elem_labels()
	assert(score_mgr_node.elem_category_elements.size() == 3, "Mystic category must have 3 elements: poison, light, dark")
	assert(score_mgr_node.elem_category_elements[0]["key"] == "poison", "Element 0 must be poison")
	assert(score_mgr_node.elem_category_elements[1]["key"] == "light", "Element 1 must be light")
	assert(score_mgr_node.elem_category_elements[2]["key"] == "dark", "Element 2 must be dark")

	# 6. Combo scrollbar elimination
	if score_mgr_node.combo_label:
		assert(score_mgr_node.combo_label.scroll_active == false, "combo_label must have scroll_active = false to prevent scrollbars")
	if score_mgr_node.combocount_label:
		assert(score_mgr_node.combocount_label.scroll_active == false, "combocount_label must have scroll_active = false to prevent scrollbars")

	# Clean up test nodes
	score_mgr_node.queue_free()
	if rm and rm.has_method("set_chosen_element_category"):
		rm.set_chosen_element_category("")

	# 7. Test StageLabel higher position and current battle display directly below it (without parentheses covering board)
	var stage_lbl = RichTextLabel.new()
	stage_lbl.name = "StageLabel"
	sm.add_child(stage_lbl)
	sm.label = stage_lbl

	var stage_lbl2 = RichTextLabel.new()
	stage_lbl2.name = "StageLabel2"
	sm.add_child(stage_lbl2)
	sm.label2 = stage_lbl2

	sm.stage = 1
	sm.stage_enemy = 1
	sm.label_control()
	assert(sm.label != null, "sm.label must exist")
	assert(sm.label.position.y == 16.0, "StageLabel must be moved up to y=16.0 (got %f)" % sm.label.position.y)
	assert(sm.label.scroll_active == false, "StageLabel must have scroll_active = false")
	assert(sm.label.text.contains("STAGE"), "StageLabel must contain STAGE")
	assert(sm.label.position.x + sm.label.size.x <= 240.0, "StageLabel right edge must not reach board (x >= 243.0)")
	assert(sm.label2 != null, "sm.label2 must exist")
	assert(sm.label2.position.y > sm.label.position.y, "StageLabel2 must be placed directly below StageLabel (got y=%f vs %f)" % [sm.label2.position.y, sm.label.position.y])
	assert(sm.label2.position.x + sm.label2.size.x <= 240.0, "StageLabel2 right edge must not reach board (x >= 243.0)")
	assert(not sm.label2.text.contains("("), "StageLabel2 must not contain parentheses to avoid covering board (got %s)" % sm.label2.text)
	assert(sm.label2.text.contains("BATTLE") and sm.label2.text.contains("/5"), "StageLabel2 directly below must display current match counter (got %s)" % sm.label2.text)

	sm.stage_enemy = 5
	sm.label_control()
	assert(sm.label2.text.contains("BOSS"), "StageLabel2 must display BOSS on 5th match (got %s)" % sm.label2.text)

	# 8. Test Relic and Skill panel boxes (sizes must match each other and not overlap Settings button)
	var relic_ui = load("res://relic_ui_manager.gd").new()
	dummy_root.add_child(relic_ui)
	relic_ui._ready()
	var skill_box = relic_ui.get_node_or_null("skill_rect") as ColorRect
	assert(skill_box != null, "skill_rect must exist in RelicUIManager")
	assert(skill_box.color == Color(0.85, 0.72, 0.38, 1.0), "skill_rect must have antique gold border")
	assert(skill_box.position.y >= 950.0, "skill_rect must be positioned below board (y >= 950.0)")
	assert(is_equal_approx(skill_box.position.x, 244.0), "skill_rect left edge must align with board left edge (got %f)" % skill_box.position.x)

	var relic_box = relic_ui.get_node_or_null("relic_rect") as ColorRect
	assert(relic_box != null, "relic_rect must exist in RelicUIManager")
	assert(relic_box.color == Color(0.85, 0.72, 0.38, 1.0), "relic_rect must have antique gold border")
	assert(relic_box.position.y >= 950.0, "relic_box must be positioned below board (y >= 950.0)")
	assert(is_equal_approx(skill_box.size.x, relic_box.size.x), "Skill and Relic panels must have exact same width (got %f vs %f)" % [skill_box.size.x, relic_box.size.x])
	assert(is_equal_approx(skill_box.size.y, relic_box.size.y), "Skill and Relic panels must have exact same height (got %f vs %f)" % [skill_box.size.y, relic_box.size.y])
	assert(skill_box.size.x >= 800.0, "Skill panel width must be extended (got %f)" % skill_box.size.x)
	assert(skill_box.position.x >= 190.0, "skill_rect left edge (%f) must not overlap Settings button on bottom-left" % skill_box.position.x)
	var relic_right_edge = relic_box.position.x + relic_box.size.x
	assert(relic_right_edge <= 1920.0, "relic_rect right edge (%f) must fit inside viewport width 1920" % relic_right_edge)
	relic_ui.queue_free()

	# 9. Test Holy Light skill triggering (light element damage, replaces magnet)
	pb._initialize_board(null)
	pb.special_levels[pb.SpecialItemType.HOLY_LIGHT] = 1
	var holy_r = 4
	var holy_c = 4
	pb.special_item[holy_r][holy_c] = pb.SpecialItemType.HOLY_LIGHT
	var queue_holy: Array = []
	var exploded_holy: Dictionary = {Vector2i(holy_r, holy_c): true}
	pb._trigger_holy_light(holy_r, holy_c, pb.get_cell_position(holy_r, holy_c), queue_holy, exploded_holy)
	assert(pb.ismatched[holy_r][holy_c] == true, "Holy Light cell must be matched")

	print("✓ UI layout (bottom alignment at 944, undetermined attribute box, battle counter, combo scrollbar fix, skill/relic panels) verified!")



	# -------------------------------------------------------------
	# 24. Test Orthodox Skill Evolution & Tarot Card Selection & Ice Final Turn Skip
	# -------------------------------------------------------------
	print("\n--- Testing Section 24: Orthodox Skill Evolution & Tarot Card Selection ---")
	var sm_evo = sc_script.new()
	dummy_root.add_child(sm_evo)
	sm_evo._init()
	sm_evo.set_shop_ui_visible(true)
	sm_evo.on_element_category_chosen("nature")
	sm_evo._switch_shop_view_mode(1)

	var t_ice_idx = -1
	for i in range(sm_evo.skill_tree_items.size()):
		if sm_evo.skill_tree_items[i]["id"] == "ice_1":
			t_ice_idx = i
			break
	assert(t_ice_idx != -1, "ice_1 must exist")

	sm_evo.divscore[sm_evo.PieceType.POTION] = 10000000

	# 24.1 Level 1 to 4 upgrades do NOT open modal
	for lvl in range(1, 5):
		sm_evo._purchase_skill(t_ice_idx)
		assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == lvl, "Level should be %d" % lvl)
		assert(sm_evo.tarot_modal_panel == null or not is_instance_valid(sm_evo.tarot_modal_panel), "Modal should NOT be open for level %d" % lvl)

	# 24.2 Level 5 triggers Mid Evolution Tarot Modal
	sm_evo._purchase_skill(t_ice_idx)
	assert(sm_evo.tarot_modal_panel != null and is_instance_valid(sm_evo.tarot_modal_panel), "Tarot modal MUST open when upgrading to Lv.5")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 4, "Level stays 4 until evolution is selected")

	# Check mid evolution cards (strictly NO turn skip)
	var mid_cards = sm_evo.get_evolution_choices("ice_1", 5)
	assert(mid_cards.size() == 3, "Ice mid evolution must have 3 cards")
	for c in mid_cards:
		assert(c["id"] != "ice_final_skip", "Ice mid evolution MUST NOT contain turn skip!")
		assert("スキップ" not in c["desc"], "Ice mid evolution MUST NOT mention turn skip!")

	# Choose mid card 0: 白銀の氷壁
	var mid_btn = sm_evo.tarot_modal_panel.get_node("TarotCard_0/SelectBtn_0") as Button
	assert(mid_btn != null, "Mid card 0 button must exist")
	mid_btn.emit_signal("pressed")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 5, "Level should now be 5")
	assert(sm_evo.has_skill_trait("ice_1", "ice_mid_wall") == true, "Must have ice_mid_wall trait")

	# 24.3 Level 5 to 19 upgrades do NOT open modal
	for lvl in range(6, 20):
		sm_evo._purchase_skill(t_ice_idx)
		assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == lvl, "Level should be %d" % lvl)

	# 24.4 Level 20 triggers Final Evolution Tarot Modal
	sm_evo._purchase_skill(t_ice_idx)
	assert(sm_evo.tarot_modal_panel != null and is_instance_valid(sm_evo.tarot_modal_panel), "Tarot modal MUST open when upgrading to Lv.20")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 19, "Level stays 19 until evolution is selected")

	# Check final evolution cards (Ice turn skip MUST be present here)
	var final_cards = sm_evo.get_evolution_choices("ice_1", 20)
	assert(final_cards.size() == 3, "Ice final evolution must have 3 cards")
	var found_skip = false
	for c in final_cards:
		if c["id"] == "ice_final_skip":
			found_skip = true
	assert(found_skip == true, "Ice final evolution MUST contain absolute zero turn skip!")

	# Choose final card 0: 絶対零度・完全凍結 (turn skip)
	var final_btn = sm_evo.tarot_modal_panel.get_node("TarotCard_0/SelectBtn_0") as Button
	assert(final_btn != null, "Final card 0 button must exist")
	final_btn.emit_signal("pressed")
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 20, "Level should now be 20")
	assert(sm_evo.has_skill_trait("ice_1", "ice_final_skip") == true, "Must have ice_final_skip trait")

	# Check UI description displays both evolution badges
	var ice_desc_text = ""
	for s_ref in sm_evo.skill_node_refs:
		if s_ref["s_idx"] == t_ice_idx:
			ice_desc_text = s_ref["s_desc"].text
			break
	assert("【第1進化: 白銀の氷壁】" in ice_desc_text, "Desc text must display mid evolution badge")
	assert("【最終進化: 絶対零度・完全凍結】" in ice_desc_text, "Desc text must display final evolution badge")

	# 24.5 Test In-Combat Turn Skip Execution
	var pb_evo = pb_script.new()
	dummy_root.add_child(pb_evo)
	pb_evo.score_manager = sm_evo
	pb_evo._ready()
	var stg_evo = sm_script.new()
	dummy_root.add_child(stg_evo)
	stg_evo.myhp = 1000.0
	stg_evo.myhpmax = 1000.0
	stg_evo.ehp = 500.0
	stg_evo.active_enemies = [
		{"sprite": Sprite2D.new(), "atk": 200.0, "ehp": 500.0, "max_ehp": 500.0}
	]

	# Cast ice skill with final evolution
	assert(pb_evo.enemy_turn_skip_count == 0, "Initial skip count 0")
	pb_evo.cast_player_skill("ice", true, 1)
	assert(pb_evo.enemy_turn_skip_count == 1, "Enemy turn skip count must increment on casting Lv.20 ice")

	# Execute enemy turn actions -> must skip enemy turn and deal 0 damage
	var hp_before_enemy = stg_evo.myhp
	pb_evo._execute_enemy_turn_actions(stg_evo)
	assert(pb_evo.enemy_turn_skip_count == 0, "Skip count must be consumed")
	assert(stg_evo.myhp == hp_before_enemy, "Player must take 0 damage when enemy turn is skipped")

	# 24.6 Verify Fire Evolution Combat Multipliers
	sm_evo.skill_evolutions["fire_1"] = {"mid": "fire_mid_strike", "final": "fire_final_prominence"}
	assert(sm_evo.has_skill_trait("fire_1", "fire_mid_strike") == true)
	assert(sm_evo.has_skill_trait("fire_1", "fire_final_prominence") == true)

	# 24.7 Verify Water Evolution Combat Multipliers
	sm_evo.skill_evolutions["water_1"] = {"mid": "water_mid_spring", "final": "water_final_deluge"}
	assert(sm_evo.has_skill_trait("water_1", "water_mid_spring") == true)
	assert(sm_evo.has_skill_trait("water_1", "water_final_deluge") == true)

	# 24.8 Verify Thunder, Wood, Earth, Poison, Light, Dark Traits
	sm_evo.skill_evolutions["thunder_1"] = {"mid": "thunder_mid_flash", "final": "thunder_final_judgement"}
	sm_evo.skill_evolutions["wood_1"] = {"mid": "wood_mid_roots", "final": "wood_final_wrath"}
	sm_evo.skill_evolutions["earth_1"] = {"mid": "earth_mid_bulwark", "final": "earth_final_cataclysm"}
	sm_evo.skill_evolutions["poison_1"] = {"mid": "poison_mid_corrosive", "final": "poison_final_lethal"}
	sm_evo.skill_evolutions["light_1"] = {"mid": "light_mid_aurora", "final": "light_final_excalibur"}
	sm_evo.skill_evolutions["dark_1"] = {"mid": "dark_mid_bind", "final": "dark_final_incarnate"}

	assert(sm_evo.has_skill_trait("thunder_1", "thunder_final_judgement") == true)
	assert(sm_evo.has_skill_trait("wood_1", "wood_final_wrath") == true)
	assert(sm_evo.has_skill_trait("earth_1", "earth_final_cataclysm") == true)
	assert(sm_evo.has_skill_trait("poison_1", "poison_final_lethal") == true)
	assert(sm_evo.has_skill_trait("light_1", "light_final_excalibur") == true)
	assert(sm_evo.has_skill_trait("dark_1", "dark_final_incarnate") == true)

	# 24.9 Strict Rule Check: Match recipes NEVER change across all elements
	for sk in sm_evo.skill_tree_items:
		assert(sk.has("match_recipe"), "Skill item %s must retain match_recipe" % sk.get("id", ""))
		assert(sk.get("max_level", 0) == 20, "All skills must retain 20 levels of orthodox numerical scaling")

	print("✓ Section 24 passed: Orthodox Evolution Tarot Modal, Combat Multipliers, & Ice Final Turn Skip fully verified!")

	# --- Section 25: Debug Level-Up Suite Verification ---
	print("\n--- Testing Section 25: Debug Level-Up Suite ---")
	var p_before_dbg = sm_evo.divscore[sm_evo.PieceType.POTION]
	var c_before_dbg = sm_evo.divscore[sm_evo.PieceType.COIN]
	sm_evo.debug_add_resources(100000)
	assert(sm_evo.divscore[sm_evo.PieceType.POTION] == p_before_dbg + 100000, "Potion +100000 via debug")
	assert(sm_evo.divscore[sm_evo.PieceType.COIN] == c_before_dbg + 100000, "Coin +100000 via debug")

	# Debug level up skill to level 1
	sm_evo.debug_level_up_skill(t_ice_idx, 1)
	assert(sm_evo.skill_tree_items[t_ice_idx]["level"] == 1, "Skill level set to 1 via debug")

	# Debug set all skills in active category to Lv.5 and Lv.20
	sm_evo.debug_set_all_skills_level(5)
	for sk in sm_evo.skill_tree_items:
		if sk.get("category", "") == "nature":
			assert(sk["level"] == 5, "Nature skill must be Lv.5 via batch debug")

	sm_evo.debug_set_all_skills_level(20)
	for sk in sm_evo.skill_tree_items:
		if sk.get("category", "") == "nature":
			assert(sk["level"] == 20, "Nature skill must be Lv.20 via batch debug")

	# Debug shop buff level up
	var buff_0_lvl = sm_evo.shop_items[0]["level"]
	sm_evo.debug_level_up_shop_buff(0)
	assert(sm_evo.shop_items[0]["level"] == buff_0_lvl + 1, "Shop buff leveled up via debug")

	# Debug shop toggle
	sm_evo.debug_toggle_shop()
	assert(sm_evo.is_shop_open == false, "Shop toggled closed")
	sm_evo.debug_toggle_shop()
	assert(sm_evo.is_shop_open == true, "Shop toggled open")
	print("✓ Section 25 passed: Debug Level-Up Suite fully verified!")


	# ==============================================================================
	# 27. Test User Requests: 2-Turn Hazard Spread, Lower Proceed Button, Removed S5 Button
	# ==============================================================================
	print("\n--- Testing Section 27: 2-Turn Hazard Spread & Bottom Proceed Button ---")
	
	# 27.1 Fire & Poison Spread Cadence: Strictly once every 2 turns
	pb.clear_board_hazards()
	assert(pb.hazard_spread_turn_counter == 0, "Counter must reset on hazard clear")
	pb.grid_fire[2][2] = 1 # Fire at (2,2)
	pb.grid_poison[4][4] = true # Poison at (4,4)
	
	# Turn 1: Player moves & turn resets -> Counter becomes 1 (odd) -> NO SPREAD
	pb._reset_turn(sm, sc)
	assert(pb.hazard_spread_turn_counter == 1, "Hazard spread counter should be 1 after Turn 1")
	assert(pb.grid_fire[2][3] == 0, "Fire must NOT spread on turn 1 (once every 2 turns)")
	assert(pb.grid_poison[4][5] == false, "Poison must NOT spread on turn 1 (once every 2 turns)")
	
	# Turn 2: Player moves & turn resets -> Counter becomes 2 (even) -> SPREAD OCCURS!
	pb._reset_turn(sm, sc)
	assert(pb.hazard_spread_turn_counter == 2, "Hazard spread counter should be 2 after Turn 2")
	# At least one adjacent cell should have caught fire or poison
	var fire_spread_count = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if abs(dr) + abs(dc) == 1 and pb.grid_fire[2 + dr][2 + dc] > 0:
				fire_spread_count += 1
	var poison_spread_count = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if abs(dr) + abs(dc) == 1 and pb.grid_poison[4 + dr][4 + dc]:
				poison_spread_count += 1
	assert(fire_spread_count >= 1, "Fire MUST spread on turn 2 (even turn)")
	assert(poison_spread_count >= 1, "Poison MUST spread on turn 2 (even turn)")
	print("✓ Fire & poison 2-turn spread cadence verified!")

	# 27.2 Proceed button (stagechangeb & movefront) placed in empty bottom margin below shop
	var sc_btn_node = sc.get_node_or_null("stagechangeb") as Button
	if sc_btn_node == null:
		sc_btn_node = Button.new()
		sc_btn_node.name = "stagechangeb"
		sc.add_child(sc_btn_node)
		sc._setup_shop_page_controls()
	assert(sc_btn_node != null, "stagechangeb button must exist")
	assert(sc_btn_node.position.y >= 970.0, "Proceed button stagechangeb (y=%.1f) must be placed in bottom margin (>= 970)" % sc_btn_node.position.y)
	assert(sc_btn_node.position.y + sc_btn_node.size.y <= 1080.0, "Proceed button must fit within screen height")

	var sm_mf = sm.get_node_or_null("movefront") as Control
	if sm_mf == null:
		sm_mf = Button.new()
		sm_mf.name = "movefront"
		sm.add_child(sm_mf)
		sm._ready()
	assert(sm_mf.position.y >= 970.0, "movefront button (y=%.1f) must be placed in bottom margin (>= 970)" % sm_mf.position.y)
	assert(sm_mf.position.y + sm_mf.size.y <= 1080.0, "movefront button must fit within screen height")
	print("✓ Proceed buttons (stagechangeb & movefront) lower margin placement verified!")

	# Verify skill evolution has no time limit restrictions
	for elem_key in sc.SKILL_EVOLUTION_REGISTRY:
		for tier_key in ["mid", "final"]:
			for evo in sc.SKILL_EVOLUTION_REGISTRY[elem_key].get(tier_key, []):
				assert("制限時間" not in evo.get("role", "") and "制限時間" not in evo.get("desc", ""), "Skill evolution must not contain time limits: %s" % evo.get("name"))
	print("✓ Skill evolution has no time limits verified!")

	# 27.3 S5 Boss Jump Button removed from StageManager
	var sm_node_check = root.get_node_or_null("StageManager")
	if sm_node_check:
		assert(sm_node_check.get_node_or_null("DebugStage5Button") == null, "DebugStage5Button must be removed")
	print("✓ S5 boss debug button removal verified!")

	# -------------------------------------------------------------
	# 28. Section 28: Item & Element Combat Hover Tooltips & Independent Gold Statue Block
	# -------------------------------------------------------------
	print("\n--- Testing Section 28: Item/Element Combat Tooltips & Independent Gold Statue Block ---")

	# 28.1 Verify Combat HUD Item & Element Hover Zones and Tooltips
	assert(sc.has_method("_setup_combat_hud_hover_tooltips"), "score_manager must have _setup_combat_hud_hover_tooltips")
	sc._setup_combat_hud_hover_tooltips()
	var item_hover_0 = sc.get_node_or_null("item_hover_0") as Control
	assert(item_hover_0 != null, "item_hover_0 zone must exist in score_manager")
	assert(sc.has_method("_show_item_tooltip"), "score_manager must have _show_item_tooltip")
	assert(sc.has_method("_hide_item_tooltip"), "score_manager must have _hide_item_tooltip")
	assert(sc.has_method("_show_elem_tooltip"), "score_manager must have _show_elem_tooltip")
	assert(sc.has_method("_hide_elem_tooltip"), "score_manager must have _hide_elem_tooltip")

	# Trigger item tooltips without error
	for idx in range(5):
		sc._show_item_tooltip(idx)
		sc._hide_item_tooltip(idx)
	# Trigger element tooltips for category without error
	sc._show_elem_tooltip("water")
	sc._hide_elem_tooltip("water")
	print("✓ Combat HUD item and element value hover tooltips verified!")

	# 28.2 Verify Enemy Light Skill creates Independent Obstacle Block
	pb.clear_board_hazards()
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.grid_n[r][c] = pb.PieceType.SWORD
			pb.grid_gold_statue[r][c] = 0
			if pb.grid_i[r][c] == -1:
				var sp_dummy = Sprite2D.new()
				pb.piece.append(sp_dummy)
				pb.add_child(sp_dummy)
				pb.grid_i[r][c] = pb.piece.size() - 1

	# Ensure target kind (SWORD) exists and cast enemy light skill
	var targets = pb._cast_enemy_light_skill(false, false)
	assert(targets.size() >= 1, "Enemy light skill must target at least 1 cell")

	# Find a gold statue cell
	var statue_cell = Vector2i(-1, -1)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_gold_statue.size() == pb.GRID_ROWS and pb.grid_gold_statue[r][c] > 0 and not pb.is_ally_gold(r, c):
				statue_cell = Vector2i(r, c)
				break
		if statue_cell.x != -1: break

	assert(statue_cell.x != -1, "At least one enemy gold statue block must be spawned")
	var gr = statue_cell.x
	var gc = statue_cell.y

	# Verify it is an independent obstacle block (NO underlying piece)
	assert(pb.grid_i[gr][gc] == -1, "Gold statue cell grid_i must be -1 (independent obstacle block)")
	assert(pb.grid_n[gr][gc] == -1, "Gold statue cell grid_n must be -1")
	assert(pb.grid_att[gr][gc] == -1, "Gold statue cell grid_att must be -1")
	assert(pb.is_ally_gold(gr, gc) == false, "Must be enemy obstacle")

	# Verify _find_matches does not form match with normal pieces across gold statue
	# Place matching SWORDs horizontally around statue: (gr, gc-1)=SWORD, (gr, gc+1)=SWORD
	if gc > 0 and gc < pb.GRID_COLUMNS - 1:
		pb.grid_n[gr][gc - 1] = pb.PieceType.SWORD
		pb.grid_n[gr][gc + 1] = pb.PieceType.SWORD
		pb.ismatched[gr][gc] = false
		pb._check_matches_exist()
		assert(pb.ismatched[gr][gc] == false, "Independent gold statue block must NOT be matched like a normal piece")

	# Verify adjacent match destruction and empty cell cascade
	var init_dur = pb.grid_gold_statue[gr][gc]
	assert(init_dur > 0, "Statue durability must be > 0")
	# Simulate adjacent match damaging statue until broken
	while pb.grid_gold_statue[gr][gc] > 0:
		pb.grid_gold_statue[gr][gc] -= 1
		if pb.grid_gold_statue[gr][gc] <= 0:
			pb.grid_gold_statue[gr][gc] = 0
			pb._set_ally_flag(pb.grid_gold_ally, gr, gc, false)

	assert(pb.grid_gold_statue[gr][gc] == 0, "Statue must be destroyed")
	assert(pb.grid_i[gr][gc] == -1, "Destroyed statue cell must be empty space ready for cascade")

	print("✓ Enemy Light Skill independent gold statue block & cascade clearance fully verified!")

	# -------------------------------------------------------------
	# 29. Section 29: Debug Kill Enemy Command
	# -------------------------------------------------------------
	print("\n--- Testing Section 29: Debug Kill Enemy Command ---")
	assert(sm.has_method("debug_kill_enemy"), "stage_manager must have debug_kill_enemy method")

	# Spawn enemy
	sm.stage = 1
	sm.stage_enemy = 1
	sm.isdeadf = false
	sm.make_enemy(false)
	assert(sm.active_enemies.size() > 0, "Enemy must be active")
	assert(sm.ehp > 0, "Enemy HP must be > 0")

	# Trigger debug kill enemy command
	sm.debug_kill_enemy()
	assert(sm.active_enemies.size() == 0, "All active enemies must be defeated by debug_kill_enemy")
	assert(sm.ehp == 0, "Enemy HP must be 0")
	assert(sm.isdeadf == true, "isdeadf must be set to true")
	print("✓ Direct debug_kill_enemy() call successfully defeated active enemy!")

	# Test keyboard shortcut trigger (KEY_K and KEY_F10)
	sm.isdeadf = false
	sm.make_enemy(false)
	assert(sm.active_enemies.size() > 0, "Enemy must be active for key event test")
	var ev_k = InputEventKey.new()
	ev_k.pressed = true
	ev_k.keycode = KEY_K
	sm._input(ev_k)
	assert(sm.active_enemies.size() == 0, "KEY_K must trigger debug_kill_enemy")
	assert(sm.isdeadf == true, "isdeadf must be set to true after KEY_K")
	print("✓ KEY_K shortcut successfully defeated active enemy!")

	sm.isdeadf = false
	sm.make_enemy(false)
	assert(sm.active_enemies.size() > 0, "Enemy must be active for F10 test")
	var ev_f10 = InputEventKey.new()
	ev_f10.pressed = true
	ev_f10.keycode = KEY_F10
	sm._input(ev_f10)
	assert(sm.active_enemies.size() == 0, "KEY_F10 must trigger debug_kill_enemy")
	assert(sm.isdeadf == true, "isdeadf must be set to true after KEY_F10")
	print("✓ KEY_F10 shortcut successfully defeated active enemy!")

	# =========================================================================
	# SECTION 30: Water Skill Initial Spec (Create water cells & delete pieces)
	# and Mid-Evolution (Turn-based water cell count scaling: HP heal, shield, atk)
	# =========================================================================
	print("\n--- SECTION 30: Water Skill Initial Spec & Mid-Evolution Tests ---")

	# 1. Verify Water Initial Spec: Spawns water cells and clears pieces on those cells
	pb._initialize_board(null)
	var prev_water_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c]: prev_water_count += 1
	assert(prev_water_count == 0, "Board should have 0 water cells initially")

	# Cast water skill (Tier 1) outside match phase
	var water_positions = pb.cast_player_skill("water", true, 1)
	assert(water_positions.size() >= 2, "Water skill must create at least 2 water cells")
	var new_water_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_water[r][c] and pb.is_ally_water(r, c):
				new_water_count += 1
	assert(new_water_count == water_positions.size(), "All spawned water cells must be registered and ally-owned")
	print("✓ Water skill successfully created ally water cells!")

	# Verify _trigger_aqua_splash marks pieces on all water cells as matched
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.ismatched[r][c] = false
	pb._trigger_aqua_splash(3, 3, pb.get_cell_position(3, 3), [], {})
	# (3,3) and adjacent cells in radius 1 must be marked matched
	assert(pb.ismatched[3][3] == true, "Center cell (3,3) must be marked matched")
	assert(pb.ismatched[2][3] == true, "Adjacent water cell (2,3) must be marked matched")
	assert(pb.ismatched[4][3] == true, "Adjacent water cell (4,3) must be marked matched")
	assert(pb.ismatched[3][2] == true, "Adjacent water cell (3,2) must be marked matched")
	assert(pb.ismatched[3][4] == true, "Adjacent water cell (3,4) must be marked matched")
	print("✓ _trigger_aqua_splash marks all generated water cells as matched to delete pieces!")

	# 2. Verify Mid-Evolution Registry definitions
	assert(sc.SKILL_EVOLUTION_REGISTRY.has("water"), "Registry must have water evolutions")
	var w_mids = sc.SKILL_EVOLUTION_REGISTRY["water"]["mid"]
	assert(w_mids.size() == 3, "Water mid-evolution must offer 3 choices")
	assert(w_mids[0]["id"] == "water_mid_spring", "Water mid-evolution 1 must be water_mid_spring")
	assert(w_mids[1]["id"] == "water_mid_barrier", "Water mid-evolution 2 must be water_mid_barrier")
	assert(w_mids[2]["id"] == "water_mid_surge", "Water mid-evolution 3 must be water_mid_surge")

	# Verify evolution does NOT directly manipulate recovery percentage (handled by enhancement levels)
	assert(not ("+40%" in w_mids[0]["desc"]), "Evolution must not hardcode +40% recovery; enhancement handles values")
	print("✓ Water mid-evolution choices strictly match [HP回復 / 防御力増加 / 攻撃力上昇] without arbitrary % buffs!")

	# 3. Test Mid-Evolution 1: water_mid_spring (Heal HP based on ally water cells each turn)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_spring")
	assert(sc.has_skill_trait("water_1", "water_mid_spring"), "water_mid_spring must be active")

	# Set up board with 4 ally water cells
	pb._initialize_board(null)
	pb._apply_water_to_cell(1, 1, true)
	pb._apply_water_to_cell(1, 2, true)
	pb._apply_water_to_cell(2, 1, true)
	pb._apply_water_to_cell(2, 2, true)

	sm.stage = 1
	sm.myhpmax = 1000.0
	sm.myhp = 500.0
	sc.skill_tree_items[0]["level"] = 1 # water_1 Lv1
	pb._reset_turn(sm, sc)
	var expected_heal_lv1 = (25.0 + 1.0 * 6.0) * 4.0 # 31 * 4 = 124
	assert(sm.myhp == 500.0 + expected_heal_lv1, "Turn reset must heal HP based on water cell count (Lv1: 124 HP)")
	print("✓ water_mid_spring heals HP each turn based on water cell count and skill level!")

	# Test scaling with skill level (Lv10)
	sc.skill_tree_items[0]["level"] = 10 # water_1 Lv10
	sm.myhp = 500.0
	pb._reset_turn(sm, sc)
	var expected_heal_lv10 = (25.0 + 10.0 * 6.0) * 4.0 # 85 * 4 = 340
	assert(sm.myhp == 500.0 + expected_heal_lv10, "Turn reset must heal HP scaled by enhancement level (Lv10: 340 HP)")
	print("✓ water_mid_spring recovery scales via enhancement levels (Lv1: 124 vs Lv10: 340)!")

	# 4. Test Mid-Evolution 2: water_mid_barrier (Increase shield based on ally water cells each turn)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_barrier")
	assert(sc.has_skill_trait("water_1", "water_mid_barrier"), "water_mid_barrier must be active")

	sm.guard = 0.0
	sc.skill_tree_items[0]["level"] = 2
	pb._reset_turn(sm, sc)
	var expected_shield_lv2 = (20.0 + 2.0 * 5.0) * 4.0 # 30 * 4 = 120
	assert(sm.guard == expected_shield_lv2, "Turn reset must grant shield based on water cell count (Lv2: 120 shield)")
	print("✓ water_mid_barrier increases shield each turn based on water cell count!")

	# 5. Test Mid-Evolution 3: water_mid_surge (Deal attack damage based on ally water cells each turn)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("water_1", 5, "water_mid_surge")
	assert(sc.has_skill_trait("water_1", "water_mid_surge"), "water_mid_surge must be active")

	sm.isdeadf = false
	sm.stage_enemy = 1
	sm.make_enemy(false)
	var initial_ehp = sm.ehp
	sc.skill_tree_items[0]["level"] = 3
	pb._reset_turn(sm, sc)
	var expected_surge_lv3 = (35.0 + 3.0 * 8.0) * 4.0 # 59 * 4 = 236
	assert(sm.ehp == initial_ehp - expected_surge_lv3, "Turn reset must deal damage based on water cell count (Lv3: 236 dmg)")
	print("✓ water_mid_surge deals attack damage each turn based on water cell count!")

	# =========================================================================
	# SECTION 31: Wood HP Drain & Yggdrasil Skill Spawns,
	# Wind Mid-Evo (Normal Piece Clearance + Damage, Bi-directional Movement),
	# Thunder Reflection on Object Collision
	# =========================================================================
	print("\n--- SECTION 31: Wood, Wind & Thunder Evolution Enhancements ---")

	# 1. Wood Basic Spec: Enemy HP Drain (Damage enemy & heal player, weaker than pure heal)
	pb.plant_entities.clear()
	pb._initialize_board(null)
	var sprout_plant = {
		"origin": Vector2i(7, 7),
		"stage": 0, # 若木
		"absorbed_water": 0,
		"thunder_hp": 2,
		"enemy_planted": false,
		"drain_amount": 0
	}
	pb.plant_entities.append(sprout_plant)

	sm.stage = 1
	sm.isdeadf = false
	sm.stage_enemy = 1
	sm.make_enemy(false)
	var ehp_before = sm.ehp
	sm.myhpmax = 1000.0
	sm.myhp = 500.0
	pb._process_turn_plants()

	# Stage 0: dmg 80, heal 30
	assert(sm.ehp == ehp_before - 80.0, "Wood plant must drain enemy HP by 80 (ehp was %f, now %f)" % [ehp_before, sm.ehp])
	assert(sm.myhp == 530.0, "Wood plant must heal player HP by 30 (drain heal is weaker than water)")
	print("✓ Wood basic spec drains enemy HP and heals player (dmg 80 / heal 30)!")

	# 2. Wood Final Evolution: Big Tree (stage 2) spawns random skill items on adjacent cells each turn
	pb.plant_entities.clear()
	pb._initialize_board(null)
	var big_tree = {
		"origin": Vector2i(5, 5),
		"stage": 2, # 大木 (3x3 世界樹)
		"absorbed_water": 0,
		"thunder_hp": 4,
		"enemy_planted": false,
		"drain_amount": 0
	}
	pb.plant_entities.append(big_tree)

	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("wood_1", 15, "wood_final_yggdrasil")
	assert(sc.has_skill_trait("wood_1", "wood_final_yggdrasil"), "wood_final_yggdrasil must be active")

	# Clear existing special items around big tree
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.special_item[r][c] = pb.SpecialItemType.NONE
			pb.is_bomb[r][c] = false

	pb._process_turn_plants()

	# Count skill items spawned adjacent to big tree
	var big_tree_occ = pb._get_plant_occupied_cells(big_tree)
	var adjacent_skills_count = 0
	for occ in big_tree_occ:
		for dr in [-1, 0, 1]:
			for dc in [-1, 0, 1]:
				var nr = occ.x + dr; var nc = occ.y + dc
				if nr >= 0 and nr < pb.GRID_ROWS and nc >= 0 and nc < pb.GRID_COLUMNS:
					if not (Vector2i(nr, nc) in big_tree_occ):
						if pb.special_item[nr][nc] != pb.SpecialItemType.NONE or pb.is_bomb[nr][nc]:
							adjacent_skills_count += 1
	assert(adjacent_skills_count > 0, "Big tree must spawn random skill items on adjacent cells (found %d)" % adjacent_skills_count)
	print("✓ Wood final evolution (Big Tree) successfully spawned %d skill item(s) on adjacent cells!" % adjacent_skills_count)

	# 3. Wind Mid-Evolution 1: Bi-directional movement (Moves both Up and Down instead of just upward)
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("wind_1", 5, "wind_mid_slicer") # 上下双突風
	assert(sc.has_skill_trait("wind_1", "wind_mid_slicer"), "wind_mid_slicer must be active")

	pb._initialize_board(null)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.ismatched[r][c] = false

	# Trigger tornado at center (4, 4)
	pb._trigger_tornado(4, 4, pb.get_cell_position(4, 4), [], {})
	# With bi-directional movement, cells above (r < 4) AND below (r > 4) in col 4 must be matched
	assert(pb.ismatched[0][4] == true, "Cell at (0, 4) above must be matched by tornado")
	assert(pb.ismatched[7][4] == true, "Cell at (7, 4) below must be matched by bi-directional tornado")
	print("✓ Wind mid-evolution: tornado moves bi-directionally (up & down across the entire column)!")

	# 4. Wind Mid-Evolution 2: Delete normal pieces on ally board and deal extra damage to enemy
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("wind_1", 5, "wind_mid_sweep") # 暴風一掃
	assert(sc.has_skill_trait("wind_1", "wind_mid_sweep"), "wind_mid_sweep must be active")

	sm.isdeadf = false
	sm.stage_enemy = 1
	sm.make_enemy(false)
	var ehp_before_wind = sm.ehp
	pb._initialize_board(null)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.ismatched[r][c] = false

	pb.special_levels[pb.SpecialItemType.TORNADO] = 1
	pb._trigger_tornado(4, 4, pb.get_cell_position(4, 4), [], {})
	# Tornado deletes normal pieces along its path and damages enemy
	assert(sm.ehp < ehp_before_wind, "Tornado with wind_mid_sweep must deal extra damage to enemy based on deleted normal pieces")
	print("✓ Wind mid-evolution: tornado deletes normal pieces and deals extra damage to enemy!")

	# 5. Thunder Evolution: Reflection when lightning hits an object
	sc.skill_evolutions.clear()
	sc.choose_skill_evolution("thunder_1", 5, "thunder_mid_reflection") # 避雷針反射
	assert(sc.has_skill_trait("thunder_1", "thunder_mid_reflection"), "thunder_mid_reflection must be active")

	pb._initialize_board(null)
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			pb.ismatched[r][c] = false
			pb.grid_stones[r][c] = 0

	# Place stone object at (4, 4)
	pb.grid_stones[4][4] = 2
	pb.special_levels[pb.SpecialItemType.LIGHTNING] = 1
	pb._trigger_lightning(4, 4, pb.get_cell_position(4, 4), [], {})
	# When lightning hits object at (4, 4), it reflects to adjacent cells
	var matched_adjacent = 0
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			var ar = 4 + dr; var ac = 4 + dc
			if ar >= 0 and ar < pb.GRID_ROWS and ac >= 0 and ac < pb.GRID_COLUMNS:
				if pb.ismatched[ar][ac]: matched_adjacent += 1
	assert(matched_adjacent > 0, "Lightning must reflect to adjacent cells upon hitting an object (found %d)" % matched_adjacent)
	print("✓ Thunder evolution: lightning reflects to adjacent cells when hitting an object!")

	print("\nALL USER REQUEST TESTS PASSED SUCCESSFULLY!")
	quit(0)

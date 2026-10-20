extends SceneTree

func _init() -> void:
	print("--- Starting Test Poison Element & Multi-Skill System ---")

	# 1. ElementData tests
	assert(ElementData.Element.POISON == 7, "Element.POISON should be 7")
	assert(ElementData.get_element_name(ElementData.Element.POISON) == "poison", "get_element_name(POISON) should be 'poison'")
	assert(ElementData.get_element_from_name("poison") == ElementData.Element.POISON, "get_element_from_name('poison') should be POISON")
	assert(ElementData.get_element_from_enemy_string("毒属性") == ElementData.Element.POISON, "get_element_from_enemy_string('毒属性') should be POISON")
	assert(ElementData.get_element_from_enemy_string("猛毒") == ElementData.Element.POISON, "get_element_from_enemy_string('猛毒') should be POISON")
	assert(ElementData.ELEMENT_COLORS.has(ElementData.Element.POISON), "ELEMENT_COLORS must have POISON")

	# Check damage multipliers for Poison
	# Attacking
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.WATER), 1.5), "Poison attacking Water should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.WIND), 1.5), "Poison attacking Wind should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.FIRE), 0.5), "Poison attacking Fire should be 0.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.POISON, ElementData.Element.LIGHT), 0.5), "Poison attacking Light should be 0.5x")
	# Defending
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.FIRE, ElementData.Element.POISON), 1.5), "Fire attacking Poison should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.LIGHT, ElementData.Element.POISON), 1.5), "Light attacking Poison should be 1.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.WATER, ElementData.Element.POISON), 0.5), "Water attacking Poison should be 0.5x")
	assert(is_equal_approx(ElementData.get_damage_multiplier(ElementData.Element.WIND, ElementData.Element.POISON), 0.5), "Wind attacking Poison should be 0.5x")
	print("✓ ElementData tests passed!")

	# 2. StageManager ENEMY_SPECIES tests
	var sm_script = load("res://stage_manager.gd")
	var species = sm_script.ENEMY_SPECIES
	assert(species.has("enemy3"), "enemy3 must exist")
	assert(species["enemy3"]["element"] == "毒属性", "enemy3 (ポイズントード) element should be 毒属性")
	assert(species["enemy3"].has("skills"), "enemy3 should have skills")
	assert("毒属性" in species["enemy3"]["skills"] and "水属性" in species["enemy3"]["skills"], "enemy3 skills should have 毒属性 and 水属性")

	assert(species["enemy20"].has("skills"), "enemy20 (デスクラウンサソリ) should have skills")
	assert("地属性" in species["enemy20"]["skills"] and "毒属性" in species["enemy20"]["skills"], "enemy20 skills should have 地属性 and 毒属性")

	assert(species["enemy22"].has("skills"), "enemy22 (ヴェノムバイパー) should have skills")
	assert(species["enemy22"]["element"] == "毒属性", "enemy22 element should be 毒属性")
	assert("毒属性" in species["enemy22"]["skills"] and "地属性" in species["enemy22"]["skills"], "enemy22 skills should have 毒属性 and 地属性")

	assert(species["enemy18"].has("skills"), "enemy18 (冥王デモニアス) should have skills")
	assert("闇属性" in species["enemy18"]["skills"] and "毒属性" in species["enemy18"]["skills"], "enemy18 skills should have 闇属性 and 毒属性")
	print("✓ StageManager ENEMY_SPECIES tests passed!")

	# 3. Instantiate scene and test PuzzleBoard poison logic
	var dummy_root = Node2D.new()
	var sm_node = Node2D.new()
	sm_node.name = "StageManager"
	sm_node.set_script(sm_script)
	dummy_root.add_child(sm_node)

	var pb_script = load("res://puzzle_board.gd")
	var pb = pb_script.new()
	pb.name = "PuzzleBoard"
	dummy_root.add_child(pb)
	root.add_child(dummy_root)
	pb._initialize_board(null)

	# Test skill info
	var s_info_normal = pb._get_enemy_skill_info("毒属性", false)
	assert(s_info_normal["name"] == "ポイズンバースト", "Normal poison skill should be ポイズンバースト")
	assert(s_info_normal["color"] == "#AB47BC", "Poison skill color should be #AB47BC")

	var s_info_boss = pb._get_enemy_skill_info("毒属性", true)
	assert(s_info_boss["name"] == "猛毒瘴気・デッドリーヴェノム", "Boss poison skill should be 猛毒瘴気・デッドリーヴェノム")

	# Test _select_enemy_skill
	var e_toad = {"key": "enemy3"}
	var toad_skills_seen = {}
	for i in range(40):
		var chosen = pb._select_enemy_skill(e_toad, sm_node)
		toad_skills_seen[chosen] = true
	assert(toad_skills_seen.has("毒属性") and toad_skills_seen.has("水属性"), "Toad should select both 毒属性 and 水属性 over multiple turns")
	print("✓ _select_enemy_skill multi-skill random selection passed! Seen: ", toad_skills_seen.keys())

	# Test grid_poison existence
	assert("grid_poison" in pb, "grid_poison must be in PuzzleBoard")
	assert(pb.grid_poison.size() == pb.GRID_ROWS, "grid_poison row size must match GRID_ROWS")

	# Test _cast_enemy_poison_skill
	var targets = pb._cast_enemy_poison_skill(false, false)
	assert(not targets.is_empty(), "Poison skill should return targeted positions")
	var poison_count = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]:
				poison_count += 1
	assert(poison_count > 0, "Board should have active poison tiles after poison skill")
	print("✓ _cast_enemy_poison_skill created %d poison tiles" % poison_count)

	# Test clear_board_hazards
	pb.clear_board_hazards()
	var remaining_poison = 0
	for r in range(pb.GRID_ROWS):
		for c in range(pb.GRID_COLUMNS):
			if pb.grid_poison[r][c]:
				remaining_poison += 1
	assert(remaining_poison == 0, "clear_board_hazards should clear all poison tiles")
	print("✓ clear_board_hazards cleared all poison tiles")

	print("\nALL POISON & MULTI-SKILL TESTS PASSED SUCCESSFULLY!")
	quit(0)

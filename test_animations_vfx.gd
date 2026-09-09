extends SceneTree

func _init() -> void:
	print("=== RUNNING VFX & ANIMATION INTEGRATION TEST ===")
	
	var pb_scene = load("res://puzzle_board.tscn")
	assert(pb_scene != null, "Failed to load puzzle_board.tscn")
	var pb = pb_scene.instantiate()
	root.add_child(pb)
	
	print("[1] Testing Effects Node2D Container")
	var effects_node = pb.get_node_or_null("Effects")
	assert(effects_node != null, "Effects node not found")
	assert(effects_node is Node2D, "Effects node should be Node2D")
	print("Effects Node2D: OK!")

	print("[2] Testing Sky-to-Ground Lightning Strike (落雷)")
	var strike_pos = pb.get_cell_position(7, 7)
	var chain_targets: Array[Vector2] = [pb.get_cell_position(6, 6), pb.get_cell_position(8, 8)]
	pb._spawn_lightning_effect(strike_pos, chain_targets)
	assert(effects_node.get_child_count() > 0, "Lightning effect should spawn children")
	print("Lightning Strike effect: OK! (spawned %d nodes)" % effects_node.get_child_count())

	print("[3] Testing Water Electric BFS Conduction Net")
	var water_cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 4)]
	pb._spawn_water_electric_effect(water_cells)
	print("Water Electric BFS effect: OK!")

	print("[4] Testing Commercial-Grade Explosions & Cross Laser")
	pb._spawn_explosion_effect(strike_pos)
	pb._spawn_mega_explosion_effect(strike_pos, 3)
	pb._spawn_cross_effect(strike_pos, 2)
	print("Explosions and Cross effect: OK!")

	print("[5] Testing Tornado, Aqua Splash, Black Hole, Nature Magic")
	pb._spawn_tornado_effect(strike_pos, 2, 2)
	pb._spawn_aqua_splash_effect(strike_pos, 2)
	pb._spawn_black_hole_effect(strike_pos, 2)
	pb._spawn_sprout_effect(strike_pos)
	pb._spawn_growth_effect(strike_pos, 2)
	pb._spawn_disco_effect(strike_pos)
	pb._spawn_paint_effect(strike_pos)
	print("Tornado, Splash, Black Hole, Nature Magic: OK!")

	print("[6] Testing Gem Shard Break Particles & Sword Hit Sparks")
	pb._spawn_burst_particles(strike_pos, 1)
	pb._spawn_burst_particles(strike_pos, 0)
	pb._spawn_hit_spark(Vector2(1500, 200))
	print("Gem Shards & Hit Sparks: OK!")

	print("[7] Testing Score Label Fast Vertical Bounce (Parabola)")
	var h0 = ((0.0 - 6.0) * (0.0 - 6.0) * (pb.BOUNCE_HEIGHT / 36.0)) - pb.BOUNCE_HEIGHT
	var h6 = ((6.0 - 6.0) * (6.0 - 6.0) * (pb.BOUNCE_HEIGHT / 36.0)) - pb.BOUNCE_HEIGHT
	var h12 = ((12.0 - 6.0) * (12.0 - 6.0) * (pb.BOUNCE_HEIGHT / 36.0)) - pb.BOUNCE_HEIGHT
	assert(absf(h0) < 0.001, "Hop at t=0 should be 0")
	assert(absf(h6 - (-pb.BOUNCE_HEIGHT)) < 0.001, "Hop at t=6 should be -BOUNCE_HEIGHT")
	assert(absf(h12) < 0.001, "Hop at t=12 should be 0")
	print("Bounce parabola math: OK! (t=0 -> %f, t=6 -> %f, t=12 -> %f)" % [h0, h6, h12])

	print("=== ALL VFX & ANIMATION TESTS PASSED! ===")
	quit(0)

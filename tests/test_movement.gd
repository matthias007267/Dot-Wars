extends TestCase


func _config() -> SimConfig:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	return config


func _assert_step_is_orthogonal(sim: Simulation, previous: Array[Vector2i], label: String) -> void:
	for id in sim.workers.count:
		var now := TestHelpers.worker_xy(sim, id)
		var delta := now - previous[id]
		check(absi(delta.x) + absi(delta.y) <= 1, "%s: Arbeiter %d bewegt sich höchstens orthogonal um 1" % [label, id])
		check(sim.world.in_bounds(now.x, now.y), "%s: in der Welt" % label)
		check_eq(sim.world.cells[sim.world.index(now.x, now.y)], Materials.EMPTY, "%s: nie in Material" % label)
		previous[id] = now


func test_worker_walks_l_shaped_tunnel_orthogonally() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"#######",
		"#w....#",
		"#####.#",
		"#####.#",
		"#####.#",
		"#####M#",
		"#######",
	], _config())
	sim.assign_area(0, Rect2i(5, 5, 1, 1))
	var previous: Array[Vector2i] = [TestHelpers.worker_xy(sim, 0)]
	var moves := 0
	for tick in 12:
		sim.tick_once()
		var before := previous[0]
		_assert_step_is_orthogonal(sim, previous, "Tick %d" % tick)
		if previous[0] != before:
			moves += 1
	check_eq(TestHelpers.worker_xy(sim, 0), Vector2i(5, 4), "Arbeiter steht direkt vor dem Ziel")
	check_eq(moves, 7, "kürzester Weg: 4 + 3 Schritte")
	check_eq(sim.workers.state[0], WorkerStore.STATE_MINING, "baut ab")


func test_worker_never_walks_through_material_or_out_of_world() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"........",
		".######.",
		".#....#.",
		".#.##.#.",
		".#.##.#.",
		".#....#.",
		".######.",
		"w.......",
	], _config())
	sim.assign_area(0, Rect2i(3, 3, 2, 2))
	var previous: Array[Vector2i] = [TestHelpers.worker_xy(sim, 0)]
	for tick in 300:
		sim.tick_once()
		_assert_step_is_orthogonal(sim, previous, "Tick %d" % tick)
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_workers_never_share_a_cell_in_a_one_wide_corridor() -> void:
	var config := _config()
	config.group_quotas = PackedInt32Array([100, 0])
	var sim := TestHelpers.sim_from_ascii([
		"##########",
		"#wwwwww..M",
		"##########",
	], config)
	sim.assign_area(0, Rect2i(9, 1, 1, 1))
	for tick in 120:
		sim.tick_once()
		var seen := {}
		for id in sim.workers.count:
			var c := sim.workers.cell[id]
			check(not seen.has(c), "Zelle doppelt belegt in Tick %d" % tick)
			seen[c] = true
		if tick % 10 == 0:
			check_no_errors(sim.check_invariants(), "Tick %d" % tick)


func test_head_on_traffic_swaps_instead_of_deadlocking() -> void:
	var config := _config()
	config.group_quotas = PackedInt32Array([50, 50])
	var sim := TestHelpers.sim_from_ascii([
		"##########",
		"#w......w#",
		"##########",
	], config)
	check_eq(sim.workers.group[0], 0, "erster Arbeiter in Gruppe 0")
	check_eq(sim.workers.group[1], 1, "zweiter Arbeiter in Gruppe 1")
	sim.assign_area(0, Rect2i(9, 1, 1, 1))
	sim.assign_area(1, Rect2i(0, 1, 1, 1))
	var crossed_0 := false
	var crossed_1 := false
	for tick in 30:
		sim.tick_once()
		crossed_0 = crossed_0 or TestHelpers.worker_xy(sim, 0).x == 8
		crossed_1 = crossed_1 or TestHelpers.worker_xy(sim, 1).x == 1
		check_no_errors(sim.check_invariants(), "Tick %d" % tick)
	check(crossed_0, "Gruppe 0 erreicht ihr Ziel am Ostende")
	check(crossed_1, "Gruppe 1 erreicht ihr Ziel am Westende")


func test_neighbor_helper_rejects_out_of_world_steps() -> void:
	var w := 4
	var count := 16
	check_eq(MovementSystem.neighbor(0, FlowField.DIR_UP, w, count), -1, "oben links")
	check_eq(MovementSystem.neighbor(0, FlowField.DIR_LEFT, w, count), -1, "links")
	check_eq(MovementSystem.neighbor(3, FlowField.DIR_RIGHT, w, count), -1, "rechts (kein Umbruch in die nächste Zeile)")
	check_eq(MovementSystem.neighbor(15, FlowField.DIR_DOWN, w, count), -1, "unten")
	check_eq(MovementSystem.neighbor(15, FlowField.DIR_RIGHT, w, count), -1, "unten rechts")
	check_eq(MovementSystem.neighbor(5, FlowField.DIR_RIGHT, w, count), 6, "gültig rechts")
	check_eq(MovementSystem.neighbor(5, FlowField.DIR_NONE, w, count), -1, "keine Richtung")


func test_move_period_limits_speed() -> void:
	var config := _config()
	config.move_period_ticks = 4
	var sim := TestHelpers.sim_from_ascii(["#########", "#w.....M#", "#########"], config)
	sim.assign_area(0, Rect2i(7, 1, 1, 1))
	sim.run_ticks(8)
	check(TestHelpers.worker_xy(sim, 0).x <= 3, "höchstens ein Schritt je 4 Takte (Position %s)" % str(TestHelpers.worker_xy(sim, 0)))

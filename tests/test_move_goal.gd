extends TestCase


func _config() -> SimConfig:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	return config


func test_worker_walks_to_goal_and_does_not_mine() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"#######",
		"#w....#",
		"#######",
	], _config())
	var goal := sim.world.index(5, 1)
	check(sim.set_move_goal(0, goal), "Ziel angenommen")
	check(not sim.set_move_goal(0, sim.world.index(0, 0)), "Material ist kein Laufziel")
	sim.fields[0].rebuild_blocking()
	check_eq(sim.fields[0].dist[goal], 0, "Ziel hat Distanz 0")
	check(sim.fields[0].dist[sim.workers.cell[0]] > 0, "Start hat einen Weg")
	var previous := TestHelpers.worker_xy(sim, 0)
	for tick in 12:
		sim.tick_once()
		var now := TestHelpers.worker_xy(sim, 0)
		check(absi(now.x - previous.x) + absi(now.y - previous.y) <= 1, "nur orthogonal")
		previous = now
	check_eq(TestHelpers.worker_xy(sim, 0), Vector2i(5, 1), "am Ziel")
	check_eq(sim.world.mined_count, 0, "kein Abbau ohne Auftrag")
	check_eq(sim.workers.faction[0], 0, "Fraktion 0")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_unreachable_goal_keeps_the_worker_waiting() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"#####",
		"#w#.#",
		"#####",
	], _config())
	var start := sim.workers.cell[0]
	check(sim.set_move_goal(0, sim.world.index(3, 1)), "Ziel jenseits der Wand")
	sim.run_ticks(40)
	check_eq(sim.workers.cell[0], start, "bleibt stehen")
	check_eq(sim.fields[0].dir[start], FlowField.DIR_NONE, "kein Weg")
	check_eq(sim.workers.state[0], WorkerStore.STATE_WAITING, "wartet")
	check_eq(sim.world.mined_count, 0, "kein Abbau")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_goal_run_is_deterministic() -> void:
	var first := _goal_hash()
	var second := _goal_hash()
	check_eq(first, second, "gleicher Zielauftrag, gleicher Zustand")


func test_workers_queue_without_sharing_a_cell() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"#######",
		"#ww...#",
		"#######",
	], _config())
	check(sim.set_move_goal(0, sim.world.index(5, 1)), "gemeinsames Ziel")
	sim.run_ticks(10)
	check_eq(TestHelpers.worker_xy(sim, 1), Vector2i(5, 1), "vorderer Arbeiter am Ziel")
	check_eq(TestHelpers.worker_xy(sim, 0), Vector2i(4, 1), "hinterer Arbeiter wartet davor")
	check_eq(sim.world.mined_count, 0, "kein Abbau")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_faction_is_stored_separately_from_group() -> void:
	var world := WorldState.new(4, 1, 8, Materials.EMPTY)
	var workers := WorkerStore.new(world.cell_count(), 2)
	workers.add(0, 1, 3)
	check_eq(workers.group[0], 1, "Gruppe")
	check_eq(workers.faction[0], 3, "Fraktion")
	check_eq(workers.group_counts[1], 1, "Gruppe zählt")


func test_one_thousand_workers_stay_on_empty_cells() -> void:
	var config := SimConfig.new()
	config.world_size = 128
	config.initial_workers = 1000
	config.move_period_ticks = 2
	var world := WorldGenerator.generate(config)
	var side := 48
	var origin := (128 - side) / 2
	world.carve_rect(Rect2i(origin, origin, side, side))
	var sim := Simulation.from_world(config, world)
	check_eq(sim.workers.count, 1000, "tausend Arbeiter")
	var goal := world.index(origin + side - 2, origin + side / 2)
	check(sim.set_move_goal(0, goal), "Ziel Gruppe 0")
	check(sim.set_move_goal(1, goal), "Ziel Gruppe 1")
	for tick in 30:
		sim.tick_once()
	check_no_errors(sim.check_invariants(), "Invarianten nach 30 Takten")
	check_eq(sim.world.mined_count, 0, "auch hier kein Abbau")
	var seen := {}
	for id in sim.workers.count:
		var cell := sim.workers.cell[id]
		check_eq(sim.workers.faction[id], 0, "Fraktion")
		check(not seen.has(cell), "keine doppelte Zelle")
		seen[cell] = true
		check_eq(sim.world.cells[cell], Materials.EMPTY, "steht auf leerem Feld")


func _goal_hash() -> int:
	var sim := TestHelpers.sim_from_ascii([
		"#########",
		"#w......#",
		"#########",
	], _config())
	sim.set_move_goal(0, sim.world.index(7, 1))
	sim.run_ticks(15)
	return sim.state_hash()

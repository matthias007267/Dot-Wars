extends TestCase


func _config() -> SimConfig:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	return config


func test_areas_are_clipped_to_the_world() -> void:
	var areas := DigAreas.new(10, 8, 2)
	check(areas.assign_rect(0, Rect2i(-5, -5, 8, 8)), "teilweise außerhalb")
	check_eq(areas.rects[0][0], Rect2i(0, 0, 3, 3), "zugeschnitten")
	check(areas.assign_rect(0, Rect2i(8, 6, 10, 10)), "überlappt rechten unteren Rand")
	check_eq(areas.rects[0][1], Rect2i(8, 6, 2, 2), "zugeschnitten auf Weltende")
	check(not areas.assign_rect(0, Rect2i(20, 20, 3, 3)), "vollständig außerhalb")
	check(not areas.assign_rect(0, Rect2i(2, 2, 0, 4)), "leeres Rechteck")
	check(not areas.assign_rect(5, Rect2i(0, 0, 2, 2)), "ungültige Gruppe")
	check(areas.assign_rect(1, Rect2i(5, 5, -3, -3)), "negative Größe wird normalisiert")
	check_eq(areas.rects[1][0], Rect2i(2, 2, 3, 3), "normalisiert")
	check_eq(areas.masks[0].count(1), 9 + 4, "Maske deckt nur gültige Zellen ab")


func test_workers_circulate_on_the_world_border_without_leaving_or_wrapping() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w.......",
		".######.",
		".######.",
		".######.",
		".######.",
		".######.",
		".######.",
		"........",
	], _config())
	sim.assign_area(0, Rect2i(1, 1, 6, 6))
	var previous := TestHelpers.worker_xy(sim, 0)
	for tick in 400:
		sim.tick_once()
		for id in sim.workers.count:
			var now := TestHelpers.worker_xy(sim, id)
			check(sim.world.in_bounds(now.x, now.y), "Arbeiter in der Welt")
		var moved := TestHelpers.worker_xy(sim, 0) - previous
		check(absi(moved.x) + absi(moved.y) <= 1, "kein Zeilenumbruch bei Tick %d" % tick)
		previous = TestHelpers.worker_xy(sim, 0)
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_fully_mined_area_leaves_workers_waiting_and_state_stable() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w.......",
		".######.",
		".######.",
		".######.",
		".######.",
		".######.",
		".######.",
		"........",
	], _config())
	sim.assign_area(0, Rect2i(1, 1, 6, 6))
	sim.run_ticks(2000)
	check_eq(sim.world.solid_count, 0, "alles abgebaut")
	check_eq(sim.world.mined_count, 36, "36 Zellen")
	check_eq(sim.world.mined_fraction(), 1.0, "Weltanteil 100 % der abbaubaren Zellen")
	check_eq(sim.workers.count, 1, "Abbau verändert Arbeitermasse nicht")
	check_eq(sim.spawner.pending(), 0, "keine offenen Entstehungen")
	check_eq(sim.areas.rects[0].size(), 0, "abgeschlossenes Rechteck wurde entfernt")
	var positions := sim.workers.cell.duplicate()
	var hash_cells := sim.world.state_hash()
	sim.run_ticks(200)
	check_eq(sim.workers.cell, positions, "Arbeiter bleiben stehen")
	check_eq(sim.world.state_hash(), hash_cells, "Welt unverändert")
	for id in sim.workers.count:
		check_eq(sim.workers.state[id], WorkerStore.STATE_WAITING, "Arbeiter %d wartet" % id)
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_fully_empty_world_is_valid() -> void:
	var world := WorldState.new(8, 8, 8, Materials.EMPTY)
	var sim := Simulation.from_world(_config(), world)
	check(sim != null, "Simulation lässt sich erzeugen")
	sim.assign_area(0, Rect2i(0, 0, 8, 8))
	sim.run_ticks(50)
	check_eq(sim.world.mined_count, 0, "nichts zu bauen")
	check_eq(sim.world.mined_fraction(), 0.0, "Anteil 0 ohne abbaubare Zellen")


func test_simulation_requires_valid_start_positions() -> void:
	var solid := WorldState.new(8, 8, 8, Materials.SOFT)
	check_eq(Simulation.from_world(_config(), solid), null, "keine leere Zelle → keine Simulation")
	var tiny := TestHelpers.parse_world(["#.#"])["world"] as WorldState
	var config := _config()
	config.initial_workers = 2
	check_eq(Simulation.from_world(config, tiny), null, "zu wenig Platz für Startarbeiter")
	config.initial_workers = 1
	check(Simulation.from_world(config, tiny) != null, "ein Arbeiter passt")
	check_eq(Simulation.from_world(config, tiny, PackedInt32Array([0])), null, "explizite Startzelle im Material")


func test_find_nearest_empty_searches_rings() -> void:
	var world := TestHelpers.parse_world(["#####", "#####", "###.#", "#####"])["world"] as WorldState
	check_eq(world.find_nearest_empty(0, 0), world.index(3, 2), "findet die einzige leere Zelle")
	check_eq(world.find_nearest_empty(3, 2), world.index(3, 2), "Start auf leerer Zelle")
	var solid := WorldState.new(4, 4, 4, Materials.HARD)
	check_eq(solid.find_nearest_empty(2, 2), -1, "keine leere Zelle")

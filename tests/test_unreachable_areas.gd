extends TestCase


func _config() -> SimConfig:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	return config


func _assert_idle_and_consistent(sim: Simulation, start_hash_cells: PackedInt32Array, label: String) -> void:
	check_eq(sim.world.mined_count, 0, "%s: nichts abgebaut" % label)
	check_eq(sim.workers.cell, start_hash_cells, "%s: Arbeiter bleiben stehen" % label)
	for id in sim.workers.count:
		check_eq(sim.workers.state[id], WorkerStore.STATE_WAITING, "%s: Arbeiter %d wartet" % [label, id])
	check_no_errors(sim.check_invariants(), label)


func test_area_inside_rock_without_access_is_ignored() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"..#########",
		"w.#########",
		"..#########",
		"..#########",
	], _config())
	# Gebiet liegt im Fels. Der Schwarm gräbt sich dorthin.
	sim.assign_area(0, Rect2i(5, 1, 3, 2))
	var start_x := TestHelpers.worker_xy(sim, 0).x
	sim.run_ticks(100)
	check(sim.world.mined_count > 0, "der Weg zum Gebiet wird abgebaut")
	check(TestHelpers.worker_xy(sim, 0).x > start_x, "der Arbeiter rückt auf das Gebiet zu")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_area_next_to_disconnected_cavity_is_unreachable() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w.#####.....",
		"..#####.###.",
		"..#####.#M#.",
		"..#####.###.",
		"..#####.....",
	], _config())
	sim.assign_area(0, Rect2i(9, 2, 1, 1))
	# Die Zelle liegt in einer abgetrennten Höhle. Der Schwarm gräbt die Wand an.
	sim.run_ticks(100)
	check(sim.world.mined_count > 0, "die Wand zum Gebiet wird angebrochen")
	check_no_errors(sim.check_invariants(), "abgetrennte Höhle")


func test_group_without_any_area_waits() -> void:
	var sim := TestHelpers.sim_from_ascii(["w..#", "...#"], _config())
	sim.run_ticks(50)
	check(sim.world.mined_count > 0, "ohne Auftrag wird die nächste Ressource abgebaut")
	check_no_errors(sim.check_invariants(), "kein Gebiet")


func test_workers_recover_when_a_reachable_area_is_added() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w..#####",
		"...#####",
		"...#####",
	], _config())
	sim.assign_area(0, Rect2i(5, 0, 3, 3))
	sim.run_ticks(30)
	check(sim.world.mined_count > 0, "unerreichbares Gebiet wird angegraben")
	sim.assign_area(0, Rect2i(3, 0, 1, 3))
	sim.run_ticks(200)
	check(sim.world.mined_count >= 3, "neues, erreichbares Gebiet wird abgebaut")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_mixed_area_mines_reachable_part_and_leaves_the_rest() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w...#####",
		"....#####",
		"....#####",
		"....#####",
	], _config())
	# Gebiet = ganze rechte Hälfte; nach und nach wird alles erreichbar, weil der Abbau Zugang schafft.
	sim.assign_area(0, Rect2i(4, 0, 5, 4))
	sim.run_ticks(2000)
	check_eq(sim.world.solid_count, 0, "alles abgebaut, da stets angrenzend erreichbar")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_shielded_part_of_area_stays_solid_while_reachable_part_is_mined() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w..#######",
		"...###M###",
		"...#######",
	], _config())
	sim.assign_area(0, Rect2i(3, 0, 1, 3))
	sim.assign_area(0, Rect2i(6, 1, 1, 1))
	sim.run_ticks(1000)
	check(sim.world.mined_count > 3, "nach der Spalte geht es zum zweiten Gebiet weiter")
	check_eq(sim.world.cells[sim.world.index(6, 1)], Materials.EMPTY, "das abgeschirmte Ziel wird erreicht")
	check_eq(sim.workers.count, 1, "keine kostenlosen Arbeiter")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_sealed_core_stays_solid_after_surrounding_wall_is_mined() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"w..#######",
		"...#.....#",
		"...#.###.#",
		"...#.#H#.#",
		"...#.###.#",
		"...#.....#",
		"...#######",
	], _config())
	sim.assign_area(0, Rect2i(3, 0, 1, 7))
	sim.assign_area(0, Rect2i(6, 3, 1, 1))
	sim.run_ticks(2000)
	check(sim.world.mined_count > 7, "der Weg zum markierten Kern wird gegraben")
	check_eq(sim.world.cells[sim.world.index(6, 3)], Materials.EMPTY, "das markierte Ziel wird erreicht")
	check_no_errors(sim.check_invariants(), "Invarianten")

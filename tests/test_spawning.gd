extends TestCase


func _corridor(length: int) -> Array:
	var rows := ["#".repeat(length + 2), "#" + ".".repeat(length) + "#", "#".repeat(length + 2)]
	return rows


func test_each_mined_cell_creates_exactly_one_worker() -> void:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	config.group_quotas = PackedInt32Array([50, 50])
	var sim := TestHelpers.sim_from_ascii(["#####", "#w..#", "#####"], config)
	sim.assign_area(0, Rect2i(0, 0, 5, 3))
	sim.assign_area(1, Rect2i(0, 0, 5, 3))
	for tick in 300:
		sim.tick_once()
		check_eq(sim.total_mass(), sim.expected_mass(), "Massenbilanz in Tick %d" % tick)
	check_eq(sim.workers.count, 1 + sim.world.mined_count, "Arbeiter = Start + abgebaute Zellen")
	check_eq(sim.world.mined_count, 12, "alle Randzellen")


func test_occupied_spawn_location_uses_nearest_free_cell_deterministically() -> void:
	var world := TestHelpers.parse_world(_corridor(5))["world"] as WorldState
	var workers := WorkerStore.new(world.cell_count(), 2)
	var spawner := SpawnSystem.new(world.cell_count(), 100)
	var cell_a := world.index(2, 1)
	var cell_b := world.index(3, 1)
	workers.add(cell_a, 0)
	workers.add(cell_b, 0)
	spawner.enqueue(cell_a)
	check_eq(spawner.process(world, workers, PackedInt32Array([100, 0])), 1, "ein Arbeiter entsteht")
	check_eq(workers.cell[2], world.index(1, 1), "Westen vor Osten: erste freie Zelle in Suchreihenfolge N,O,S,W")
	spawner.enqueue(cell_a)
	spawner.process(world, workers, PackedInt32Array([100, 0]))
	check_eq(workers.cell[3], world.index(4, 1), "nächste freie Zelle")
	var second := TestHelpers.parse_world(_corridor(5))["world"] as WorldState
	var workers2 := WorkerStore.new(second.cell_count(), 2)
	var spawner2 := SpawnSystem.new(second.cell_count(), 100)
	workers2.add(cell_a, 0)
	workers2.add(cell_b, 0)
	spawner2.enqueue(cell_a)
	spawner2.process(second, workers2, PackedInt32Array([100, 0]))
	check_eq(workers2.cell, workers.cell.slice(0, 3), "identisches Ergebnis bei Wiederholung")


func test_spawn_waits_in_queue_when_no_free_cell_exists_and_keeps_mass() -> void:
	var world := TestHelpers.parse_world(["####", "#..#", "####"])["world"] as WorldState
	var workers := WorkerStore.new(world.cell_count(), 2)
	var spawner := SpawnSystem.new(world.cell_count(), 100)
	workers.add(world.index(1, 1), 0)
	workers.add(world.index(2, 1), 0)
	spawner.enqueue(world.index(1, 1))
	spawner.enqueue(world.index(2, 1))
	check_eq(spawner.process(world, workers, PackedInt32Array([100, 0])), 0, "kein Platz")
	check_eq(spawner.pending(), 2, "beide warten")
	check_eq(workers.count, 2, "keine Arbeiter verloren oder doppelt")
	world.set_material(world.index(3, 1), Materials.EMPTY)
	check_eq(spawner.process(world, workers, PackedInt32Array([100, 0])), 1, "ein Platz frei")
	check_eq(spawner.pending(), 1, "einer wartet weiter")
	world.set_material(world.index(3, 0), Materials.EMPTY)
	check_eq(spawner.process(world, workers, PackedInt32Array([100, 0])), 1, "zweiter Platz frei")
	check_eq(spawner.pending(), 0, "Warteschlange leer")
	check_eq(workers.count, 4, "alle vier Arbeiter existieren")


func test_search_limit_keeps_far_spawns_queued() -> void:
	var world := TestHelpers.parse_world(_corridor(8))["world"] as WorldState
	var workers := WorkerStore.new(world.cell_count(), 1)
	var spawner := SpawnSystem.new(world.cell_count(), 2)
	for x in range(1, 5):
		workers.add(world.index(x, 1), 0)
	spawner.enqueue(world.index(1, 1))
	check_eq(spawner.process(world, workers, PackedInt32Array([100])), 0, "freie Zelle liegt außerhalb des Suchlimits")
	check_eq(spawner.pending(), 1, "bleibt in der Warteschlange")


func test_spawn_origin_in_solid_is_rejected() -> void:
	var world := TestHelpers.parse_world(_corridor(3))["world"] as WorldState
	var workers := WorkerStore.new(world.cell_count(), 1)
	var spawner := SpawnSystem.new(world.cell_count(), 10)
	check_eq(spawner.find_free_cell(world, workers, 0), -1, "Ursprung in Material")


func test_new_workers_are_never_placed_in_material_or_on_each_other() -> void:
	var config := SimConfig.new()
	config.world_size = 64
	config.group_quotas = PackedInt32Array([50, 50])
	var sim := Simulation.create(config)
	sim.assign_area(0, Rect2i(24, 24, 16, 16))
	sim.assign_area(1, Rect2i(24, 24, 16, 16))
	for block in 30:
		sim.run_ticks(20)
		check_no_errors(sim.check_invariants(), "Block %d" % block)
	check(sim.world.mined_count > 20, "es wurde tatsächlich abgebaut (%d)" % sim.world.mined_count)

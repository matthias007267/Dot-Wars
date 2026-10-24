extends TestCase

const Backend = preload("res://src/sim/native_search.gd")


func test_native_and_reference_keep_every_tick_identical() -> void:
	var was_enabled: bool = Backend.enabled
	for level in range(5):
		var config := SimConfig.new()
		config.world_size = 32
		config.initial_workers = 12
		config.move_period_ticks = 1
		var sim := Simulation.create(config)
		sim.upgrades.swarm_level = level
		sim.assign_area(0, Rect2i(0, 0, 32, 32))
		sim.assign_area(1, Rect2i(0, 0, 32, 32))
		var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
		for tick in range(80):
			Backend.enabled = false
			reference.tick_once()
			Backend.enabled = was_enabled
			sim.tick_once()
			check_eq(sim.state_hash(), reference.state_hash(), "Stufe %d Takt %d" % [level, tick])
		check_no_errors(sim.check_invariants(), "native Bilanz")
	Backend.enabled = was_enabled


func test_native_rejects_invalid_array_lengths() -> void:
	var native := Backend.backend()
	if "--require-native" in OS.get_cmdline_user_args():
		check(native != null, "Nativer Rechenkern muss verfügbar sein")
	if native == null:
		check(true, "Fallback ohne installierte native Bibliothek")
		return
	check_eq(native.search(PackedByteArray([0]), PackedInt32Array(), PackedByteArray([1]), PackedByteArray(), {}, 0, 1, 0, 8, -1, -1), -1, "keine ungültigen Speicherzugriffe")
	check_eq(native.flow_spread(PackedByteArray([0]), PackedByteArray(), PackedInt32Array(), PackedByteArray(), PackedInt32Array(), 0, 8, false, 1), null, "ungültiges Wegfeld abgewiesen")


func test_batched_neighborhoods_match_reference_at_edges_and_in_crowds() -> void:
	var native := Backend.backend()
	if native == null:
		check(true, "Fallback ohne native Bibliothek")
		return
	var config := SimConfig.new()
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	for cell in range(500):
		var id := sim.workers.add(cell, 0, (cell / 70) % 3)
		sim.workers.aim[id] = cell * 37 - 1
	var result: Array = native.neighborhoods(world.cells, sim.workers.occupant, sim.workers.cell, sim.workers.faction, sim.workers.aim, 32)
	for id in sim.workers.count:
		check_eq(result[0][id] != 0, SwarmMind._boxed(sim, id), "Eingekreist %d" % id)
		check_eq(result[1][id], SwarmMind._watch(sim, id, sim.workers.aim[id]), "Signatur %d" % id)


func test_nearest_stand_keeps_reference_ties_and_blocked_cells() -> void:
	var was_enabled: bool = Backend.enabled
	var config := SimConfig.new()
	config.world_size = 32
	var sim := Simulation.create(config)
	var field := sim.fields[0]
	field.anchors = sim.workers.cell.duplicate()
	field.blocked.resize(sim.world.cell_count())
	for cell in range(0, sim.world.cell_count(), 29):
		field.blocked[cell] = 1
	for goal in range(0, sim.world.cell_count(), 13):
		field.goal_cell = goal
		Backend.enabled = false
		var expected := field._nearest_stand()
		Backend.enabled = was_enabled
		check_eq(field._nearest_stand(), expected, "Marschziel %d" % goal)
	field.anchors = PackedInt32Array()
	Backend.enabled = false
	var empty_expected := field._nearest_stand()
	Backend.enabled = was_enabled
	check_eq(field._nearest_stand(), empty_expected, "ohne Anker")

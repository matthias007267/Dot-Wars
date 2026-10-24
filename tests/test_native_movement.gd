extends TestCase

const Backend = preload("res://src/sim/native_search.gd")


func test_native_movement_matches_reference_for_swaps_detours_and_mining() -> void:
	var was_enabled: bool = Backend.enabled
	for variant in range(6):
		var config := SimConfig.new()
		config.world_size = 64
		config.mode = SimConfig.MODE_MATCH
		config.ai_count = 2
		config.initial_workers = 40
		var world := WorldState.new(64, 64, 8, Materials.EMPTY)
		var sim := Simulation.from_world(config, world)
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + variant
		for cell in world.cell_count():
			if world.cells[cell] == Materials.EMPTY and sim.workers.is_free(cell) and rng.randi_range(0, 9) == 0:
				world.set_material(cell, Materials.SOFT)
		for group in sim.fields.size():
			sim.assign_area(group, Rect2i(0, 0, 64, 64))
			for cell in world.cell_count():
				sim.fields[group].dir[cell] = rng.randi_range(0, 5)
				sim.fields[group].dist[cell] = rng.randi_range(-1, 20)
		var blocked := PackedByteArray()
		blocked.resize(world.cell_count())
		for cell in range(0, world.cell_count(), 17): blocked[cell] = 1
		for id in sim.workers.count:
			if id % 4 == 0:
				sim.workers.aim[id] = sim.workers.cell[id] + 1
				sim.workers.aim_step[id] = sim.workers.cell[id] if id % 8 == 0 else sim.workers.cell[id] - 64
		var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
		reference.workers.aim_step = sim.workers.aim_step.duplicate()
		for group in sim.fields.size():
			reference.fields[group].dir = sim.fields[group].dir.duplicate()
			reference.fields[group].dist = sim.fields[group].dist.duplicate()
		var speed := [0, 37, 150][variant % 3] as int
		var faction_period := PackedByteArray([1, 2, 3]) if variant >= 3 else PackedByteArray()
		for tick in range(30):
			Backend.enabled = false
			MovementSystem.step(tick, reference.workers, reference.world, reference.areas, reference.fields, 3, speed, blocked, faction_period)
			Backend.enabled = was_enabled
			MovementSystem.step(tick, sim.workers, world, sim.areas, sim.fields, 3, speed, blocked, faction_period)
			check_eq(sim.workers.state_hash(), reference.workers.state_hash(), "Fall %d Takt %d" % [variant, tick])
			check_eq(sim.workers.occupant, reference.workers.occupant, "Belegung nach ID-Reihenfolge")
			check_eq(sim.workers.move_credit, reference.workers.move_credit, "Beschleunigungsrest")
	Backend.enabled = was_enabled

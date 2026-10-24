extends TestCase
const Backend = preload("res://src/sim/native_search.gd")


func test_energy_batch_matches_reference_including_invalid_positions() -> void:
	var native := Backend.backend()
	if native == null:
		check(true, "GDScript-Fallback")
		return
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var workers := WorkerStore.new(world.cell_count(), 1, 32)
	var energy := EnergyStore.new()
	energy._dist.resize(world.cell_count())
	for cell in world.cell_count():
		energy._dist[cell] = (cell * 17) % 39 - 1
		if cell % 9 == 0: workers.add(cell, 0)
		elif cell % 13 == 0: world.set_material(cell, Materials.SOFT)
	var positions := PackedInt32Array([-1, world.cell_count(), -100])
	for cell in world.cell_count(): positions.append(cell)
	var result: PackedInt32Array = native.energy_next(positions, world.cells, workers.occupant, energy._dist, 32)
	check_eq(result.size(), positions.size(), "keine Punkte verloren")
	for index in positions.size():
		check_eq(result[index], energy._next_cell(positions[index], world, workers), "N/O/S/W und Belegung")
	check_eq(native.energy_next(positions, world.cells, PackedInt32Array(), energy._dist, 32), null, "ungültige Belegung abgewiesen")


func test_native_energy_distance_field_matches_reference_after_world_changes() -> void:
	var was_enabled: bool = Backend.enabled
	var config := SimConfig.new()
	config.world_size = 32
	var world := WorldGenerator.generate(config)
	var energy := EnergyStore.new()
	var reference := EnergyStore.new()
	var gates := PackedInt32Array([world.index(15, 15), world.index(15, 16)])
	for iteration in range(12):
		world.open_without_mining(iteration * 37)
		Backend.enabled = false
		reference._rebuild(world, gates)
		Backend.enabled = was_enabled
		energy._rebuild(world, gates)
		check_eq(energy._dist, reference._dist, "identische Entfernungen nach Änderung")
	Backend.enabled = was_enabled

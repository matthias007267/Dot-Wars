extends TestCase
## D-086: incremental paths for large maps must equal the full recomputation.
const Backend = preload("res://src/sim/native_search.gd")


func _walled_world(size: int, seed_value: int) -> WorldState:
	var world := WorldState.new(size, size, 8, Materials.EMPTY)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cell in world.cell_count():
		if rng.randi_range(0, 3) == 0: world.set_material(cell, Materials.HARD)
	# A full wall keeps separate components until mining breaks through.
	for y in size: world.set_material(world.index(size / 2, y), Materials.HARD)
	return world


func test_incremental_energy_routes_equal_full_rebuild_native_and_reference() -> void:
	var was_enabled: bool = Backend.enabled
	for native in [true, false]:
		Backend.enabled = native and was_enabled
		var world := _walled_world(40, 9101)
		var gates := PackedInt32Array([world.index(3, 3), world.index(36, 36), world.index(4, 30)])
		var owners := PackedByteArray([0, 1, 1])
		world.set_material(gates[2], Materials.HARD) # A solid gate opens later.
		var energy := EnergyStore.new()
		energy._rebuild_routed(world, gates, owners, 2)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5150
		for step in 40:
			for i in rng.randi_range(1, 6):
				var cell := rng.randi_range(0, world.cell_count() - 1)
				if world.cells[cell] != Materials.EMPTY: world.mine_cell(cell)
			if step == 10: world.mine_cell(gates[2])
			check(energy._update_routed(world, gates, owners), "openings update in place (native %s, step %d)" % [native, step])
			var fresh := EnergyStore.new()
			fresh._rebuild_routed(world, gates, owners, 2)
			check_eq(energy._routed, fresh._routed, "fields equal full rebuild (native %s, step %d)" % [native, step])
			check_eq(energy._dist, fresh._dist, "resume field equals full rebuild")
		world.set_material(world.index(10, 10), Materials.HARD)
		check(not energy._update_routed(world, gates, owners), "a closed cell requires a full rebuild")
	Backend.enabled = was_enabled


func test_army_cache_follows_opened_cells_like_reference() -> void:
	var backend := Backend.backend()
	if backend == null or not backend.has_method("army_step_reachable"):
		check(true, "reference installation")
		return
	var config := SimConfig.new()
	config.world_size = 48
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 2
	config.initial_workers = 5
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, _walled_world(48, 4401))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8128
	var placed := 0
	for cell in sim.world.cell_count():
		if placed >= 90 or sim.world.cells[cell] != Materials.EMPTY or sim.workers.occupant[cell] >= 0 or rng.randi_range(0, 6) != 0: continue
		var uid: int = sim.army.add(cell, placed % 2)
		# Goals on both sides of the wall: reachable, disconnected and solid.
		sim.army.goals[sim.army.slots[uid]] = [sim.world.index(40, 8), sim.world.index(5, 40), sim.world.index(24, 24)][placed % 3]
		placed += 1
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	reference.army.reference_only = true
	for tick in 80:
		# Mining opens a few cells per tick, including the dividing wall.
		for i in 3:
			var cell := rng.randi_range(0, sim.world.cell_count() - 1)
			if tick % 7 == 0: cell = sim.world.index(24, rng.randi_range(0, 47))
			if sim.world.cells[cell] != Materials.EMPTY:
				sim.world.mine_cell(cell)
				reference.world.mine_cell(cell)
		sim.tick_once()
		reference.tick_once()
		check_eq(sim.state_hash(), reference.state_hash(), "tick %d" % tick)
		check_eq(sim.army.occupant, reference.army.occupant, "occupancy at tick %d" % tick)
	check(sim.army.native_steps > 0, "native army actually ran")


func test_native_flow_job_equals_stateless_native_and_resumes_from_a_mid_build_save() -> void:
	var backend := Backend.backend()
	if backend == null or not backend.has_method("flow_job_begin"):
		check(true, "reference installation")
		return
	var config := SimConfig.new()
	config.world_size = 96
	config.field_budget_per_tick = 64
	var world := WorldGenerator.generate(config)
	world.carve_rect(Rect2i(6, 6, 84, 84)) # Large free area: builds span many ticks.
	var origin := Simulation.from_world(config, world)
	origin.assign_area(0, Rect2i(0, 0, 96, 96))
	# Both sides start from the same loaded copy; a fresh and a loaded start differ
	# in their first tick independently of this change (see MATCH_PERFORMANCE.md).
	var sim := SaveGame.from_snapshot(SaveGame.snapshot(origin))
	var stateless := SaveGame.from_snapshot(SaveGame.snapshot(origin))
	for field in stateless.fields: field.use_job = false
	var saved := false
	for tick in 160:
		sim.tick_once()
		stateless.tick_once()
		var building := false
		for field in sim.fields: building = building or field._job_active
		if not saved and building and tick >= 3:
			# Save in the middle of a native build and continue from the copy.
			sim = SaveGame.from_snapshot(SaveGame.snapshot(sim))
			saved = true
		check_eq(sim.state_hash(), stateless.state_hash(), "tick %d" % tick)
		for group in sim.fields.size():
			check_eq(sim.fields[group].generation, stateless.fields[group].generation, "publishes, tick %d" % tick)
			check(sim.fields[group].dist == stateless.fields[group].dist, "published field, tick %d group %d" % [tick, group])
	check(saved, "a native build was saved mid-way")


func test_background_save_keeps_the_state_of_the_call() -> void:
	var config := SimConfig.new()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	var sim := Simulation.create(config)
	for i in 30: sim.tick_once()
	var path := "user://test-background-save.dw"
	var expected := SaveGame.to_bytes(sim)
	check(SaveGame.write_file_background(path, sim), "background save accepted")
	for i in 40: sim.tick_once() # The game continues while the worker writes.
	SaveGame.finish_background_write()
	check(SaveGame.last_write_ok, "write and rename succeeded")
	check_eq(FileAccess.get_file_as_bytes(path), expected, "file holds the state of the call")
	check(not FileAccess.file_exists(path + ".tmp"), "no temporary file left")
	sim.debug_mode = true
	check(not SaveGame.write_file_background(path, sim), "test lab never autosaves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

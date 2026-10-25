extends TestCase
const Backend = preload("res://src/sim/native_search.gd")

func _backend() -> RefCounted:
	var backend := Backend.backend()
	if "--require-native" in OS.get_cmdline_user_args():
		check(backend != null and backend.has_method("army_step"), "neuer Armee-Kern tatsächlich vorhanden")
	return backend

func _fixture(seed_value: int, size_value := 32, population := 180) -> Simulation:
	var config := SimConfig.new()
	config.world_size = size_value
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 2
	config.initial_workers = 5
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(size_value, size_value, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for cell in sim.world.cell_count():
		if sim.world.cells[cell] != Materials.EMPTY or sim.workers.occupant[cell] >= 0: continue
		if rng.randi_range(0, 10) == 0: sim.world.set_material(cell, Materials.HARD)
	var free := PackedInt32Array()
	for cell in sim.world.cell_count():
		if sim.world.cells[cell] == Materials.EMPTY and sim.workers.occupant[cell] < 0: free.append(cell)
	for index in mini(population, free.size()):
		var at := rng.randi_range(0, free.size() - 1)
		var cell := free[at]
		free.remove_at(at)
		var uid: int = sim.army.add(cell, rng.randi_range(0, 2))
		var slot: int = sim.army.slots[uid]
		sim.army.goals[slot] = [sim.world.index(2, 2), sim.world.index(size_value - 3, size_value - 3), -1][index % 3]
		sim.army.hp[slot] = rng.randi_range(1, ArmyState.HEALTH)
		sim.army.next_move[slot] = rng.randi_range(0, 6)
		sim.army.last_attack[slot] = rng.randi_range(-ArmyState.ATTACK_PERIOD, 0)
	return sim

func test_native_army_matches_reference_each_tick_with_walls_allies_and_deaths() -> void:
	var backend := _backend()
	if backend == null or not backend.has_method("army_step"):
		check(true, "Referenzinstallation ohne optionalen Rechenkern")
		return
	for scenario in 8:
		var sim := _fixture(7710 + scenario)
		if scenario % 2 == 0: sim.army.teams[2] = 1
		if scenario >= 4: sim.rules.control[1] = MatchRules.CONTROL_AI
		# Dense swap removal must not change stable processing order.
		for index in range(5): sim.army.remove(sim.army.ids[index * 2])
		var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
		check(reference != null, "Vergleichsstand ladbar")
		if reference == null: continue
		reference.army.reference_only = true
		for tick in 50:
			if tick == 15:
				# A terrain revision invalidates both shared route caches.
				var cell := sim.world.index(3, 3)
				if sim.workers.occupant[cell] < 0 and sim.army.occupant[cell] < 0:
					sim.world.set_material(cell, Materials.HARD)
					reference.world.set_material(cell, Materials.HARD)
			if tick == 20:
				sim.upgrades.energy += 40
				reference.upgrades.energy += 40
				sim.buy_warrior()
				reference.buy_warrior()
			sim.tick_once()
			reference.tick_once()
			check_eq(sim.state_hash(), reference.state_hash(), "Szenario %d, Takt %d" % [scenario, tick])
			check_eq(sim.army.occupant, reference.army.occupant, "dynamische Belegung identisch")
			check_no_errors(sim.check_invariants(), "Armee- und Arbeiterbilanzen")
		check_eq(sim.army.native_steps, 50, "jeder Takt lief nativ")

func test_native_army_large_population_keeps_tick_hashes() -> void:
	var backend := _backend()
	if backend == null or not backend.has_method("army_step"):
		check(true, "optionaler Kern fehlt")
		return
	var sim := _fixture(4301, 128, 2500)
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(reference != null, "großer Vergleichsstand")
	if reference == null: return
	reference.army.reference_only = true
	for tick in 15:
		sim.tick_once()
		reference.tick_once()
		check_eq(sim.state_hash(), reference.state_hash(), "2500 Krieger Takt %d" % tick)
	check_eq(sim.army.native_steps, 15, "großer Fall läuft tatsächlich nativ")

func _args(sim: Simulation) -> Array:
	return [sim.army.ids, sim.army.cells, sim.army.owners, sim.army.goals, sim.army.next_move,
		sim.army.last_attack, sim.army.occupant, sim.workers.occupant, sim.workers.faction,
		sim.army.teams, PackedInt32Array([-1, -1, -1, -1]), PackedInt32Array(),
		PackedInt32Array([1, 10, 2, 3, 5])]

func test_native_army_rejects_bad_shapes_without_mutating_input() -> void:
	var backend := _backend()
	if backend == null or not backend.has_method("army_step"):
		check(true, "optionaler Kern fehlt")
		return
	var sim := _fixture(731, 32, 8)
	sim.army.goals.fill(-1)
	var before := sim.state_hash()
	for index in [1, 2, 6, 7, 9, 10, 12]:
		var bundle := _args(sim)
		bundle[index] = PackedByteArray() if index == 2 else PackedInt32Array()
		check(backend.army_step(bundle, [], sim.world.cells, 32, 0) == null, "ungültige Arraylänge %d" % index)
		check_eq(sim.state_hash(), before, "keine Mutation ungültiger Eingaben")
	var bundle := _args(sim)
	bundle[0] = sim.army.ids.duplicate()
	bundle[0][1] = bundle[0][0]
	check(backend.army_step(bundle, [], sim.world.cells, 32, 0) == null, "doppelte stabile IDs")
	check_eq(sim.state_hash(), before, "keine Mutation bei ungültiger ID")
	check(backend.army_step(_args(sim), [], sim.world.cells, 0, 0) == null, "ungültige Breite")

func test_more_than_sixteen_goals_keeps_reference_rules() -> void:
	var sim := _fixture(921, 32, 20)
	for index in sim.army.count: sim.army.goals[index] = index
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(reference != null, "Fallbackstand ladbar")
	if reference == null: return
	reference.army.reference_only = true
	sim.tick_once()
	reference.tick_once()
	var native := Backend.backend()
	var cached := native != null and native.has_method("army_step_cached")
	check_eq(sim.army.native_steps, 1 if cached else 0, "viele Ziele verwenden den verfügbaren exakten Rechenpfad")
	check_eq(sim.state_hash(), reference.state_hash(), "Fallback erhält Regeln")

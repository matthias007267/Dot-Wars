extends TestCase
const Scenarios = preload("res://bench/stability_scenarios.gd")
const Backend = preload("res://src/sim/native_search.gd")

func _empty(side := 32) -> Simulation:
	var config := SimConfig.new()
	config.world_size = side
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(side, side, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.army.teams[1] = 0
	return sim

func test_clear_l_proof_does_not_skip_an_earlier_valid_direction() -> void:
	var sim := _empty()
	sim.world.set_material(sim.world.index(7, 4), Materials.HARD)
	sim.world.set_material(sim.world.index(5, 6), Materials.HARD)
	var uid: int = sim.army.add(sim.world.index(4, 4), 0)
	sim.army.goals[0] = sim.world.index(8, 8)
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	reference.army.reference_only = true
	sim.army.step(sim)
	reference.army.step(reference)
	check_eq(sim.army.cells[sim.army.slots[uid]], sim.world.index(5, 4), "Osten bleibt vor Süden trotz unklarem L ab Nachbar")
	check_eq(sim.state_hash(), reference.state_hash(), "vollständige BFS entscheidet den mehrdeutigen Fall")

func test_many_goals_eviction_and_terrain_changes_match_each_tick() -> void:
	var sim := _empty()
	for y in range(2, 30):
		if y != 5 and y != 26: sim.world.set_material(sim.world.index(16, y), Materials.HARD)
	var placed := 0
	for cell in sim.world.cell_count():
		if placed >= 180: break
		if sim.world.cells[cell] != Materials.EMPTY or sim.workers.occupant[cell] >= 0: continue
		var uid: int = sim.army.add(cell, 0)
		sim.army.goals[sim.army.slots[uid]] = sim.world.index(18 + placed % 12, 2 + placed / 12)
		placed += 1
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	reference.army.reference_only = true
	for tick in 30:
		if tick == 10:
			sim.world.open_without_mining(sim.world.index(16, 16))
			reference.world.open_without_mining(reference.world.index(16, 16))
		sim.tick_once()
		reference.tick_once()
		check_eq(sim.state_hash(), reference.state_hash(), "180 Ziele mit Revision, Takt %d" % tick)
		check_no_errors(sim.check_invariants(), "keine Überlappung")
	var backend := Backend.backend()
	if backend != null and backend.has_method("army_step_cached"): check_eq(sim.army.native_steps, 30, "kein langsamer Viele-Ziele-Rückfall")

func test_cached_routes_do_not_cross_contaminate_two_worlds() -> void:
	var first := _empty()
	var second := _empty()
	first.world.set_material(first.world.index(5, 4), Materials.HARD)
	second.world.set_material(second.world.index(4, 5), Materials.HARD)
	for sim in [first, second]:
		sim.army.add(sim.world.index(4, 4), 0)
		sim.army.goals[0] = sim.world.index(8, 8)
	var ref_first := SaveGame.from_snapshot(SaveGame.snapshot(first))
	var ref_second := SaveGame.from_snapshot(SaveGame.snapshot(second))
	ref_first.army.reference_only = true
	ref_second.army.reference_only = true
	for tick in 20:
		first.tick_once()
		second.tick_once()
		ref_first.tick_once()
		ref_second.tick_once()
		check_eq(first.state_hash(), ref_first.state_hash(), "Welt A mit gleicher Revision")
		check_eq(second.state_hash(), ref_second.state_hash(), "Welt B mit anderer Belegung")

func test_mixed_save_continues_with_work_energy_and_combat() -> void:
	var sim: Simulation = Scenarios.create("mixed", 1000)
	check(sim != null, "gemischter Test startet")
	if sim == null: return
	for tick in 500:
		Scenarios.commands(sim, "mixed", tick)
		sim.tick_once()
	var loaded := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(loaded != null, "Arbeiter, Energie und Krieger ladbar")
	if loaded == null: return
	check_eq(loaded.state_hash(), sim.state_hash(), "vollständiger Zustand nach Laden")
	for tick in range(500, 550):
		Scenarios.commands(sim, "mixed", tick)
		Scenarios.commands(loaded, "mixed", tick)
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "gemischtes Fortsetzen Takt %d" % tick)
		if loaded.state_hash() != sim.state_hash(): break
	check_no_errors(loaded.check_invariants(), "geladene Mengenbilanzen")


func test_invalid_resume_payloads_are_rejected_and_old_saves_stay_readable() -> void:
	var sim := _empty()
	for malformed in range(4):
		var snapshot := SaveGame.snapshot(sim)
		if malformed == 0: snapshot.resume.flow[0].dist = PackedInt32Array()
		if malformed == 1: snapshot.resume.faces[0] = PackedInt32Array([sim.world.cell_count()])
		if malformed == 2: snapshot.resume.energy._routed = [PackedInt32Array([0])]
		if malformed == 3: snapshot.resume.front._band = PackedInt32Array([0])
		check(SaveGame.from_snapshot(snapshot) == null, "ungültiger Resume-Block %d" % malformed)
	var legacy := SaveGame.snapshot(sim)
	legacy.erase("resume")
	legacy.erase("chunk_size")
	var loaded := SaveGame.from_snapshot(legacy)
	check(loaded != null, "Version 2 ohne neue Resume-Daten bleibt lesbar")
	if loaded != null:
		loaded.run_ticks(20)
		check_no_errors(loaded.check_invariants(), "Altstand nach Fortsetzen")

func test_narrow_corridor_resumes_after_blocker_is_removed() -> void:
	var sim := _empty()
	for x in range(2, 11):
		sim.world.set_material(sim.world.index(x, 4), Materials.HARD)
		sim.world.set_material(sim.world.index(x, 6), Materials.HARD)
	var uid: int = sim.army.add(sim.world.index(3, 5), 0)
	var blocker: int = sim.army.add(sim.world.index(4, 5), 1)
	sim.army.goals[sim.army.slots[uid]] = sim.world.index(8, 5)
	sim.army.step(sim)
	check_eq(sim.army.cells[sim.army.slots[uid]], sim.world.index(3, 5), "verbündeter Krieger blockiert Ein-Zellen-Weg")
	sim.army.remove(blocker)
	sim.tick_count += 1
	sim.army.step(sim)
	check_eq(sim.army.cells[sim.army.slots[uid]], sim.world.index(4, 5), "Terrain-Cache hält keine veraltete Einheitenblockade")
	check_no_errors(sim.check_invariants(), "Belegung nach Freigabe")

func test_visibility_graph_matches_full_bfs_with_hundreds_of_goals() -> void:
	var native := Backend.backend()
	if native == null or not native.has_method("army_route_stats"):
		check(true, "optionaler Sichtgraph-Kern fehlt")
		return
	var sim := _empty(64)
	for x in range(8, 60, 8):
		for y in range(2, 62):
			if absi(y - (7 if (x / 8) % 2 == 0 else 56)) > 1: sim.world.set_material(sim.world.index(x, y), Materials.HARD)
	var placed := 0
	for y in range(2, 62, 3):
		for x in range(2, 62, 3):
			if placed >= 300: break
			var cell := sim.world.index(x, y)
			if sim.world.cells[cell] != Materials.EMPTY: continue
			var uid: int = sim.army.add(cell, 0)
			sim.army.goals[sim.army.slots[uid]] = sim.world.index(2 + placed % 59, 40 + placed / 59)
			placed += 1
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(reference != null, "Graphvergleich ladbar")
	if reference == null: return
	reference.army.reference_only = true
	for tick in 12:
		if tick == 6:
			sim.world.open_without_mining(sim.world.index(8, 32))
			reference.world.open_without_mining(reference.world.index(8, 32))
		sim.tick_once()
		reference.tick_once()
		check_eq(sim.state_hash(), reference.state_hash(), "exakte Graph-Distanzen und Richtung bei Takt %d" % tick)
	var stats: PackedInt64Array = native.army_route_stats()
	check(stats[3] > 0, "Sichtgraph wurde tatsächlich verwendet")
	check_no_errors(sim.check_invariants(), "Graphbelegung konsistent")
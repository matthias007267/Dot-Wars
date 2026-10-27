extends TestCase
const Planner = preload("res://src/sim/research_ai.gd")

func _sim() -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.rules.wallet(sim, 1).energy = 10000
	return sim

func _center(sim: Simulation, cell := 100) -> int:
	var site := sim.construction.place(sim, 3, cell, PackedInt32Array(), 1)
	check(site >= 0, "bezahltes KI-Zentrum")
	if site >= 0: sim.construction.sites.contribute(site, 1, 300)
	return site

func test_ai_connects_and_completes_research_through_real_deliveries() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	sim.tick_count = 1
	var before := sim.rules.wallet(sim, 1).energy
	Planner.step(sim, 1)
	check(not sim.energy_network.cells.is_empty(), "KI hat eigene Leitungen gelegt")
	for owner in sim.energy_network.owners: check_eq(owner, 1, "nur eigenes Netz")
	check_eq(sim.rules.wallet(sim, 1).energy, before - 60, "Leitungen kostenlos, Forschung sofort bezahlt")
	check_eq(sim.research.jobs.size(), 1, "KI-Auftrag gestartet")
	check_eq(sim.research.jobs[0].elapsed, 0, "kein kostenloser Fortschritt beim Start")
	sim.run_ticks(8)
	check_eq(int(sim.research.jobs[0].elapsed), 8, "acht direkt versorgte Forschungstakte")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "KI-Netz und Sendungen gespeichert")
	if loaded == null: return
	for tick in 800:
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "KI-Forschung nach Laden taktsynchron")
	check_eq(sim.research.level(1, "dig"), 1, "KI-Forschung abgeschlossen")
	check_eq(sim.rules.wallet(sim, 1).dig_level, 1, "nur eigene Fraktionswirkung")
	check_eq(sim.upgrades.dig_level, 0, "kein Spielervorteil")
	check(sim.rules.wallet(sim, 1).energy <= before - 60, "Lieferenergie bezahlt")

func test_ai_repairs_missing_link_and_does_not_carve_or_use_foreign_network() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	sim.tick_count = 1
	Planner.step(sim, 1)
	var path := sim.energy_network.connected_path(sim, 1, sim.construction.center(1), sim.construction.center(site))
	check(not path.is_empty(), "verbunden")
	if path.is_empty(): return
	var cut := path[path.size() / 2]
	check(sim.energy_network.remove(1, cut), "Unterbrechung")
	sim.tick_count = 101
	Planner.step(sim, 1)
	check(not sim.energy_network.connected_path(sim, 1, sim.construction.center(1), sim.construction.center(site)).is_empty(), "KI verbindet erneut")
	var blocked := _sim()
	var target := _center(blocked)
	if target < 0: return
	for x in 32: blocked.world.set_material(blocked.world.index(x, 8), Materials.HARD)
	var terrain := blocked.world.state_hash()
	blocked.tick_count = 1
	Planner.step(blocked, 1)
	check_eq(blocked.world.state_hash(), terrain, "kein kostenloses Graben")
	check(blocked.research.jobs.is_empty(), "kein unversorgbarer Auftrag")

func test_all_ai_difficulties_research_on_the_normal_simulation_path() -> void:
	for difficulty in [SimConfig.DIFFICULTY_EASY, SimConfig.DIFFICULTY_NORMAL, SimConfig.DIFFICULTY_HARD]:
		var sim := _sim()
		var site := _center(sim)
		if site < 0: return
		sim.rules.difficulty[1] = difficulty
		sim.rules.control[1] = MatchRules.CONTROL_AI
		sim.run_ticks(850)
		check(sim.research.level(1, "dig") >= 1, "Forschung mit KI-Stufe %d" % difficulty)
		check_no_errors(sim.check_invariants(), "keine KI-Bilanzumgehung")

func test_ai_reserves_the_whole_next_research_price_instead_of_one_energy_point() -> void:
	var sim := _sim()
	var site := _center(sim)
	var route := sim.energy_network.plan_connection(sim, 1, 1, site)
	sim.energy_network.place_path(sim, 1, route)
	sim.rules.wallet(sim, 1).energy = 40
	check_eq(Planner.reserve(sim, 1), 60, "sammelt gesamten Startpreis")
	sim.rules.wallet(sim, 1).energy = 60
	sim.tick_count = 1
	Planner.step(sim, 1)
	check_eq(sim.rules.wallet(sim, 1).energy, 0, "Forschung startet mit vollständiger Einmalzahlung")
	check_eq(Planner.reserve(sim, 1), 0, "bezahlter Auftrag benötigt keine weiteren Energiepunkte")

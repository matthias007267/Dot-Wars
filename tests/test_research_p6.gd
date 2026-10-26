extends TestCase
## P6: Research requires a finished center, explicit conduits, delivered energy and simulation ticks.
const Store = preload("res://src/sim/settlement_store.gd")

func _sim() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_RESEARCH
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 5000
	return sim

func _center(sim: Simulation) -> int:
	var site := sim.construction.place(sim, Store.Kind.RESEARCH_CENTER, 100, PackedInt32Array())
	check(site >= 0, "Forschungszentrum kann platziert werden")
	if site >= 0: sim.construction.sites.contribute(site, 0, 300)
	return site

func test_research_requires_ready_center_and_prerequisites() -> void:
	var sim := _sim()
	check(not sim.research.start(sim, 0, -1, "dig"), "ohne Zentrum keine Forschung")
	var site := sim.construction.place(sim, Store.Kind.RESEARCH_CENTER, 100, PackedInt32Array())
	check(site >= 0, "Zentrum platziert")
	check(not sim.research.start(sim, 0, site, "dig"), "Baustelle kann nicht forschen")
	sim.construction.sites.contribute(site, 0, 300)
	check(not sim.research.start(sim, 0, site, "swarm"), "Schwarm benötigt Abbaueffizienz")
	check(sim.research.start(sim, 0, site, "dig"), "fertiges Zentrum startet Forschung")
	check(not sim.research.start(sim, 0, site, "speed"), "Zentrum nur ein Auftrag gleichzeitig")
	check(not sim.buy(Upgrades.KIND_DIG), "alter Sofortkauf ist deaktiviert")
	check_eq(sim.upgrades.dig_level, 0, "Forschung wirkt nicht sofort")

func test_research_waits_for_delivered_energy_and_finishes_over_time() -> void:
	var sim := _sim()
	var site := _center(sim)
	check(sim.research.start(sim, 0, site, "dig"), "Forschung gestartet")
	var wallet_before := sim.upgrades.energy
	sim.research.step(sim)
	check_eq(sim.research.jobs[0].elapsed, 0, "ohne Lieferung kein Fortschritt")
	check_eq(sim.upgrades.energy, wallet_before, "ohne Verbindung keine Abbuchung")
	var cost := sim.research.details("dig", 1)
	sim.research.supply[site] = int(cost.energy)
	for tick in int(cost.ticks):
		sim.tick_count += 1
		sim.research.step(sim)
	check_eq(sim.research.level(0, "dig"), 1, "Technologie abgeschlossen")
	check_eq(sim.upgrades.dig_level, 1, "Effekt nach Abschluss aktiv")
	check_eq(sim.research.jobs.size(), 0, "Auftrag entfernt")
	check_eq(int(sim.research.supply.get(site, 0)), 0, "Energie tatsächlich verbraucht")
	check(sim.research.can_start(sim, 0, site, "swarm"), "Folgetechnologie freigeschaltet")

func test_research_state_survives_snapshot() -> void:
	var sim := _sim()
	var site := _center(sim)
	check(sim.research.start(sim, 0, site, "energy_speed"), "Auftrag gestartet")
	sim.research.supply[site] = 12
	sim.research.step(sim)
	var data := sim.research.snapshot()
	var restored := ResearchSystem.new()
	restored.setup(sim.research.levels.size())
	check(restored.restore(sim, data), "Forschungszustand geladen")
	check_eq(restored.jobs.size(), 1, "laufender Auftrag erhalten")
	check_eq(restored.jobs[0].elapsed, sim.research.jobs[0].elapsed, "Fortschritt erhalten")
	check_eq(restored.supply[site], sim.research.supply[site], "Energiepuffer erhalten")

func test_research_catalog_has_valid_dependencies() -> void:
	for tech in ResearchSystem.CATALOG:
		var entry: Dictionary = ResearchSystem.CATALOG[tech]
		check(int(entry.max) > 0, "Stufenbegrenzung")
		check(int(entry.ticks) > 0 and int(entry.energy) > 0, "Forschungsaufwand")
		for requirement in entry.requires:
			check(ResearchSystem.CATALOG.has(requirement), "Voraussetzung existiert")

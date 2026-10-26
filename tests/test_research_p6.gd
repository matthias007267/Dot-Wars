extends TestCase
## P6: Research requires a finished center, explicit conduits, delivered energy and simulation ticks.
const Planner = preload("res://src/sim/construction_ai.gd")
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
	sim.rules.wallet(sim, 1).energy = 5000
	return sim

func _center(sim: Simulation, cell := 100, owner := 0) -> int:
	var site := sim.construction.place(sim, Store.Kind.RESEARCH_CENTER, cell, PackedInt32Array(), owner)
	check(site >= 0, "Forschungszentrum kann platziert werden")
	if site >= 0: sim.construction.sites.contribute(site, owner, 300)
	return site

func test_research_requires_ready_center_and_prerequisites() -> void:
	var sim := _sim()
	check(not sim.research.start(sim, 0, -1, "dig"), "ohne Zentrum keine Forschung")
	var site := sim.construction.place(sim, Store.Kind.RESEARCH_CENTER, 100, PackedInt32Array())
	check(site >= 0, "Zentrum platziert")
	if site < 0: return
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
	if site < 0: return
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


func _connect(sim: Simulation, site: int, owner := 0) -> PackedInt32Array:
	var source := -1
	for building in sim.construction.sites.records:
		if building.owner == owner and building.kind == Store.Kind.MAIN_CORE and not building.destroyed:
			source = building.id
			break
	if source < 0: return PackedInt32Array()
	for start in sim.construction.sites.perimeter(source):
		for goal in sim.construction.sites.perimeter(site):
			var path := sim.energy_network.plan_path(sim, owner, start, goal)
			if not path.is_empty():
				sim.energy_network.place_path(sim, owner, path)
				return sim.energy_network.connected_path(sim, owner, sim.construction.center(source), sim.construction.center(site))
	return PackedInt32Array()

func test_network_delivery_is_physical_and_research_finishes_at_exact_duration() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	var path := _connect(sim, site)
	check(not path.is_empty(), "Leitung verbindet Kern und Zentrum")
	if path.is_empty(): return
	var before := sim.upgrades.energy
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag gestartet")
	check_eq(sim.upgrades.energy, before, "keine pauschale Vorauszahlung")
	sim.tick_count = 8
	sim.research.step(sim)
	check_eq(sim.research.shipments.size(), 1, "bezahlter physischer Energiedot versandt")
	check_eq(sim.upgrades.energy, before - 1, "genau eine Energie im Versand")
	check_eq(sim.research.jobs[0].elapsed, 0, "Versand ist noch keine Lieferung")
	check(not sim.research.is_powered(site, 9), "keine Verbrauchsanzeige vor Ankunft")
	for tick in path.size():
		check_eq(sim.research.shipments[0].cell, path[tick], "Dot wandert genau eine Leitungszelle pro Takt")
		sim.tick_count += 1
		sim.research.step(sim)
	check_eq(sim.research.jobs[0].elapsed, 1, "Ankunft ermöglicht ersten Forschungstakt")
	check(sim.research.is_powered(site, sim.tick_count + 1), "Glow nur bei tatsächlichem Verbrauch")
	var cost := sim.research.details("dig", 1)
	# End-to-end simulation: delivery, tick scheduling, unlock and saved effect.
	for tick in int(cost.ticks) + int(cost.energy) * 8 + path.size():
		if sim.research.jobs.is_empty(): break
		sim.tick_once()
	check_eq(sim.research.level(0, "dig"), 1, "Forschung nach echten Lieferungen abgeschlossen")
	check_eq(sim.upgrades.dig_level, 1, "globale Wirkung")
	check(sim.research.jobs.is_empty(), "Auftrag genau einmal abgeschlossen")
	var paid := before - sim.upgrades.energy
	check_eq(paid, int(cost.energy) + int(sim.research.supply.get(site, 0)) + sim.research.shipments.size(), "bezahlte Energie = verbraucht + Puffer + unterwegs")
	check_no_errors(sim.check_invariants(), "physische Forschung erhält Spielbilanzen")

func test_delivered_buffer_pauses_and_resumes_without_losing_progress() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	check(sim.research.start(sim, 0, site, "speed"), "Auftrag")
	sim.research.deliver(site)
	sim.tick_once()
	check_eq(sim.research.jobs[0].elapsed, 1, "ein versorgter Takt")
	check(sim.research.is_powered(site, sim.tick_count), "Verbrauch aktiv")
	var before := sim.research.jobs[0].duplicate(true)
	sim.run_ticks(12)
	check_eq(sim.research.jobs[0], before, "Unterversorgung erhält gesamten Fortschritt")
	check(not sim.research.is_powered(site, sim.tick_count), "kein Glow bei Pause")
	sim.research.deliver(site)
	sim.tick_once()
	check_eq(sim.research.jobs[0].elapsed, 2, "Fortsetzung nach erneuter Lieferung")
	check_eq(sim.research.jobs[0].spent, 2, "nur gelieferte Energie verbraucht")

func test_parallel_centers_and_factions_keep_jobs_and_effects_separate() -> void:
	var sim := _sim()
	var first := _center(sim)
	var second := _center(sim, 200)
	var foreign := _center(sim, 300, 1)
	if first < 0 or second < 0 or foreign < 0: return
	check(not sim.research.start(sim, 0, foreign, "dig"), "kein fremdes Zentrum nutzen")
	check(sim.research.start(sim, 0, first, "dig"), "erstes Zentrum")
	check(not sim.research.start(sim, 0, second, "dig"), "keine doppelte Technologie pro Fraktion")
	check(sim.research.start(sim, 0, second, "speed"), "andere Technologie parallel")
	check(sim.research.start(sim, 1, foreign, "dig"), "Gegner forscht unabhängig dieselbe Technologie")
	sim.research.supply[first] = 60
	sim.research.supply[second] = 55
	for tick in 180: sim.tick_once()
	check_eq(sim.research.level(0, "dig"), 1, "Abbau abgeschlossen")
	check_eq(sim.research.level(0, "speed"), 1, "Bewegung gleichzeitig abgeschlossen")
	check_eq(sim.research.level(1, "dig"), 0, "keine gegnerische Freischaltung ohne Energie")
	check_eq(sim.rules.wallet(sim, 1).dig_level, 0, "keine fremde Wirkung")
	check_eq(sim.research.jobs.size(), 1, "nur unversorgter Gegnerauftrag bleibt")
	check_eq(sim.research.jobs[0].elapsed, 0, "kein geteilter Puffer")

func test_each_level_consumes_catalog_cost_and_unlocks_only_after_last_tick() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	for stage in range(1, Upgrades.SPEED_MAX + 1):
		var cost := sim.research.details("speed", stage)
		check(sim.research.start(sim, 0, site, "speed"), "nächste Stufe")
		sim.research.supply[site] = int(cost.energy)
		for tick in int(cost.ticks) - 1:
			sim.tick_count += 1
			sim.research.step(sim)
		check_eq(sim.research.level(0, "speed"), stage - 1, "kein vorzeitiger Abschluss")
		check_eq(sim.upgrades.speed_level, stage - 1, "Effekt erst am letzten Takt")
		sim.tick_count += 1
		sim.research.step(sim)
		check_eq(sim.research.level(0, "speed"), stage, "genaue Forschungsdauer")
		check_eq(sim.research.supply[site], 0, "genauer Katalogpreis verbraucht")
	check(not sim.research.start(sim, 0, site, "speed"), "Maximum bleibt gesperrt")
	check_eq(sim.upgrades.worker_period(8), 1, "Bewegungswirkung der höchsten Forschungsstufe")

func test_network_placement_is_free_nonblocking_and_rejects_buildings_and_terrain() -> void:
	var sim := _sim()
	var cell := sim.world.index(2, 2)
	var worker := sim.workers.add(cell, 0, 0)
	sim.initial_mass += 1
	var before := sim.upgrades.energy
	check(sim.place_energy_conduit(cell), "Leitung darf unter Arbeiter liegen")
	check_eq(sim.workers.occupant[cell], worker, "keine Änderung der Belegung")
	check_eq(sim.upgrades.energy, before, "kostenlos")
	check(not sim.energy_network.place(sim, 1, cell), "keine fremde Überlagerung")
	check(not sim.place_energy_conduit(sim.construction.center(0)), "kein Gebäude überlagert")
	sim.world.set_material(cell + 1, Materials.HARD)
	check(not sim.place_energy_conduit(cell + 1), "nur freies Terrain")
	check_no_errors(sim.check_invariants(), "nicht blockierendes Netz")

func test_save_load_with_in_flight_energy_continues_tick_identically() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	var path := _connect(sim, site)
	check(not path.is_empty(), "Netz")
	if path.is_empty(): return
	check(sim.research.start(sim, 0, site, "energy_speed"), "Auftrag")
	sim.run_ticks(8)
	check(not sim.research.shipments.is_empty(), "Speichern mit unterwegs befindlicher Energie")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "vollständiger Spielstand geladen")
	if loaded == null: return
	check_eq(loaded.state_hash(), sim.state_hash(), "Netz, Energie und Auftrag erhalten")
	for tick in 40:
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "deterministische Fortsetzung Takt %d" % tick)

func test_broken_conduit_pauses_shipments_and_can_be_saved_then_reconnected() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	var path := _connect(sim, site)
	check(not path.is_empty(), "Netz")
	if path.is_empty(): return
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	sim.run_ticks(8)
	check(not sim.research.shipments.is_empty(), "Energie unterwegs")
	var cell: int = sim.research.shipments[0].cell
	check(sim.energy_network.remove(0, path[path.size() - 1]), "Leitung unterbrochen")
	sim.run_ticks(3)
	check_eq(sim.research.shipments[0].cell, cell, "Energie wartet an Unterbrechung")
	check_eq(sim.research.jobs[0].elapsed, 0, "keine unsichtbare Direktlieferung")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "unterbrochenes Netz ist ein gültiger Spielstand")
	if loaded == null: return
	check_eq(loaded.state_hash(), sim.state_hash(), "pausierter Transport bleibt erhalten")
	for state in [sim, loaded]:
		check(state.energy_network.place(state, 0, path[path.size() - 1]), "Netz repariert")
	for tick in path.size() + 2:
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "gleiche Fortsetzung nach Wiederanschluss")
	check(sim.research.jobs[0].elapsed > 0, "Forschung setzt nach realer Lieferung fort")

func test_research_restore_rejects_corruption_without_partial_state_changes() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	var restored := ResearchSystem.new()
	restored.setup(sim.research.levels.size())
	var before := restored.state_hash()
	var broken := sim.research.snapshot()
	broken.shipments = [{"site": site, "faction": 0, "source": -1, "cell": -1, "index": 0}]
	check(not restored.restore(sim, broken), "ungültige Sendung zurückgewiesen")
	check_eq(restored.state_hash(), before, "fehlgeschlagenes Laden ist atomar")
	broken = sim.research.snapshot()
	broken.jobs[0].tech = "unknown"
	check(not restored.restore(sim, broken), "unbekannte Technologie zurückgewiesen")
	broken = sim.research.snapshot()
	broken.jobs[0].elapsed = broken.jobs[0].ticks
	check(not restored.restore(sim, broken), "unmögliche Restzeit zurückgewiesen")

func test_research_center_is_not_production_or_last_core_protection() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	check_eq(sim.construction.production_site(0, site), -1, "kein Produktionsstandort")
	check(not sim.buy_worker(site), "kein Arbeiterkauf am Forschungszentrum")
	check(not sim.research.start(sim, 0, 0, "dig"), "Hauptkern ist kein Forschungszentrum")
	sim.construction.damage(sim, 0, 600)
	sim.tick_once()
	check_eq(sim.rules.alive[0], 0, "Forschungszentrum ersetzt keinen Überlebenskern")

func test_ai_plans_paid_research_center_before_outpost() -> void:
	var sim := _sim()
	var cells := sim.spawner.find_free_cells(sim.world, sim.workers, sim.construction.origin(sim, 1), 6, sim.world.cell_count())
	for cell in cells: sim.workers.add(cell, sim.rules.group_of[1], 1)
	sim.initial_mass = sim.workers.mass_sum()
	sim.rules.wallet(sim, 1).energy = 1000
	sim.tick_count = 1
	var before := sim.rules.wallet(sim, 1).energy
	check(Planner.step(sim, 1), "KI priorisiert Forschungsinfrastruktur")
	check_eq(sim.construction.sites.count(1, Store.Kind.RESEARCH_CENTER), 1, "Zentrum geplant")
	check_eq(sim.rules.wallet(sim, 1).energy, before - sim.construction.price(3, 1), "normaler Baupreis")
	var site := sim.construction.sites.records.size() - 1
	sim.run_ticks(700)
	check(sim.construction.sites.records[site].ready, "Arbeiter bauen Forschungszentrum fertig")

func test_destroyed_center_cancels_jobs_without_unlocking_or_duplicating_energy() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	var path := _connect(sim, site)
	check(not path.is_empty(), "Netz")
	if path.is_empty(): return
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	sim.run_ticks(8)
	check(not sim.research.shipments.is_empty(), "bezahlte Sendung unterwegs")
	sim.research.deliver(site)
	sim.construction.damage(sim, site, 200)
	var before := sim.upgrades.energy
	sim.tick_once()
	check(sim.research.jobs.is_empty(), "zerstörtes Zentrum verliert Auftrag")
	check(sim.research.shipments.is_empty(), "kein Transport an zerstörtes Zentrum")
	check(not sim.research.supply.has(site), "kein Puffer am zerstörten Zentrum")
	check_eq(sim.research.level(0, "dig"), 0, "kein kostenloser Abschluss")
	check_eq(sim.upgrades.dig_level, 0, "kein Effekt")
	check_eq(sim.upgrades.energy, before, "keine doppelte Gutschrift oder weiterer Versand")
	check(not sim.research.start(sim, 0, site, "dig"), "keine neue Forschung am zerstörten Zentrum")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "abgebrochener Forschungszustand speicherbar")

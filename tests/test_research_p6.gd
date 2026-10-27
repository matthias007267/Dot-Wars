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

func _connect(sim: Simulation, site: int, owner := 0) -> PackedInt32Array:
	var sources: PackedInt32Array = sim.construction.sites.ready_sites(owner)
	if sources.is_empty(): return PackedInt32Array()
	var path := sim.energy_network.plan_connection(sim, owner, sources[0], site)
	sim.energy_network.place_path(sim, owner, path)
	return path

func _center(sim: Simulation, cell := 100, owner := 0, connected := true) -> int:
	var site: int = sim.construction.place(sim, Store.Kind.RESEARCH_CENTER, cell, PackedInt32Array(), owner)
	check(site >= 0, "bezahltes Forschungszentrum")
	if site >= 0:
		sim.construction.sites.contribute(site, owner, 300)
		if connected: _connect(sim, site, owner)
	return site

func test_research_requires_ready_connected_center_funds_and_prerequisites() -> void:
	var sim := _sim()
	check(not sim.research.start(sim, 0, -1, "dig"), "kein Zentrum")
	var site: int = sim.construction.place(sim, 3, 100, PackedInt32Array())
	check(not sim.research.start(sim, 0, site, "dig"), "Baustelle forscht nicht")
	sim.construction.sites.contribute(site, 0, 300)
	check(not sim.research.start(sim, 0, site, "dig"), "kein Netz")
	_connect(sim, site)
	check(not sim.research.start(sim, 0, site, "swarm"), "Abbau als Voraussetzung")
	sim.upgrades.energy = 59
	check(not sim.research.start(sim, 0, site, "dig"), "vollständiger Preis erforderlich")
	check_eq(sim.upgrades.energy, 59, "abgelehnter Auftrag kostet nichts")
	sim.upgrades.energy = 60
	check(sim.research.start(sim, 0, site, "dig"), "fertig, verbunden und bezahlt")
	check_eq(sim.upgrades.energy, 0, "sofort genau 60 abgezogen")
	check(not sim.research.start(sim, 0, site, "speed"), "nur ein Auftrag je Zentrum")
	check(not sim.buy(Upgrades.KIND_DIG), "Sofortkauf bleibt entfernt")
	check_eq(sim.upgrades.dig_level, 0, "Kosten erzeugen keinen Soforteffekt")

func test_upfront_research_continues_at_zero_wallet_and_finishes_exactly_on_last_tick() -> void:
	var sim := _sim()
	var site := _center(sim)
	sim.upgrades.energy = 60
	check(sim.research.start(sim, 0, site, "dig"), "Start")
	for tick in 179:
		sim.research.step(sim)
		sim.tick_count += 1
	check_eq(sim.upgrades.dig_level, 0, "kein vorzeitiger Effekt")
	check_eq(int(sim.research.jobs[0].elapsed), 179, "nur ein Zeitfortschritt")
	check_eq(sim.upgrades.energy, 0, "keine weitere Zahlung erforderlich")
	sim.research.step(sim)
	check_eq(sim.research.level(0, "dig"), 1, "Abschluss bei Takt 180")
	check_eq(sim.upgrades.dig_level, 1, "Effekt aktiv")
	check(sim.research.jobs.is_empty(), "Auftrag nur einmal abgeschlossen")
	check(not sim.research.snapshot().has("shipments") and not sim.research.snapshot().has("supply"), "keine Einzelenergie im Laufzeitstate")

func test_broken_or_foreign_conduits_pause_paid_time_and_resume_without_charge() -> void:
	var sim := _sim()
	var site := _center(sim, 100, 0, false)
	var path := _connect(sim, site)
	check(sim.research.start(sim, 0, site, "speed"), "Start")
	for tick in 12: sim.research.step(sim)
	var before := sim.upgrades.energy
	var cut := path[path.size() / 2]
	sim.energy_network.remove(0, cut)
	for tick in 20: sim.research.step(sim)
	check_eq(int(sim.research.jobs[0].elapsed), 12, "Leitungsabriss hält Fortschritt")
	check(not sim.research.is_powered(site, sim.tick_count + 1), "Aktivität aus")
	sim.energy_network.place(sim, 1, cut)
	sim.research.step(sim)
	check_eq(int(sim.research.jobs[0].elapsed), 12, "fremde Leitung hilft nicht")
	sim.energy_network.remove(1, cut)
	sim.energy_network.place(sim, 0, cut)
	sim.research.step(sim)
	check_eq(int(sim.research.jobs[0].elapsed), 13, "sofort fortgesetzt")
	check_eq(sim.upgrades.energy, before, "keine erneute Abbuchung")

func test_parallel_centers_and_factions_keep_jobs_effects_and_wallets_separate() -> void:
	var sim := _sim()
	var a := _center(sim)
	var b := _center(sim, 200)
	var c := _center(sim, 300, 1)
	check(not sim.research.start(sim, 0, c, "dig"), "kein fremdes Zentrum")
	var own := sim.upgrades.energy
	var enemy := sim.rules.wallet(sim, 1).energy
	check(sim.research.start(sim, 0, a, "dig"), "erster Auftrag")
	check(not sim.research.start(sim, 0, b, "dig"), "keine doppelte Technologie")
	check(sim.research.start(sim, 0, b, "speed"), "parallel andere Technologie")
	check(sim.research.start(sim, 1, c, "dig"), "unabhängige Gegnerforschung")
	check_eq(sim.upgrades.energy, own - 115, "nur eigene Aufträge bezahlt")
	check_eq(sim.rules.wallet(sim, 1).energy, enemy - 60, "nur Gegner zahlt Gegnerauftrag")
	for tick in 180: sim.research.step(sim)
	check_eq(sim.upgrades.dig_level, 1, "eigener Abbau")
	check_eq(sim.upgrades.speed_level, 1, "eigene Bewegung")
	check_eq(sim.rules.wallet(sim, 1).dig_level, 1, "eigener Gegnereffekt")

func test_each_level_freezes_price_and_waits_for_full_catalog_duration() -> void:
	var sim := _sim()
	var site := _center(sim)
	for stage in range(1, Upgrades.SPEED_MAX + 1):
		var cost := sim.research.details("speed", stage)
		var before := sim.upgrades.energy
		check(sim.research.start(sim, 0, site, "speed"), "Folgestufe")
		check_eq(sim.upgrades.energy, before - int(cost.energy), "voller Stufenpreis")
		for tick in int(cost.ticks) - 1: sim.research.step(sim)
		check_eq(sim.upgrades.speed_level, stage - 1, "kein vorzeitiger Effekt")
		sim.research.step(sim)
		check_eq(sim.upgrades.speed_level, stage, "genaue Dauer")
	check(not sim.research.start(sim, 0, site, "speed"), "Maximum")

func test_save_load_with_paid_job_and_cut_network_continues_tick_identically() -> void:
	var sim := _sim()
	var site := _center(sim)
	check(sim.research.start(sim, 0, site, "energy_speed"), "Start")
	sim.run_ticks(8)
	var path := sim.energy_network.connected_path(sim, 0, sim.construction.center(0), sim.construction.center(site))
	var cut := path[path.size() / 2]
	sim.energy_network.remove(0, cut)
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "bezahlte Pause gespeichert")
	if loaded == null: return
	check_eq(loaded.state_hash(), sim.state_hash(), "Zustand erhalten")
	for state in [sim, loaded]: state.energy_network.place(state, 0, cut)
	for tick in 40:
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "taktgleiche Fortsetzung")

func test_restore_rejects_corruption_without_partial_changes() -> void:
	var sim := _sim()
	var site := _center(sim)
	check(sim.research.start(sim, 0, site, "dig"), "Start")
	var data := sim.research.snapshot()
	for field in ["energy", "ticks", "site", "paid"]:
		var broken := data.duplicate(true)
		broken.jobs[0][field] = -1
		var before := sim.research.state_hash()
		var wallet := sim.upgrades.energy
		check(not sim.research.restore(sim, broken), "ungültiges Feld " + field)
		check_eq(sim.research.state_hash(), before, "atomare Ablehnung")
		check_eq(sim.upgrades.energy, wallet, "keine Teilgutschrift")

func test_destroyed_center_aborts_prepaid_job_once_without_refund() -> void:
	var sim := _sim()
	var site := _center(sim)
	check(sim.research.start(sim, 0, site, "dig"), "Start")
	var before := sim.upgrades.energy
	sim.construction.damage(sim, site, 200)
	check(SaveGame.from_bytes(SaveGame.to_bytes(sim)) != null, "Zerstörung noch vor nächstem Forschungstakt speicherbar")
	sim.research.step(sim)
	check(sim.research.jobs.is_empty(), "abgebrochen")
	check_eq(sim.research.lost_energy, 60, "bezahlter Auftrag verloren")
	sim.research.step(sim)
	check_eq(sim.research.lost_energy, 60, "nur einmal Verlust")
	check_eq(sim.upgrades.energy, before, "keine Erstattung")
	check(SaveGame.from_bytes(SaveGame.to_bytes(sim)) != null, "Abbruch speicherbar")

func test_research_catalog_has_valid_dependencies() -> void:
	for tech in ResearchSystem.CATALOG:
		var entry: Dictionary = ResearchSystem.CATALOG[tech]
		check(int(entry.max) > 0 and int(entry.ticks) > 0 and int(entry.energy) > 0, "Katalogwerte")
		for dependency in entry.requires: check(ResearchSystem.CATALOG.has(dependency), "Voraussetzung")

func test_legacy_paid_buffers_and_shipments_migrate_without_double_payment() -> void:
	var sim := _sim()
	var site := _center(sim)
	var legacy := {"levels": sim.research.levels.duplicate(true), "jobs": [{"faction": 0, "site": site, "tech": "dig", "elapsed": 17, "ticks": 180, "energy": 60, "spent": 20, "efficiency": 0}], "supply": {site: 10}, "shipments": [{"site": site, "faction": 0, "source": sim.construction.center(0), "cell": 68, "index": 0}], "lost_energy": 0}
	sim.upgrades.energy = 0
	check(sim.research.restore(sim, legacy), "alter bezahlter Zustand migriert")
	check_eq(int(sim.research.jobs[0].paid), 31, "Verbrauch, Puffer und Sendung angerechnet")
	check_eq(int(sim.research.jobs[0].elapsed), 17, "Fortschritt erhalten")
	sim.research.step(sim)
	check_eq(int(sim.research.jobs[0].elapsed), 17, "fehlende Restzahlung pausiert")
	sim.upgrades.energy = 29
	sim.research.step(sim)
	check_eq(sim.upgrades.energy, 0, "nur unbezahlt gebliebener Rest abgezogen")
	check_eq(int(sim.research.jobs[0].elapsed), 18, "Fortsetzung")
	var snapshot := sim.research.snapshot()
	check(sim.research.restore(sim, snapshot), "neuer Stand wieder ladbar")
	check_eq(sim.upgrades.energy, 0, "kein nochmaliger Migrationsgewinn")
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

func test_legacy_idle_reservations_are_returned_once_not_duplicated_on_reload() -> void:
	var sim := _sim()
	var site := _center(sim)
	var old := {"levels": sim.research.levels.duplicate(true), "jobs": [], "supply": {site: 3}, "shipments": [{"site": site, "faction": 0, "source": sim.construction.center(0), "cell": 68, "index": 0}], "lost_energy": 0}
	var before := sim.upgrades.energy
	check(sim.research.restore(sim, old), "alte unbenutzte Reservierung lesbar")
	check_eq(sim.upgrades.energy, before + 4, "drei Pufferpunkte und eine bezahlte Sendung zurückgebucht")
	check(sim.research.restore(sim, sim.research.snapshot()), "neuer Stand ladbar")
	check_eq(sim.upgrades.energy, before + 4, "kein zweiter Gewinn beim Laden")

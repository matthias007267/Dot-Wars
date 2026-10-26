extends TestCase

func _sim() -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 20000
	return sim

func _center(sim: Simulation, cell := 100) -> int:
	var id := sim.construction.place(sim, 3, cell, PackedInt32Array())
	check(id >= 0, "Forschungszentrum")
	if id >= 0: sim.construction.sites.contribute(id, 0, 300)
	return id

func _connect(sim: Simulation, site: int) -> PackedInt32Array:
	var path := sim.energy_network.plan_connection(sim, 0, 0, site)
	check(not path.is_empty(), "platzierbarer Netzpfad")
	sim.energy_network.place_path(sim, 0, path)
	return sim.energy_network.connected_path(sim, 0, sim.construction.center(0), sim.construction.center(site))

func test_regular_building_unlocks_are_faction_scoped_and_saved() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	check(not sim.construction.unlocked(sim, 1), "Außenposten zunächst gesperrt")
	check(not sim.research.start(sim, 0, site, "outpost"), "Bewegung erforderlich")
	check(TestHelpers.complete_buffered_research(sim, site, "speed"), "Voraussetzung")
	check(TestHelpers.complete_buffered_research(sim, site, "outpost"), "Freischaltung erforscht")
	check(sim.construction.unlocked(sim, 1), "normale Freischaltung ohne Testlabor")
	check(not sim.construction.unlocked(sim, 1, 1), "keine Gegnerfreischaltung")
	check(sim.construction.place(sim, 1, 300, PackedInt32Array()) >= 0, "regulärer Bau")
	check(TestHelpers.complete_buffered_research(sim, site, "energy_speed"), "Energietransport")
	check(TestHelpers.complete_buffered_research(sim, site, "interceptor"), "Abfangstation erforscht")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "Freischaltungen gespeichert")
	if loaded != null:
		check(loaded.construction.unlocked(loaded, 1), "Außenposten bleibt frei")
		check(loaded.construction.unlocked(loaded, 2), "Abfangstation bleibt frei")

func test_efficiency_reduces_cost_not_duration_and_freezes_running_job_price() -> void:
	var sim := _sim()
	var site := _center(sim)
	var other := _center(sim, 200)
	if site < 0 or other < 0: return
	check(TestHelpers.complete_buffered_research(sim, site, "energy_speed"), "Voraussetzung")
	for stage in range(1, 4):
		check(TestHelpers.complete_buffered_research(sim, site, "efficiency"), "Effizienzstufe")
		check_eq(sim.research.details("dig", 1, 0).energy, 60 - 6 * stage, "10/20/30 Prozent")
		check_eq(sim.research.details("dig", 1, 0).ticks, 180, "Dauer unverändert")
		if stage == 1:
			check(sim.research.start(sim, 0, other, "dig"), "paralleler Auftrag mit 10 Prozent Rabatt")
			check_eq(sim.research.jobs[0].energy, 54, "Startpreis")
	check(not sim.research.can_start(sim, 0, site, "efficiency"), "Maximalstufe")
	check_eq(sim.research.jobs[0].energy, 54, "laufender Auftrag nicht nachträglich umgepreist")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "eingefrorener Preis nach späterer Forschung gültig")
	if loaded != null: check_eq(loaded.research.jobs[0].energy, 54, "gespeicherter Preis")

func test_removed_occupied_conduit_pauses_and_restore_reconnects_without_teleport() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	var path := _connect(sim, site)
	if path.is_empty(): return
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	sim.run_ticks(8)
	var cell: int = sim.research.shipments[0].cell
	check(sim.energy_network.remove(0, cell), "Leitung unter Sendung abgerissen")
	sim.run_ticks(10)
	check_eq(sim.research.shipments[0].cell, cell, "Sendung bleibt am Ort")
	check_eq(sim.research.jobs[0].elapsed, 0, "kein Fortschritt ohne Lieferung")
	check(sim.energy_network.place(sim, 1, cell), "fremde Ersatzleitung")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "Pause auf abgerissener/fremder Zelle gespeichert")
	if loaded == null: return
	loaded.run_ticks(3)
	check_eq(loaded.research.shipments[0].cell, cell, "kein Transport auf fremder Leitung")
	check(loaded.energy_network.remove(1, cell), "fremde Leitung entfernt")
	check(loaded.energy_network.place(loaded, 0, cell), "Wiederanschluss")
	loaded.run_ticks(800)
	check_eq(loaded.research.level(0, "dig"), 1, "Fortsetzung ohne kostenlose Technologie")
	check_eq(loaded.research.lost_energy, 0, "kein Verlust durch Leitungsabriss")

func test_source_loss_keeps_paid_shipments_and_target_loss_records_exact_loss() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	_connect(sim, site)
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	sim.run_ticks(8)
	var count := sim.research.shipments.size()
	check(count > 0, "bezahlte Energie")
	# A surviving outpost protects the faction; already paid energy stays on the network.
	sim.construction.outposts_unlocked = true
	var outpost := sim.construction.place(sim, 1, 300, PackedInt32Array())
	check(outpost >= 0, "Ersatzversorgung")
	if outpost < 0: return
	sim.construction.sites.contribute(outpost, 0, 300)
	var route := sim.energy_network.plan_connection(sim, 0, outpost, site)
	sim.energy_network.place_path(sim, 0, route)
	sim.construction.damage(sim, 0, 600)
	sim.run_ticks(16)
	check(sim.research.jobs[0].elapsed > 0, "bezahlte Energie kommt trotz Quellverlust an")
	check(sim.research.source_for(sim, 0, site) == sim.construction.center(outpost), "eigene Ersatzquelle gewählt")
	var pending := sim.research.shipments.size() + int(sim.research.supply.get(site, 0))
	var wallet := sim.upgrades.energy
	sim.construction.damage(sim, site, 200)
	sim.tick_once()
	check_eq(sim.research.lost_energy, pending, "Verlust genau einmal erfasst")
	check_eq(sim.upgrades.energy, wallet, "keine Erstattung")
	sim.tick_once()
	check_eq(sim.research.lost_energy, pending, "keine doppelte Verlustbuchung")

func test_demolition_requires_reachable_workers_and_twenty_percent_work() -> void:
	var sim := _sim()
	var site := _center(sim)
	if site < 0: return
	check(not sim.construction.start_demolition(sim, site), "kein Sofortabriss ohne Arbeiter")
	var edge: int = sim.construction.sites.perimeter(site)[0]
	var worker := sim.workers.add(edge, 0, 0)
	sim.initial_mass += 1
	check(sim.construction.start_demolition(sim, site), "eigener Abriss")
	check(not sim.construction.start_demolition(sim, 0), "Hauptkern geschützt")
	sim.run_ticks(30)
	sim.construction.damage(sim, site, 1)
	check(sim.construction.demolitions.has(site), "Treffer bricht Abriss nicht still ab")
	sim.run_ticks(29)
	check(sim.construction.sites.valid(site), "59 Arbeitertakte reichen nicht")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "laufender Abriss gespeichert")
	sim.tick_once()
	check(not sim.construction.sites.valid(site), "60 = 20 Prozent von 300")
	if loaded != null:
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "Abriss nach Laden identisch")

func test_new_overlays_and_hidden_build_actions_do_not_expose_enemy_state() -> void:
	var sim := _sim()
	var renderer := WorldRenderer.new()
	renderer.energy_sim = sim
	var hidden := sim.world.index(30, 30)
	check(not sim.fog.is_visible(0, hidden), "unbekannte Zelle")
	check(not renderer.overlay_visible(hidden, 1), "fremde Netzaktivität verborgen")
	check(renderer.overlay_visible(hidden, 0), "eigene Infrastruktur bekannt")
	sim.research.shipments.append({"site": 0, "faction": 1, "source": 0, "cell": hidden, "index": 0})
	check(renderer.visible_shipments().is_empty(), "keine fremde Sendung im Ausgabepfad")
	var hud := GameHud.new()
	hud.sim = sim
	hud.toggle_energy_network()
	check(not hud.place_energy_network_cell(hidden), "keine Terrainprobe durch Blindplatzierung")
	check(not hud.demolish_at(hidden), "keine Gebäudeprobe durch Blindabriss")
	check(sim.energy_network.plan_path(sim, 0, hidden, hidden - 1, 0).is_empty(), "keine unsichtbare Netzvorschau")
	hud.free()
	renderer.free()

func test_graph_has_catalog_nodes_dependency_edges_and_inspectable_locks() -> void:
	var sim := _sim()
	var view := ResearchTreeView.new()
	view.refresh(sim, -1)
	check_eq(view.buttons.size(), ResearchSystem.CATALOG.size(), "alle Katalogknoten")
	check(view.positions["swarm"].y > view.positions["dig"].y, "Voraussetzung oberhalb des Kindes")
	view.select_tech("outpost")
	check_eq(view.selected, "outpost", "gesperrte Technologie auswählbar")
	check(not view.available("outpost"), "gesperrte Forschung nicht startbar")
	view.set_zoom(3.0)
	check_eq(view.zoom, 1.6, "Zoom begrenzt")
	view.set_zoom(0.1)
	check_eq(view.zoom, 0.55, "herauszoomen begrenzt")
	view.free()

func test_building_cannot_cover_conduits_and_poison_saved_network() -> void:
	var sim := _sim()
	check(sim.energy_network.place(sim, 0, 100), "Leitung")
	check_eq(sim.construction.place(sim, 3, 100, PackedInt32Array()), -1, "Leitung vor Gebäudebau entfernen")
	check(sim.energy_network.remove(0, 100), "Q-Leitungsabriss")
	check(sim.construction.place(sim, 3, 100, PackedInt32Array()) >= 0, "Bau nach Freiräumen")
	check(SaveGame.from_bytes(SaveGame.to_bytes(sim)) != null, "Baugrund und Netz konsistent gespeichert")

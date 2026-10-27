extends TestCase

func _sim() -> Simulation:
	var config := TestHelpers.default_config()
	config.mode = SimConfig.MODE_MATCH
	config.world_size = 32
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	return sim

func _center(sim: Simulation, owner := 0, cell := 100) -> int:
	sim.rules.wallet(sim, owner).energy = 600
	var site := sim.construction.place(sim, 3, cell, PackedInt32Array(), owner)
	if site >= 0:
		sim.construction.sites.contribute(site, owner, 300)
		var path := sim.energy_network.plan_connection(sim, owner, owner, site)
		sim.energy_network.place_path(sim, owner, path)
	return site

func test_atlas_regions_layers_and_icons_share_one_catalog() -> void:
	for atlas: SpriteAtlas in [SpriteCatalog.ATLAS, SpriteCatalog.UNITS]:
		check_eq(atlas.body.get_size(), atlas.team_mask.get_size(), "deckungsgleiche Ebenen")
		for key in atlas.rows:
			var first := SpriteCatalog.region(key)
			var last := SpriteCatalog.region(key, (atlas.frames - 1) * atlas.frame_ticks)
			check(Rect2(Vector2.ZERO, atlas.body.get_size()).encloses(first.merge(last)), key + " vollständig im Atlas")
	check(SpriteCatalog.region("worker.idle") != SpriteCatalog.region("warrior.idle"), "eigene Art-Silhouetten")
	check_eq(SpriteCatalog.region("worker.mine", 0), SpriteCatalog.region("worker.mine", 16), "Quadrat bleibt beim Arbeiten gleich")
	check_eq(TacticalArt.icon("research"), SpriteCatalog.icon("research"), "HUD und Welt teilen Katalog")
	check_eq(SpriteCatalog.icon("worker").get_size(), Vector2(32, 32), "HUD-Porträt")
	var mask: Image = SpriteCatalog.UNITS.team_mask.get_image()
	var body: Image = SpriteCatalog.UNITS.body.get_image()
	var team_pixel := Vector2i(4, 16)
	check(mask.get_pixelv(team_pixel).a > 0.0, "Außenrand trägt separate Fraktionsmaske")
	check(body.get_pixelv(team_pixel).a == 0.0, "Teamfarbe nicht in Körpergrafik eingebrannt")

func test_approved_square_variants_keep_team_band_and_distinct_armor() -> void:
	var previous := 0
	for key in ["worker.idle", "warrior.1", "warrior.2", "warrior.3"]:
		var source := Rect2i(SpriteCatalog.region(key))
		check_eq(source.size, Vector2i(32, 32), "gleicher quadratischer Fußabdruck")
		var body: Image = SpriteCatalog.UNITS.body.get_image().get_region(source)
		var team: Image = SpriteCatalog.UNITS.team_mask.get_image().get_region(source)
		for point in [Vector2i(3, 16), Vector2i(28, 16), Vector2i(16, 3), Vector2i(16, 28)]:
			check(team.get_pixelv(point).a > 0.9, key + " durchgehende Teamkennung an allen vier Seiten")
		var art_hash := hash([body.get_data(), team.get_data()])
		check(art_hash != previous, key + " unterscheidbare Grafik")
		previous = art_hash
	check_eq(SpriteCatalog.worker_row(WorkerStore.STATE_MOVING), SpriteCatalog.worker_row(WorkerStore.STATE_MINING), "keine neue Pose beim Abbau")
	check_eq(SpriteCatalog.warrior_row(), SpriteCatalog.row("warrior.1"), "bestehender Basiskrieger bleibt Stufe 1")

func test_workers_encode_real_state_faction_and_only_own_upgrades() -> void:
	var sim := _sim()
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	for state in WorkerStore.STATE_COUNT:
		var id := sim.workers.add(320 + state, 0, 0)
		sim.workers.state[id] = state
	var enemy := sim.workers.add(330, 0, 1) # same color group, different faction
	sim.upgrades.dig_level = 4
	var before := sim.state_hash()
	var view := WorkerRenderer.new()
	view.world = sim.world
	view.workers = sim.workers
	view.sim = sim
	view.glow_enabled = false
	view._ready()
	view.show_tick(0)
	for state in WorkerStore.STATE_COUNT:
		var offset := (320 + state) * 4
		check_eq(view._details[offset], SpriteCatalog.worker_row(state), "tatsächlicher Arbeitszustand")
		check_eq(view._details[offset + 1], state, "Arbeitszustand statt Blickrichtung")
		check_eq(view._details[offset + 3], 2, "vorhandene eigene Forschungsmarkierung")
	check_eq(view._details[sim.workers.cell[enemy] * 4 + 2], 1, "Fraktion unabhängig von Farbgruppe")
	check_eq(view._details[sim.workers.cell[enemy] * 4 + 3], 0, "keine erfundene Gegnerforschung")
	check_eq(view.material.get_shader_parameter("glow_strength"), 0.0, "Leuchten abgeschaltet")
	check(view.material.get_shader_parameter("sprites_enabled"), "Sprite bleibt ohne Leuchten lesbar")
	check_eq(sim.state_hash(), before, "Darstellung ändert keine Simulation")
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	view.show_tick(1)
	check_eq(view._details[320 * 4 + 3], 0, "alte Forschungsmarkierung entfernt")
	check_eq(view._bytes[320 * 4 + 3], 0, "tote Einheit unsichtbar")
	view.free()

func test_unit_details_do_not_retain_hidden_or_dead_units() -> void:
	var sim := _sim()
	var hidden := sim.world.index(25, 3)
	sim.army.add(hidden, 1)
	var view := ArmyRenderer.new()
	view.sim = sim
	view.show_tick(0)
	check_eq(view._bytes[hidden * 4 + 3], 0, "verborgener Krieger nicht gezeichnet")
	check_eq(view._details[hidden * 4 + 2], 0, "keine verborgenen Fraktionsdetails")
	var own := sim.workers.cell[0] + 2
	var uid := sim.army.add(own, 0)
	var slot: int = sim.army.slots[uid]
	sim.army.last_attack[slot] = 1
	view.show_tick(1)
	check_eq(view._details[own * 4 + 1], 2, "tatsächlicher Angriff")
	view.show_tick(4)
	check_eq(view._details[own * 4 + 1], 0, "Angriff endet ohne neue Treffer")
	sim.army.next_move[slot] = 8
	view.show_tick(6)
	check_eq(view._details[own * 4 + 1], 1, "echter Bewegungstimer")
	sim.army.remove(uid)
	view.show_tick(7)
	check_eq(view._details[own * 4], 0, "entfernte Kriegerdetails bereinigt")
	view.free()

func test_research_visuals_follow_delivery_progress_and_completion() -> void:
	var sim := _sim()
	var site := _center(sim)
	check(site >= 0, "Zentrum")
	if site < 0: return
	var row: Dictionary = sim.construction.sites.records[site]
	var visuals := ResearchVisualState.new()
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "idle", "bereit ohne Auftrag")
	check(sim.research.start(sim, 0, site, "dig"), "echter Forschungsauftrag")
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "active", "bezahlter verbundener Auftrag aktiv")
	sim.tick_once()
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "active", "reale Lieferung startet Aktivität")
	var path := sim.energy_network.connected_path(sim, 0, sim.construction.center(0), sim.construction.center(site))
	var cut := path[path.size() / 2]
	sim.energy_network.remove(0, cut)
	sim.tick_once()
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "waiting", "Netzabriss unterbricht Aktivität")
	sim.energy_network.place(sim, 0, cut)
	while not sim.research.jobs.is_empty():
		sim.tick_once()
		visuals.sync(sim)
		if sim.research.jobs.size() == 1 and int(sim.research.jobs[0].elapsed) == 61:
			check_eq(visuals.state(sim, row), "active", "bereits bezahlte Restdauer bleibt aktiv")
	check_eq(visuals.state(sim, row), "complete", "beobachteter tatsächlicher Abschluss")
	var before := sim.state_hash()
	visuals.sync(sim)
	check_eq(sim.state_hash(), before, "rein visuelle Abschlussanzeige")
	sim.run_ticks(ResearchVisualState.COMPLETE_TICKS)
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "idle", "Abschlussanzeige endet in Simulationszeit")

func test_hidden_centers_and_unobserved_completions_have_no_activity() -> void:
	var sim := _sim()
	var site := _center(sim, 1, sim.world.index(24, 2))
	check(site >= 0, "gegnerisches Zentrum")
	if site < 0: return
	var row: Dictionary = sim.construction.sites.records[site]
	check(not CavernLighting.site_visible(sim, row), "Zentrum verborgen")
	check(sim.research.start(sim, 1, site, "dig"), "gegnerischer Auftrag")
	sim.tick_once()
	var visuals := ResearchVisualState.new()
	visuals.sync(sim)
	check(not visuals._jobs.has(site), "keine Aufnahme verborgener Aktivitäten")
	check_eq(visuals.state(sim, row), "idle", "kein Betriebssignal durch Fog")
	sim.run_ticks(180)
	visuals.sync(sim)
	check(not visuals._completed_until.has(site), "kein ungesehener Abschlussblitz")
	check_eq(visuals.state(sim, row), "idle", "verborgener Endstand bleibt inaktiv")

func test_losing_sight_discards_activity_and_completion_history() -> void:
	var sim := _sim()
	var site := _center(sim, 1, sim.world.index(24, 2))
	check(site >= 0, "gegnerisches Zentrum")
	if site < 0: return
	var row: Dictionary = sim.construction.sites.records[site]
	check(sim.research.start(sim, 1, site, "dig"), "beobachteter Auftrag")
	sim.tick_once()
	# Explicit knowledge fixture: the renderer must respond even within one tick.
	sim.fog.visible[0].fill(1)
	var visuals := ResearchVisualState.new()
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "active", "Betrieb während Sichtkontakt")
	var memory := row.duplicate(true)
	sim.fog.visible[0].fill(0)
	visuals.sync(sim)
	check(not visuals._jobs.has(site), "Beobachtung bei Sichtverlust verworfen")
	check_eq(visuals.state(sim, memory), "idle", "Erinnerungsbild ohne Live-Betrieb")
	sim.run_ticks(180)
	visuals.sync(sim)
	sim.fog.visible[0].fill(1)
	visuals.sync(sim)
	check_eq(visuals.state(sim, row), "idle", "Wiederentdeckung meldet keinen verborgenen Abschluss")
	check(not visuals._completed_until.has(site), "keine nachträgliche Abschlussanimation")

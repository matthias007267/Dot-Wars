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

func test_lighting_uses_player_knowledge_and_preserves_simulation() -> void:
	var sim := _sim()
	var hidden := sim.rules.cores[1]
	check(not sim.fog.is_visible(0, hidden), "Gegnerkern unbekannt")
	var before := sim.state_hash()
	var sources := CavernLighting.sources(sim)
	check(sources.size() > 0, "eigene Beleuchtung")
	for source in sources: check(source.cell != hidden, "kein Licht verrät den Gegnerkern")
	var lighting := CavernLighting.new()
	var texture := lighting.update(sim)
	check(texture != null, "Lichtkarte erzeugt")
	check(lighting.width <= 512 and lighting.height <= 512, "Texturgröße begrenzt")
	check_eq(lighting.update(sim), texture, "unveränderte Quellen nutzen dieselbe Textur")
	check_eq(sim.state_hash(), before, "Beleuchtung verändert keine Spielregeln")

func test_light_cap_and_unit_types_are_visual_only() -> void:
	var sim := _sim()
	for i in 100:
		sim.research.shipments.append({"site": 0, "faction": 0, "cell": 200 + i, "source": 0, "index": 0})
	check_eq(CavernLighting.sources(sim).size(), 64, "Lichtquellen begrenzt")
	var worker := TacticalArt.icon("worker")
	var warrior := TacticalArt.icon("warrior")
	check(worker != warrior, "unterschiedliche Silhouetten")
	check_eq(TacticalArt.icon("worker"), worker, "Icontexturen werden wiederverwendet")
	check_eq(worker.get_size(), Vector2(32, 32), "Pixelraster")

func test_hud_uses_one_bottom_strip_and_keeps_live_actions() -> void:
	var hud := GameHud.new()
	hud.sim = _sim()
	hud.clock = TickClock.new()
	var layer := Control.new()
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	check_eq(hud._bottom_strip.get_parent(), layer, "gemeinsame Leiste")
	check_eq(hud._bottom_strip.anchor_top, 1.0, "unten verankert")
	check(hud._research_center_button.icon != null, "Bauicon")
	check_eq(hud._buy_worker_button.get_parent(), hud._dock_row, "Kauf bleibt erreichbar")
	hud.select_at(hud.sim.workers.cell[0])
	hud._refresh_selection()
	check(hud._selection_caption.text.contains("1 EINHEIT"), "Auswahl an echte Einheiten gebunden")
	layer.free()
	hud.free()

func test_research_light_requires_actual_consumption() -> void:
	var sim := _sim()
	sim.upgrades.energy = 300
	var site := sim.construction.place(sim, 3, 100, PackedInt32Array())
	check(site >= 0, "Forschungszentrum")
	if site < 0: return
	sim.construction.sites.contribute(site, 0, 300)
	var center := sim.construction.center(site)
	var has_light := false
	for source in CavernLighting.sources(sim):
		if source.cell == center: has_light = true
	check(not has_light, "inaktives Zentrum erzeugt kein Verbrauchslicht")
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	sim.research.deliver(site)
	sim.tick_once()
	has_light = false
	for source in CavernLighting.sources(sim):
		if source.cell == center: has_light = true
	check(has_light, "tatsächlich verbrauchte Energie beleuchtet Umgebung")
	sim.tick_once()
	has_light = false
	for source in CavernLighting.sources(sim):
		if source.cell == center: has_light = true
	check(not has_light, "Unterversorgung löscht Aktivitätslicht")

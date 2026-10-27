extends TestCase

func _sim() -> Simulation:
	var config := TestHelpers.default_config()
	config.mode = SimConfig.MODE_MATCH
	config.world_size = 64
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
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

func test_research_has_base_light_and_consumption_adds_activity() -> void:
	var sim := _sim()
	sim.upgrades.energy = 300
	var site := sim.construction.place(sim, 3, 100, PackedInt32Array())
	check(site >= 0, "Forschungszentrum")
	if site < 0: return
	sim.construction.sites.contribute(site, 0, 300)
	var center := sim.construction.center(site)
	var base_strength := 0.0
	for source in CavernLighting.sources(sim):
		if source.cell == center: base_strength = source.strength
	check(base_strength > 0, "inaktives eigenes Zentrum hat Grundlicht")
	check(sim.research.start(sim, 0, site, "dig"), "Auftrag")
	sim.research.deliver(site)
	sim.tick_once()
	var active_strength := 0.0
	for source in CavernLighting.sources(sim):
		if source.cell == center: active_strength = source.strength
	check(active_strength > base_strength, "nur tatsächlicher Verbrauch verstärkt das Aktivitätslicht")
	sim.tick_once()
	var waiting_strength := 0.0
	for source in CavernLighting.sources(sim):
		if source.cell == center: waiting_strength = source.strength
	check_eq(waiting_strength, base_strength, "Unterversorgung lässt nur Grundlicht bestehen")

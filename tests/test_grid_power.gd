extends TestCase
func _sim() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 10000
	return sim
func _center(sim: Simulation) -> int:
	var site: int = sim.construction.place(sim, 3, sim.world.index(27, 25), PackedInt32Array())
	sim.construction.sites.contribute(site, 0, 300)
	return site
func _connect(sim: Simulation, source: int, site: int) -> PackedInt32Array:
	var path := sim.energy_network.plan_connection(sim, 0, source, site)
	sim.energy_network.place_path(sim, 0, path)
	return path

func test_components_require_own_source_and_cut_or_foreign_conduits_disconnect() -> void:
	var sim := _sim()
	var site := _center(sim)
	check_eq(sim.energy_network.source_site(sim, site), -1, "kein impliziter Anschluss")
	var path := _connect(sim, 0, site)
	check_eq(sim.energy_network.source_site(sim, site), 0, "eigener Kern speist das Netz")
	for cell in path: check_eq(sim.energy_network.cell_source(sim, cell), 0, "Netzzellen kennen eigene Quelle")
	var cut := path[path.size() / 2]
	sim.energy_network.remove(0, cut)
	check_eq(sim.energy_network.source_site(sim, site), -1, "Unterbrechung sofort erkannt")
	sim.energy_network.place(sim, 1, cut)
	check_eq(sim.energy_network.source_site(sim, site), -1, "fremde Leitung überbrückt nicht")
	sim.energy_network.remove(1, cut)
	sim.energy_network.place(sim, 0, cut)
	check_eq(sim.energy_network.source_site(sim, site), 0, "Wiederanschluss ohne Energietransport")

func test_topology_is_cached_across_repeated_queries_damage_and_unrelated_mining() -> void:
	var sim := _sim()
	var site := _center(sim)
	var path := _connect(sim, 0, site)
	sim.energy_network.source_site(sim, site)
	var builds := sim.energy_network.power_rebuilds
	for index in 100: sim.energy_network.source_site(sim, site)
	check_eq(sim.energy_network.power_rebuilds, builds, "keine Wegberechnung je Verbraucherabfrage")
	sim.construction.damage(sim, site, 1)
	sim.energy_network.source_site(sim, site)
	check_eq(sim.energy_network.power_rebuilds, builds, "HP-Änderung baut Netz nicht neu")
	sim.world.set_material(sim.world.index(2, 2), Materials.ROCK)
	sim.energy_network.source_site(sim, site)
	check_eq(sim.energy_network.power_rebuilds, builds, "fremde Terrainänderung baut Netz nicht neu")
	sim.world.set_material(path[path.size() / 2], Materials.ROCK)
	check_eq(sim.energy_network.source_site(sim, site), -1, "tatsächlich blockierte Leitung schaltet ab")
	check_eq(sim.energy_network.power_rebuilds, builds + 1, "nur relevante Topologieänderung neu berechnet")

func test_outpost_is_a_real_alternative_source_and_its_loss_disconnects() -> void:
	var sim := _sim()
	var site := _center(sim)
	sim.construction.outposts_unlocked = true
	var outpost: int = sim.construction.place(sim, 1, sim.world.index(20, 32), PackedInt32Array())
	sim.construction.sites.contribute(outpost, 0, 300)
	_connect(sim, outpost, site)
	check_eq(sim.energy_network.source_site(sim, site), outpost, "über Außenposten versorgt")
	sim.construction.damage(sim, outpost, 200)
	check_eq(sim.energy_network.source_site(sim, site), -1, "zerstörte Quelle speist nicht weiter")
	check_eq(sim.energy_network.source_site(sim, 0), 0, "Hauptkern bleibt eigenständige Quelle")

func test_paid_research_keeps_connected_network_live_at_zero_wallet_until_finished() -> void:
	var sim := _sim()
	var site := _center(sim)
	var path := _connect(sim, 0, site)
	check(sim.research.start(sim, 0, site, "dig"), "bezahlt gestartet")
	sim.upgrades.energy = 0
	check_eq(sim.energy_network.energized_factions(sim)[0], 1, "bezahlte Aktivität hält Netzlicht bei Nullguthaben")
	var cut := path[path.size() / 2]
	sim.energy_network.remove(0, cut)
	check_eq(sim.energy_network.energized_factions(sim)[0], 0, "unterbrochene Aktivität erzeugt keinen Stromfluss")
	sim.energy_network.place(sim, 0, cut)
	for tick in 180: sim.research.step(sim)
	check_eq(sim.energy_network.energized_factions(sim)[0], 0, "nach bezahltem Abschluss ohne weiteres Guthaben dunkel")

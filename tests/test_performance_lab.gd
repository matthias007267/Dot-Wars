extends TestCase
## Testlabor bleibt unabhängig von regulären Käufen und erhält die Massenbilanz.


func test_debug_upgrades_are_free_reversible_and_disabled_by_default() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := Simulation.create(config)
	var energy := sim.upgrades.energy
	check(not sim.debug_adjust_upgrade(Upgrades.KIND_SPEED, 1), "außerhalb Testlabor gesperrt")
	sim.debug_mode = true
	check(sim.debug_adjust_upgrade(Upgrades.KIND_SPEED, 1), "Arbeiter hoch")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_SWARM, 1), "Intelligenz hoch")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_DIG, 1), "Abbau hoch")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_FUSION2, 1), "Fusion 2")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_FUSION2, 1), "Fusion 3")
	check_eq(sim.upgrades.max_size(), 3, "Fusion hoch")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_FUSION2, -1), "Fusion runter")
	check_eq(sim.upgrades.max_size(), 2, "Fusion 2")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_SPEED, -1), "Arbeiter runter")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_SWARM, -1), "Intelligenz runter")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_DIG, -1), "Abbau runter")
	check_eq(sim.upgrades.speed_level, 0, "zurück auf 0")
	check_eq(sim.upgrades.swarm_level, 0, "zurück auf 0")
	check_eq(sim.upgrades.dig_level, 0, "zurück auf 0")
	check_eq(sim.upgrades.energy, energy, "kein Energieverbrauch")
	check_eq(sim.upgrades.purchased, 0, "kein bezahlter Kauf")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_debug_core_can_grow_and_shrink_without_costs() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := Simulation.create(config)
	sim.debug_mode = true
	check(sim.debug_adjust_upgrade(Upgrades.KIND_CORE, 1), "Kern hoch")
	check_eq(sim.upgrades.core_level, 1, "Stufe 1")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_CORE, -1), "Kern runter")
	check_eq(sim.upgrades.core_level, 0, "Stufe 0")
	check_eq(sim.core_mask.count(1), 0, "keine reservierten Zellen")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_debug_bulk_spawn_preserves_mass() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 64
	var sim := Simulation.create(config)
	sim.world.carve_rect(Rect2i(10, 10, 44, 44))
	check_eq(sim.debug_spawn_workers(100), 0, "nur Testlabor")
	sim.debug_mode = true
	var before := sim.workers.count
	var spawned := sim.debug_spawn_workers(100)
	check_eq(spawned, 100, "100 Dots in einem Suchlauf")
	check_eq(sim.workers.count, before + 100, "Dots angelegt")
	check_eq(sim.purchased_workers, 100, "Massenbilanz erhöht")
	check_no_errors(sim.check_invariants(), "Bilanz")
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Testzustand technisch ladbar")
	if restored != null:
		check(not restored.debug_mode, "Testlabor nicht dauerhaft aktiv")
		check_eq(restored.state_hash(), sim.state_hash(), "Testwerte deterministisch")


func test_swarm_searches_are_bounded_for_large_populations() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.move_period_ticks = 1
	var world := WorldState.new(64, 64, 8, Materials.SOFT)
	world.carve_rect(Rect2i(3, 3, 58, 58))
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	for i in 120:
		sim.workers.add(world.index(5 + i % 30, 5 + int(i / 30)), 0)
	sim.initial_mass = 120
	sim.peak_mass = 120
	sim.upgrades.swarm_level = Upgrades.SWARM_MAX
	sim.assign_area(0, Rect2i(0, 0, 64, 64))
	sim.tick_once()
	check(SwarmMind.seeks_last_tick <= SwarmMind.MAX_SEEKS_PER_TICK, "Suchläufe je Takt gedeckelt")
	check(SwarmMind.paths_last_tick <= SwarmMind.MAX_PATHS_PER_TICK, "Pfadläufe je Takt gedeckelt")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_tunnel_width_follows_active_order_party() -> void:
	check_eq(DigGuidance.tunnel_radius(1), 0, "ein Dot: schmal")
	check_eq(DigGuidance.tunnel_radius(8), 1, "acht Dots: drei Zellen")
	check_eq(DigGuidance.tunnel_radius(24), 2, "24 Dots: fünf Zellen")
	check_eq(DigGuidance.tunnel_radius(50), 3, "50 Dots: sieben Zellen")
	check_eq(DigGuidance.tunnel_radius(120), 4, "120 Dots: neun Zellen")
	var narrow := _route_marked(1)
	var wide := _route_marked(24)
	check(wide > narrow, "viele Dots erhalten eine breitere Arbeitsfront (%d > %d)" % [wide, narrow])


func _route_marked(worker_count: int) -> int:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var world := WorldState.new(32, 32, 8, Materials.SOFT)
	world.carve_rect(Rect2i(3, 3, 8, 8))
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	for i in worker_count:
		sim.workers.add(world.index(4 + i % 6, 4 + int(i / 6)), 0)
	var route := DigGuidance.mark_route(sim, 0, world.index(26, 7))
	check_eq(route, DigGuidance.ROUTE_MINING, "Felsweg markiert")
	var marked := 0
	for cell in sim.areas.masks[0]:
		if cell == 1:
			marked += 1
	return marked

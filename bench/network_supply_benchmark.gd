extends SceneTree
## Same real research centers/conduits before and after the supply redesign.
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var config := SimConfig.new()
	config.world_size = 256
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_ALL
	var sim := Simulation.from_world(config, WorldState.new(256, 256, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	var technologies := ["dig", "swarm", "speed", "energy_speed", "outpost", "interceptor", "efficiency", "defense", "victory"]
	for owner in 4:
		sim.rules.wallet(sim, owner).energy = 1000000
		sim.research.levels[owner] = {"dig": 1, "speed": 1, "energy_speed": 1}
		var source := owner
		var core := sim.construction.center(source)
		for index in technologies.size():
			var x := core % 256 + 8 + index % 3 * 5
			var y := core / 256 - 8 + index / 3 * 5
			var site: int = sim.construction.place(sim, 3, sim.world.index(x, y), PackedInt32Array(), owner)
			if site < 0:
				printerr("Research fixture placement failed")
				quit(1)
				return
			sim.construction.sites.contribute(site, owner, 300)
			var path := sim.energy_network.plan_connection(sim, owner, source, site)
			sim.energy_network.place_path(sim, owner, path)
			if not sim.research.start(sim, owner, site, technologies[index]):
				printerr("Research fixture start failed: ", technologies[index])
				quit(1)
				return
	var measured := 0
	var maximum := 0
	for tick in 80:
		sim.tick_count = tick
		var start := Time.get_ticks_usec()
		sim.research.step(sim)
		var duration := Time.get_ticks_usec() - start
		measured += duration
		maximum = maxi(maximum, duration)
	var state := sim.research.snapshot()
	print("NETWORK BENCH centers=36 jobs=", sim.research.jobs.size(), " conduit_cells=", sim.energy_network.cells.size(), " avg_ms=", measured / 80000.0, " peak_ms=", maximum / 1000.0, " paid_shipments=", state.get("shipments", []).size())
	quit(0 if sim.research.jobs.size() == 36 else 1)

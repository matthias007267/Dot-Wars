extends SceneTree
## Reproduzierbares 4-Fraktionen-Szenario; --graphic aktiviert HUD/Rendering.
const Live = preload("res://bench/live_benchmark.gd")
const Backend = preload("res://src/sim/native_search.gd")


func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	var config := SimConfig.new()
	config.world_size = 256
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	config.initial_workers = 1
	config.move_period_ticks = 1
	var population := 10000
	var level := 4
	var ticks := 100
	var out_path := ""
	var graphic := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--workers="): population = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--swarm="): level = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--ticks="): ticks = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--out="): out_path = arg.substr(6)
		elif arg == "--graphic": graphic = true
	if population < 4 or population > 40000 or level < 0 or level > 4 or ticks < 1:
		quit(2)
		return
	var world := WorldState.new(256, 256, 32, Materials.EMPTY)
	var sim := Simulation.from_world(config, world)
	# Durchmischte Fraktionen; alle vier Kerne stehen unter realem Angriff.
	for cell in world.cell_count():
		if sim.workers.count >= population: break
		if world.cells[cell] == Materials.EMPTY and sim.workers.is_free(cell):
			var faction := sim.workers.count % 4
			sim.workers.add(cell, sim.rules.group_of[faction], faction)
	sim.initial_mass = sim.workers.mass_sum()
	sim.peak_mass = sim.initial_mass
	sim.debug_mode = true
	sim.debug_modified = true
	sim.rules.core_hp.fill(1000000)
	for faction in range(4):
		sim.rules.control[faction] = MatchRules.CONTROL_REMOTE
		sim.rules.wallet(sim, faction).swarm_level = level
		var group := sim.rules.group_of[faction]
		sim.set_move_goal(group, sim.rules.hill_cell + faction)
		var enemy := (faction + 1) % 4
		for gate in SacrificeSystem.delivery_cells(world, sim.rules.cores[enemy]):
			if sim.workers.is_free(gate):
				for id in sim.workers.count:
					if int(sim.workers.faction[id]) == faction:
						sim.workers.move_to(id, gate, 0)
						break
				break
	if graphic:
		if DisplayServer.get_name() == "headless":
			quit(2)
			return
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var app := Live.BenchApp.new()
		root.add_child(app)
		app._attach(sim)
		app.set_process_unhandled_input(false)
		app.camera.set_process(false)
		app.camera.set_process_input(false)
		app.camera.set_process_unhandled_input(false)
		app.clock.reset()
		var sampler := Live.Sampler.new()
		sampler.app = app
		sampler.sim = sim
		sampler.seconds = 10.0
		sampler.warmup_seconds = 3.0
		sampler.initial_workers = population
		sampler.out_path = out_path
		root.add_child(sampler)
		return
	var times := PackedFloat64Array()
	var started := Time.get_ticks_usec()
	for tick in ticks:
		sim.tick_once()
		times.append(sim.last_tick_usec / 1000.0)
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	times.sort()
	var errors := sim.check_invariants()
	var result := {"scenario": "four_faction_march_and_core_combat", "workers": sim.workers.count, "swarm": level, "native": Backend.backend() != null, "ticks": ticks, "seconds": elapsed, "avg_tick_ms": elapsed * 1000.0 / ticks, "p95_tick_ms": times[int(ceil(times.size() * 0.95)) - 1], "max_tick_ms": times[-1], "core_hp": Array(sim.rules.core_hp), "hash": sim.state_hash(), "invariants": Array(errors)}
	print("POPULATION_BENCHMARK ", JSON.stringify(result))
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			quit(2)
			return
		file.store_string(JSON.stringify(result, "  "))
	quit(0 if errors.is_empty() else 1)

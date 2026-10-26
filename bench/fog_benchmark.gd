extends SceneTree
## Headless benchmark: godot --headless --path . -s bench/fog_benchmark.gd
const Fog = preload("res://src/sim/fog_of_war.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for size in [128, 512, 1024]:
		var config := SimConfig.new()
		config.world_size = size
		config.mode = SimConfig.MODE_MATCH
		config.ai_count = 1
		config.initial_workers = 1
		var sim := Simulation.from_world(config, WorldState.new(size, size, 8, Materials.EMPTY))
		if sim == null:
			push_error("Simulation initialization failed: %d" % size)
			quit(1)
			return
		var fog := Fog.new()
		fog.setup(sim.world, sim.rules.faction_count)
		var start := Time.get_ticks_usec()
		fog.update(sim)
		var cold_ms := float(Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		for i in 10: fog.update(sim)
		var warm_ms := float(Time.get_ticks_usec() - start) / 10000.0
		print("fog_benchmark size=%d cells=%d workers=%d cold_ms=%.3f warm_ms=%.3f cache_entries=%d" % [size, sim.world.cell_count(), sim.workers.count, cold_ms, warm_ms, fog._sight_cache.size()])
	quit()

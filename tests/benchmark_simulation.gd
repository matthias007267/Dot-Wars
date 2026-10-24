extends SceneTree
## Headless: godot --headless --path . -s tests/benchmark_simulation.gd -- --workers=1000 --ticks=40 --swarm=4
## Keine harte Zeitschranke: Ausgabe dient zum Vergleich auf derselben Hardware.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var count := 1000
	var ticks := 40
	var swarm := 4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--workers="):
			count = clampi(arg.get_slice("=", 1).to_int(), 1, 4000)
		elif arg.begins_with("--ticks="):
			ticks = clampi(arg.get_slice("=", 1).to_int(), 1, 1000)
		elif arg.begins_with("--swarm="):
			swarm = clampi(arg.get_slice("=", 1).to_int(), 0, Upgrades.SWARM_MAX)
	var config := SimConfig.new()
	config.world_size = 128
	config.initial_workers = count
	config.move_period_ticks = 1
	var world := WorldGenerator.generate(config)
	world.carve_rect(Rect2i(12, 12, 104, 104))
	var sim := Simulation.from_world(config, world)
	if sim == null:
		push_error("Benchmark konnte nicht gestartet werden")
		quit(1)
		return
	sim.upgrades.swarm_level = swarm
	sim.assign_area(0, Rect2i(8, 8, 110, 110))
	sim.assign_area(1, Rect2i(8, 8, 110, 110))
	var started := Time.get_ticks_usec()
	var worst := 0
	for _tick in ticks:
		sim.tick_once()
		worst = maxi(worst, sim.last_tick_usec)
	var elapsed := Time.get_ticks_usec() - started
	print("BENCH dots=%d swarm=%d ticks=%d total_ms=%.2f avg_ms=%.3f worst_ms=%.3f target_ms=%.3f move_ms=%.3f mining_ms=%.3f spawn_ms=%.3f" % [
		sim.workers.count, swarm, ticks, elapsed / 1000.0, elapsed / 1000.0 / ticks, worst / 1000.0,
		sim.stage_usec[Simulation.Stage.TARGET_SEARCH] / 1000.0 / ticks,
		sim.stage_usec[Simulation.Stage.MOVEMENT] / 1000.0 / ticks,
		sim.stage_usec[Simulation.Stage.MINING] / 1000.0 / ticks,
		sim.stage_usec[Simulation.Stage.SPAWN] / 1000.0 / ticks,
	])
	quit(0)

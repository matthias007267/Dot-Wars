extends SceneTree
## Kontrollierter Grafiklauf mit realem HUD und Rendering, ohne Speicherzugriffe.
## godot --path . -s bench/live_benchmark.gd -- --workers=1000 --seconds=10 --warmup-seconds=5 --out=bench/results/live.json

class BenchApp:
	extends "res://src/main.gd"
	var last_app_process_usec: int = 0
	var frame_probe: Node

	func _process(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._process(delta)
		last_app_process_usec = Time.get_ticks_usec() - started

class Sampler:
	extends Node
	var app: Node
	var sim: Simulation
	var seconds: float
	var warmup_seconds: float
	var out_path: String
	var started: int
	var measured_from: int = 0
	var tick_start: int
	var stage_start: PackedInt64Array
	var frames: int = 0
	var frame_ms := PackedFloat64Array()
	var samples: Array[Dictionary] = []
	var sample_from: int
	var sample_tick: int
	var sample_frames: int = 0
	var initial_workers: int
	var initial_warriors: int
	var last_frame_usec: int
	var engine_delta_seconds: float = 0.0
	var caps_start: int
	var discarded_start: int
	var max_app_process_ms: float = 0.0
	var slow_frames := 0
	var max_title_update_ms := 0.0
	var stall_frames: Array[Dictionary] = []

	func _ready() -> void:
		process_priority = 100
		started = Time.get_ticks_usec()
		initial_warriors = sim.army.count

	func _process(delta: float) -> void:
		var now := Time.get_ticks_usec()
		if measured_from == 0:
			if (now - started) / 1000000.0 < warmup_seconds:
				return
			measured_from = now
			last_frame_usec = now
			caps_start = app.clock.catch_up_limit_hits
			discarded_start = app.clock.discarded_usec
			tick_start = sim.tick_count
			stage_start = sim.stage_usec.duplicate()
			sample_from = now
			sample_tick = sim.tick_count
			return
		frames += 1
		sample_frames += 1
		var wall_frame_ms := (now - last_frame_usec) / 1000.0
		var app_ms: float = app.last_app_process_usec / 1000.0
		frame_ms.append(wall_frame_ms)
		max_app_process_ms = maxf(max_app_process_ms, app_ms)
		if wall_frame_ms > 50.0: slow_frames += 1
		if wall_frame_ms > 50.0 and stall_frames.size() < 50:
			stall_frames.append({"wall_frame_ms": wall_frame_ms, "app_process_ms": app_ms, "last_tick_ms": sim.last_tick_usec / 1000.0})
		last_frame_usec = now
		engine_delta_seconds += delta
		var sample_seconds := (now - sample_from) / 1000000.0
		if sample_seconds >= 1.0:
			var fps := sample_frames / sample_seconds
			var tps := (sim.tick_count - sample_tick) / sample_seconds
			samples.append({
				"elapsed_s": (now - measured_from) / 1000000.0,
				"fps": fps, "actual_ticks_per_s": tps,
				"workers": sim.workers.count, "warriors": sim.army.count, "energy_dots": sim.energy_dots.cells.size(),
				"last_tick_ms": sim.last_tick_usec / 1000.0,
				"seek_requests_last_tick": SwarmMind.seeks_last_tick,
				"path_requests_last_tick": SwarmMind.paths_last_tick,
			})
			var title_start := Time.get_ticks_usec()
			DisplayServer.window_set_title("DOT WARS Benchmark | %.1f FPS | %.1f Takte/s | %d Arbeiter" % [fps, tps, sim.workers.count])
			max_title_update_ms = maxf(max_title_update_ms, (Time.get_ticks_usec() - title_start) / 1000.0)
			sample_from = now
			sample_tick = sim.tick_count
			sample_frames = 0
		var elapsed := (now - measured_from) / 1000000.0
		if elapsed >= seconds:
			_finish(elapsed)

	func _finish(elapsed: float) -> void:
		set_process(false)
		var ticks := sim.tick_count - tick_start
		var stages := {}
		for name in Simulation.Stage.keys():
			var idx: int = Simulation.Stage[name]
			stages[name.to_lower()] = (sim.stage_usec[idx] - stage_start[idx]) / 1000.0 / maxi(1, ticks)
		var states := {"waiting": 0, "moving": 0, "mining": 0, "blocked": 0, "building": 0}
		var state_names := ["waiting", "moving", "mining", "blocked", "building"]
		for id in sim.workers.count:
			states[state_names[sim.workers.state[id]]] += 1
		frame_ms.sort()
		var errors := sim.check_invariants()
		var result := {
			"frame_phases": app.frame_probe.summary() if app.frame_probe != null else {}, "godot": Engine.get_version_info()["string"],
			"cpu": OS.get_processor_name(), "os": OS.get_name(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"fps_cap": Engine.max_fps, "native_army_steps": sim.army.native_steps, "configured_renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
			"viewport": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
			"world_size": sim.world.width, "seed": sim.config.world_seed,
			"move_period": sim.config.move_period_ticks,
			"swarm_level": sim.upgrades.swarm_level,
			"warriors_initial": initial_warriors, "warriors_end": sim.army.count, "warrior_losses": sim.army.lost, "workers_requested": initial_workers, "workers_end": sim.workers.count,
			"pending_spawns_end": sim.spawner.pending(),
			"energy_dots_end": sim.energy_dots.cells.size(), "mass_end": sim.total_mass(),
			"warmup_seconds": warmup_seconds, "measured_seconds": elapsed,
			"engine_delta_seconds": engine_delta_seconds,
			"catch_up_limit_hits": app.clock.catch_up_limit_hits - caps_start,
			"discarded_clock_seconds": (app.clock.discarded_usec - discarded_start) / 1000000.0,
			"ticks": ticks, "actual_ticks_per_s": ticks / elapsed,
			"fps": frames / elapsed, "frames": frames,
			"p95_frame_ms": frame_ms[mini(frame_ms.size() - 1, int(ceil(frame_ms.size() * 0.95)) - 1)],
			"max_frame_ms": frame_ms[-1],
			"p99_frame_ms": frame_ms[mini(frame_ms.size() - 1, ceili(frame_ms.size() * 0.99) - 1)],
			"frames_over_50ms": slow_frames, "native_fog_updates": sim.fog.native_updates,
			"max_title_update_ms": max_title_update_ms, "max_app_process_ms": max_app_process_ms, "stall_frames_over_50ms": stall_frames,
			"stage_avg_ms": stages, "worker_states_end": states,
			"state_hash_end": sim.state_hash(),
			"invariants_ok": errors.is_empty(), "invariant_errors": Array(errors),
			"samples": samples,
		}
		if not out_path.is_empty():
			var dir := out_path.get_base_dir()
			if not dir.is_empty():
				var dir_error := DirAccess.make_dir_recursive_absolute(dir)
				if dir_error != OK:
					printerr("Ergebnisordner nicht schreibbar: ", dir)
					get_tree().quit(2)
					return
			var file := FileAccess.open(out_path, FileAccess.WRITE)
			if file == null:
				printerr("Ergebnisdatei nicht schreibbar: ", out_path)
				get_tree().quit(2)
				return
			file.store_string(JSON.stringify(result, "  "))
		print("LIVE_BENCHMARK ", JSON.stringify(result))
		get_tree().quit(0 if errors.is_empty() else 1)


func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Grafikbenchmark braucht ein sichtbares Fenster.")
		quit(2)
		return
	var config := SimConfig.from_cmdline(OS.get_cmdline_user_args())
	config.population_test_mode = true
	var seconds := 10.0
	var warmup := 5.0
	var out_path := ""
	var swarm := 0
	config.initial_workers = 1000
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--workers="):
			config.initial_workers = value.to_int()
		elif arg.begins_with("--seconds="):
			seconds = value.to_float()
		elif arg.begins_with("--warmup-seconds="):
			warmup = value.to_float()
		elif arg.begins_with("--move-period="):
			config.move_period_ticks = value.to_int()
		elif arg.begins_with("--swarm="):
			swarm = clampi(value.to_int(), 0, Upgrades.SWARM_MAX)
		elif arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())
	var errors := config.validate()
	if seconds <= 0.0 or warmup < 0.0 or config.mode != SimConfig.MODE_CLEARING:
		errors.append("positive Messdauer, nichtnegativer Warmup und Räumungsmodus erforderlich")
	var side := mini(ceili(sqrt(config.initial_workers * 2.0)), config.world_size - 8)
	if side * side < config.initial_workers:
		errors.append("Welt zu klein für die gewünschte Population")
	if not errors.is_empty():
		printerr(", ".join(errors))
		quit(2)
		return
	var world := WorldGenerator.generate(config)
	var origin := (config.world_size - side) / 2
	world.carve_rect(Rect2i(origin, origin, side, side))
	var sim := Simulation.from_world(config, world)
	if sim == null:
		quit(2)
		return
	sim.debug_mode = true
	sim.upgrades.swarm_level = swarm
	sim.assign_area(0, Rect2i(0, 0, config.world_size / 2, config.world_size))
	sim.assign_area(1, Rect2i(config.world_size / 2, 0, config.world_size - config.world_size / 2, config.world_size))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app := BenchApp.new()
	root.add_child(app)
	app._attach(sim)
	# Keine Eingabe: Aufträge, Tempo und Kameraposition bleiben während des Laufs fest.
	app.set_process_unhandled_input(false)
	app.camera.set_process_input(false)
	app.camera.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.hud.process_mode = Node.PROCESS_MODE_DISABLED
	app.clock.reset()
	var sampler := Sampler.new()
	sampler.app = app
	sampler.sim = sim
	sampler.seconds = seconds
	sampler.warmup_seconds = warmup
	sampler.out_path = out_path
	sampler.initial_workers = config.initial_workers
	root.add_child(sampler)

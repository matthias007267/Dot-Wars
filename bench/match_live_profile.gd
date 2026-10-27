extends SceneTree
## Grafiklauf einer reinen KI-Partie mit Teilzeiten der Bild-Aktualisierung.
##
##   godot --path . -s bench/match_live_profile.gd -- [--ai=3] [--skip-minutes=10] [--seconds=30] [--seed=1337] [--out=pfad.json]
##
## Die Partie wird zuerst headless vorgespult, dann mit HUD/Minimap/Fog gezeichnet.
## Keine Speicherzugriffe; alle Fraktionen spielt die KI. Kein Spielregelpfad.

class ProfiledApp:
	extends "res://src/main.gd"
	var parts := {}
	var tick_frames := 0

	func _process(delta: float) -> void:
		if sim == null: return
		var t := Time.get_ticks_usec()
		var ticks := clock.advance_wall_time(t)
		if ticks > 0:
			tick_frames += 1
			sim.run_ticks(ticks)
			t = _part("sim", t)
			if fog_view != null: fog_view.show_tick(sim.tick_count)
			t = _part("fog_view", t)
			workers_view.show_tick(sim.tick_count)
			t = _part("workers_view", t)
			army_view.show_tick(sim.tick_count)
			t = _part("army_view", t)
			energy_view.show_energy()
			t = _part("energy_view", t)
			if hud != null: hud.refresh()
			t = _part("hud", t)
			renderer.sync_match(sim)
			t = _part("world_sync", t)

	func _part(label: String, since: int) -> int:
		var now := Time.get_ticks_usec()
		parts[label] = int(parts.get(label, 0)) + now - since
		return now


class Sampler:
	extends Node
	var app: ProfiledApp
	var seconds := 30.0
	var warmup := 3.0
	var out_path := ""
	var started := 0
	var last := 0
	var frame_ms := PackedFloat64Array()
	var base_parts := {}
	var base_tick_frames := 0
	var base_ticks := 0

	func _ready() -> void:
		started = Time.get_ticks_usec()
		last = started

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var elapsed := (now - started) / 1000000.0
		if elapsed < warmup:
			last = now
			base_parts = app.parts.duplicate()
			base_tick_frames = app.tick_frames
			base_ticks = app.sim.tick_count
			return
		frame_ms.append((now - last) / 1000.0)
		last = now
		if elapsed < warmup + seconds: return
		var sorted := frame_ms.duplicate()
		sorted.sort()
		var total := 0.0
		var over := 0
		for v in sorted:
			total += v
			if v > 33.4: over += 1
		var tick_frames := maxi(1, app.tick_frames - base_tick_frames)
		var per_tick_frame := {}
		for key in app.parts:
			per_tick_frame[key] = snappedf((int(app.parts[key]) - int(base_parts.get(key, 0))) / 1000.0 / tick_frames, 0.001)
		var result := {
			"fps": snappedf(sorted.size() / seconds, 0.01),
			"mean_frame_ms": snappedf(total / sorted.size(), 0.001),
			"p95_frame_ms": sorted[int(sorted.size() * 0.95) - 1],
			"p99_frame_ms": sorted[int(sorted.size() * 0.99) - 1],
			"max_frame_ms": sorted[-1],
			"frames_over_33ms": over,
			"ticks_per_s": snappedf((app.sim.tick_count - base_ticks) / seconds, 0.01),
			"tick_frames": tick_frames,
			"ms_per_tick_frame": per_tick_frame,
			"warriors": app.sim.army.count, "workers": app.sim.workers.count,
			"energy_dots": app.sim.energy_dots.cells.size(),
			"invariant_errors": Array(app.sim.check_invariants()),
		}
		print("MATCH_LIVE ", JSON.stringify(result))
		if out_path != "":
			var file := FileAccess.open(out_path, FileAccess.WRITE)
			if file: file.store_string(JSON.stringify(result, "  "))
		get_tree().quit(0)


func _init() -> void:
	_start.call_deferred()


func _start() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Grafiklauf braucht ein sichtbares Fenster.")
		quit(2)
		return
	var config := SimConfig.new()
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	config.world_size = 256
	config.world_seed = 1337
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	config.group_quotas = PackedInt32Array([40, 30, 30])
	var skip := 10
	var sampler := Sampler.new()
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--ai="): config.ai_count = value.to_int()
		elif arg.begins_with("--seed="): config.world_seed = value.to_int()
		elif arg.begins_with("--skip-minutes="): skip = value.to_int()
		elif arg.begins_with("--seconds="): sampler.seconds = value.to_float()
		elif arg.begins_with("--out="): sampler.out_path = arg.substr(6)
	var sim := Simulation.create(config)
	if sim == null:
		quit(2)
		return
	sim.debug_mode = true
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_AI)
	sim.run_ticks(skip * 60 * SimConfig.TICKS_PER_SECOND)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app := ProfiledApp.new()
	root.add_child(app)
	app._attach(sim)
	app.set_process_unhandled_input(false)
	app.camera.set_process_input(false)
	app.camera.set_process_unhandled_input(false)
	app.clock.reset()
	sampler.app = app
	root.add_child(sampler)

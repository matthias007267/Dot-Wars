extends "res://bench/live_benchmark.gd"
## Real HUD/renderer, deterministic fixture. No regular save writes.
func _start() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var population := 2000
	var fps_cap := 0
	var output := ""
	var seconds := 20.0
	var render_off := false
	var hide_hud := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps-cap="): fps_cap = clampi(arg.get_slice("=", 1).to_int(), 0, 240)
		if arg.begins_with("--warriors="): population = clampi(arg.get_slice("=", 1).to_int(), 1, 10000)
		if arg == "--render-off": render_off = true
		if arg == "--hide-hud": hide_hud = true
		if arg.begins_with("--seconds="): seconds = maxf(1.0, arg.get_slice("=", 1).to_float())
		if arg.begins_with("--out="): output = arg.substr(6)
	var config := SimConfig.new()
	config.world_size = 256
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 5
	config.victory_mask = 0
	var sim := Simulation.from_world(config, WorldState.new(256, 256, 1337, Materials.EMPTY))
	sim.debug_mode = true
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	var placed := 0
	for y in range(30, 230):
		for x in range(30, 230):
			if placed >= population: break
			var cell := sim.world.index(x, y)
			if sim.world.cells[cell] != Materials.EMPTY or sim.workers.occupant[cell] >= 0: continue
			var owner := int(placed >= population / 2)
			var uid: int = sim.army.add(cell, owner)
			if uid < 0: continue
			sim.army.goals[sim.army.slots[uid]] = sim.world.index(220, 220) if owner == 0 else sim.world.index(30, 220)
			placed += 1
	Engine.max_fps = fps_cap
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app := BenchApp.new()
	root.add_child(app)
	app._attach(sim)
	app.camera.position = Vector2(128, 128)
	app.camera.zoom = Vector2(3.5, 3.5)
	app._screenshot = output.get_basename() + ".png"
	app._screenshot_in = -1
	app._frames_left = 2147483647
	app.set_process_unhandled_input(false)
	app.camera.set_process_input(false)
	app.camera.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.hud.process_mode = Node.PROCESS_MODE_DISABLED
	app.clock.reset()
	if "--profile-frames" in OS.get_cmdline_user_args():
		app.frame_probe = load("res://bench/frame_probe.gd").new()
		app.frame_probe.app = app
		app.add_child(app.frame_probe)
	if hide_hud: app.hud.hide()
	if render_off: RenderingServer.set_render_loop_enabled(false)
	var sampler := Sampler.new()
	sampler.app = app
	sampler.sim = sim
	sampler.seconds = seconds
	sampler.warmup_seconds = 3.0
	sampler.out_path = output
	sampler.initial_workers = sim.workers.count
	root.add_child(sampler)

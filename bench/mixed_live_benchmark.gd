extends "res://bench/live_benchmark.gd"
const Scenarios = preload("res://bench/stability_scenarios.gd")
class Orders:
	extends Node
	var sim: Simulation
	var next_tick := 0
	var kind := "mixed_reserve"
	func _process(_delta: float) -> void:
		if sim.tick_count >= next_tick:
			Scenarios.commands(sim, kind, sim.tick_count)
			next_tick = sim.tick_count + 100

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var output := ""
	var kind := "mixed_reserve"
	var duration := 60.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): kind = arg.get_slice("=", 1)
		if arg.begins_with("--out="): output = arg.substr(6)
		if arg.begins_with("--seconds="): duration = maxf(5.0, arg.get_slice("=", 1).to_float())
	var sim: Simulation = Scenarios.create(kind)
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var app := BenchApp.new()
	root.add_child(app)
	app._attach(sim)
	app.camera.position = Vector2(128, 128)
	app.camera.zoom = Vector2(3.5, 3.5)
	app.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.camera.set_process_unhandled_input(false)
	app.hud.process_mode = Node.PROCESS_MODE_DISABLED
	app.frame_probe = load("res://bench/frame_probe.gd").new()
	app.frame_probe.app = app
	app.add_child(app.frame_probe)
	var orders := Orders.new()
	orders.sim = sim
	orders.kind = kind
	orders.process_priority = -50
	app.add_child(orders)
	var sampler := Sampler.new()
	sampler.app = app
	sampler.sim = sim
	sampler.seconds = duration
	sampler.warmup_seconds = 5.0
	sampler.out_path = output
	sampler.initial_workers = sim.workers.count
	root.add_child(sampler)

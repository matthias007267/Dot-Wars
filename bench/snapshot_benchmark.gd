extends SceneTree
## Echte Diagnosepartie mit dem normalen Spielrenderer messen, ohne reguläre Saves.
## godot --path . -s bench/snapshot_benchmark.gd -- eingabe.dw ausgabe.json

func _init() -> void:
	_start.call_deferred()

func _start() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		printerr("Erwartet: sichtbares Fenster und -- eingabe.dw ausgabe.json")
		quit(2)
		return
	var sim := SaveGame.read_file(args[0])
	if sim == null:
		quit(2)
		return
	sim.debug_mode = true
	sim.debug_modified = true
	var benchmark := load("res://bench/live_benchmark.gd")
	var app: Node = benchmark.BenchApp.new()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.add_child(app)
	app._attach(sim)
	app.clock.speed = 1
	app.set_process_unhandled_input(false)
	app.camera.set_process_input(false)
	app.camera.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.hud.process_mode = Node.PROCESS_MODE_DISABLED
	var sampler: Node = benchmark.Sampler.new()
	sampler.app = app
	sampler.sim = sim
	sampler.seconds = 15.0
	sampler.warmup_seconds = 3.0
	sampler.out_path = args[1]
	sampler.initial_workers = sim.workers.count
	root.add_child(sampler)

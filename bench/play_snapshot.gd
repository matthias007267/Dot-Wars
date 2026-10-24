extends SceneTree
## Interaktive Diagnosekopie. Kein regulärer Speicherstand wird geschrieben.
func _init() -> void:
	_start.call_deferred()

func _start() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DisplayServer.get_name() == "headless":
		quit(2)
		return
	var sim := SaveGame.read_file(args[0])
	if sim == null:
		quit(2)
		return
	sim.debug_mode = true
	sim.debug_modified = true
	var app := load("res://src/main.gd").new() as Node
	root.add_child(app)
	app._attach(sim)
	app.clock.speed = 1
	app.clock.paused = true
	app.hud.toggle_pause_menu()
	DisplayServer.window_set_title("DOT WARS – Diagnosekopie %d Arbeiter – aktuelle Version" % sim.workers.count)

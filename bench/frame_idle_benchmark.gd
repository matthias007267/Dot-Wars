extends SceneTree
class App:
	extends Node
	var last_app_process_usec := 0
	var device_guard: Node
	var sim: Simulation
	var clock := TickClock.new()
	var ticks := 0
	func _process(_delta: float) -> void: ticks += clock.advance_wall_time(Time.get_ticks_usec())

var app: App
var probe: Node
var start := 0
var frames := 0
var output := ""
func _init() -> void: _start.call_deferred()
func _start() -> void:
	Engine.max_fps = 60
	if "--exclusive" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(DisplayServer.screen_get_size())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.substr(6)
	if "--render-off" in OS.get_cmdline_user_args(): RenderingServer.set_render_loop_enabled(false)
	app = App.new()
	var config := SimConfig.new()
	config.world_size = 32
	app.sim = Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY), PackedInt32Array(), false)
	root.add_child(app)
	var guard := preload("res://src/window_event_guard.gd").new()
	app.device_guard = guard
	app.add_child(guard)
	probe = load("res://bench/frame_probe.gd").new()
	probe.app = app
	app.add_child(probe)
	start = Time.get_ticks_usec()
func _process(_delta: float) -> bool:
	if start == 0: return false
	frames += 1
	var elapsed := (Time.get_ticks_usec() - start) / 1000000.0
	if elapsed < 12.0: return false
	var result := {"seconds": elapsed, "fps": frames / elapsed, "ticks_per_s": app.ticks / elapsed,
		"headless": DisplayServer.get_name() == "headless", "frame_phases": probe.summary()}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  "))
	print(JSON.stringify(result))
	quit()
	return true

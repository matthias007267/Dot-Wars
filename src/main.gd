extends Node
## Menü, Welt, Arbeiter und Aufträge. Die Simulation bleibt headless testbar.

var sim: Simulation
var world: WorldState
var renderer: WorldRenderer
var workers_view: WorkerRenderer
var camera: CameraController
var hud: GameHud
var orders: OrderOverlay
var clock := TickClock.new()

var _menu: MainMenu
var _frames_left := -1
var _warmup := 30
var _measured := 0
var _measured_time := 0.0
var _screenshot := ""
var _screenshot_in := -1
var _drag_from := Vector2.ZERO
var _dragging := false
var _last_mined := 0
var _tone: AudioStreamPlayer
var _autosave_tick := 0


func _ready() -> void:
	_read_launch_flags()
	if _autostart():
		var config := SimConfig.from_cmdline(OS.get_cmdline_user_args())
		_boot(config)
		return
	_menu = MainMenu.new()
	_menu.start_requested.connect(_boot)
	_menu.load_requested.connect(_boot_from_save)
	add_child(_menu)


func _boot(config: SimConfig) -> void:
	var errors := config.validate()
	if not errors.is_empty():
		push_error("Konfiguration ungültig: " + ", ".join(errors))
		get_tree().quit(1)
		return
	var started := Time.get_ticks_usec()
	var created := Simulation.create(config)
	if created == null or not created.check_invariants().is_empty():
		push_error("Startprüfung fehlgeschlagen")
		get_tree().quit(1)
		return
	var generation_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("DOT WARS bereit: %dx%d Seed %d" % [created.world.width, created.world.height, config.world_seed])
	print("Welt erzeugt in %.0f ms, Arbeiter %d" % [generation_ms, created.workers.count])
	_attach(created)


func _boot_from_save(path: String) -> void:
	var loaded := SaveGame.read_file(path)
	if loaded == null:
		push_error("Speicherstand ungültig")
		if hud != null:
			hud.report("Speicherstand ungültig.")
		return
	print("DOT WARS bereit: %dx%d Seed %d" % [loaded.world.width, loaded.world.height, loaded.config.world_seed])
	print("Spielstand geladen, Arbeiter %d" % loaded.workers.count)
	_attach(loaded)


func _attach(next: Simulation) -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_clear_playfield()
	sim = next
	world = sim.world
	_last_mined = world.mined_count
	_autosave_tick = sim.tick_count
	renderer = WorldRenderer.new()
	renderer.world = world
	workers_view = WorkerRenderer.new()
	workers_view.world = world
	workers_view.workers = sim.workers
	workers_view.colors = sim.group_colors
	camera = CameraController.new()
	camera.world_size = Vector2(world.width, world.height)
	renderer.camera = camera
	if _has_flag("--grid"):
		renderer.show_grid = true
	if _has_flag("--chunks"):
		renderer.show_chunks = true
	add_child(renderer)
	add_child(workers_view)
	orders = OrderOverlay.new()
	orders.sim = sim
	add_child(orders)
	add_child(camera)
	hud = GameHud.new()
	hud.sim = sim
	hud.clock = clock
	hud.camera = camera
	hud.renderer = renderer
	hud.load_requested.connect(_boot_from_save)
	add_child(hud)
	workers_view.show_tick(sim.tick_count)
	_prepare_tone()


func _clear_playfield() -> void:
	for node in [renderer, workers_view, orders, camera, hud, _tone]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	renderer = null
	workers_view = null
	orders = null
	camera = null
	hud = null
	_tone = null


func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position
			_dragging = true
		elif _dragging:
			_dragging = false
			_finish_drag(event.position)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_G and renderer != null:
		renderer.show_grid = not renderer.show_grid
		renderer.queue_redraw()
	elif event.keycode == KEY_C and renderer != null:
		renderer.show_chunks = not renderer.show_chunks
		renderer.queue_redraw()
	elif event.keycode == KEY_SPACE:
		clock.paused = not clock.paused
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()
	elif event.keycode == KEY_F5:
		SaveGame.write_file("user://slot.dw", sim)
	elif event.keycode == KEY_F9:
		_boot_from_save("user://slot.dw")
	if hud != null:
		hud.refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	var ticks := clock.advance(delta)
	if ticks > 0:
		sim.run_ticks(ticks)
		workers_view.show_tick(sim.tick_count)
		if world.mined_count != _last_mined:
			_last_mined = world.mined_count
			_play_tone()
		if sim.tick_count - _autosave_tick >= 600 and not _headless():
			_autosave_tick = sim.tick_count
			SaveGame.write_file("user://autosave.dw", sim)
		if hud != null:
			hud.refresh()
	_capture_screenshot()
	_measure_frames(delta)


func _finish_drag(screen: Vector2) -> void:
	if hud == null:
		return
	var start := _cell_at(_drag_from)
	var end := _cell_at(screen)
	if start.x < 0 or end.x < 0:
		return
	if hud.command_mode == GameHud.Command.MOVE:
		# Ein einzelner Klick setzt einen Sammelpunkt. Ziehen bleibt dem Abbau vorbehalten.
		if _drag_from.distance_to(screen) < 8.0:
			hud.issue_move_goal(world.index(end.x, end.y))
		return
	var rect := Rect2i(start, Vector2i.ZERO).expand(end)
	rect.size += Vector2i.ONE
	hud.issue_dig_area(rect)


func _cell_at(screen: Vector2) -> Vector2i:
	var viewport := get_viewport().get_visible_rect().size
	var world_pos := WorldCoordinates.screen_to_world(screen, camera.position, camera.zoom.x, viewport)
	return WorldCoordinates.world_to_cell(world_pos, world.width, world.height)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _autostart() -> bool:
	if _headless():
		return true
	if not _screenshot.is_empty() or _frames_left >= 0:
		return true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size=") or arg.begins_with("--seed=") or arg == "--play":
			return true
	return false


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _prepare_tone() -> void:
	_tone = AudioStreamPlayer.new()
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = 8000
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(240)
	for i in bytes.size():
		bytes[i] = 180 if i % 8 < 4 else 70
	wav.data = bytes
	_tone.stream = wav
	_tone.volume_db = -18.0
	add_child(_tone)


func _play_tone() -> void:
	if _tone != null and not _headless():
		_tone.play()


func _read_launch_flags() -> void:
	_screenshot = _user_arg("--screenshot=")
	var frames := _user_arg("--frames=")
	if not frames.is_empty():
		_frames_left = frames.to_int()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window := _user_arg("--window=")
	if not window.is_empty():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(window.get_slice("x", 0)), int(window.get_slice("x", 1))))
	if not _screenshot.is_empty():
		_screenshot_in = 8


func _capture_screenshot() -> void:
	if _screenshot_in <= 0:
		return
	_screenshot_in -= 1
	if _screenshot_in > 0:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(_screenshot)
	print("SCREENSHOT %s" % _screenshot)
	if _frames_left < 0:
		get_tree().quit(0)


func _measure_frames(delta: float) -> void:
	if _frames_left < 0:
		return
	_frames_left -= 1
	if _warmup > 0:
		_warmup -= 1
	else:
		_measured += 1
		_measured_time += delta
	if _frames_left > 0:
		return
	var viewport := get_viewport().get_visible_rect().size
	var fps := 0.0 if _measured_time <= 0.0 else float(_measured) / _measured_time
	print("RENDER fps %.1f frames %d viewport %dx%d world %d workers %d" % [
		fps, _measured, int(viewport.x), int(viewport.y), world.width, sim.workers.count,
	])
	get_tree().quit(0)


func _user_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""


func _has_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()

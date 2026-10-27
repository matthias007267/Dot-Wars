extends Node
## Menü, Welt, Arbeiter und Aufträge. Die Simulation bleibt headless testbar.

var device_guard: Node
var sim: Simulation
var world: WorldState
var renderer: WorldRenderer
const FogView = preload("res://src/render/fog_overlay.gd")
var fog_view: FogOverlay
const ArmyView = preload("res://src/render/army_renderer.gd")
var army_view
var workers_view: WorkerRenderer
var energy_view: EnergyRenderer
var camera: CameraController
var hud: GameHud
var orders: OrderOverlay
var clock := TickClock.new()

var _menu: MainMenu
var _frames_left := -1
var _warmup := 30
var _measured := 0
var _measured_time := 0.0
var _frame_measure_started_usec: int = 0
var _screenshot := ""
var _screenshot_in := -1
var _press_at := Vector2.ZERO
var _press_button := -1
var _press_ctrl := false
var _pressing := false
var _panning := false
var _last_mined := 0
var _tone: AudioStreamPlayer
var _autosave_tick := 0


func _ready() -> void:
	device_guard = preload("res://src/window_event_guard.gd").new()
	add_child(device_guard)
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


func _restart() -> void:
	if sim == null:
		return
	var config := sim.config
	clock.paused = false
	_boot(config)


func _leave() -> void:
	clock.paused = false
	_clear_playfield()
	sim = null
	world = null
	_menu = MainMenu.new()
	_menu.start_requested.connect(_boot)
	_menu.load_requested.connect(_boot_from_save)
	add_child(_menu)


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
	clock.reset()
	world = sim.world
	_last_mined = world.mined_count
	_autosave_tick = sim.tick_count
	renderer = WorldRenderer.new()
	renderer.world = world
	renderer.energy_sim = sim
	renderer.core_mask = sim.core_mask
	renderer.building_mask = sim.buildings.mask(world.cell_count())
	renderer.sync_match(sim)
	energy_view = EnergyRenderer.new()
	energy_view.world = world
	energy_view.energy = sim.energy_dots
	workers_view = WorkerRenderer.new()
	workers_view.world = world
	workers_view.sim = sim
	workers_view.workers = sim.workers
	workers_view.colors = sim.group_colors
	if sim._match_live():
		workers_view.fog = sim.fog
		energy_view.fog = sim.fog
	camera = CameraController.new()
	camera.world_size = Vector2(world.width, world.height)
	renderer.camera = camera
	if _has_flag("--grid"):
		renderer.show_grid = true
	if _has_flag("--chunks"):
		renderer.show_chunks = true
	add_child(renderer)
	if sim._match_live():
		fog_view = FogView.new()
		fog_view.sim = sim
		fog_view.cavern_style = renderer.world_fx_enabled
		add_child(fog_view)
	add_child(energy_view)
	add_child(workers_view)
	army_view = ArmyView.new()
	army_view.sim = sim
	add_child(army_view)
	orders = OrderOverlay.new()
	orders.sim = sim
	add_child(orders)
	add_child(camera)
	hud = GameHud.new()
	hud.sim = sim
	hud.clock = clock
	hud.camera = camera
	hud.renderer = renderer
	hud.fog_view = fog_view
	hud.load_requested.connect(_boot_from_save)
	hud.restart_requested.connect(_restart)
	hud.leave_requested.connect(_leave)
	add_child(hud)
	if sim.rules.cores.size() > 0:
		var core := sim.rules.cores[0]
		camera.position = Vector2(core % world.width, core / world.width)
	workers_view.show_tick(sim.tick_count)
	army_view.show_tick(sim.tick_count)
	_prepare_tone()


func _clear_playfield() -> void:
	for node in [renderer, fog_view, energy_view, workers_view, army_view, orders, camera, hud, _tone]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	renderer = null
	fog_view = null
	workers_view = null
	army_view = null
	energy_view = null
	orders = null
	camera = null
	hud = null
	_tone = null


func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventMouseMotion and _pressing:
		if hud != null and hud.energy_network_active() and _press_button == MOUSE_BUTTON_LEFT:
			if renderer != null: renderer.set_energy_preview(_energy_network_path(_press_at, event.position))
			return
		_preview_drag(event.position)
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		if hud != null and hud.menu_open():
			return
		if event.pressed:
			if hud != null and hud.energy_network_active() and event.button_index == MOUSE_BUTTON_LEFT:
				if renderer != null: renderer.set_energy_preview(_energy_network_path(event.position, event.position))
			_press_button = event.button_index
			_press_at = event.position
			_press_ctrl = event.ctrl_pressed
			_pressing = true
			_panning = false
			_preview_drag(event.position)
		elif _pressing and event.button_index == _press_button:
			_pressing = false
			if hud != null and hud.energy_network_active() and event.button_index == MOUSE_BUTTON_LEFT:
				sim.energy_network.place_path(sim, 0, _energy_network_path(_press_at, event.position))
				if renderer != null: renderer.set_energy_preview(PackedInt32Array())
				return
			if hud != null and hud.demolition_active() and event.button_index == MOUSE_BUTTON_LEFT:
				var target := _cell_at(event.position)
				if target.x >= 0: hud.demolish_at(world.index(target.x, target.y))
				return
			_finish_pointer(event)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E and hud != null and not hud.menu_open():
		_pressing = false
		if orders != null: orders.drag_active = false
		hud.toggle_energy_network()
		if renderer != null: renderer.set_energy_preview(PackedInt32Array())
	elif event.keycode == KEY_Q and hud != null and not hud.menu_open():
		_pressing = false
		if orders != null: orders.drag_active = false
		hud.toggle_demolition()
		if renderer != null: renderer.set_energy_preview(PackedInt32Array())
	elif event.keycode == KEY_G and renderer != null:
		renderer.show_grid = not renderer.show_grid
		renderer.queue_redraw()
	elif event.keycode == KEY_C and renderer != null:
		renderer.show_chunks = not renderer.show_chunks
		renderer.queue_redraw()
	elif event.keycode == KEY_ESCAPE and hud != null:
		hud.toggle_pause_menu()
	elif event.keycode == KEY_SPACE:
		if hud != null and hud.menu_open():
			hud.toggle_pause_menu()
		else:
			clock.paused = not clock.paused
	elif event.keycode == KEY_F11:
		_toggle_fullscreen()
	elif event.keycode == KEY_F7 and sim.debug_mode:
		_export_diagnostic_snapshot()
	elif event.keycode == KEY_F5:
		if not sim.debug_modified and not sim.debug_mode:
			SaveGame.write_file("user://slot.dw", sim)
	elif event.keycode == KEY_F9:
		_boot_from_save("user://slot.dw")
	if hud != null:
		hud.refresh()


func _process(delta: float) -> void:
	if sim == null:
		return
	var ticks := clock.advance_wall_time(Time.get_ticks_usec())
	if ticks > 0:
		sim.run_ticks(ticks)
		if fog_view != null: fog_view.show_tick(sim.tick_count)
		workers_view.show_tick(sim.tick_count)
		army_view.show_tick(sim.tick_count)
		energy_view.show_energy()
		if world.mined_count != _last_mined:
			_last_mined = world.mined_count
			_play_tone()
		if sim.tick_count - _autosave_tick >= 600 and not _headless() and not sim.debug_mode and not sim.debug_modified:
			_autosave_tick = sim.tick_count
			SaveGame.write_file("user://autosave.dw", sim)
		if hud != null:
			hud.refresh()
		renderer.sync_match(sim)
	_capture_screenshot()
	_measure_frames(delta)


func _preview_drag(screen: Vector2) -> void:
	var dragged := _press_at.distance_to(screen) >= 8.0
	if _press_button == MOUSE_BUTTON_RIGHT and not _press_ctrl:
		if dragged and camera != null:
			if not _panning:
				camera.begin_pan(screen)
				_panning = true
			else:
				camera.drag_pan(screen)
		if orders != null:
			orders.drag_active = false
		return
	if orders == null:
		return
	orders.drag_active = dragged
	orders.drag_conquer = _press_button == MOUSE_BUTTON_RIGHT and _press_ctrl
	if not dragged:
		return
	var start := _cell_at(_press_at)
	var end := _cell_at(screen)
	if start.x < 0 or end.x < 0:
		orders.drag_active = false
		return
	var rect := Rect2i(start, Vector2i.ZERO).expand(end)
	rect.size += Vector2i.ONE
	orders.drag_rect = rect


func _energy_network_path(from_screen: Vector2, to_screen: Vector2) -> PackedInt32Array:
	var start := _cell_at(from_screen)
	var finish := _cell_at(to_screen)
	if start.x < 0 or finish.x < 0: return PackedInt32Array()
	return sim.energy_network.plan_path(sim, 0, world.index(start.x, start.y), world.index(finish.x, finish.y), 0)


func _finish_pointer(event: InputEventMouseButton) -> void:
	if orders != null:
		orders.drag_active = false
	var screen := event.position
	var dragged := _press_at.distance_to(screen) >= 8.0
	if _press_button == MOUSE_BUTTON_RIGHT and not _press_ctrl and dragged:
		if camera != null:
			camera.end_pan()
		_panning = false
		return
	if hud == null:
		return
	var end := _cell_at(screen)
	if end.x < 0:
		return
	var gesture := GameHud.pointer_gesture(_press_button, _press_ctrl, dragged)
	if gesture == GameHud.Pointer.SELECT_ONE or gesture == GameHud.Pointer.SELECT_RECT:
		if gesture == GameHud.Pointer.SELECT_ONE and hud.command_mode == GameHud.Command.BUILD:
			hud.issue_build(world.index(end.x, end.y))
			return
		if gesture == GameHud.Pointer.SELECT_ONE:
			hud.select_at(world.index(end.x, end.y))
			return
		var start := _cell_at(_press_at)
		if start.x < 0:
			return
		var rect := Rect2i(start, Vector2i.ZERO).expand(end)
		rect.size += Vector2i.ONE
		hud.select_in_rect(rect)
		return
	var target := world.index(end.x, end.y)
	if gesture == GameHud.Pointer.WAR:
		hud.issue_war(target)
		return
	if gesture == GameHud.Pointer.MARCH:
		hud.issue_march(target)
		return
	if gesture != GameHud.Pointer.CONQUER:
		return
	var origin := _cell_at(_press_at)
	if origin.x < 0:
		return
	var area := Rect2i(origin, Vector2i.ZERO).expand(end)
	area.size += Vector2i.ONE
	hud.issue_conquer(area)


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


func _measure_frames(_delta: float) -> void:
	if _frames_left < 0:
		return
	_frames_left -= 1
	if _warmup > 0:
		_warmup -= 1
		_frame_measure_started_usec = Time.get_ticks_usec()
	else:
		_measured += 1
		_measured_time = (Time.get_ticks_usec() - _frame_measure_started_usec) / 1000000.0
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


## Explizite Diagnosekopie: niemals ein regulärer Slot oder Autosave.
func _export_diagnostic_snapshot() -> void:
	if sim == null or not sim.debug_mode:
		return
	var dir := "user://diagnostics"
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_error("Diagnoseordner nicht schreibbar")
		return
	var path := "%s/live-%d-%d.dw" % [dir, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Diagnosekopie nicht schreibbar")
		return
	file.store_buffer(SaveGame.to_bytes(sim))
	file.close()
	print("DIAGNOSTIC_SNAPSHOT ", ProjectSettings.globalize_path(path))
	if hud != null:
		hud.report("Diagnosekopie gesichert. Reguläre Spielstände bleiben unverändert.")

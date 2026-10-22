extends Node
## Zeigt die Welt und die Arbeiter. Linksklick setzt ein gemeinsames Laufziel.
## Ohne Abbauauftrag wird nichts abgebaut.

var sim: Simulation
var world: WorldState
var renderer: WorldRenderer
var workers_view: WorkerRenderer
var camera: CameraController
var clock := TickClock.new()

var _status: Label
var _frames_left := -1
var _warmup := 30
var _measured := 0
var _measured_time := 0.0
var _screenshot := ""
var _screenshot_in := -1


func _ready() -> void:
	var config := SimConfig.from_cmdline(OS.get_cmdline_user_args())
	var errors := config.validate()
	if not errors.is_empty():
		push_error("Konfiguration ungültig: " + ", ".join(errors))
		get_tree().quit(1)
		return
	_read_launch_flags()

	var started := Time.get_ticks_usec()
	sim = Simulation.create(config)
	if sim == null or not sim.check_invariants().is_empty():
		push_error("Startprüfung fehlgeschlagen")
		get_tree().quit(1)
		return
	world = sim.world
	var generation_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("DOT WARS bereit: %dx%d Seed %d" % [world.width, world.height, config.world_seed])
	print("Welt erzeugt in %.0f ms, Arbeiter %d" % [generation_ms, sim.workers.count])

	renderer = WorldRenderer.new()
	renderer.world = world
	workers_view = WorkerRenderer.new()
	workers_view.world = world
	workers_view.workers = sim.workers
	camera = CameraController.new()
	camera.world_size = Vector2(world.width, world.height)
	renderer.camera = camera
	if _has_flag("--grid"):
		renderer.show_grid = true
	if _has_flag("--chunks"):
		renderer.show_chunks = true
	add_child(renderer)
	add_child(workers_view)
	add_child(camera)
	_build_hud(config)
	workers_view.show_tick(sim.tick_count)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_set_goal_under_cursor(event.position)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_G:
		renderer.show_grid = not renderer.show_grid
		renderer.queue_redraw()
	elif event.keycode == KEY_C:
		renderer.show_chunks = not renderer.show_chunks
		renderer.queue_redraw()
	elif event.keycode == KEY_SPACE:
		clock.paused = not clock.paused
		_refresh_status()


func _process(delta: float) -> void:
	var ticks := clock.advance(delta)
	if ticks > 0:
		sim.run_ticks(ticks)
		workers_view.show_tick(sim.tick_count)
		_refresh_status()
	_capture_screenshot()
	_measure_frames(delta)


func _set_goal_under_cursor(screen: Vector2) -> void:
	var viewport := get_viewport().get_visible_rect().size
	var world_pos := WorldCoordinates.screen_to_world(screen, camera.position, camera.zoom.x, viewport)
	var cell := WorldCoordinates.world_to_cell(world_pos, world.width, world.height)
	if cell.x < 0:
		return
	var index := world.index(cell.x, cell.y)
	var placed := false
	for group_id in sim.quotas.size():
		placed = sim.set_move_goal(group_id, index) or placed
	if placed:
		_refresh_status()


func _refresh_status() -> void:
	if _status == null:
		return
	var goal := sim.move_goal(0)
	var goal_text := "kein Ziel"
	if goal >= 0:
		goal_text = "Ziel %d,%d" % [goal % world.width, goal / world.width]
	var pause := "Pause" if clock.paused else "läuft"
	_status.text = "Arbeiter %d  ·  Tick %d  ·  %s  ·  %s" % [sim.workers.count, sim.tick_count, pause, goal_text]


func _build_hud(config: SimConfig) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right"]:
		margin.add_theme_constant_override(side, 16)
	layer.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_label(box, "DOT WARS  ·  %d × %d  ·  Seed %d" % [world.width, world.height, config.world_seed], 20)
	_label(box, "Linksklick ins Leere setzt das Ziel  ·  Leertaste Pause  ·  Mausrad Zoom  ·  Rechte Taste oder WASD verschieben", 15)
	_label(box, "G Raster  ·  C Chunks  ·  Gelb und Cyan sind die beiden Gruppen", 15)
	_status = _label(box, "", 16)
	_refresh_status()

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	_swatch(row, Materials.SOFT, "Weich")
	_swatch(row, Materials.MEDIUM, "Mittel")
	_swatch(row, Materials.HARD, "Hart")
	_swatch(row, Materials.INDESTRUCTIBLE, "Unzerstörbar")


func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)
	return label


func _swatch(parent: Node, material: int, title: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var chip := ColorRect.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.custom_minimum_size = Vector2(14, 14)
	chip.color = Materials.COLORS[material]
	row.add_child(chip)
	_label(row, title, 15)


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

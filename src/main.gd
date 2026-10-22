extends Node
## Zeigt die generierte Dot-Welt. Arbeiter werden in dieser Phase nicht erzeugt und nicht bewegt.

var world: WorldState
var renderer: WorldRenderer
var camera: CameraController

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
		_screenshot_in = 3

	var started := Time.get_ticks_usec()
	world = WorldGenerator.generate(config)
	var generation_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("DOT WARS bereit: %dx%d Seed %d" % [world.width, world.height, config.world_seed])
	print("Welt erzeugt in %.0f ms, unzerstörbar %d" % [generation_ms, world.indestructible_count])

	renderer = WorldRenderer.new()
	renderer.world = world
	camera = CameraController.new()
	camera.world_size = Vector2(world.width, world.height)
	renderer.camera = camera
	if _has_flag("--grid"):
		renderer.show_grid = true
	if _has_flag("--chunks"):
		renderer.show_chunks = true
	add_child(renderer)
	add_child(camera)
	_build_hud(config)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_G:
		renderer.show_grid = not renderer.show_grid
		renderer.queue_redraw()
	elif event.keycode == KEY_C:
		renderer.show_chunks = not renderer.show_chunks
		renderer.queue_redraw()


func _process(delta: float) -> void:
	if _screenshot_in > 0:
		_screenshot_in -= 1
		if _screenshot_in == 0:
			var image := get_viewport().get_texture().get_image()
			image.save_png(_screenshot)
			print("SCREENSHOT %s" % _screenshot)
			if _frames_left < 0:
				get_tree().quit(0)
				return
	if _frames_left < 0:
		return
	_frames_left -= 1
	if _warmup > 0:
		_warmup -= 1
	else:
		_measured += 1
		_measured_time += delta
	if _frames_left == 0:
		var viewport := get_viewport().get_visible_rect().size
		var fps := 0.0 if _measured_time <= 0.0 else float(_measured) / _measured_time
		print("RENDER fps %.1f frames %d viewport %dx%d world %d" % [
			fps, _measured, int(viewport.x), int(viewport.y), world.width,
		])
		get_tree().quit(0)


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
	_label(box, "Mausrad zoomt  ·  Rechte Taste, WASD oder Pfeile verschieben  ·  G Raster  ·  C Chunks", 15)
	_label(box, "Keine Arbeiter in dieser Ansicht.", 15)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	_swatch(row, Materials.SOFT, "Weich")
	_swatch(row, Materials.MEDIUM, "Mittel")
	_swatch(row, Materials.HARD, "Hart")
	_swatch(row, Materials.INDESTRUCTIBLE, "Unzerstörbar")


func _label(parent: Node, text: String, size: int) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.93, 0.94, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(label)


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


func _user_arg(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return ""


func _has_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args()

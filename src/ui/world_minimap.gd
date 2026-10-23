class_name WorldMinimap
extends Control
## Kleine, anklickbare Weltübersicht. Verwendet die bereits erzeugte Welttextur.
## Keine zusätzliche Material- oder Arbeiter-Simulation.

var world: WorldState
var renderer: WorldRenderer
var camera: CameraController

var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Klicken, um die Kamera zur gewünschten Position zu bewegen."
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	if world == null or renderer == null:
		return
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Materials.BACKDROP, true)
	var texture := renderer.current_texture()
	if texture == null:
		return
	# Weltverhältnis statt verzerrter Darstellung.
	var factor := minf(size.x / float(world.width), size.y / float(world.height))
	var map_size := Vector2(world.width * factor, world.height * factor)
	var origin := (size - map_size) * 0.5
	var map_rect := Rect2(origin, map_size)
	draw_texture_rect(texture, map_rect, false)
	draw_rect(map_rect, Color(1, 1, 1, 0.28), false, 1.0)

	if camera != null:
		var viewport_size := camera.get_viewport_rect().size
		var zoom := maxf(camera.zoom.x, 0.001)
		var visible := WorldCoordinates.visible_world_rect(camera.position, zoom, viewport_size)
		visible = visible.intersection(Rect2(Vector2.ZERO, Vector2(world.width, world.height)))
		if visible.has_area():
			var marker := Rect2(
				origin + visible.position * factor,
				visible.size * factor
			)
			draw_rect(marker, Color(1, 1, 1, 0.95), false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if camera == null or world == null:
		return
	var factor := minf(size.x / float(world.width), size.y / float(world.height))
	if factor <= 0.0:
		return
	var map_size := Vector2(world.width * factor, world.height * factor)
	var origin := (size - map_size) * 0.5
	var local_pos: Vector2 = (event.position - origin) / factor
	camera.focus_world(local_pos)
	accept_event()
	queue_redraw()

class_name CameraController
extends Camera2D
## Verschieben mit mittlerer Maustaste, WASD und den Pfeiltasten. Die rechte Taste schickt Arbeiter.
## Das Mausrad zoomt zum Cursor. Der Zoombereich liegt zwischen der ganzen Welt und 40 Pixeln je Zelle.

const MAX_ZOOM := 40.0
const START_ZOOM := 10.0
const KEY_SPEED := 520.0
const WHEEL_FACTOR := 1.12

var world_size := Vector2.ZERO

var _min_zoom := 1.0
var _dragging := false
var _drag_screen := Vector2.ZERO
var _drag_camera := Vector2.ZERO


func _ready() -> void:
	make_current()
	position_smoothing_enabled = false
	get_viewport().size_changed.connect(_apply_view)
	_apply_view()


func _apply_view() -> void:
	var viewport := get_viewport_rect().size
	if viewport.x < 1.0 or viewport.y < 1.0 or world_size.x < 1.0:
		return
	_min_zoom = minf(WorldCoordinates.fit_zoom(world_size, viewport), MAX_ZOOM)
	var next := clampf(zoom.x if zoom.x > 0.0 else START_ZOOM, _min_zoom, MAX_ZOOM)
	if is_equal_approx(zoom.x, 1.0) and is_equal_approx(zoom.y, 1.0):
		next = clampf(START_ZOOM, _min_zoom, MAX_ZOOM)
		position = world_size * 0.5
	zoom = Vector2(next, next)
	_clamp_position()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction == Vector2.ZERO:
		return
	position += direction.normalized() * KEY_SPEED * delta / zoom.x
	_clamp_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = event.position - _drag_screen
		position = _drag_camera - delta / zoom.x
		_clamp_position()


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not event.pressed:
			return
		var factor := WHEEL_FACTOR if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / WHEEL_FACTOR
		_zoom_at(event.position, factor)
		return
	if event.button_index != MOUSE_BUTTON_MIDDLE:
		return
	_dragging = event.pressed
	if _dragging:
		_drag_screen = event.position
		_drag_camera = position
	get_viewport().set_input_as_handled()


func _zoom_at(screen: Vector2, factor: float) -> void:
	var viewport := get_viewport_rect().size
	var before := WorldCoordinates.screen_to_world(screen, position, zoom.x, viewport)
	var next := clampf(zoom.x * factor, _min_zoom, MAX_ZOOM)
	zoom = Vector2(next, next)
	var after := WorldCoordinates.screen_to_world(screen, position, zoom.x, viewport)
	position += before - after
	_clamp_position()


## Verschiebt die Kamera durch die Minimap, mit denselben Weltgrenzen wie bei WASD.
func focus_world(target: Vector2) -> void:
	position = target
	_clamp_position()


func _clamp_position() -> void:
	var viewport := get_viewport_rect().size
	var half := viewport / zoom.x * 0.5
	position.x = _clamp_axis(position.x, half.x, world_size.x)
	position.y = _clamp_axis(position.y, half.y, world_size.y)


func _clamp_axis(value: float, half_view: float, extent: float) -> float:
	var lower := half_view
	var upper := extent - half_view
	if lower >= upper:
		return extent * 0.5
	return clampf(value, lower, upper)

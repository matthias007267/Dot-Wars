class_name WorldCoordinates
extends RefCounted
## Umrechnung zwischen Zelle, Welt und Bildschirm.
## Eine Zelle ist 1×1 Welteinheit. Die Kamera sitzt auf der Weltmitte ihres Bildes,
## ohne Drehung und ohne zusätzlichen Offset. Das entspricht einer Camera2D.


static func cell_origin(cell: Vector2i) -> Vector2:
	return Vector2(cell)


static func world_to_cell(world_pos: Vector2, width: int, height: int) -> Vector2i:
	var x := floori(world_pos.x)
	var y := floori(world_pos.y)
	if x < 0 or y < 0 or x >= width or y >= height:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


static func screen_to_world(screen: Vector2, camera_center: Vector2, zoom: float, viewport_size: Vector2) -> Vector2:
	return (screen - viewport_size * 0.5) / zoom + camera_center


static func world_to_screen(world_pos: Vector2, camera_center: Vector2, zoom: float, viewport_size: Vector2) -> Vector2:
	return (world_pos - camera_center) * zoom + viewport_size * 0.5


static func visible_world_rect(camera_center: Vector2, zoom: float, viewport_size: Vector2) -> Rect2:
	var size := viewport_size / zoom
	return Rect2(camera_center - size * 0.5, size)


## Zoom, bei dem die ganze Welt mit etwas Rand in das Fenster passt.
static func fit_zoom(world_size: Vector2, viewport_size: Vector2) -> float:
	return minf(viewport_size.x / world_size.x, viewport_size.y / world_size.y) * 0.94

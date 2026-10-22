class_name WorldRenderer
extends Node2D
## Eine Textur für die ganze Welt, ein Pixel pro Zelle. Geändert wird nur der betroffene Chunk.
## Es gibt keine Node pro Zelle.

const GRID_MIN_ZOOM := 8.0
const PIT_GLOW_MIN_ZOOM := 3.0

var world: WorldState
var camera: Camera2D
var show_grid := false
var show_chunks := false

var _bytes := PackedByteArray()
var _image: Image
var _texture: ImageTexture


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_bytes.resize(world.cell_count() * 4)
	paint_all(_bytes, world, palette_bytes(), _pit_index())
	_upload()
	world.consume_dirty_chunks()
	queue_redraw()


func _process(_delta: float) -> void:
	var dirty := world.consume_dirty_chunks()
	if dirty.is_empty():
		return
	var palette := palette_bytes()
	for chunk in dirty:
		paint_rect(_bytes, world, palette, world.chunk_rect(chunk), _pit_index())
	_upload()
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture, Rect2(0, 0, world.width, world.height), false)
	_draw_pit_glow()
	if show_chunks:
		_draw_chunks()
	if show_grid:
		_draw_grid()


## Gibt der Minimap die bereits vorhandene, aktualisierte Welttextur.
func current_texture() -> Texture2D:
	return _texture


static func palette_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(Materials.COUNT * 4)
	for material in Materials.COUNT:
		var color := Materials.COLORS[material]
		var offset := material * 4
		bytes[offset] = _channel(color.r)
		bytes[offset + 1] = _channel(color.g)
		bytes[offset + 2] = _channel(color.b)
		bytes[offset + 3] = 255
	return bytes


static func paint_all(
	bytes: PackedByteArray, world: WorldState, palette: PackedByteArray, pit: int = -1
) -> void:
	var cells := world.cells
	for idx in cells.size():
		_write_cell(bytes, palette, world, idx, cells[idx], pit)


static func paint_rect(
	bytes: PackedByteArray, world: WorldState, palette: PackedByteArray, rect: Rect2i, pit: int = -1
) -> void:
	var cells := world.cells
	var width := world.width
	for y in range(rect.position.y, rect.end.y):
		var row := y * width
		for x in range(rect.position.x, rect.end.x):
			var idx := row + x
			_write_cell(bytes, palette, world, idx, cells[idx], pit)


func _upload() -> void:
	_image = Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


## Der Lichtakzent wird nur beim Zeichnen berechnet; kein Pixel/Node je Zelle.
## Bei kleinen Zoomstufen bleibt das Energiekern ein einzelner farbiger Dot.
func _draw_pit_glow() -> void:
	if camera == null or camera.zoom.x < PIT_GLOW_MIN_ZOOM:
		return
	var point := WorldGenerator.sacrifice_cell(world)
	var center := Vector2(point.x + 0.5, point.y + 0.5)
	var glow := Materials.PIT_COLOR
	draw_circle(center, 3.6, Color(glow.r, glow.g, glow.b, 0.055))
	draw_circle(center, 2.4, Color(glow.r, glow.g, glow.b, 0.095))
	draw_circle(center, 1.35, Color(glow.r, glow.g, glow.b, 0.18))


func _draw_grid() -> void:
	if camera == null or camera.zoom.x < GRID_MIN_ZOOM:
		return
	var area := _visible_world()
	if not area.has_area():
		return
	var color := Color(1, 1, 1, 0.22)
	var x0 := floori(area.position.x)
	var y0 := floori(area.position.y)
	var x1 := ceili(area.end.x)
	var y1 := ceili(area.end.y)
	var width := 1.0 / camera.zoom.x
	for x in range(x0, x1 + 1):
		draw_line(Vector2(x, y0), Vector2(x, y1), color, width)
	for y in range(y0, y1 + 1):
		draw_line(Vector2(x0, y), Vector2(x1, y), color, width)


func _draw_chunks() -> void:
	var area := _visible_world()
	if not area.has_area():
		return
	var color := Color(0.95, 0.78, 0.25, 0.7)
	var step := world.chunk_size
	var width := 1.5 / maxf(camera.zoom.x if camera != null else 1.0, 0.001)
	var x0 := int(area.position.x / step) * step
	var y0 := int(area.position.y / step) * step
	var x := x0
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), color, width)
		x += step
	var y := y0
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, width)
		y += step


func _visible_world() -> Rect2:
	var viewport := get_viewport_rect().size
	var zoom := camera.zoom.x if camera != null else 1.0
	var center := camera.position if camera != null else Vector2(world.width, world.height) * 0.5
	var visible := WorldCoordinates.visible_world_rect(center, zoom, viewport)
	return visible.intersection(Rect2(0, 0, world.width, world.height))


func _pit_index() -> int:
	var pit := WorldGenerator.sacrifice_cell(world)
	return world.index(pit.x, pit.y)


static func _write_cell(
	bytes: PackedByteArray, palette: PackedByteArray, world: WorldState, idx: int, material: int, pit: int = -1
) -> void:
	var dst := idx * 4
	if idx == pit:
		var pit_color := Materials.PIT_COLOR
		bytes[dst] = _channel(pit_color.r)
		bytes[dst + 1] = _channel(pit_color.g)
		bytes[dst + 2] = _channel(pit_color.b)
		bytes[dst + 3] = 255
		return
	var src := material * 4
	var red := int(palette[src])
	var green := int(palette[src + 1])
	var blue := int(palette[src + 2])
	# Dezente, reproduzierbare Tonabstufungen machen Flächen lebendig,
	# ohne Umrandungen, Texturassets oder zeitabhängiges Rauschen.
	# Die Material-ID und die Spiellogik bleiben unverändert.
	if Materials.is_mineable(material):
		var offset := material_variation(idx, material)
		red = clampi(red + offset, 0, 255)
		green = clampi(green + offset, 0, 255)
		blue = clampi(blue + offset, 0, 255)
	var dug := world.progress[idx]
	if dug > 0 and Materials.is_mineable(material):
		var durability := Materials.durability(material, SimConfig.TICKS_PER_SECOND)
		var shade := 0.0 if durability <= 0 else clampf(float(dug) / float(durability), 0.0, 1.0)
		var empty := Materials.EMPTY * 4
		red = int(round(lerpf(red, palette[empty], shade)))
		green = int(round(lerpf(green, palette[empty + 1], shade)))
		blue = int(round(lerpf(blue, palette[empty + 2], shade)))
	bytes[dst] = red
	bytes[dst + 1] = green
	bytes[dst + 2] = blue
	bytes[dst + 3] = 255


## Geringe Helligkeitsvarianz je Zelle (-6 bis +6), unabhängig vom Seed.
static func material_variation(index: int, material: int) -> int:
	var hashed := (index * 31 + material * 127) & 0x7FFFFFFF
	hashed = (hashed ^ (hashed >> 7) ^ (hashed >> 13)) & 0x7FFFFFFF
	return (hashed % 5 - 2) * 3


static func _channel(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)

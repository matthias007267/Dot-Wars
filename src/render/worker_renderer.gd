class_name WorkerRenderer
extends Node2D
## Zeichnet alle Arbeiter in eine Textur, ein Pixel pro Zelle. Keine Node pro Arbeiter.

var world: WorldState
var camera: Camera2D
const GLOW_MIN_ZOOM := 7.0
const MAX_GLOW_UNITS := 240
var workers: WorkerStore
var colors: Array[Color] = [
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0x53, 0xC7, 0xFF),
]

var _bytes := PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _drawn_tick := -1
var _painted := PackedInt32Array()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_bytes.resize(world.cell_count() * 4)
	_upload()


## Baut die Textur neu, wenn ein neuer Simulationstakt gezeichnet werden soll.
func show_tick(tick: int) -> void:
	if tick == _drawn_tick:
		return
	for idx in _painted:
		var dst := idx * 4
		_bytes[dst] = 0
		_bytes[dst + 1] = 0
		_bytes[dst + 2] = 0
		_bytes[dst + 3] = 0
	_painted.clear()
	var palette := _palette()
	var width := world.width
	for id in workers.count:
		var group_id := int(workers.group[id])
		var color_index := group_id if group_id < colors.size() else 0
		var src := color_index * 4
		var unit_size := int(workers.size[id])
		var anchor := workers.cell[id]
		for dy in unit_size:
			var row := anchor + dy * width
			for dx in unit_size:
				var cell := row + dx
				var dst := cell * 4
				_bytes[dst] = palette[src]
				_bytes[dst + 1] = palette[src + 1]
				_bytes[dst + 2] = palette[src + 2]
				_bytes[dst + 3] = 255
				_painted.append(cell)
	_upload()
	_drawn_tick = tick
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(0, 0, world.width, world.height), false)
	_draw_worker_accents()


## Nur bei Nahansicht und für wenige sichtbare Einheiten: dezente Lichtakzente.
## Kein zusätzlicher Node pro Arbeiter und keine Änderung der Worker-Textur.
func _draw_worker_accents() -> void:
	if camera == null or camera.zoom.x < GLOW_MIN_ZOOM:
		return
	var zoom := camera.zoom.x
	var viewport := get_viewport_rect().size
	var bounds := Rect2(camera.position - viewport / (2.0 * zoom), viewport / zoom)
	var painted := 0
	for id in workers.count:
		if painted >= MAX_GLOW_UNITS:
			break
		var cell := workers.cell[id]
		var x := cell % world.width
		var y := cell / world.width
		var size := int(workers.size[id])
		if not bounds.grow(2.0).has_point(Vector2(x, y)):
			continue
		var group_id := int(workers.group[id])
		var tint := colors[group_id] if group_id < colors.size() else colors[0]
		draw_rect(Rect2(x - 0.75, y - 0.75, size + 1.5, size + 1.5), Color(tint.r, tint.g, tint.b, 0.10), true)
		painted += 1


func _upload() -> void:
	_image = Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


func _palette() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(colors.size() * 4)
	for index in colors.size():
		var color := colors[index]
		var offset := index * 4
		bytes[offset] = _channel(color.r)
		bytes[offset + 1] = _channel(color.g)
		bytes[offset + 2] = _channel(color.b)
		bytes[offset + 3] = 255
	return bytes


func _channel(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)

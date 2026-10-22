class_name WorkerRenderer
extends Node2D
## Zeichnet alle Arbeiter in eine Textur, ein Pixel pro Zelle. Keine Node pro Arbeiter.

const GROUP_COLORS: Array[Color] = [
	Color(0.98, 0.86, 0.12),
	Color(0.25, 0.88, 0.95),
]

var world: WorldState
var workers: WorkerStore

var _bytes := PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _drawn_tick := -1


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_bytes.resize(world.cell_count() * 4)
	_upload()


## Baut die Textur neu, wenn ein neuer Simulationstakt gezeichnet werden soll.
func show_tick(tick: int) -> void:
	if tick == _drawn_tick:
		return
	_bytes.fill(0)
	var palette := _palette()
	for id in workers.count:
		var group_id := int(workers.group[id])
		var color_index := group_id if group_id < GROUP_COLORS.size() else 0
		var src := color_index * 4
		var dst := workers.cell[id] * 4
		_bytes[dst] = palette[src]
		_bytes[dst + 1] = palette[src + 1]
		_bytes[dst + 2] = palette[src + 2]
		_bytes[dst + 3] = 255
	_upload()
	_drawn_tick = tick
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(0, 0, world.width, world.height), false)


func _upload() -> void:
	_image = Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)


func _palette() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(GROUP_COLORS.size() * 4)
	for index in GROUP_COLORS.size():
		var color := GROUP_COLORS[index]
		var offset := index * 4
		bytes[offset] = _channel(color.r)
		bytes[offset + 1] = _channel(color.g)
		bytes[offset + 2] = _channel(color.b)
		bytes[offset + 3] = 255
	return bytes


func _channel(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)

class_name EnergyRenderer
extends Node2D
## Zeichnet transportierte Energie als eigene Pixeltextur.
## Arbeiter werden darüber gezeichnet und bleiben bei Konflikten sichtbar.

var world: WorldState
var energy: EnergyStore
var _texture: ImageTexture
var _bytes := PackedByteArray()
var _previous := PackedInt32Array()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	_bytes.resize(world.cell_count() * 4)
	show_energy()


func show_energy() -> void:
	for c in _previous:
		var i := c * 4
		_bytes[i] = 0
		_bytes[i + 1] = 0
		_bytes[i + 2] = 0
		_bytes[i + 3] = 0
	_previous.clear()
	for c in energy.cells:
		if c < 0 or c >= world.cell_count():
			continue
		var i := c * 4
		_bytes[i] = 0x53
		_bytes[i + 1] = 0xC7
		_bytes[i + 2] = 0xFF
		_bytes[i + 3] = 255
		_previous.append(c)
	var img := Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
	else:
		_texture.update(img)
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(0, 0, world.width, world.height), false)

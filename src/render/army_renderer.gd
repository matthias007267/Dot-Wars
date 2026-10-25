class_name ArmyRenderer
extends Node2D
## Eine Textur für alle Krieger; keine Szene pro Dot.
const PALETTE := [245, 78, 80, 255, 255, 122, 89, 255, 126, 182, 255, 255, 93, 222, 154, 255]
var sim: Simulation
var _bytes := PackedByteArray()
var _texture: ImageTexture
var _painted := PackedInt32Array()
var _tick := -1

func show_tick(tick: int) -> void:
	if tick == _tick: return
	_tick = tick
	if sim.army.count == 0 and _painted.is_empty(): return
	if _bytes.is_empty(): _bytes.resize(sim.world.cell_count() * 4)
	for cell in _painted:
		var at := cell * 4
		_bytes[at] = 0
		_bytes[at + 1] = 0
		_bytes[at + 2] = 0
		_bytes[at + 3] = 0
	var positions := sim.army.cells
	var owners := sim.army.owners
	for index in positions.size():
		var at := positions[index] * 4
		var color := owners[index] * 4
		_bytes[at] = PALETTE[color]
		_bytes[at + 1] = PALETTE[color + 1]
		_bytes[at + 2] = PALETTE[color + 2]
		_bytes[at + 3] = 255
	_painted = positions.duplicate()
	var image := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null: _texture = ImageTexture.create_from_image(image)
	else: _texture.update(image)
	texture_filter = TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if _texture != null: draw_texture_rect(_texture, Rect2(0, 0, sim.world.width, sim.world.height), false)

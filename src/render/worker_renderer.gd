class_name WorkerRenderer
extends Node2D
## Zeichnet alle Arbeiter in eine Textur, ein Pixel pro Zelle. Keine Node pro Arbeiter.

const DOT_GLOW_SHADER := preload("res://src/render/shaders/dot_glow.gdshader")
@export var glow_enabled := true
@export_range(0.0, 1.0, 0.05) var glow_strength := 0.80

var sim: Simulation
var world: WorldState
var workers: WorkerStore
var fog = null
var viewer := 0
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
	if glow_enabled:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = DOT_GLOW_SHADER
		shader_material.set_shader_parameter("glow_strength", glow_strength)
		shader_material.set_shader_parameter("dot_brightness", 1.13)
		material = shader_material
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
	if material is ShaderMaterial and sim != null:
		material.set_shader_parameter("upgrade_marks", mini(2, maxi(sim.upgrades.dig_level, sim.upgrades.speed_level) / 2))
	var palette := _palette()
	var width := world.width
	for id in workers.count:
		if fog != null and not fog.is_visible(viewer, workers.cell[id]): continue
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

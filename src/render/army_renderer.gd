class_name ArmyRenderer
extends Node2D
## Eine Textur für alle Krieger; keine Szene pro Dot.
const PALETTE := [245, 78, 80, 255, 255, 122, 89, 255, 126, 182, 255, 255, 93, 222, 154, 255]
const DOT_SHADER := preload("res://src/render/shaders/dot_glow.gdshader")
var sim: Simulation
var viewer := 0
@export var sprites_enabled := true
@export var glow_enabled := true
var _bytes := PackedByteArray()
var _texture: ImageTexture
var _painted := PackedInt32Array()
var _tick := -1
var _details := PackedByteArray()
var _detail_texture: ImageTexture

func _ready() -> void:
	var effect := ShaderMaterial.new()
	effect.shader = DOT_SHADER
	effect.set_shader_parameter("unit_kind", 1)
	effect.set_shader_parameter("glow_strength", 0.45 if glow_enabled else 0.0)
	SpriteCatalog.configure_units(effect)
	effect.set_shader_parameter("sprites_enabled", sprites_enabled)
	material = effect
	if _detail_texture != null: material.set_shader_parameter("unit_details", _detail_texture)

func _process(_delta: float) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("sprite_detail", get_canvas_transform().get_scale().x >= 10.0)

func show_tick(tick: int) -> void:
	if tick == _tick: return
	_tick = tick
	if sim.army.count == 0 and _painted.is_empty(): return
	if _bytes.is_empty(): _bytes.resize(sim.world.cell_count() * 4)
	if _details.is_empty(): _details.resize(_bytes.size())
	for cell in _painted:
		var at := cell * 4
		_bytes[at] = 0
		_bytes[at + 1] = 0
		_bytes[at + 2] = 0
		_bytes[at + 3] = 0
		for channel in 4: _details[at + channel] = 0
	var positions := sim.army.cells
	var owners := sim.army.owners
	for index in positions.size():
		if sim._match_live() and not sim.fog.is_visible(viewer, positions[index]): continue
		var at := positions[index] * 4
		var color := owners[index] * 4
		_bytes[at] = PALETTE[color]
		_bytes[at + 1] = PALETTE[color + 1]
		_bytes[at + 2] = PALETTE[color + 2]
		_bytes[at + 3] = 255
		_details[at] = SpriteCatalog.warrior_row(sim.army, index, tick)
		_details[at + 1] = SpriteCatalog.facing(positions[index], sim.army.goals[index], sim.world.width)
		_details[at + 2] = owners[index]
	_painted = positions.duplicate()
	var image := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null: _texture = ImageTexture.create_from_image(image)
	else: _texture.update(image)
	var details := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _details)
	if _detail_texture == null: _detail_texture = ImageTexture.create_from_image(details)
	else: _detail_texture.update(details)
	if material is ShaderMaterial:
		material.set_shader_parameter("unit_details", _detail_texture)
		material.set_shader_parameter("simulation_tick", tick)
	texture_filter = TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if _texture != null: draw_texture_rect(_texture, Rect2(0, 0, sim.world.width, sim.world.height), false)

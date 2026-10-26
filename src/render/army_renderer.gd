class_name ArmyRenderer
extends Node2D
## Eine Textur für alle Krieger; keine Szene pro Dot.
const PALETTE := [245, 78, 80, 255, 255, 122, 89, 255, 126, 182, 255, 255, 93, 222, 154, 255]
const DOT_SHADER := preload("res://src/render/shaders/dot_glow.gdshader")
var sim: Simulation
var viewer := 0
@export var sprites_enabled := true
@export var glow_enabled := true
## Asset-review override only. Live matches use the existing basic warrior (1).
@export_range(1, 3) var visual_level := 1
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
	# Bulk clear is bounded by map area and avoids eight script writes per old dot.
	_bytes.fill(0)
	_details.fill(0)
	var positions := sim.army.cells
	var owners := sim.army.owners
	var match_live := sim._match_live()
	var sight: PackedByteArray = sim.fog.visible[viewer] if match_live else PackedByteArray()
	var sprite_row := SpriteCatalog.warrior_row(visual_level)
	var attacks := sim.army.last_attack
	var moves := sim.army.next_move
	for index in positions.size():
		if match_live and sight[positions[index]] == 0: continue
		var at := positions[index] * 4
		var color := owners[index] * 4
		_bytes[at] = PALETTE[color]
		_bytes[at + 1] = PALETTE[color + 1]
		_bytes[at + 2] = PALETTE[color + 2]
		_bytes[at + 3] = 255
		_details[at] = sprite_row
		var attack := attacks[index]
		_details[at + 1] = 2 if attack >= 0 and tick >= attack and tick - attack < 3 else (1 if moves[index] > tick else 0)
		_details[at + 2] = owners[index]
		_details[at + 3] = visual_level
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

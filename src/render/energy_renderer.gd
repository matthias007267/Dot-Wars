class_name EnergyRenderer
extends Node2D
## Zeichnet transportierte Energie als eigene Pixeltextur.
## Arbeiter werden darüber gezeichnet und bleiben bei Konflikten sichtbar.

const DOT_GLOW_SHADER := preload("res://src/render/shaders/energy_dot.gdshader")
@export var glow_enabled := true
@export_range(0.0, 1.0, 0.05) var glow_strength := 0.95

var world: WorldState
var energy: EnergyStore
var fog = null
var viewer := 0
var _texture: ImageTexture
var _bytes := PackedByteArray()
var _previous := PackedInt32Array()


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	var shader_material := ShaderMaterial.new()
	shader_material.shader = DOT_GLOW_SHADER
	shader_material.set_shader_parameter("glow_strength", glow_strength if glow_enabled else 0.0)
	material = shader_material
	_bytes.resize(world.cell_count() * 4)
	show_energy()

func _process(_delta: float) -> void:
	if material is ShaderMaterial:
		material.set_shader_parameter("sprite_detail", get_global_transform_with_canvas().get_scale().x >= 12.0)


func show_energy() -> void:
	energy.ensure_tracks()
	for c in _previous:
		var i := c * 4
		_bytes[i] = 0
		_bytes[i + 1] = 0
		_bytes[i + 2] = 0
		_bytes[i + 3] = 0
	_previous.clear()
	for token in energy.cells.size():
		var c := energy.cells[token]
		if c < 0 or c >= world.cell_count() or (fog != null and not fog.is_visible(viewer, c)):
			continue
		var i := c * 4
		var tint := MatchRules.FACTION_COLORS[0]
		if energy.owner[token] == EnergyStore.NEUTRAL: tint = Color8(180, 180, 180)
		elif energy.owner[token] > 0 and energy.owner[token] < MatchRules.FACTION_COLORS.size(): tint = MatchRules.FACTION_COLORS[energy.owner[token]]
		if _bytes[i + 3] == 0: _previous.append(c)
		_bytes[i] = int(tint.r * 255.0)
		_bytes[i + 1] = int(tint.g * 255.0)
		_bytes[i + 2] = int(tint.b * 255.0)
		# Alpha encodes presence/buffer status; the shader keeps the team rim opaque.
		_bytes[i + 3] = 128 if energy.held_by[token] >= 0 else 255
	var img := Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
	else:
		_texture.update(img)
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(0, 0, world.width, world.height), false)

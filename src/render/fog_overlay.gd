class_name FogOverlay
extends Node2D
## Full-opacity unexplored pixels; stale terrain for explored but unseen pixels.
## Drawn above terrain and below dots. No access to enemy live unit state.
var sim: Simulation
var faction := 0
var _texture: ImageTexture
var _minimap_texture: ImageTexture
var _minimap_bytes := PackedByteArray()
var _bytes := PackedByteArray()
var _tick := -1
const UNEXPLORED := Color8(8, 10, 17)
const MEMORY_SHADE := 0.38

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	if sim != null: show_tick(sim.tick_count)

func show_tick(tick: int) -> void:
	if sim == null or not sim._match_live() or sim.fog.factions <= faction: return
	if tick == _tick: return
	_tick = tick
	var fog = sim.fog
	var current_visible: PackedByteArray = fog.visible[faction]
	var current_explored: PackedByteArray = fog.explored[faction]
	var current_terrain: PackedByteArray = fog.known_terrain[faction]
	# Avoid full-map CPU repaint and GPU uploads on unchanged player knowledge.
	if _last_visible == current_visible and _last_explored == current_explored and _last_terrain == current_terrain: return
	_last_visible = current_visible.duplicate()
	_last_explored = current_explored.duplicate()
	_last_terrain = current_terrain.duplicate()
	var count := sim.world.cell_count()
	if _bytes.size() != count * 4: _bytes.resize(count * 4)
	if _minimap_bytes.size() != count * 4: _minimap_bytes.resize(count * 4)
	for cell in count:
		var offset := cell * 4
		var known := fog.known_material(faction, cell)
		var map_color := UNEXPLORED
		if known >= 0 and known < Materials.COUNT:
			map_color = Materials.COLORS[known]
			if not fog.is_visible(faction, cell): map_color = map_color * MEMORY_SHADE
		_minimap_bytes[offset] = clampi(int(map_color.r * 255.0), 0, 255)
		_minimap_bytes[offset + 1] = clampi(int(map_color.g * 255.0), 0, 255)
		_minimap_bytes[offset + 2] = clampi(int(map_color.b * 255.0), 0, 255)
		_minimap_bytes[offset + 3] = 255
		if fog.is_visible(faction, cell):
			_bytes[offset + 3] = 0
			continue
		var color := UNEXPLORED
		if fog.is_explored(faction, cell):
			var material := fog.known_material(faction, cell)
			if material >= 0 and material < Materials.COUNT:
				color = Materials.COLORS[material] * MEMORY_SHADE
		_bytes[offset] = clampi(int(color.r * 255.0), 0, 255)
		_bytes[offset + 1] = clampi(int(color.g * 255.0), 0, 255)
		_bytes[offset + 2] = clampi(int(color.b * 255.0), 0, 255)
		_bytes[offset + 3] = 255
	var img := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null: _texture = ImageTexture.create_from_image(img)
	else: _texture.update(img)
	var minimap_image := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _minimap_bytes)
	if _minimap_texture == null: _minimap_texture = ImageTexture.create_from_image(minimap_image)
	else: _minimap_texture.update(minimap_image)
	queue_redraw()

func minimap_texture() -> Texture2D:
	return _minimap_texture

func _draw() -> void:
	if _texture != null and sim != null:
		draw_texture_rect(_texture, Rect2(0, 0, sim.world.width, sim.world.height), false)

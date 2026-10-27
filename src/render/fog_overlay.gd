class_name FogOverlay
extends Node2D
## Full-opacity unexplored pixels; stale terrain for explored but unseen pixels.
## Drawn above terrain and below dots. No access to enemy live unit state.
var sim: Simulation
var faction := 0
@export var cavern_style := true
const CHUNK_SIZE := 64
var _chunks: Array[Sprite2D] = []
var _chunk_pixels: Array[PackedByteArray] = []
var _chunk_floor_pixels: Array[PackedByteArray] = []
var _chunk_floor_textures: Array[ImageTexture] = []
var _chunk_id_textures: Array[ImageTexture] = []
var _chunk_width := 0
var _chunk_height := 0
var _chunk_style := true
var _texture: ImageTexture
var _minimap_texture: ImageTexture
var _minimap_bytes := PackedByteArray()
var _bytes := PackedByteArray()
var _floor_bytes := PackedByteArray()
var _tick := -1
var _last_visible := PackedByteArray()
var _last_explored := PackedByteArray()
var _last_terrain := PackedByteArray()
var _last_floor := PackedByteArray()
var _last_style := true
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
	var current_floor: PackedByteArray = fog.known_excavated[faction]
	var full := _last_visible.size() != current_visible.size() or _last_style != cavern_style
	if not full and _last_visible == current_visible and _last_explored == current_explored and _last_terrain == current_terrain and _last_floor == current_floor: return
	var count := sim.world.cell_count()
	if _bytes.size() != count * 4: _bytes.resize(count * 4)
	if _floor_bytes.size() != count: _floor_bytes.resize(count)
	if _minimap_bytes.size() != count * 4: _minimap_bytes.resize(count * 4)
	var cols := ceili(float(sim.world.width) / CHUNK_SIZE)
	var dirty := {}
	var width := sim.world.width
	# Compare unchanged rows in packed C++ operations before entering pixel loops.
	for y in sim.world.height:
		var begin := y * width
		var end := begin + width
		if not full and current_visible.slice(begin, end) == _last_visible.slice(begin, end) and current_explored.slice(begin, end) == _last_explored.slice(begin, end) and current_terrain.slice(begin, end) == _last_terrain.slice(begin, end) and current_floor.slice(begin, end) == _last_floor.slice(begin, end): continue
		for cell in range(begin, end):
			if not full and current_visible[cell] == _last_visible[cell] and current_explored[cell] == _last_explored[cell] and current_terrain[cell] == _last_terrain[cell] and current_floor[cell] == _last_floor[cell]: continue
			var seen := current_visible[cell] == 1
			var explored_cell := current_explored[cell] == 1
			_floor_bytes[cell] = current_floor[cell] if explored_cell else 0
			var known := int(current_terrain[cell]) if explored_cell else -1
			var offset := cell * 4
			var map_color := UNEXPLORED
			if known >= 0 and known < Materials.COUNT:
				map_color = Materials.COLORS[known]
				if not seen: map_color *= MEMORY_SHADE
			_minimap_bytes[offset] = clampi(int(map_color.r * 255.0), 0, 255)
			_minimap_bytes[offset + 1] = clampi(int(map_color.g * 255.0), 0, 255)
			_minimap_bytes[offset + 2] = clampi(int(map_color.b * 255.0), 0, 255)
			_minimap_bytes[offset + 3] = 255
			dirty[(cell / sim.world.width / CHUNK_SIZE) * cols + (cell % sim.world.width / CHUNK_SIZE)] = true
			if seen:
				_bytes[offset + 3] = 0
				continue
			var color := UNEXPLORED
			if known >= 0 and known < Materials.COUNT:
				color = Materials.COLORS[known]
				if not cavern_style: color *= MEMORY_SHADE
			_bytes[offset] = clampi(int(color.r * 255.0), 0, 255)
			_bytes[offset + 1] = clampi(int(color.g * 255.0), 0, 255)
			_bytes[offset + 2] = clampi(int(color.b * 255.0), 0, 255)
			_bytes[offset + 3] = 255
	_last_visible = current_visible.duplicate()
	_last_explored = current_explored.duplicate()
	_last_terrain = current_terrain.duplicate()
	_last_floor = current_floor.duplicate()
	_last_style = cavern_style
	_update_chunks(dirty)
	var minimap_image := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _minimap_bytes)
	if _minimap_texture == null: _minimap_texture = ImageTexture.create_from_image(minimap_image)
	else: _minimap_texture.update(minimap_image)
	queue_redraw()

func _update_chunks(dirty: Dictionary) -> void:
	var w := sim.world.width
	var h := sim.world.height
	var cols := ceili(float(w) / float(CHUNK_SIZE))
	var rows := ceili(float(h) / float(CHUNK_SIZE))
	if cols != _chunk_width or rows != _chunk_height or _chunk_style != cavern_style:
		for sprite in _chunks: sprite.queue_free()
		_chunks.clear()
		_chunk_pixels.clear()
		_chunk_floor_pixels.clear()
		_chunk_floor_textures.clear()
		_chunk_id_textures.clear()
		_chunk_width = cols
		_chunk_height = rows
		_chunk_style = cavern_style
		for cy in rows:
			for cx in cols:
				var sprite := Sprite2D.new()
				sprite.centered = false
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position = Vector2(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
				var effect := ShaderMaterial.new()
				effect.shader = WorldRenderer.TERRAIN_SHADER
				effect.set_shader_parameter("stone_floor", WorldRenderer.FLOOR_TEXTURE)
				effect.set_shader_parameter("ore_tiles", WorldRenderer.ORE_TEXTURE)
				effect.set_shader_parameter("ambient_multiplier", MEMORY_SHADE)
				effect.set_shader_parameter("vignette_strength", 0.0)
				effect.set_shader_parameter("cell_origin", sprite.position)
				if cavern_style: sprite.material = effect
				add_child(sprite)
				_chunks.append(sprite)
				_chunk_pixels.append(PackedByteArray())
				_chunk_floor_pixels.append(PackedByteArray())
				_chunk_floor_textures.append(null)
				_chunk_id_textures.append(null)
	for index in dirty:
		var cx: int = index % cols
		var cy: int = index / cols
		var cw := mini(CHUNK_SIZE, w - cx * CHUNK_SIZE)
		var ch := mini(CHUNK_SIZE, h - cy * CHUNK_SIZE)
		var pixels := PackedByteArray()
		var floor_pixels := PackedByteArray()
		var id_pixels := PackedByteArray()
		for y in ch:
			var start := ((cy * CHUNK_SIZE + y) * w + cx * CHUNK_SIZE) * 4
			pixels.append_array(_bytes.slice(start, start + cw * 4))
			floor_pixels.append_array(_floor_bytes.slice(start / 4, start / 4 + cw))
			id_pixels.append_array(_last_terrain.slice(start / 4, start / 4 + cw))
		# Building foundations use remembered sites, never hidden live construction.
		for row in sim.fog.known_sites[faction].values():
			if row.destroyed: continue
			var area: Rect2i = row.rect.intersection(Rect2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE, cw, ch))
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					var cell := (y - cy * CHUNK_SIZE) * cw + x - cx * CHUNK_SIZE
					if id_pixels[cell] == Materials.INDESTRUCTIBLE: id_pixels[cell] = 254
		if pixels == _chunk_pixels[index] and floor_pixels == _chunk_floor_pixels[index]: continue
		_chunk_pixels[index] = pixels
		_chunk_floor_pixels[index] = floor_pixels
		var img := Image.create_from_data(cw, ch, false, Image.FORMAT_RGBA8, pixels)
		var sprite := _chunks[index]
		if sprite.texture == null: sprite.texture = ImageTexture.create_from_image(img)
		else: (sprite.texture as ImageTexture).update(img)
		var floor_image := Image.create_from_data(cw, ch, false, Image.FORMAT_R8, floor_pixels)
		if _chunk_floor_textures[index] == null: _chunk_floor_textures[index] = ImageTexture.create_from_image(floor_image)
		else: _chunk_floor_textures[index].update(floor_image)
		if sprite.material is ShaderMaterial:
			sprite.material.set_shader_parameter("floor_history", _chunk_floor_textures[index])
			sprite.material.set_shader_parameter("floor_history_enabled", true)
			var ids := Image.create_from_data(cw, ch, false, Image.FORMAT_R8, id_pixels)
			if _chunk_id_textures[index] == null: _chunk_id_textures[index] = ImageTexture.create_from_image(ids)
			else: _chunk_id_textures[index].update(ids)
			sprite.material.set_shader_parameter("material_ids", _chunk_id_textures[index])
			sprite.material.set_shader_parameter("material_ids_enabled", true)

func minimap_texture() -> Texture2D:
	return _minimap_texture



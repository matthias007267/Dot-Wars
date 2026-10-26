class_name FogOverlay
extends Node2D
## Full-opacity unexplored pixels; stale terrain for explored but unseen pixels.
## Drawn above terrain and below dots. No access to enemy live unit state.
var sim: Simulation
var faction := 0
const CHUNK_SIZE := 64
var _chunks: Array[Sprite2D] = []
var _chunk_pixels: Array[PackedByteArray] = []
var _chunk_width := 0
var _chunk_height := 0
var _texture: ImageTexture
var _minimap_texture: ImageTexture
var _minimap_bytes := PackedByteArray()
var _bytes := PackedByteArray()
var _tick := -1
var _last_visible := PackedByteArray()
var _last_explored := PackedByteArray()
var _last_terrain := PackedByteArray()
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
	_update_chunks()
	var minimap_image := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, _minimap_bytes)
	if _minimap_texture == null: _minimap_texture = ImageTexture.create_from_image(minimap_image)
	else: _minimap_texture.update(minimap_image)
	queue_redraw()

func _update_chunks() -> void:
	var w := sim.world.width
	var h := sim.world.height
	var cols := ceili(float(w) / float(CHUNK_SIZE))
	var rows := ceili(float(h) / float(CHUNK_SIZE))
	if cols != _chunk_width or rows != _chunk_height:
		for sprite in _chunks: sprite.queue_free()
		_chunks.clear()
		_chunk_pixels.clear()
		_chunk_width = cols
		_chunk_height = rows
		for cy in rows:
			for cx in cols:
				var sprite := Sprite2D.new()
				sprite.centered = false
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.position = Vector2(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
				add_child(sprite)
				_chunks.append(sprite)
				_chunk_pixels.append(PackedByteArray())
	for cy in rows:
		for cx in cols:
			var cw := mini(CHUNK_SIZE, w - cx * CHUNK_SIZE)
			var ch := mini(CHUNK_SIZE, h - cy * CHUNK_SIZE)
			var pixels := PackedByteArray()
			pixels.resize(cw * ch * 4)
			for y in ch:
				for x in cw:
					var src := ((cy * CHUNK_SIZE + y) * w + cx * CHUNK_SIZE + x) * 4
					var dst := (y * cw + x) * 4
					for channel in 4: pixels[dst + channel] = _bytes[src + channel]
			var index := cy * cols + cx
			if pixels == _chunk_pixels[index]: continue
			_chunk_pixels[index] = pixels
			var img := Image.create_from_data(cw, ch, false, Image.FORMAT_RGBA8, pixels)
			var sprite := _chunks[index]
			if sprite.texture == null: sprite.texture = ImageTexture.create_from_image(img)
			else: (sprite.texture as ImageTexture).update(img)

func minimap_texture() -> Texture2D:
	return _minimap_texture



class_name WorldRenderer
extends Node2D
## Eine Textur für die ganze Welt, ein Pixel pro Zelle. Geändert wird nur der betroffene Chunk.
## Es gibt keine Node pro Zelle.

const GRID_MIN_ZOOM := 8.0
const PIT_GLOW_MIN_ZOOM := 2.5
const TERRAIN_SHADER := preload("res://src/render/shaders/terrain.gdshader")

## Reine Darstellungsoptionen, ohne Einfluss auf die Welt oder das HUD.
@export var world_fx_enabled := true
@export_range(0.0, 1.0, 0.05) var terrain_detail := 0.85
@export_range(0.0, 1.0, 0.05) var tunnel_depth := 0.80
@export_range(0.0, 0.35, 0.01) var vignette_strength := 0.15

var world: WorldState
var camera: Camera2D
var show_grid := false
var show_chunks := false
## 1 färbt eine leere Zelle als Kernfläche. Leer lässt den Tunnel unverändert.
var core_mask := PackedByteArray()
## 1 ist eine Quelle, 2 ein Veredler. Die Zelle bleibt leer.
var building_mask := PackedByteArray()
## Non-blocking overlay; no terrain texture rebuild for conduit placement.
var energy_network: EnergyNetwork
var _network_revision := -1
## Fraktionskerne, Hügel und Reliquien. Leer lässt die Einzelspieler-Ansicht unverändert.
var marker_cores := PackedInt32Array()
var marker_rgb := PackedByteArray()
var marker_hill := -1
var marker_relics := PackedInt32Array()
var marker_relic_rgb := PackedByteArray()
var _marker_stamp := 0
const HILL_COLOR := Color8(0xE6, 0xC3, 0x5C)
const RELIC_COLOR := Color8(0xD7, 0xC4, 0xFF)

var _bytes := PackedByteArray()
var _image: Image
var _texture: ImageTexture
var _surface: Sprite2D
var _last_glow_frame := -1


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	# Nur dieser eine Sprite erhaelt den Welt-Shader. Eigene Draw-Befehle
	# (Kernlicht, Raster) liegen darueber; die Minimap nutzt die Rohtextur.
	_surface = Sprite2D.new()
	_surface.centered = false
	_surface.texture_filter = TEXTURE_FILTER_NEAREST
	_surface.show_behind_parent = true
	if world_fx_enabled:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = TERRAIN_SHADER
		shader_material.set_shader_parameter("detail_strength", terrain_detail)
		shader_material.set_shader_parameter("edge_strength", tunnel_depth)
		shader_material.set_shader_parameter("vignette_strength", vignette_strength)
		_surface.material = shader_material
	add_child(_surface)
	_bytes.resize(world.cell_count() * 4)
	_paint_everything()
	_upload()
	world.consume_dirty_chunks()
	queue_redraw()


func _process(_delta: float) -> void:
	if energy_network != null and _network_revision != energy_network.revision:
		_network_revision = energy_network.revision
		queue_redraw()
	var dirty := world.consume_dirty_chunks()
	if not dirty.is_empty():
		var palette := palette_bytes()
		for chunk in dirty:
			paint_rect(
				_bytes, world, palette, world.chunk_rect(chunk), _pit_index(), core_mask, building_mask,
				marker_cores, marker_rgb, marker_hill, marker_relics, marker_relic_rgb
			)
		_upload()
		queue_redraw()
	# Kernpuls mit maximal etwa 15 Updates/Sekunde, ohne Welttextur-Upload.
	if world_fx_enabled and camera != null and camera.zoom.x >= PIT_GLOW_MIN_ZOOM:
		var glow_frame := int(Time.get_ticks_msec() / 66)
		if glow_frame != _last_glow_frame:
			_last_glow_frame = glow_frame
			queue_redraw()


func _draw_energy_network() -> void:
	if energy_network == null: return
	for i in energy_network.cells.size():
		var cell: int = energy_network.cells[i]
		var x := cell % energy_network.width
		var y := cell / energy_network.width
		var color := Color8(0x43, 0xBD, 0xDB, 0xC8) if energy_network.owners[i] == 0 else Color8(0xFF, 0x9C, 0x67, 0xC8)
		draw_rect(Rect2(Vector2(x, y), Vector2.ONE), color)

func _draw() -> void:
	if _texture == null:
		return
	_draw_pit_glow()
	_draw_energy_network()
	if show_chunks:
		_draw_chunks()
	if show_grid:
		_draw_grid()


## Gibt der Minimap die bereits vorhandene, aktualisierte Welttextur.
func current_texture() -> Texture2D:
	return _texture


static func palette_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(Materials.COUNT * 4)
	for material in Materials.COUNT:
		var color := Materials.COLORS[material]
		var offset := material * 4
		bytes[offset] = _channel(color.r)
		bytes[offset + 1] = _channel(color.g)
		bytes[offset + 2] = _channel(color.b)
		bytes[offset + 3] = 255
	return bytes


static func paint_all(
	bytes: PackedByteArray,
	world: WorldState,
	palette: PackedByteArray,
	pit: int = -1,
	mask: PackedByteArray = PackedByteArray(),
	buildings: PackedByteArray = PackedByteArray(),
	cores: PackedInt32Array = PackedInt32Array(),
	core_rgb: PackedByteArray = PackedByteArray(),
	hill: int = -1,
	relics: PackedInt32Array = PackedInt32Array(),
	relic_rgb: PackedByteArray = PackedByteArray(),
) -> void:
	var cells := world.cells
	for idx in cells.size():
		_write_cell(bytes, palette, world, idx, cells[idx], pit, mask, buildings, cores, core_rgb, hill, relics, relic_rgb)


static func paint_rect(
	bytes: PackedByteArray,
	world: WorldState,
	palette: PackedByteArray,
	rect: Rect2i,
	pit: int = -1,
	mask: PackedByteArray = PackedByteArray(),
	buildings: PackedByteArray = PackedByteArray(),
	cores: PackedInt32Array = PackedInt32Array(),
	core_rgb: PackedByteArray = PackedByteArray(),
	hill: int = -1,
	relics: PackedInt32Array = PackedInt32Array(),
	relic_rgb: PackedByteArray = PackedByteArray(),
) -> void:
	var cells := world.cells
	var width := world.width
	for y in range(rect.position.y, rect.end.y):
		var row := y * width
		for x in range(rect.position.x, rect.end.x):
			var idx := row + x
			_write_cell(
				bytes, palette, world, idx, cells[idx], pit, mask, buildings, cores, core_rgb, hill, relics, relic_rgb
			)


## Zeichnet die Kernfläche neu. Der Aufruf kommt nach einem Kauf oder einem geladenen Stand.
func set_core_mask(mask: PackedByteArray) -> void:
	core_mask = mask
	if _bytes.is_empty() or world == null:
		return
	_paint_everything()
	_upload()
	queue_redraw()


func set_buildings(mask: PackedByteArray) -> void:
	building_mask = mask
	if _bytes.is_empty() or world == null:
		return
	_paint_everything()
	_upload()
	queue_redraw()


## Zeichnet Kerne, Hügel und Reliquien neu, wenn sich ein Besitzer ändert.
func sync_match(sim: Simulation) -> void:
	if sim.config.mode != SimConfig.MODE_MATCH or sim.rules.cores.is_empty():
		return
	var stamp := hash([sim.rules.relic_owner, _site_marker_state(sim), sim.fog.known_sites[0], sim.fog.visible[0]]) if sim._match_live() else hash([sim.rules.relic_owner, _site_marker_state(sim)])
	if not marker_cores.is_empty() and stamp == _marker_stamp:
		return
	_marker_stamp = stamp
	marker_cores = PackedInt32Array()
	marker_rgb = PackedByteArray()
	var sites: Array = sim.fog.remembered_sites(0) if sim._match_live() else sim.construction.sites.records
	for row in sites:
		if row.destroyed or not row.ready: continue
		var rect: Rect2i = row.rect
		var center := (rect.position.y + rect.size.y / 2) * world.width + rect.position.x + rect.size.x / 2
		marker_cores.append(center)
		_append_rgb(marker_rgb, MatchRules.FACTION_COLORS[row.owner])
	marker_hill = sim.rules.hill_cell if not sim._match_live() or sim.fog.is_explored(0, sim.rules.hill_cell) else -1
	marker_relics = PackedInt32Array()
	marker_relic_rgb = PackedByteArray()
	for index in sim.rules.relic_cell.size():
		var relic_cell := int(sim.rules.relic_cell[index])
		if sim._match_live() and not sim.fog.is_visible(0, relic_cell): continue
		marker_relics.append(relic_cell)
		var owner := int(sim.rules.relic_owner[index])
		var color := RELIC_COLOR
		if owner >= 0 and owner < MatchRules.FACTION_COLORS.size():
			color = MatchRules.FACTION_COLORS[owner]
		_append_rgb(marker_relic_rgb, color)
	if _bytes.is_empty() or world == null:
		return
	_paint_everything()
	_upload()
	queue_redraw()


func _paint_everything() -> void:
	paint_all(
		_bytes, world, palette_bytes(), _pit_index(), core_mask, building_mask,
		marker_cores, marker_rgb, marker_hill, marker_relics, marker_relic_rgb
	)


func _append_rgb(bytes: PackedByteArray, color: Color) -> void:
	bytes.append(_channel(color.r))
	bytes.append(_channel(color.g))
	bytes.append(_channel(color.b))


func _upload() -> void:
	_image = Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, _bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	if _surface != null:
		_surface.texture = _texture


## Die Kerne aller Fraktionen leuchten ohne zusaetzliche Nodes oder Lichtquellen.
## Im Fernzoom bleibt die Basismarkierung exakt ein Weltpixel.
func _draw_pit_glow() -> void:
	if not world_fx_enabled or camera == null or camera.zoom.x < PIT_GLOW_MIN_ZOOM:
		return
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.0028)
	if marker_cores.is_empty():
		_glow_at(_pit_index(), Materials.PIT_COLOR, pulse)
		return
	for index in marker_cores.size():
		var at := index * 3
		if at + 2 >= marker_rgb.size():
			continue
		var color := Color8(marker_rgb[at], marker_rgb[at + 1], marker_rgb[at + 2])
		_glow_at(marker_cores[index], color, pulse)


func _glow_at(cell: int, color: Color, pulse: float) -> void:
	if cell < 0 or cell >= world.cell_count():
		return
	var center := Vector2(float(cell % world.width) + 0.5, float(cell / world.width) + 0.5)
	var radius := 3.0 + 0.3 * pulse
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.045 + 0.025 * pulse))
	draw_circle(center, 1.9 + 0.2 * pulse, Color(color.r, color.g, color.b, 0.095 + 0.045 * pulse))
	draw_arc(center, 2.1 + 0.25 * pulse, 0.0, TAU, 28,
		Color(color.r, color.g, color.b, 0.30 + 0.15 * pulse), 0.14, true)


func _draw_grid() -> void:
	if camera == null or camera.zoom.x < GRID_MIN_ZOOM:
		return
	var area := _visible_world()
	if not area.has_area():
		return
	var color := Color(1, 1, 1, 0.22)
	var x0 := floori(area.position.x)
	var y0 := floori(area.position.y)
	var x1 := ceili(area.end.x)
	var y1 := ceili(area.end.y)
	var width := 1.0 / camera.zoom.x
	for x in range(x0, x1 + 1):
		draw_line(Vector2(x, y0), Vector2(x, y1), color, width)
	for y in range(y0, y1 + 1):
		draw_line(Vector2(x0, y), Vector2(x1, y), color, width)


func _draw_chunks() -> void:
	var area := _visible_world()
	if not area.has_area():
		return
	var color := Color(0.95, 0.78, 0.25, 0.7)
	var step := world.chunk_size
	var width := 1.5 / maxf(camera.zoom.x if camera != null else 1.0, 0.001)
	var x0 := int(area.position.x / step) * step
	var y0 := int(area.position.y / step) * step
	var x := x0
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), color, width)
		x += step
	var y := y0
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, width)
		y += step


func _visible_world() -> Rect2:
	var viewport := get_viewport_rect().size
	var zoom := camera.zoom.x if camera != null else 1.0
	var center := camera.position if camera != null else Vector2(world.width, world.height) * 0.5
	var visible := WorldCoordinates.visible_world_rect(center, zoom, viewport)
	return visible.intersection(Rect2(0, 0, world.width, world.height))


func _pit_index() -> int:
	if not marker_cores.is_empty():
		return -1
	var pit := WorldGenerator.sacrifice_cell(world)
	return world.index(pit.x, pit.y)


static func _write_cell(
	bytes: PackedByteArray,
	palette: PackedByteArray,
	world: WorldState,
	idx: int,
	material: int,
	pit: int = -1,
	mask: PackedByteArray = PackedByteArray(),
	buildings: PackedByteArray = PackedByteArray(),
	cores: PackedInt32Array = PackedInt32Array(),
	core_rgb: PackedByteArray = PackedByteArray(),
	hill: int = -1,
	relics: PackedInt32Array = PackedInt32Array(),
	relic_rgb: PackedByteArray = PackedByteArray(),
) -> void:
	var dst := idx * 4
	if idx == pit:
		var pit_color := Materials.PIT_COLOR
		bytes[dst] = _channel(pit_color.r)
		bytes[dst + 1] = _channel(pit_color.g)
		bytes[dst + 2] = _channel(pit_color.b)
		bytes[dst + 3] = 255
		return
	if material == Materials.EMPTY and idx < mask.size() and mask[idx] == 1:
		var plaza := Materials.PLAZA_COLOR
		bytes[dst] = _channel(plaza.r)
		bytes[dst + 1] = _channel(plaza.g)
		bytes[dst + 2] = _channel(plaza.b)
		bytes[dst + 3] = 255
		return
	if material == Materials.EMPTY and idx < buildings.size() and buildings[idx] != 0:
		var mark := Materials.SOURCE_COLOR if buildings[idx] == Buildings.KIND_SOURCE else Materials.REFINERY_COLOR
		bytes[dst] = _channel(mark.r)
		bytes[dst + 1] = _channel(mark.g)
		bytes[dst + 2] = _channel(mark.b)
		bytes[dst + 3] = 255
		return
	if material == Materials.INDESTRUCTIBLE and _paint_indexed(bytes, dst, idx, cores, core_rgb):
		return
	if material == Materials.EMPTY and idx == hill:
		_paint_rgb(bytes, dst, HILL_COLOR)
		return
	if material == Materials.EMPTY and _paint_indexed(bytes, dst, idx, relics, relic_rgb):
		return
	var src := material * 4
	var red := int(palette[src])
	var green := int(palette[src + 1])
	var blue := int(palette[src + 2])
	# Dezente, reproduzierbare Tonabstufungen machen Flächen lebendig,
	# ohne Umrandungen, Texturassets oder zeitabhängiges Rauschen.
	# Die Material-ID und die Spiellogik bleiben unverändert.
	if Materials.is_mineable(material):
		var offset := material_variation(idx, material)
		red = clampi(red + offset, 0, 255)
		green = clampi(green + offset, 0, 255)
		blue = clampi(blue + offset, 0, 255)
	var dug := world.progress[idx]
	if dug > 0 and Materials.is_mineable(material):
		var durability := Materials.durability(material, SimConfig.TICKS_PER_SECOND)
		var shade := 0.0 if durability <= 0 else clampf(float(dug) / float(durability), 0.0, 1.0)
		var empty := Materials.EMPTY * 4
		red = int(round(lerpf(red, palette[empty], shade)))
		green = int(round(lerpf(green, palette[empty + 1], shade)))
		blue = int(round(lerpf(blue, palette[empty + 2], shade)))
	bytes[dst] = red
	bytes[dst + 1] = green
	bytes[dst + 2] = blue
	bytes[dst + 3] = 255


## Geringe Helligkeitsvarianz je Zelle (-6 bis +6), unabhängig vom Seed.
static func material_variation(index: int, material: int) -> int:
	var hashed := (index * 31 + material * 127) & 0x7FFFFFFF
	hashed = (hashed ^ (hashed >> 7) ^ (hashed >> 13)) & 0x7FFFFFFF
	return (hashed % 5 - 2) * 3


static func _channel(value: float) -> int:
	return clampi(int(round(value * 255.0)), 0, 255)


static func _paint_rgb(bytes: PackedByteArray, dst: int, color: Color) -> void:
	bytes[dst] = _channel(color.r)
	bytes[dst + 1] = _channel(color.g)
	bytes[dst + 2] = _channel(color.b)
	bytes[dst + 3] = 255


static func _paint_indexed(
	bytes: PackedByteArray, dst: int, idx: int, cells: PackedInt32Array, rgb: PackedByteArray
) -> bool:
	for index in cells.size():
		if cells[index] != idx:
			continue
		var at := index * 3
		if at + 2 >= rgb.size():
			return false
		bytes[dst] = rgb[at]
		bytes[dst + 1] = rgb[at + 1]
		bytes[dst + 2] = rgb[at + 2]
		bytes[dst + 3] = 255
		return true
	return false


func _site_marker_state(sim: Simulation) -> Array:
	var state := []
	for row in sim.construction.sites.records: state.append([row.id, row.ready, row.destroyed])
	return state

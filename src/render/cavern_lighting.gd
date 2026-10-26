class_name CavernLighting
extends RefCounted
## Low resolution CPU light field: max 64 sources, no light/Node per unit.
const SCALE := 2
const MAX_SOURCES := 64
var texture: ImageTexture
var width := 0
var height := 0
var _stamp := -1

static func sources(sim: Simulation) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in sim.construction.sites.records:
		if row.destroyed: continue
		var cell := sim.construction.center(row.id)
		if not site_visible(sim, row): continue
		var tint := TacticalArt.tint(row.owner)
		if row.kind == 3 and not sim.research.is_powered(row.id, sim.tick_count): continue
		# Research illumination is emitted only on an actual consumption tick.
		result.append({"cell": cell, "radius": 9.0 if row.kind == 0 else 5.0, "tint": tint, "strength": 0.95 if row.ready else 0.25})
		if result.size() == MAX_SOURCES: return result
	for shipment in sim.research.shipments:
		if sim._match_live() and shipment.faction != 0 and not sim.fog.is_visible(0, shipment.cell): continue
		result.append({"cell": shipment.cell, "radius": 3.5, "tint": TacticalArt.tint(shipment.faction), "strength": 0.5})
		if result.size() == MAX_SOURCES: break
	return result

static func site_visible(sim: Simulation, row: Dictionary) -> bool:
	if not sim._match_live() or row.owner == 0: return true
	var rect: Rect2i = row.rect
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if sim.fog.is_visible(0, y * sim.world.width + x): return true
	return false

func update(sim: Simulation) -> Texture2D:
	var visible_sources := sources(sim)
	var stamp := hash(visible_sources)
	if stamp == _stamp and texture != null: return texture
	_stamp = stamp
	var stride := maxi(SCALE, ceili(float(maxi(sim.world.width, sim.world.height)) / 512.0))
	width = ceili(float(sim.world.width) / stride)
	height = ceili(float(sim.world.height) / stride)
	var bytes := PackedByteArray()
	bytes.resize(width * height * 3)
	for source in visible_sources:
		var center := Vector2(source.cell % sim.world.width, source.cell / sim.world.width) + Vector2(0.5, 0.5)
		var radius: float = source.radius
		for y in range(maxi(0, floori((center.y - radius) / stride)), mini(height, ceili((center.y + radius) / stride))):
			for x in range(maxi(0, floori((center.x - radius) / stride)), mini(width, ceili((center.x + radius) / stride))):
				var distance := (Vector2(x, y) * stride + Vector2.ONE * stride * 0.5).distance_to(center) / radius
				var strength: float = pow(maxf(0.0, 1.0 - distance), 1.6) * source.strength
				var offset := (y * width + x) * 3
				for channel in 3:
					bytes[offset + channel] = mini(255, bytes[offset + channel] + int(source.tint[channel] * strength * 255.0))
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGB8, bytes)
	if texture == null: texture = ImageTexture.create_from_image(image)
	else: texture.update(image)
	return texture

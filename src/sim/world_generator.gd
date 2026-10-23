class_name WorldGenerator
extends RefCounted
## Reproduzierbare Weltgenerierung mit reiner Ganzzahl-Wertnoise (unabhängig von Engine-Versionen).
##
## Die Welt ist ein zusammenhängender Materialkörper. In der Mitte liegt ein leerer Starttunnel.
## Eine Zelle neben dem Tunnel ist für das spätere Energiekern reserviert und unzerstörbar.
## Ein kleines unzerstörbares Feld daneben macht diesen Materialtyp in der Ansicht sichtbar.

const LARGE_SCALE := 32
const SMALL_SCALE := 11


static func generate(config: SimConfig) -> WorldState:
	var size := config.world_size
	var world := WorldState.new(size, size, config.chunk_size, Materials.SOFT)
	var noise := _noise_field(size, config.world_seed)
	var thresholds := _thresholds(noise, config.soft_percent, config.soft_percent + config.medium_percent)
	for idx in size * size:
		var value := noise[idx]
		var material := Materials.HARD
		if value < thresholds[0]:
			material = Materials.SOFT
		elif value < thresholds[1]:
			material = Materials.MEDIUM
		world.cells[idx] = material
	# Mehrspieler hat Basen auf dem Ring. Der alte Mittelkreuz-Tunnel und das Opferloch bleiben Einzelspieler.
	if config.mode != SimConfig.MODE_MATCH:
		carve_start_tunnel(world, config.tunnel_arm_length)
		_place_unbreakable(world, config.tunnel_arm_length)
	# Der Rausch schreibt das Array direkt. Die Flächenliste liest danach den fertigen Stand.
	world.rebuild_faces()
	return world


## Zelle des späteren Opferlochs: orthogonal neben der Tunnelmitte, nicht auf dem Tunnel.
static func sacrifice_cell(world: WorldState) -> Vector2i:
	return Vector2i(world.width / 2 + 1, world.height / 2 + 1)


## Kreuzförmiger Starttunnel um den Weltmittelpunkt.
static func carve_start_tunnel(world: WorldState, arm: int) -> void:
	var cx := world.width / 2
	var cy := world.height / 2
	world.carve_rect(Rect2i(cx - arm, cy, arm * 2 + 1, 1))
	world.carve_rect(Rect2i(cx, cy - arm, 1, arm * 2 + 1))


static func _place_unbreakable(world: WorldState, arm: int) -> void:
	var pit := sacrifice_cell(world)
	var pit_idx := world.index(pit.x, pit.y)
	if world.cells[pit_idx] != Materials.EMPTY:
		world.set_material(pit_idx, Materials.INDESTRUCTIBLE)
	var origin_x := clampi(world.width / 2 - arm - 6, 1, world.width - 5)
	var origin_y := clampi(world.height / 2 - arm - 6, 1, world.height - 5)
	for y in range(origin_y, origin_y + 4):
		for x in range(origin_x, origin_x + 4):
			var idx := world.index(x, y)
			if world.cells[idx] == Materials.EMPTY or idx == pit_idx:
				continue
			world.set_material(idx, Materials.INDESTRUCTIBLE)


## Quantile der sortierten Rauschwerte, damit die Materialanteile exakt den Vorgaben entsprechen.
static func _thresholds(noise: PackedInt32Array, low_percent: int, high_percent: int) -> PackedInt32Array:
	var sorted := noise.duplicate()
	sorted.sort()
	var n := sorted.size()
	return PackedInt32Array([
		sorted[clampi(n * low_percent / 100, 0, n - 1)] if low_percent > 0 else -1,
		sorted[clampi(n * high_percent / 100, 0, n - 1)] if high_percent > 0 else -1,
	])


static func _noise_field(size: int, world_seed: int) -> PackedInt32Array:
	var field := PackedInt32Array()
	field.resize(size * size)
	for y in size:
		for x in size:
			var large := _value_noise(x, y, LARGE_SCALE, world_seed)
			var small := _value_noise(x, y, SMALL_SCALE, world_seed + 7919)
			field[y * size + x] = (large * 13 + small * 7) / 20
	return field


static func _lattice(gx: int, gy: int, world_seed: int) -> int:
	var h := (gx * 374761393 + gy * 668265263 + world_seed * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 0xFFFF


## Bilinear geglättete Wertnoise, ausschließlich Ganzzahlarithmetik. Ergebnis 0..65535.
static func _value_noise(x: int, y: int, scale: int, world_seed: int) -> int:
	var gx := x / scale
	var gy := y / scale
	var tx := _smooth(x % scale, scale)
	var ty := _smooth(y % scale, scale)
	var full := scale * scale * scale
	var v00 := _lattice(gx, gy, world_seed)
	var v10 := _lattice(gx + 1, gy, world_seed)
	var v01 := _lattice(gx, gy + 1, world_seed)
	var v11 := _lattice(gx + 1, gy + 1, world_seed)
	var top := (v00 * (full - tx) + v10 * tx) / full
	var bottom := (v01 * (full - tx) + v11 * tx) / full
	return (top * (full - ty) + bottom * ty) / full


## Smoothstep 3t² − 2t³ in Einheiten von scale³.
static func _smooth(offset: int, scale: int) -> int:
	return offset * offset * (3 * scale - 2 * offset)

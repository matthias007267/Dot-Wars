class_name WorldGenerator
extends RefCounted
## Reproduzierbare Weltgenerierung mit reiner Ganzzahl-Wertnoise (unabhängig von Engine-Versionen).
##
## Die Welt ist vollständig mit Material gefüllt und damit zusammenhängend; lediglich der
## Starttunnel in der Mitte ist leer.

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
	carve_start_tunnel(world, config.tunnel_arm_length)
	return world


## Kreuzförmiger Starttunnel um den Weltmittelpunkt.
static func carve_start_tunnel(world: WorldState, arm: int) -> void:
	var cx := world.width / 2
	var cy := world.height / 2
	world.carve_rect(Rect2i(cx - arm, cy, arm * 2 + 1, 1))
	world.carve_rect(Rect2i(cx, cy - arm, 1, arm * 2 + 1))


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

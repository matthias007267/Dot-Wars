class_name CoreZone
extends RefCounted
## Fläche um den Energiekern. Arbeiter betreten sie nicht, Energie wird dort gutgeschrieben.
## Der Kern selbst bleibt die unzerstörbare Zelle und gehört nicht zur begehbaren Fläche.


## Zellen, die bei diesem Radius leer werden, und die Maske der reservierten Fläche.
## Maske 1 verbietet Arbeiter. Der Außenring bleibt begehbar, damit der Tunnel verbunden bleibt.
static func plan(world: WorldState, radius: int) -> Dictionary:
	var mask := PackedByteArray()
	mask.resize(world.cell_count())
	mask.fill(0)
	var carve := PackedInt32Array()
	if radius <= 0:
		return {"mask": mask, "carve": carve}
	var pit := WorldGenerator.sacrifice_cell(world)
	var pit_idx := world.index(pit.x, pit.y)
	var limit := radius + 1
	var y0 := maxi(pit.y - limit, 0)
	var y1 := mini(pit.y + limit, world.height - 1)
	var x0 := maxi(pit.x - limit, 0)
	var x1 := mini(pit.x + limit, world.width - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dist := maxi(absi(x - pit.x), absi(y - pit.y))
			if dist > limit:
				continue
			var idx := world.index(x, y)
			if idx == pit_idx:
				continue
			if Materials.is_mineable(world.cells[idx]):
				carve.append(idx)
			var empty := world.cells[idx] == Materials.EMPTY or Materials.is_mineable(world.cells[idx])
			if dist <= radius and empty:
				mask[idx] = 1
	return {"mask": mask, "carve": carve}

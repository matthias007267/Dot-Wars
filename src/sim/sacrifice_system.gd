class_name SacrificeSystem
extends RefCounted
## Liefert Einheiten am Opferloch ab. Eine Einheit wird genau einmal entfernt.


static func delivery_cells(world: WorldState, pit: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var width := world.width
	var x := pit % width
	var candidates: Array[int] = []
	if pit >= width:
		candidates.append(pit - width)
	if x < width - 1:
		candidates.append(pit + 1)
	if pit + width < world.cell_count():
		candidates.append(pit + width)
	if x > 0:
		candidates.append(pit - 1)
	for cell in candidates:
		if world.cells[cell] == Materials.EMPTY:
			result.append(cell)
	return result


## Entfernt abliefernde Einheiten. Gibt die geopferte Masse zurück.
## Die letzte Masse des Durchlaufs bleibt stehen, der Auftrag der Gruppe wird dann gelöscht.
static func step(
	workers: WorkerStore,
	orders: PackedByteArray,
	delivery: PackedInt32Array,
	total_mass: int,
) -> int:
	if delivery.is_empty():
		return 0
	var gate := {}
	for cell in delivery:
		gate[cell] = true
	var gained := 0
	var id := 0
	while id < workers.count:
		var group_id := int(workers.group[id])
		if group_id >= orders.size() or orders[group_id] == 0 or not gate.has(workers.cell[id]):
			id += 1
			continue
		var unit_mass := workers.mass[id]
		if total_mass - gained - unit_mass < 1:
			orders[group_id] = 0
			id += 1
			continue
		gained += unit_mass
		var replaced := workers.remove_swap(id)
		if replaced < 0:
			break
	return gained

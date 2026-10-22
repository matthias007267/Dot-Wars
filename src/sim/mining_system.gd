class_name MiningSystem
extends RefCounted
## Zielwahl und Abbaufortschritt. Datenorientiert und zustandslos (GDExtension-tauglich).
##
## Der Fortschritt liegt an der Zelle. Eine Zelle wird genau einmal abgeschlossen: Sobald sie leer
## ist, tragen weitere Arbeiter im selben Tick nichts mehr bei.


## Sucht eine feste, markierte Nachbarzelle (Reihenfolge N, O, S, W). Setzt bei Erfolg Ziel und Zustand.
static func acquire_target(workers: WorkerStore, world: WorldState, areas: DigAreas, id: int) -> bool:
	var c := workers.cell[id]
	var mask: PackedByteArray = areas.masks[workers.group[id]]
	var cells := world.cells
	var w := world.width
	var x := c % w
	var found := WorkerStore.NO_TARGET
	if c >= w and _can_mine(cells, mask, c - w):
		found = c - w
	elif x < w - 1 and _can_mine(cells, mask, c + 1):
		found = c + 1
	elif c < world.cell_count() - w and _can_mine(cells, mask, c + w):
		found = c + w
	elif x > 0 and _can_mine(cells, mask, c - 1):
		found = c - 1
	if found == WorkerStore.NO_TARGET:
		return false
	workers.target[id] = found
	workers.state[id] = WorkerStore.STATE_MINING
	return true


## Verarbeitet alle abbauenden Arbeiter in ID-Reihenfolge. Gibt die Zahl abgeschlossener Zellen zurück
## und trägt deren Positionen in `spawner` ein.
static func step(
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	spawner: SpawnSystem,
	work_per_hardness: int,
	dig_power: int,
) -> int:
	var completed := 0
	var cells := world.cells
	var progress := world.progress
	var state := workers.state
	var target := workers.target
	for id in workers.count:
		if state[id] != WorkerStore.STATE_MINING:
			continue
		var cell := target[id]
		var mask: PackedByteArray = areas.masks[workers.group[id]]
		if not Materials.is_mineable(cells[cell]) or mask[cell] == 0:
			if not acquire_target(workers, world, areas, id):
				state[id] = WorkerStore.STATE_WAITING
			continue
		var total := progress[cell] + dig_power
		if total >= Materials.durability(cells[cell], work_per_hardness):
			if world.mine_cell(cell):
				spawner.enqueue(cell)
				completed += 1
		else:
			progress[cell] = total
	return completed


static func _can_mine(cells: PackedByteArray, mask: PackedByteArray, idx: int) -> bool:
	return Materials.is_mineable(cells[idx]) and mask[idx] == 1

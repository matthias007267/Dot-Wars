class_name MiningSystem
extends RefCounted
## Zielwahl und Abbaufortschritt. Datenorientiert und zustandslos (GDExtension-tauglich).
##
## Der Fortschritt liegt an der Zelle. Eine Zelle wird genau einmal abgeschlossen: Sobald sie leer
## ist, tragen weitere Arbeiter im selben Tick nichts mehr bei.


## Sucht eine feste, markierte Nachbarzelle (Reihenfolge N, O, S, W). Setzt bei Erfolg Ziel und Zustand.
static func acquire_target(workers: WorkerStore, world: WorldState, areas: DigAreas, id: int) -> bool:
	if workers.size[id] > 1:
		return _acquire_around_footprint(workers, world, areas, id)
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
			world.note_progress(cell)
	return completed


## Wie `step`, aber mit Bruch-Abbauleistung und verteilter Leistung großer Einheiten.
static func step_scaled(
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	spawner: SpawnSystem,
	work_per_hardness: int,
	dig_power: int,
	dig_num: int,
	dig_den: int,
) -> int:
	var completed := 0
	for id in workers.count:
		if workers.state[id] != WorkerStore.STATE_MINING:
			continue
		var targets := _targets_for(workers, world, areas, id)
		if targets.is_empty():
			if not acquire_target(workers, world, areas, id):
				workers.state[id] = WorkerStore.STATE_WAITING
			continue
		var power := WorkerStore.SIZE_POWER[workers.size[id]] * dig_power
		var base := power / targets.size()
		var extra := power % targets.size()
		for index in targets.size():
			var share := base + (1 if index < extra else 0)
			if share <= 0:
				continue
			if _apply_power(workers, world, areas, spawner, id, targets[index], share, work_per_hardness, dig_num, dig_den):
				completed += 1
	return completed


static func _can_mine(cells: PackedByteArray, mask: PackedByteArray, idx: int) -> bool:
	return Materials.is_mineable(cells[idx]) and mask[idx] == 1


static func _acquire_around_footprint(
	workers: WorkerStore, world: WorldState, areas: DigAreas, id: int
) -> bool:
	var targets := _targets_for(workers, world, areas, id)
	if targets.is_empty():
		return false
	workers.target[id] = targets[0]
	workers.state[id] = WorkerStore.STATE_MINING
	return true


static func _targets_for(workers: WorkerStore, world: WorldState, areas: DigAreas, id: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	var seen := {}
	var mask: PackedByteArray = areas.masks[workers.group[id]]
	var cells := world.cells
	var width := world.width
	var limit := int(workers.size[id])
	var anchor := workers.cell[id]
	for dy in limit:
		for dx in limit:
			var center := anchor + dy * width + dx
			var x := center % width
			var neighbors: Array[int] = []
			if center >= width:
				neighbors.append(center - width)
			if x < width - 1:
				neighbors.append(center + 1)
			if center + width < world.cell_count():
				neighbors.append(center + width)
			if x > 0:
				neighbors.append(center - 1)
			for cell in neighbors:
				if seen.has(cell) or not _can_mine(cells, mask, cell):
					continue
				seen[cell] = true
				found.append(cell)
				if found.size() == limit:
					return found
	return found


static func _apply_power(
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	spawner: SpawnSystem,
	id: int,
	cell: int,
	share: int,
	work_per_hardness: int,
	dig_num: int,
	dig_den: int,
) -> bool:
	var mask: PackedByteArray = areas.masks[workers.group[id]]
	if not _can_mine(world.cells, mask, cell):
		return false
	var points := share
	if dig_num != dig_den:
		world.progress_frac[cell] += share * dig_num
		points = world.progress_frac[cell] / dig_den
		world.progress_frac[cell] -= points * dig_den
	var total: int = world.progress[cell] + points
	if total >= Materials.durability(world.cells[cell], work_per_hardness):
		if world.mine_cell(cell):
			spawner.enqueue(cell)
			return true
		return false
	world.progress[cell] = total
	world.note_progress(cell)
	return false

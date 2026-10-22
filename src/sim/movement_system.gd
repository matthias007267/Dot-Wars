class_name MovementSystem
extends RefCounted
## Orthogonale Bewegung entlang des Flow-Fields. Datenorientiert und zustandslos (GDExtension-tauglich).
##
## Regeln: ein Schritt pro Arbeiter, nur orthogonal, nur auf leere und freie Zellen innerhalb der
## Welt. Das Flow-Field ist ein Hinweis; der aktuelle Weltzustand wird vor jedem Schritt geprüft.


## Neue Zelle nach einem Schritt in Richtung `direction` oder -1 außerhalb der Welt.
static func neighbor(c: int, direction: int, width: int, cell_count: int) -> int:
	match direction:
		FlowField.DIR_UP:
			return c - width if c >= width else -1
		FlowField.DIR_RIGHT:
			return c + 1 if c % width < width - 1 else -1
		FlowField.DIR_DOWN:
			return c + width if c < cell_count - width else -1
		FlowField.DIR_LEFT:
			return c - 1 if c % width > 0 else -1
	return -1


static func step(
	tick: int,
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	fields: Array[FlowField],
	move_period: int,
) -> void:
	var terrain := world.cells
	var width := world.width
	var cell_count := world.cell_count()
	var state := workers.state
	var group := workers.group
	var cell_of := workers.cell
	var occupant := workers.occupant
	for id in workers.count:
		if state[id] == WorkerStore.STATE_MINING or (tick + id) % move_period != 0:
			continue
		var c := cell_of[id]
		var field := fields[group[id]]
		var direction := field.dir[c]
		if direction == FlowField.DIR_ARRIVED:
			if not MiningSystem.acquire_target(workers, world, areas, id):
				state[id] = WorkerStore.STATE_WAITING
			continue
		if direction == FlowField.DIR_NONE:
			state[id] = WorkerStore.STATE_WAITING
			continue
		var n := neighbor(c, direction, width, cell_count)
		if n < 0 or terrain[n] != Materials.EMPTY:
			state[id] = WorkerStore.STATE_WAITING
			continue
		if occupant[n] == WorkerStore.NO_WORKER:
			workers.move_to(id, n, tick)
		elif not _try_swap(tick, workers, fields, id, n, width, cell_count):
			if not _try_detour(tick, workers, terrain, field, id, width, cell_count):
				state[id] = WorkerStore.STATE_BLOCKED


## Frontaler Gegenverkehr: Der Blockierende will genau auf unsere Zelle.
static func _try_swap(
	tick: int,
	workers: WorkerStore,
	fields: Array[FlowField],
	id: int,
	n: int,
	width: int,
	cell_count: int,
) -> bool:
	var other := workers.occupant[n]
	if workers.state[other] == WorkerStore.STATE_MINING or workers.last_move_tick[other] == tick:
		return false
	var other_dir := fields[workers.group[other]].dir[n]
	if neighbor(n, other_dir, width, cell_count) != workers.cell[id]:
		return false
	workers.swap_cells(id, other, tick)
	return true


## Weicht auf eine freie Nachbarzelle aus, die ebenfalls näher am Ziel liegt.
static func _try_detour(
	tick: int,
	workers: WorkerStore,
	terrain: PackedByteArray,
	field: FlowField,
	id: int,
	width: int,
	cell_count: int,
) -> bool:
	var c := workers.cell[id]
	var own_dist := field.dist[c]
	for direction in [FlowField.DIR_UP, FlowField.DIR_RIGHT, FlowField.DIR_DOWN, FlowField.DIR_LEFT]:
		var n := neighbor(c, direction, width, cell_count)
		if n < 0 or terrain[n] != Materials.EMPTY or workers.occupant[n] != WorkerStore.NO_WORKER:
			continue
		var d := field.dist[n]
		if d >= 0 and d < own_dist:
			workers.move_to(id, n, tick)
			return true
	return false

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
	var dirs: Array[PackedByteArray] = []
	for field in fields:
		dirs.append(field.dir)
	# Arbeiter id ist in diesem Takt dran, wenn (tick + id) % move_period == 0.
	var first_id := posmod(-tick, move_period)
	for id in range(first_id, workers.count, move_period):
		if state[id] == WorkerStore.STATE_MINING:
			continue
		var c := cell_of[id]
		var direction := dirs[group[id]][c]
		if direction == FlowField.DIR_ARRIVED:
			if not MiningSystem.acquire_target(workers, world, areas, id):
				state[id] = WorkerStore.STATE_WAITING
			continue
		if direction == FlowField.DIR_NONE:
			state[id] = WorkerStore.STATE_WAITING
			continue
		var n := -1
		if direction == FlowField.DIR_UP:
			if c >= width:
				n = c - width
		elif direction == FlowField.DIR_DOWN:
			if c < cell_count - width:
				n = c + width
		elif direction == FlowField.DIR_RIGHT:
			if c % width < width - 1:
				n = c + 1
		elif c % width > 0:
			n = c - 1
		if n < 0 or terrain[n] != Materials.EMPTY:
			state[id] = WorkerStore.STATE_WAITING
		elif occupant[n] == WorkerStore.NO_WORKER:
			workers.move_to(id, n, tick)
		elif not _try_swap(tick, workers, dirs, id, n, width, cell_count):
			if not _try_detour(tick, workers, terrain, fields[group[id]], direction, id, width, cell_count):
				state[id] = WorkerStore.STATE_BLOCKED


## Frontaler Gegenverkehr: Der Blockierende will genau auf unsere Zelle.
static func _try_swap(
	tick: int,
	workers: WorkerStore,
	dirs: Array[PackedByteArray],
	id: int,
	n: int,
	width: int,
	cell_count: int,
) -> bool:
	var other := workers.occupant[n]
	if workers.state[other] == WorkerStore.STATE_MINING or workers.last_move_tick[other] == tick:
		return false
	var other_dir := dirs[workers.group[other]][n]
	if neighbor(n, other_dir, width, cell_count) != workers.cell[id]:
		return false
	workers.swap_cells(id, other, tick)
	return true


## Weicht seitlich auf eine freie Nachbarzelle aus, die ebenfalls näher am Ziel liegt.
## Nur die beiden Querrichtungen kommen in Frage: Rückwärts ist nie näher, geradeaus ist blockiert.
static func _try_detour(
	tick: int,
	workers: WorkerStore,
	terrain: PackedByteArray,
	field: FlowField,
	blocked_direction: int,
	id: int,
	width: int,
	cell_count: int,
) -> bool:
	var vertical := blocked_direction == FlowField.DIR_UP or blocked_direction == FlowField.DIR_DOWN
	var c := workers.cell[id]
	var own_dist := field.dist[c]
	var first := FlowField.DIR_LEFT if vertical else FlowField.DIR_UP
	var second := FlowField.DIR_RIGHT if vertical else FlowField.DIR_DOWN
	return (
		_step_if_closer(tick, workers, terrain, field, id, neighbor(c, first, width, cell_count), own_dist)
		or _step_if_closer(tick, workers, terrain, field, id, neighbor(c, second, width, cell_count), own_dist)
	)


static func _step_if_closer(
	tick: int,
	workers: WorkerStore,
	terrain: PackedByteArray,
	field: FlowField,
	id: int,
	n: int,
	own_dist: int,
) -> bool:
	if n < 0 or terrain[n] != Materials.EMPTY or workers.occupant[n] != WorkerStore.NO_WORKER:
		return false
	var d := field.dist[n]
	if d < 0 or d >= own_dist:
		return false
	workers.move_to(id, n, tick)
	return true

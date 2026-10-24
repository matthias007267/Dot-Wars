class_name MovementSystem
extends RefCounted

const NATIVE_SEARCH = preload("res://src/sim/native_search.gd")
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
	speed_points: int = 0,
	forbidden: PackedByteArray = PackedByteArray(),
	faction_period: PackedByteArray = PackedByteArray(),
) -> void:
	var native := NATIVE_SEARCH.backend()
	if native != null and workers.max_size <= 1:
		var field_arrays: Array = []
		for field in fields:
			field_arrays.append(field.dir)
			field_arrays.append(field.dist)
		var result: Variant = native.move_workers([
			workers.cell, workers.group, workers.faction, workers.state, workers.target,
			workers.aim, workers.aim_step, workers.last_move_tick, workers.move_credit,
			workers.size, workers.occupant,
		], field_arrays, world.cells, forbidden, areas.masks, faction_period,
			world.width, tick, move_period, speed_points)
		if result is Array and result.size() == 6:
			workers.cell = result[0]
			workers.state = result[1]
			workers.target = result[2]
			workers.last_move_tick = result[3]
			workers.move_credit = result[4]
			workers.occupant = result[5]
			return
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
	# speed_points > 0 ersetzt den Grundtakt: 100 Punkte sind ein Schritt.
	# Eine gesetzte Fraktionsperiode ersetzt den gemeinsamen Schritt, sonst bleibt der Takt bytegleich.
	var use_speed := speed_points > 0
	var use_faction := not faction_period.is_empty()
	var first_id := 0 if use_speed or use_faction else posmod(-tick, move_period)
	var stride := 1 if use_speed or use_faction else move_period
	for id in range(first_id, workers.count, stride):
		if use_faction:
			var pace := move_period
			var faction_id := int(workers.faction[id])
			if faction_id < faction_period.size():
				pace = int(faction_period[faction_id])
			if pace > 1 and posmod(tick + id, pace) != 0:
				continue
		if use_speed:
			workers.move_credit[id] += speed_points
			if workers.move_credit[id] < 100:
				continue
			workers.move_credit[id] -= 100
		if state[id] == WorkerStore.STATE_MINING:
			continue
		if workers.size[id] > 1:
			_step_large(tick, workers, world, areas, fields, dirs, id, forbidden)
			continue
		var c := cell_of[id]
		var direction := dirs[group[id]][c]
		var personal := workers.aim[id]
		if personal >= 0:
			var step_cell := workers.aim_step[id]
			if step_cell == c:
				if MiningSystem.claim_cell(workers, world, areas, id, personal):
					continue
				state[id] = WorkerStore.STATE_WAITING
				continue
			if step_cell < 0:
				state[id] = WorkerStore.STATE_WAITING
				continue
			var personal_dir := _dir_between(c, step_cell, width)
			if personal_dir != FlowField.DIR_NONE:
				direction = personal_dir
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
		if n < 0 or terrain[n] != Materials.EMPTY or _in_zone(forbidden, n):
			state[id] = WorkerStore.STATE_WAITING
		elif occupant[n] == WorkerStore.NO_WORKER:
			workers.move_to(id, n, tick)
		elif not _try_swap(tick, workers, dirs, id, n, width, cell_count):
			if not _try_detour(tick, workers, terrain, fields[group[id]], direction, id, width, cell_count, forbidden):
				state[id] = WorkerStore.STATE_BLOCKED


static func _dir_between(here: int, dest: int, width: int) -> int:
	if dest == here - width:
		return FlowField.DIR_UP
	if dest == here + width:
		return FlowField.DIR_DOWN
	if dest == here + 1 and here % width < width - 1:
		return FlowField.DIR_RIGHT
	if dest == here - 1 and here % width > 0:
		return FlowField.DIR_LEFT
	return FlowField.DIR_NONE


static func _in_zone(forbidden: PackedByteArray, idx: int) -> bool:
	return not forbidden.is_empty() and idx >= 0 and idx < forbidden.size() and forbidden[idx] == 1


static func _step_large(
	tick: int,
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	fields: Array[FlowField],
	dirs: Array[PackedByteArray],
	id: int,
	forbidden: PackedByteArray,
) -> void:
	var width := world.width
	var unit_size := int(workers.size[id])
	var anchor := workers.cell[id]
	var direction := dirs[workers.group[id]][anchor]
	if direction == FlowField.DIR_ARRIVED:
		if not MiningSystem.acquire_target(workers, world, areas, id):
			workers.state[id] = WorkerStore.STATE_WAITING
		return
	if direction == FlowField.DIR_NONE:
		workers.state[id] = WorkerStore.STATE_WAITING
		return
	var field := fields[workers.group[id]]
	var own_dist := field.dist[anchor]
	if _try_large_step(tick, workers, world, id, unit_size, anchor, direction, forbidden):
		return
	var vertical := direction == FlowField.DIR_UP or direction == FlowField.DIR_DOWN
	var first := FlowField.DIR_LEFT if vertical else FlowField.DIR_UP
	var second := FlowField.DIR_RIGHT if vertical else FlowField.DIR_DOWN
	if _try_large_toward(tick, workers, world, field, id, unit_size, anchor, first, own_dist, forbidden):
		return
	if _try_large_toward(tick, workers, world, field, id, unit_size, anchor, second, own_dist, forbidden):
		return
	workers.state[id] = WorkerStore.STATE_BLOCKED


static func _try_large_toward(
	tick: int,
	workers: WorkerStore,
	world: WorldState,
	field: FlowField,
	id: int,
	unit_size: int,
	anchor: int,
	direction: int,
	own_dist: int,
	forbidden: PackedByteArray,
) -> bool:
	var dest := _anchor_after(anchor, direction, unit_size, world.width, world.height)
	if dest < 0 or not _footprint_open(workers, world, id, dest, unit_size, forbidden):
		return false
	var dist := field.dist[dest]
	if dist < 0 or dist >= own_dist:
		return false
	workers.move_footprint(id, dest, tick)
	return true


static func _try_large_step(
	tick: int,
	workers: WorkerStore,
	world: WorldState,
	id: int,
	unit_size: int,
	anchor: int,
	direction: int,
	forbidden: PackedByteArray,
) -> bool:
	var dest := _anchor_after(anchor, direction, unit_size, world.width, world.height)
	if dest < 0 or not _footprint_open(workers, world, id, dest, unit_size, forbidden):
		return false
	workers.move_footprint(id, dest, tick)
	return true


static func _anchor_after(anchor: int, direction: int, unit_size: int, width: int, height: int) -> int:
	var x := anchor % width
	var y := anchor / width
	match direction:
		FlowField.DIR_UP:
			y -= 1
		FlowField.DIR_DOWN:
			y += 1
		FlowField.DIR_LEFT:
			x -= 1
		FlowField.DIR_RIGHT:
			x += 1
		_:
			return -1
	if x < 0 or y < 0 or x + unit_size > width or y + unit_size > height:
		return -1
	return y * width + x


static func _footprint_open(
	workers: WorkerStore, world: WorldState, id: int, anchor: int, unit_size: int, forbidden: PackedByteArray
) -> bool:
	var width := world.width
	var cells := world.cells
	for dy in unit_size:
		for dx in unit_size:
			var idx := anchor + dy * width + dx
			if cells[idx] != Materials.EMPTY or _in_zone(forbidden, idx):
				return false
			var occ := workers.occupant[idx]
			if occ != WorkerStore.NO_WORKER and occ != id:
				return false
	return true


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
	forbidden: PackedByteArray,
) -> bool:
	var vertical := blocked_direction == FlowField.DIR_UP or blocked_direction == FlowField.DIR_DOWN
	var c := workers.cell[id]
	var own_dist := field.dist[c]
	var first := FlowField.DIR_LEFT if vertical else FlowField.DIR_UP
	var second := FlowField.DIR_RIGHT if vertical else FlowField.DIR_DOWN
	return (
		_step_if_closer(tick, workers, terrain, field, id, neighbor(c, first, width, cell_count), own_dist, forbidden)
		or _step_if_closer(tick, workers, terrain, field, id, neighbor(c, second, width, cell_count), own_dist, forbidden)
	)


static func _step_if_closer(
	tick: int,
	workers: WorkerStore,
	terrain: PackedByteArray,
	field: FlowField,
	id: int,
	n: int,
	own_dist: int,
	forbidden: PackedByteArray,
) -> bool:
	if n < 0 or terrain[n] != Materials.EMPTY or _in_zone(forbidden, n) or workers.occupant[n] != WorkerStore.NO_WORKER:
		return false
	var d := field.dist[n]
	if d < 0 or d >= own_dist:
		return false
	workers.move_to(id, n, tick)
	return true

class_name SwarmMind
extends RefCounted

const NATIVE_SEARCH = preload("res://src/sim/native_search.gd")
## Eigene Ziele je Dot. Stufe 0 lässt das gemeinsame Wegfeld unverändert.
## Ab Stufe 1 sucht jeder Arbeiter einen markierten Fels, den noch niemand der eigenen Fraktion hat.
## Steht er zu lange auf einer Zelle, ohne abzubauen, sucht er neu. Sind alle Nachbarzellen von
## eigenen Arbeitern belegt, wartet diese Suche, bis wieder eine frei ist.


const PATIENCE := [0, 80, 40, 20, 10]
const BUDGET := [0, 64, 192, 768, 3072]
## Obergrenze für teure individuelle BFS-Arbeit pro Simulationstakt.
## Große Schwärme verteilen ihre Sucharbeit deterministisch über mehrere Takte.
const MAX_SEEKS_PER_TICK := 24
const MAX_PATHS_PER_TICK := 48
static var seeks_last_tick: int = 0
static var paths_last_tick: int = 0
## Wie oft ein eigener Weg neu gesucht wurde. Tests lesen das, die Simulation nicht.
static var path_builds: int = 0
## Temporäre, gemeinsam wiederverwendete Suchpuffer. Keine Zuordnung zu festen Dot-Gruppen:
## Jeder Dot behält sein Ziel, die BFS allokiert aber nicht mehr die ganze Welt pro Suche.
static var _visit_stamp := PackedInt32Array()
static var _parent := PackedInt32Array()
static var _queue := PackedInt32Array()
static var _stamp: int = 0
## Geometriecache, maximal 4 MiB; größere Welten verwenden dieselben direkten Randprüfungen.
static var _neighbor_table := PackedInt32Array()
static var _neighbor_width: int = 0


static func _prepare_search(cell_count: int, width: int) -> void:
	if _visit_stamp.size() != cell_count:
		_visit_stamp.resize(cell_count)
		_visit_stamp.fill(0)
		_parent.resize(cell_count)
		_queue.resize(cell_count)
		_stamp = 0
	if cell_count <= 262144:
		if _neighbor_table.size() != cell_count * 4 or _neighbor_width != width:
			_neighbor_width = width
			_neighbor_table.resize(cell_count * 4)
			for cell in cell_count:
				var at := cell * 4
				var x := cell % width
				_neighbor_table[at] = cell - width if cell >= width else -1
				_neighbor_table[at + 1] = cell + 1 if x < width - 1 else -1
				_neighbor_table[at + 2] = cell + width if cell + width < cell_count else -1
				_neighbor_table[at + 3] = cell - 1 if x > 0 else -1
	elif not _neighbor_table.is_empty():
		_neighbor_table = PackedInt32Array()
	_stamp += 1
	if _stamp >= 2000000000:
		_visit_stamp.fill(0)
		_stamp = 1


static func _neighbor(cell: int, direction: int, width: int, count: int) -> int:
	match direction:
		0:
			return cell - width if cell >= width else -1
		1:
			return cell + 1 if cell % width < width - 1 else -1
		2:
			return cell + width if cell + width < count else -1
		3:
			return cell - 1 if cell % width > 0 else -1
	return -1


static func step(sim: Simulation) -> void:
	var workers := sim.workers
	seeks_last_tick = 0
	paths_last_tick = 0
	if workers.count == 0:
		return
	var positions := workers.cell
	var groups := workers.group
	var factions := workers.faction
	var states := workers.state
	var targets := workers.target
	var sizes := workers.size
	var aims := workers.aim
	var aim_steps := workers.aim_step
	var aim_watches := workers.aim_watch
	var idle_ticks := workers.idle_ticks
	var idle_cells := workers.idle_cell
	var group_goals := PackedInt32Array()
	for field in sim.fields:
		group_goals.append(field.goal_cell)
	var levels := _levels(sim)
	var active := false
	for level in levels:
		if level > 0:
			active = true
			break
	if not active:
		for id in workers.count:
			if aims[id] != WorkerStore.NO_TARGET:
				aims[id] = WorkerStore.NO_TARGET
				aim_steps[id] = WorkerStore.NO_TARGET
				aim_watches[id] = 0
		return
	var boxed_snapshot := PackedByteArray()
	var watch_snapshot := PackedInt64Array()
	var native := NATIVE_SEARCH.backend()
	if native != null:
		var neighborhood: Variant = native.neighborhoods(sim.world.cells, workers.occupant, workers.cell, workers.faction, workers.aim, sim.world.width)
		if neighborhood is Array and neighborhood.size() == 2:
			boxed_snapshot = neighborhood[0]
			watch_snapshot = neighborhood[1]
	var claimed := {}
	for id in workers.count:
		if int(states[id]) != WorkerStore.STATE_MINING:
			continue
		var rock := int(targets[id])
		if not _marked(sim, id, rock):
			continue
		claimed[_key(int(factions[id]), rock)] = id
	# Nur bei großen Schwärmen rotieren die IDs. Kleine Szenen bleiben bytegleich.
	# Die Position ist aus tick_count ableitbar und braucht keinen Save-Zustand.
	var start := 0
	if workers.count > MAX_SEEKS_PER_TICK:
		start = (sim.tick_count * MAX_SEEKS_PER_TICK) % workers.count
	for offset in workers.count:
		var id := (start + offset) % workers.count
		var faction := int(factions[id])
		var level := levels[mini(faction, levels.size() - 1)]
		if level <= 0 or int(sizes[id]) > 1 or group_goals[int(groups[id])] >= 0:
			aims[id] = WorkerStore.NO_TARGET
			aim_steps[id] = WorkerStore.NO_TARGET
			aim_watches[id] = 0
			continue
		if int(states[id]) == WorkerStore.STATE_MINING and _marked(sim, id, int(targets[id])):
			aims[id] = int(targets[id])
			idle_ticks[id] = 0
			idle_cells[id] = int(positions[id])
			aim_steps[id] = int(positions[id])
			continue
		var cell := int(positions[id])
		if cell != int(idle_cells[id]):
			idle_cells[id] = cell
			idle_ticks[id] = 0
		else:
			idle_ticks[id] += 1
		var boxed := boxed_snapshot[id] != 0 if boxed_snapshot.size() == workers.count else _boxed(sim, id)
		var previous := int(aims[id])
		var drop: bool = int(idle_ticks[id]) >= int(PATIENCE[level]) and not boxed
		var keep := previous
		if drop or not _marked(sim, id, keep) or claimed.has(_key(faction, keep)):
			keep = WorkerStore.NO_TARGET
		if keep >= 0:
			aims[id] = keep
			claimed[_key(faction, keep)] = id
		elif boxed:
			aims[id] = WorkerStore.NO_TARGET
		else:
			if seeks_last_tick >= MAX_SEEKS_PER_TICK:
				continue
			seeks_last_tick += 1
			var ban := previous if drop else WorkerStore.NO_TARGET
			var found := _seek(sim, id, level, claimed, ban)
			if found < 0 and ban >= 0:
				found = _seek(sim, id, level, claimed, WorkerStore.NO_TARGET)
			aims[id] = found
			if found >= 0:
				claimed[_key(faction, found)] = id
		var aim_now := int(aims[id])
		var sig := watch_snapshot[id] if watch_snapshot.size() == workers.count and aim_now == previous else _watch(sim, id, aim_now)
		if sig == int(aim_watches[id]) and aim_now == previous:
			continue
		if paths_last_tick >= MAX_PATHS_PER_TICK:
			# Ein veralteter Schritt darf nicht gegen die aktuelle Belegung benutzt werden.
			aim_steps[id] = WorkerStore.NO_TARGET
			continue
		paths_last_tick += 1
		aim_watches[id] = sig
		aim_steps[id] = _first_step(sim, id, aim_now, level)


static func _levels(sim: Simulation) -> PackedInt32Array:
	var count := 1
	if sim.config.mode == SimConfig.MODE_MATCH:
		count = maxi(1, sim.rules.faction_count)
	var levels := PackedInt32Array()
	levels.resize(count)
	for faction in count:
		var level := 0
		if sim.config.mode == SimConfig.MODE_MATCH:
			level = sim.rules.wallet(sim, faction).swarm_level
		elif faction == 0:
			level = sim.upgrades.swarm_level
		levels[faction] = clampi(level, 0, Upgrades.SWARM_MAX)
	return levels


static func _key(faction: int, cell: int) -> int:
	return faction * 16777216 + cell


static func _marked(sim: Simulation, id: int, cell: int) -> bool:
	if cell < 0 or cell >= sim.world.cell_count():
		return false
	var group := int(sim.workers.group[id])
	if group < 0 or group >= sim.areas.masks.size():
		return false
	var mask: PackedByteArray = sim.areas.masks[group]
	return Materials.is_mineable(sim.world.cells[cell]) and mask[cell] == 1


static func _boxed(sim: Simulation, id: int) -> bool:
	var workers := sim.workers
	var cell := int(workers.cell[id])
	var faction := int(workers.faction[id])
	var width := sim.world.width
	var count := sim.world.cell_count()
	var neighbors := _neighbors(cell, width, count)
	if neighbors.is_empty():
		return false
	for next in neighbors:
		var occ := int(workers.occupant[next])
		if occ == WorkerStore.NO_WORKER or occ == id or int(workers.faction[occ]) != faction:
			return false
	return true


static func _watch(sim: Simulation, id: int, aim: int) -> int:
	var workers := sim.workers
	var cell := int(workers.cell[id])
	var width := sim.world.width
	var count := sim.world.cell_count()
	var sig := aim * 3 + cell + 1
	var occ := workers.occupant
	var cells := sim.world.cells
	if cell >= width:
		sig = sig * 11 + int(occ[cell - width]) + int(cells[cell - width]) * 17
	if cell % width < width - 1:
		sig = sig * 11 + int(occ[cell + 1]) + int(cells[cell + 1]) * 17
	if cell + width < count:
		sig = sig * 11 + int(occ[cell + width]) + int(cells[cell + width]) * 17
	if cell % width > 0:
		sig = sig * 11 + int(occ[cell - 1]) + int(cells[cell - 1]) * 17
	return sig


static func _seek(sim: Simulation, id: int, level: int, claimed: Dictionary, ban: int) -> int:
	var workers := sim.workers
	var width := sim.world.width
	var count := sim.world.cell_count()
	var origin := int(workers.cell[id])
	if not _standable(sim, origin):
		return WorkerStore.NO_TARGET
	var native := NATIVE_SEARCH.backend()
	if native != null:
		var forbidden := PackedByteArray() if sim.config.mode == SimConfig.MODE_MATCH else sim.core_mask
		return int(native.search(sim.world.cells, workers.occupant, sim.areas.masks[int(workers.group[id])], forbidden, claimed, int(workers.faction[id]), width, origin, int(BUDGET[level]), -1, ban))
	_prepare_search(count, width)
	# Lokale Referenzen vermeiden Script-/Objektzugriffe je besuchter Kante.
	# Budget, Nachbarreihenfolge und Belegungsregeln bleiben identisch.
	var neighbors := _neighbor_table
	var cached_neighbors := not neighbors.is_empty()
	var visited := _visit_stamp
	var queue := _queue
	var cells := sim.world.cells
	var occupancy := workers.occupant
	var mask: PackedByteArray = sim.areas.masks[int(workers.group[id])]
	var blocked := sim.core_mask
	var blocked_count := 0 if sim.config.mode == SimConfig.MODE_MATCH else blocked.size()
	var owner_key := int(workers.faction[id]) * 16777216
	var stamp := _stamp
	visited[origin] = stamp
	queue[0] = origin
	var tail := 1
	var head := 0
	var budget: int = int(BUDGET[level])
	while head < tail and budget > 0:
		var cell := queue[head]
		head += 1
		var x := cell % width
		for direction in 4:
			var next: int
			if cached_neighbors:
				next = neighbors[cell * 4 + direction]
				if next < 0:
					continue
			else:
				match direction:
					0:
						if cell < width:
							continue
						next = cell - width
					1:
						if x >= width - 1:
							continue
						next = cell + 1
					2:
						if cell + width >= count:
							continue
						next = cell + width
					_:
						if x <= 0:
							continue
						next = cell - 1
			budget -= 1
			var material := int(cells[next])
			if material >= Materials.SOFT and material <= Materials.HARD and mask[next] == 1 and next != ban and not claimed.has(owner_key + next):
				return next
			if visited[next] != stamp and material == Materials.EMPTY and (next >= blocked_count or blocked[next] == 0) and int(occupancy[next]) == WorkerStore.NO_WORKER:
				visited[next] = stamp
				queue[tail] = next
				tail += 1
			if budget <= 0:
				break
	return WorkerStore.NO_TARGET


static func _first_step(sim: Simulation, id: int, rock: int, level: int) -> int:
	path_builds += 1
	if rock < 0:
		return WorkerStore.NO_TARGET
	var workers := sim.workers
	var origin := int(workers.cell[id])
	var width := sim.world.width
	var count := sim.world.cell_count()
	for direction in 4:
		if _neighbor(origin, direction, width, count) == rock:
			return origin
	var native := NATIVE_SEARCH.backend()
	if native != null:
		var forbidden := PackedByteArray() if sim.config.mode == SimConfig.MODE_MATCH else sim.core_mask
		return int(native.search(sim.world.cells, workers.occupant, sim.areas.masks[int(workers.group[id])], forbidden, {}, int(workers.faction[id]), width, origin, int(BUDGET[level]), rock, -1))
	_prepare_search(count, width)
	var neighbors := _neighbor_table
	var cached_neighbors := not neighbors.is_empty()
	var visited := _visit_stamp
	var parent := _parent
	var queue := _queue
	var cells := sim.world.cells
	var occupancy := workers.occupant
	var blocked := sim.core_mask
	var blocked_count := 0 if sim.config.mode == SimConfig.MODE_MATCH else blocked.size()
	var stamp := _stamp
	visited[origin] = stamp
	parent[origin] = -1
	queue[0] = origin
	var tail := 1
	var budget: int = int(BUDGET[level])
	var head := 0
	var stand := -1
	while head < tail and stand < 0 and budget > 0:
		var cell := queue[head]
		head += 1
		var x := cell % width
		for direction in 4:
			var next: int
			if cached_neighbors:
				next = neighbors[cell * 4 + direction]
				if next < 0:
					continue
			else:
				match direction:
					0:
						if cell < width:
							continue
						next = cell - width
					1:
						if x >= width - 1:
							continue
						next = cell + 1
					2:
						if cell + width >= count:
							continue
						next = cell + width
					_:
						if x <= 0:
							continue
						next = cell - 1
			budget -= 1
			if next == rock:
				stand = cell
				break
			if visited[next] == stamp:
				continue
			if int(cells[next]) == Materials.EMPTY and (next >= blocked_count or blocked[next] == 0) and int(occupancy[next]) == WorkerStore.NO_WORKER:
				visited[next] = stamp
				parent[next] = cell
				queue[tail] = next
				tail += 1
			if budget <= 0:
				break
	if stand < 0 or stand == origin:
		return origin if stand == origin else WorkerStore.NO_TARGET
	var step := stand
	while parent[step] != origin and parent[step] >= 0:
		step = parent[step]
	return step


static func _standable(sim: Simulation, idx: int) -> bool:
	if sim.world.cells[idx] != Materials.EMPTY:
		return false
	if sim.config.mode == SimConfig.MODE_MATCH or sim.core_mask.is_empty():
		return true
	return idx >= sim.core_mask.size() or sim.core_mask[idx] == 0


static func _neighbors(cell: int, width: int, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var x := cell % width
	if cell >= width:
		result.append(cell - width)
	if x < width - 1:
		result.append(cell + 1)
	if cell + width < count:
		result.append(cell + width)
	if x > 0:
		result.append(cell - 1)
	return result

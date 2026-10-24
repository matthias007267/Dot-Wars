class_name SwarmMind
extends RefCounted
## Eigene Ziele je Dot. Stufe 0 lässt das gemeinsame Wegfeld unverändert.
## Ab Stufe 1 sucht jeder Arbeiter einen markierten Fels, den noch niemand der eigenen Fraktion hat.
## Steht er zu lange auf einer Zelle, ohne abzubauen, sucht er neu. Sind alle Nachbarzellen von
## eigenen Arbeitern belegt, wartet diese Suche, bis wieder eine frei ist.


const PATIENCE := [0, 80, 40, 20, 10]
const BUDGET := [0, 64, 192, 768, 3072]
## Wie oft ein eigener Weg neu gesucht wurde. Tests lesen das, die Simulation nicht.
static var path_builds: int = 0


static func step(sim: Simulation) -> void:
	var workers := sim.workers
	if workers.count == 0:
		return
	var levels := _levels(sim)
	var active := false
	for level in levels:
		if level > 0:
			active = true
			break
	if not active:
		for id in workers.count:
			if workers.aim[id] != WorkerStore.NO_TARGET:
				workers.aim[id] = WorkerStore.NO_TARGET
				workers.aim_step[id] = WorkerStore.NO_TARGET
				workers.aim_watch[id] = 0
		return
	var claimed := {}
	for id in workers.count:
		if int(workers.state[id]) != WorkerStore.STATE_MINING:
			continue
		var rock := int(workers.target[id])
		if not _marked(sim, id, rock):
			continue
		claimed[_key(int(workers.faction[id]), rock)] = id
	for id in workers.count:
		var faction := int(workers.faction[id])
		var level := levels[mini(faction, levels.size() - 1)]
		if level <= 0 or int(workers.size[id]) > 1 or sim.move_goal(int(workers.group[id])) >= 0:
			workers.aim[id] = WorkerStore.NO_TARGET
			workers.aim_step[id] = WorkerStore.NO_TARGET
			workers.aim_watch[id] = 0
			continue
		if int(workers.state[id]) == WorkerStore.STATE_MINING and _marked(sim, id, int(workers.target[id])):
			workers.aim[id] = int(workers.target[id])
			workers.idle_ticks[id] = 0
			workers.idle_cell[id] = int(workers.cell[id])
			workers.aim_step[id] = int(workers.cell[id])
			continue
		var cell := int(workers.cell[id])
		if cell != int(workers.idle_cell[id]):
			workers.idle_cell[id] = cell
			workers.idle_ticks[id] = 0
		else:
			workers.idle_ticks[id] += 1
		var boxed := _boxed(sim, id)
		var previous := int(workers.aim[id])
		var drop: bool = int(workers.idle_ticks[id]) >= int(PATIENCE[level]) and not boxed
		var keep := previous
		if drop or not _marked(sim, id, keep) or claimed.has(_key(faction, keep)):
			keep = WorkerStore.NO_TARGET
		if keep >= 0:
			workers.aim[id] = keep
			claimed[_key(faction, keep)] = id
		elif boxed:
			workers.aim[id] = WorkerStore.NO_TARGET
		else:
			var ban := previous if drop else WorkerStore.NO_TARGET
			var found := _seek(sim, id, level, claimed, ban)
			if found < 0 and ban >= 0:
				found = _seek(sim, id, level, claimed, WorkerStore.NO_TARGET)
			workers.aim[id] = found
			if found >= 0:
				claimed[_key(faction, found)] = id
		var aim_now := int(workers.aim[id])
		var sig := _watch(sim, id, aim_now)
		if sig == int(workers.aim_watch[id]) and aim_now == previous:
			continue
		workers.aim_watch[id] = sig
		workers.aim_step[id] = _first_step(sim, id, aim_now, level)


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
	var faction := int(workers.faction[id])
	var width := sim.world.width
	var count := sim.world.cell_count()
	var seen := PackedByteArray()
	seen.resize(count)
	var queue := PackedInt32Array()
	var origin := int(workers.cell[id])
	if not _standable(sim, origin):
		return WorkerStore.NO_TARGET
	seen[origin] = 1
	queue.append(origin)
	var budget: int = int(BUDGET[level])
	var head := 0
	while head < queue.size() and budget > 0:
		var cell := queue[head]
		head += 1
		for next in _neighbors(cell, width, count):
			budget -= 1
			if _marked(sim, id, next) and next != ban and not claimed.has(_key(faction, next)):
				return next
			if seen[next] == 0 and _standable(sim, next) and int(workers.occupant[next]) == WorkerStore.NO_WORKER:
				seen[next] = 1
				queue.append(next)
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
	for next in _neighbors(origin, width, count):
		if next == rock:
			return origin
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-2)
	var queue := PackedInt32Array()
	parent[origin] = -1
	queue.append(origin)
	var budget: int = int(BUDGET[level])
	var head := 0
	var stand := -1
	while head < queue.size() and stand < 0 and budget > 0:
		var cell := queue[head]
		head += 1
		for next in _neighbors(cell, width, count):
			budget -= 1
			if next == rock:
				stand = cell
				break
			if parent[next] != -2:
				continue
			if _standable(sim, next) and int(workers.occupant[next]) == WorkerStore.NO_WORKER:
				parent[next] = cell
				queue.append(next)
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

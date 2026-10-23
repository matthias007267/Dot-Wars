class_name WorkFront
extends RefCounted
## Automatische Arbeitsfront einer Gruppe.
## Zuerst nur Fels innerhalb von 16 Zellen. Ist dort nichts, wächst die Suche
## einmal je Stufe auf 32, 64 und danach auf die ganze erreichbare Höhle.
## Dieselbe leere Suche läuft nicht in jedem Takt erneut.


const RADII: Array[int] = [16, 32, 64, -1]
const MOVE_RESET := 8

var _band := PackedInt32Array()
var _empty := PackedByteArray()
var _grow := PackedByteArray()
var _cursor := PackedInt32Array()
var _epoch := PackedInt32Array()
var _min_x := PackedInt32Array()
var _min_y := PackedInt32Array()
var _max_x := PackedInt32Array()
var _max_y := PackedInt32Array()
var _snap_ids: Array = []
var _snap_cells: Array = []
var _seen := PackedInt32Array()
var _stamp: int = 1
var _queue := PackedInt32Array()
var _depth := PackedInt32Array()


func mark_nearest(sim: Simulation, group_id: int) -> bool:
	_ensure(group_id + 1)
	var origins := _origins(sim, group_id)
	if origins.is_empty():
		return false
	var band := _band[group_id]
	if _empty[group_id] == 1 and _cache_holds(sim, group_id):
		if _grow[group_id] == 0:
			return false
		band = mini(band + 1, RADII.size() - 1)
		_band[group_id] = band
		_grow[group_id] = 0
		_empty[group_id] = 0
	elif _empty[group_id] == 1:
		band = 0
		_band[group_id] = 0
		_grow[group_id] = 0
		_empty[group_id] = 0
	var radius := RADII[band]
	if not sim.world.has_face_within(origins, radius):
		_remember_empty(sim, group_id, radius)
		return false
	var found := _bfs(sim, origins, radius)
	if found.is_empty():
		_remember_empty(sim, group_id, radius)
		return false
	if not sim.assign_cells(group_id, found):
		_remember_empty(sim, group_id, radius)
		return false
	_band[group_id] = 0
	_empty[group_id] = 0
	_grow[group_id] = 0
	return true


func _ensure(groups: int) -> void:
	while _band.size() < groups:
		_band.append(0)
		_empty.append(0)
		_grow.append(0)
		_cursor.append(0)
		_epoch.append(0)
		_min_x.append(0)
		_min_y.append(0)
		_max_x.append(0)
		_max_y.append(0)
		_snap_ids.append(PackedInt32Array())
		_snap_cells.append(PackedInt32Array())


func _origins(sim: Simulation, group_id: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var workers := sim.workers
	var cells := sim.world.cells
	for id in workers.count:
		if int(workers.group[id]) != group_id:
			continue
		var cell := int(workers.cell[id])
		if cells[cell] == Materials.EMPTY:
			result.append(cell)
	return result


func _cache_holds(sim: Simulation, group_id: int) -> bool:
	var world := sim.world
	if _epoch[group_id] != world.change_epoch:
		return false
	var ids: PackedInt32Array = _snap_ids[group_id]
	var cells: PackedInt32Array = _snap_cells[group_id]
	var workers := sim.workers
	var width := world.width
	var live := 0
	for id in workers.count:
		if int(workers.group[id]) != group_id:
			continue
		live += 1
		var at := ids.find(id)
		if at < 0:
			return false
		var cell := int(workers.cell[id])
		var previous := cells[at]
		if absi(cell % width - previous % width) + absi(int(cell / width) - int(previous / width)) >= MOVE_RESET:
			return false
	if live != ids.size():
		return false
	var log := world.change_log
	var cursor := _cursor[group_id]
	if cursor > log.size():
		return false
	for n in range(cursor, log.size()):
		var idx := log[n]
		var x := idx % width
		var y := int(idx / width)
		if x < _min_x[group_id] or x > _max_x[group_id] or y < _min_y[group_id] or y > _max_y[group_id]:
			continue
		return false
	return true


func _remember_empty(sim: Simulation, group_id: int, radius: int) -> void:
	var world := sim.world
	var workers := sim.workers
	var ids := PackedInt32Array()
	var cells := PackedInt32Array()
	var width := world.width
	var min_x := width
	var min_y := world.height
	var max_x := 0
	var max_y := 0
	for id in workers.count:
		if int(workers.group[id]) != group_id:
			continue
		var cell := int(workers.cell[id])
		ids.append(id)
		cells.append(cell)
		var x := cell % width
		var y := int(cell / width)
		min_x = mini(min_x, x)
		min_y = mini(min_y, y)
		max_x = maxi(max_x, x)
		max_y = maxi(max_y, y)
	if radius < 0:
		min_x = 0
		min_y = 0
		max_x = width - 1
		max_y = world.height - 1
	else:
		min_x = maxi(0, min_x - radius)
		min_y = maxi(0, min_y - radius)
		max_x = mini(width - 1, max_x + radius)
		max_y = mini(world.height - 1, max_y + radius)
	_snap_ids[group_id] = ids
	_snap_cells[group_id] = cells
	_min_x[group_id] = min_x
	_min_y[group_id] = min_y
	_max_x[group_id] = max_x
	_max_y[group_id] = max_y
	_cursor[group_id] = world.change_log.size()
	_epoch[group_id] = world.change_epoch
	_empty[group_id] = 1
	_grow[group_id] = 0 if _band[group_id] >= RADII.size() - 1 else 1


func _bfs(sim: Simulation, origins: PackedInt32Array, radius: int) -> PackedInt32Array:
	var world := sim.world
	var count := world.cell_count()
	var width := world.width
	_prepare_seen(count)
	_queue.clear()
	_depth.clear()
	var stamp := _stamp
	for cell in origins:
		if _seen[cell] == stamp:
			continue
		_seen[cell] = stamp
		_queue.append(cell)
		_depth.append(0)
	var found := PackedInt32Array()
	var head := 0
	var cells := world.cells
	while head < _queue.size() and found.size() < DigGuidance.FRONTIER_CAP:
		var cell := _queue[head]
		var depth := _depth[head]
		head += 1
		var x := cell % width
		var neighbors := PackedInt32Array()
		if cell >= width:
			neighbors.append(cell - width)
		if x < width - 1:
			neighbors.append(cell + 1)
		if cell + width < count:
			neighbors.append(cell + width)
		if x > 0:
			neighbors.append(cell - 1)
		for next in neighbors:
			if _seen[next] == stamp:
				continue
			if Materials.is_mineable(cells[next]):
				if radius >= 0 and depth + 1 > radius:
					continue
				_seen[next] = stamp
				found.append(next)
				if found.size() >= DigGuidance.FRONTIER_CAP:
					break
				continue
			if cells[next] != Materials.EMPTY:
				continue
			if radius >= 0 and depth + 1 > radius:
				continue
			_seen[next] = stamp
			_queue.append(next)
			_depth.append(depth + 1)
	return found


func _prepare_seen(count: int) -> void:
	if _seen.size() != count:
		_seen.resize(count)
		_seen.fill(0)
		_stamp = 1
	_stamp += 1
	if _stamp > 2000000000:
		_seen.fill(0)
		_stamp = 1

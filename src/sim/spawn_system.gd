class_name SpawnSystem
extends RefCounted
## Entstehung neuer Arbeiter. Jede abgebaute Zelle ergibt genau einen Eintrag in der FIFO-Warteschlange.
##
## Entstehungsort ist die abgebaute Zelle. Ist sie belegt, wird per BFS (Reihenfolge N, O, S, W)
## die nächste freie, zusammenhängende leere Zelle gesucht. Gibt es keine, bleibt der Eintrag
## (und alle dahinter) in der Warteschlange – es geht keine Masse verloren.

var _queue := PackedInt32Array()
var _head: int = 0
var _search_limit: int
var _stamp := PackedInt32Array()
var _stamp_generation: int = 0
var _frontier := PackedInt32Array()


func _init(cell_count: int, search_limit: int) -> void:
	_search_limit = search_limit
	_stamp.resize(cell_count)
	_stamp.fill(0)


func pending() -> int:
	return _queue.size() - _head


func export_queue() -> PackedInt32Array:
	return _queue.slice(_head)


func import_queue(items: PackedInt32Array) -> void:
	_queue = items.duplicate()
	_head = 0


func enqueue(origin_cell: int) -> void:
	_queue.append(origin_cell)


## Platziert so viele wartende Arbeiter wie möglich. Gibt die Anzahl neuer Arbeiter zurück.
func process(world: WorldState, workers: WorkerStore, quotas: PackedInt32Array) -> int:
	var spawned := 0
	while _head < _queue.size():
		var cell := find_free_cell(world, workers, _queue[_head])
		if cell < 0:
			break
		workers.add(cell, GroupQuotas.pick_group(workers.group_mass, quotas))
		_head += 1
		spawned += 1
	if _head > 1024 and _head * 2 > _queue.size():
		_queue = _queue.slice(_head)
		_head = 0
	return spawned


## Nächste freie leere Zelle ab `origin` (inklusive) oder -1.
func find_free_cell(world: WorldState, workers: WorkerStore, origin: int) -> int:
	var found := find_free_cells(world, workers, origin, 1, _search_limit)
	return -1 if found.is_empty() else found[0]


## Bis zu `want` freie leere Zellen in BFS-Reihenfolge (N, O, S, W) ab `origin`.
## `limit` begrenzt die Zahl untersuchter Zellen. Die Zellen werden nicht belegt.
func find_free_cells(
	world: WorldState, workers: WorkerStore, origin: int, want: int, limit: int
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if world.cells[origin] != Materials.EMPTY:
		return result
	_stamp_generation += 1
	_frontier.clear()
	_frontier.append(origin)
	_stamp[origin] = _stamp_generation
	var cells := world.cells
	var w := world.width
	var size := world.cell_count()
	var head := 0
	while head < _frontier.size() and head < limit:
		var c := _frontier[head]
		head += 1
		if workers.is_free(c):
			result.append(c)
			if result.size() == want:
				return result
		var x := c % w
		if c >= w:
			_visit(cells, c - w)
		if x < w - 1:
			_visit(cells, c + 1)
		if c < size - w:
			_visit(cells, c + w)
		if x > 0:
			_visit(cells, c - 1)
	return result


func _visit(cells: PackedByteArray, c: int) -> void:
	if _stamp[c] != _stamp_generation and cells[c] == Materials.EMPTY:
		_stamp[c] = _stamp_generation
		_frontier.append(c)

class_name SpawnSystem
extends RefCounted
## Entstehung gekaufter Arbeiter. Abbau füllt diese Warteschlange nicht.
##
## Der Kauf nennt eine Zelle am Energiekern. Ist sie belegt, sucht eine BFS (Nord, Ost, Süd, West)
## die nächste freie leere Zelle. Gibt es keine, bleibt der Eintrag und alles dahinter liegen.

var _queue := PackedInt32Array()
var _head: int = 0
var _sites := PackedInt32Array()
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
	_sites.resize(items.size())
	_sites.fill(-1)


func site_queue() -> PackedInt32Array:
	return _sites.slice(_head)

func import_sites(items: PackedInt32Array) -> void:
	_sites = items.duplicate()

func enqueue(origin_cell: int, site: int = -1) -> void:
	_queue.append(origin_cell)
	_sites.append(site)


## Platziert so viele wartende Arbeiter wie möglich. Gibt die Anzahl neuer Arbeiter zurück.
## `forbidden` markiert Zellen, die durchlaufen, aber nicht belegt werden dürfen.
func process(
	world: WorldState,
	workers: WorkerStore,
	quotas: PackedInt32Array,
	forbidden: PackedByteArray = PackedByteArray(),
	sim: Simulation = null,
) -> int:
	var spawned := 0
	while _head < _queue.size():
		if sim != null and _sites[_head] >= 0:
			var site := _sites[_head]
			if not sim.construction.sites.valid(site):
				sim.rules.removed_mass += 1
				_head += 1
				continue
			_queue[_head] = sim.construction.origin(sim, site)
		var cell := find_free_cell(world, workers, _queue[_head], forbidden)
		if cell < 0:
			break
		workers.add(cell, GroupQuotas.pick_group(workers.group_mass, quotas))
		_head += 1
		spawned += 1
	if _head > 1024 and _head * 2 > _queue.size():
		_queue = _queue.slice(_head)
		_sites = _sites.slice(_head)
		_head = 0
	return spawned


## Nächste freie leere Zelle ab `origin` (inklusive) oder -1.
func find_free_cell(
	world: WorldState, workers: WorkerStore, origin: int, forbidden: PackedByteArray = PackedByteArray()
) -> int:
	var found := find_free_cells(world, workers, origin, 1, _search_limit, forbidden)
	return -1 if found.is_empty() else found[0]


## Bis zu `want` freie leere Zellen in BFS-Reihenfolge (N, O, S, W) ab `origin`.
## `limit` begrenzt die Zahl untersuchter Zellen. Die Zellen werden nicht belegt.
## Verbotene leere Zellen werden durchquert, aber nicht als Ergebnis genommen.
func find_free_cells(
	world: WorldState,
	workers: WorkerStore,
	origin: int,
	want: int,
	limit: int,
	forbidden: PackedByteArray = PackedByteArray(),
) -> PackedInt32Array:
	var result := PackedInt32Array()
	if origin < 0 or origin >= world.cell_count() or world.cells[origin] != Materials.EMPTY:
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
		if workers.is_free(c) and not _forbidden(forbidden, c):
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


func _forbidden(forbidden: PackedByteArray, idx: int) -> bool:
	return idx >= 0 and idx < forbidden.size() and forbidden[idx] == 1


func cancel_site(site: int) -> int:
	var origins := PackedInt32Array()
	var bindings := PackedInt32Array()
	var cancelled := 0
	for i in range(_head, _queue.size()):
		if _sites[i] == site:
			cancelled += 1
		else:
			origins.append(_queue[i])
			bindings.append(_sites[i])
	import_queue(origins)
	import_sites(bindings)
	return cancelled

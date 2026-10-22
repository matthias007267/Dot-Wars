class_name FlowField
extends RefCounted
## Gemeinsame Zielsuche einer Gruppe.
##
## Quellen sind leere Zellen, die orthogonal an festes, markiertes Material der Gruppe grenzen.
## Eine Multi-Source-BFS über leere Zellen liefert für jede erreichbare Zelle die Distanz zur
## nächsten Quelle und die Richtung des nächsten Schritts. Das Ergebnis gilt für alle Arbeiter der
## Gruppe, es gibt keine individuelle Wegsuche.
##
## Die Berechnung ist in Phasen (Quellen suchen, Ausbreiten) mit festem Budget pro Aufruf
## zerlegt und schreibt in einen Hintergrundpuffer. Erst nach Abschluss wird getauscht.

const DIR_NONE := 0
const DIR_UP := 1
const DIR_RIGHT := 2
const DIR_DOWN := 3
const DIR_LEFT := 4
## Der Arbeiter steht bereits auf einer Abbauposition.
const DIR_ARRIVED := 5

const UNREACHABLE := -1

enum Phase { IDLE, SEED, SPREAD }

## Veröffentlichtes Ergebnis (wird von Arbeitern gelesen).
var dist := PackedInt32Array()
var dir := PackedByteArray()
## Wird bei jeder Veröffentlichung erhöht.
var generation: int = 0

var _group: int
var _world: WorldState
var _areas: DigAreas
var _next_dist := PackedInt32Array()
var _next_dir := PackedByteArray()
var _queue := PackedInt32Array()
var _head: int = 0
var _phase: Phase = Phase.IDLE
var _rect_index: int = 0
var _scan_pos: int = 0
var _rect_solid := PackedInt32Array()
var _built_world_revision: int = -1
var _built_area_revision: int = -1


func _init(world: WorldState, areas: DigAreas, group_id: int) -> void:
	_world = world
	_areas = areas
	_group = group_id
	var n := world.cell_count()
	dist.resize(n)
	dist.fill(UNREACHABLE)
	dir.resize(n)
	dir.fill(DIR_NONE)
	_next_dist = dist.duplicate()
	_next_dir = dir.duplicate()


func is_building() -> bool:
	return _phase != Phase.IDLE


## Führt höchstens `budget` Zellbesuche aus und startet bei veralteten Daten einen neuen Aufbau.
func step(budget: int) -> void:
	if _phase != Phase.IDLE and _areas.revision != _built_area_revision:
		_begin()
	elif _phase == Phase.IDLE:
		if _world.revision == _built_world_revision and _areas.revision == _built_area_revision:
			return
		_begin()
	var remaining := budget
	while remaining > 0 and _phase != Phase.IDLE:
		if _phase == Phase.SEED:
			remaining = _scan_seeds(remaining)
		else:
			remaining = _spread(remaining)


## Baut das Feld vollständig (Tests, Benchmark).
func rebuild_blocking() -> void:
	_begin()
	while _phase != Phase.IDLE:
		if _phase == Phase.SEED:
			_scan_seeds(1 << 40)
		else:
			_spread(1 << 40)


func _begin() -> void:
	_built_world_revision = _world.revision
	_built_area_revision = _areas.revision
	_next_dist.fill(UNREACHABLE)
	_next_dir.fill(DIR_NONE)
	_queue.clear()
	_head = 0
	_rect_index = 0
	_scan_pos = 0
	var rects: Array[Rect2i] = _areas.rects[_group]
	_rect_solid.resize(rects.size())
	_rect_solid.fill(0)
	_phase = Phase.SEED


func _scan_seeds(budget: int) -> int:
	var rects: Array[Rect2i] = _areas.rects[_group]
	var cells := _world.cells
	var w := _world.width
	var h := _world.height
	var remaining := budget
	while _rect_index < rects.size():
		var rect := rects[_rect_index]
		var total := rect.size.x * rect.size.y
		while _scan_pos < total:
			if remaining <= 0:
				return 0
			remaining -= 1
			var x := rect.position.x + _scan_pos % rect.size.x
			var y := rect.position.y + _scan_pos / rect.size.x
			_scan_pos += 1
			var idx := y * w + x
			if cells[idx] == Materials.EMPTY:
				continue
			_rect_solid[_rect_index] += 1
			if x > 0:
				_seed(idx - 1)
			if x < w - 1:
				_seed(idx + 1)
			if y > 0:
				_seed(idx - w)
			if y < h - 1:
				_seed(idx + w)
		_rect_index += 1
		_scan_pos = 0
	_phase = Phase.SPREAD
	return remaining


func _seed(idx: int) -> void:
	if _world.cells[idx] == Materials.EMPTY and _next_dist[idx] == UNREACHABLE:
		_next_dist[idx] = 0
		_next_dir[idx] = DIR_ARRIVED
		_queue.append(idx)


func _spread(budget: int) -> int:
	var w := _world.width
	var size := _world.cell_count()
	var remaining := budget
	while _head < _queue.size():
		if remaining <= 0:
			return 0
		remaining -= 1
		var idx := _queue[_head]
		_head += 1
		var next_distance := _next_dist[idx] + 1
		var x := idx % w
		# Ein Nachbar erreicht `idx`, indem er sich in Richtung `idx` bewegt.
		if x > 0:
			_relax(idx - 1, next_distance, DIR_RIGHT)
		if x < w - 1:
			_relax(idx + 1, next_distance, DIR_LEFT)
		if idx >= w:
			_relax(idx - w, next_distance, DIR_DOWN)
		if idx < size - w:
			_relax(idx + w, next_distance, DIR_UP)
	_publish()
	return remaining


func _relax(idx: int, distance: int, direction: int) -> void:
	if _world.cells[idx] == Materials.EMPTY and _next_dist[idx] == UNREACHABLE:
		_next_dist[idx] = distance
		_next_dir[idx] = direction
		_queue.append(idx)


func _publish() -> void:
	var swap_dist := dist
	dist = _next_dist
	_next_dist = swap_dist
	var swap_dir := dir
	dir = _next_dir
	_next_dir = swap_dir
	generation += 1
	_phase = Phase.IDLE
	var finished := PackedInt32Array()
	for i in _rect_solid.size():
		if _rect_solid[i] == 0:
			finished.append(i)
	if not finished.is_empty():
		_areas.remove_rects(_group, finished)

class_name FlowField
extends RefCounted
## Gemeinsame Zielsuche einer Gruppe.
##
## Quellen sind leere Zellen neben festem, markiertem Material und ein gesetztes Laufziel.
## Eine Multi-Source-BFS über leere Zellen liefert für jede erreichbare Zelle die Distanz zur
## nächsten Quelle und die Richtung des nächsten Schritts. Das Ergebnis gilt für alle Arbeiter der
## Gruppe, es gibt keine individuelle Wegsuche.
##
## Die Berechnung ist in Phasen (Quellen suchen, Ausbreiten, lokale Korrektur) mit festem
## Budget pro Aufruf zerlegt und schreibt in einen Hintergrundpuffer. Erst nach Abschluss
## wird getauscht. Wenige geänderte Zellen korrigieren das letzte veröffentlichte Feld.
## Ein neues Gebiet, ein neues Laufziel oder eine große Änderung bauen es vollständig neu.

const DIR_NONE := 0
const DIR_UP := 1
const DIR_RIGHT := 2
const DIR_DOWN := 3
const DIR_LEFT := 4
## Der Arbeiter steht bereits auf einer Abbauposition.
const DIR_ARRIVED := 5

const UNREACHABLE := -1

enum Phase { IDLE, SEED, SPREAD, PATCH }

## Mehr geöffnete Zellen als das: vollständiger Neuaufbau statt lokaler Korrektur.
const PATCH_CELL_LIMIT := 32
## Größerer Abhängigkeitskegel: die Korrektur würde einen Takt zu lange blockieren.
const PATCH_CLEAR_LIMIT := 8192

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
var _applied_changes: int = 0
var _applied_epoch: int = 0
var _published_changes: int = 0
var _published_epoch: int = 0
var _published_revision: int = -1
var _count_rects_on_publish: bool = false
var _improve: bool = false
## Vollständige Aufbauten und abgeschlossene lokale Korrekturen.
var full_rebuilds: int = 0
var patches: int = 0
## Leere Zielzelle der Gruppe. -1 heißt: kein Laufziel, nur Abbaugebiete.
var goal_cell: int = -1
## 1 verbietet die Zelle für Arbeiter. Leer heißt: nichts gesperrt.
var blocked := PackedByteArray()
var _built_goal: int = -2


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
	var goal_changed := goal_cell != _built_goal
	var area_changed := _areas.revision != _built_area_revision
	var world_changed := _world.revision != _built_world_revision or _world.change_epoch != _applied_epoch
	if _phase != Phase.IDLE and (area_changed or goal_changed or world_changed):
		if _phase == Phase.PATCH and world_changed and not area_changed and not goal_changed:
			_restart_patch_from_published()
		else:
			_begin()
	elif _phase == Phase.IDLE:
		if not area_changed and not goal_changed and not world_changed:
			return
		if area_changed or goal_changed or generation == 0 or not _can_patch():
			_begin()
		else:
			_begin_patch()
	var remaining := budget
	while remaining > 0 and _phase != Phase.IDLE:
		if _phase == Phase.SEED:
			remaining = _scan_seeds(remaining)
		elif _phase == Phase.PATCH:
			remaining = _spread(remaining)
		else:
			remaining = _spread(remaining)


## Der nächste Takt baut das Feld neu, auch wenn die Welt sich nicht geändert hat.
func force_rebuild() -> void:
	_built_world_revision = -1
	_applied_changes = _world.change_log.size()
	_applied_epoch = _world.change_epoch


## Baut das Feld vollständig (Tests, Benchmark).
func rebuild_blocking() -> void:
	_begin()
	while _phase != Phase.IDLE:
		if _phase == Phase.SEED:
			_scan_seeds(1 << 40)
		else:
			_spread(1 << 40)


func _begin() -> void:
	full_rebuilds += 1
	_count_rects_on_publish = false
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
	_built_goal = goal_cell
	_applied_changes = _world.change_log.size()
	_applied_epoch = _world.change_epoch
	_improve = false
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
			if not Materials.is_mineable(cells[idx]):
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
	if goal_cell >= 0 and _open(goal_cell):
		_seed(goal_cell)
	_phase = Phase.SPREAD
	return remaining


func _open(idx: int) -> bool:
	if idx < 0 or idx >= _world.cell_count() or _world.cells[idx] != Materials.EMPTY:
		return false
	return blocked.is_empty() or idx >= blocked.size() or blocked[idx] == 0


func _seed(idx: int) -> void:
	if _open(idx) and _next_dist[idx] == UNREACHABLE:
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
	if not _open(idx):
		return
	if _improve:
		if _next_dist[idx] != UNREACHABLE and _next_dist[idx] <= distance:
			return
	elif _next_dist[idx] != UNREACHABLE:
		return
	_next_dist[idx] = distance
	_next_dir[idx] = direction
	_queue.append(idx)


func _can_patch() -> bool:
	var pending := _world.change_log.size() - _applied_changes
	return pending > 0 and pending <= PATCH_CELL_LIMIT and _world.change_epoch == _applied_epoch


func _begin_patch() -> void:
	var changed := _world.change_log.slice(_applied_changes)
	_built_world_revision = _world.revision
	_applied_changes = _world.change_log.size()
	_applied_epoch = _world.change_epoch
	_built_goal = goal_cell
	_next_dist = dist.duplicate()
	_next_dir = dir.duplicate()
	_queue.clear()
	_head = 0
	_improve = true
	_count_rects_on_publish = true
	var lost := PackedInt32Array()
	for idx in changed:
		if _world.cells[idx] != Materials.EMPTY and _next_dist[idx] >= 0:
			lost.append(idx)
		_note_lost_sources(idx, lost)
	var cleared := PackedInt32Array()
	if not _clear_dependents(lost, cleared):
		_begin()
		return
	for idx in changed:
		_reseed_opened(idx)
	for idx in cleared:
		_reseed_opened(idx)
	_phase = Phase.PATCH


func _note_lost_sources(idx: int, lost: PackedInt32Array) -> void:
	var width := _world.width
	var count := _world.cell_count()
	var neighbors := PackedInt32Array()
	_collect_neighbors(idx, width, count, neighbors)
	for cell in neighbors:
		if _next_dist[cell] == 0 and _next_dir[cell] == DIR_ARRIVED and not _is_source(cell):
			lost.append(cell)


func _clear_dependents(roots: PackedInt32Array, cleared: PackedInt32Array) -> bool:
	if roots.is_empty():
		return true
	var width := _world.width
	var count := _world.cell_count()
	var pending := roots.duplicate()
	var old_dist := PackedInt32Array()
	old_dist.resize(roots.size())
	for i in roots.size():
		if _next_dist[roots[i]] == UNREACHABLE:
			old_dist[i] = -1
			continue
		old_dist[i] = _next_dist[roots[i]]
		_next_dist[roots[i]] = UNREACHABLE
		_next_dir[roots[i]] = DIR_NONE
		cleared.append(roots[i])
	var head := 0
	var neighbors := PackedInt32Array()
	while head < pending.size():
		if pending.size() > PATCH_CLEAR_LIMIT:
			return false
		var parent := pending[head]
		var parent_dist := old_dist[head]
		head += 1
		if parent_dist < 0:
			continue
		_collect_neighbors(parent, width, count, neighbors)
		for cell in neighbors:
			if _next_dist[cell] != parent_dist + 1:
				continue
			if MovementSystem.neighbor(cell, _next_dir[cell], width, count) != parent:
				continue
			old_dist.append(_next_dist[cell])
			_next_dist[cell] = UNREACHABLE
			_next_dir[cell] = DIR_NONE
			pending.append(cell)
			cleared.append(cell)
	return true


func _reseed_opened(idx: int) -> void:
	if not _open(idx):
		return
	if _is_source(idx):
		_next_dist[idx] = 0
		_next_dir[idx] = DIR_ARRIVED
		_queue.append(idx)
		return
	var width := _world.width
	var count := _world.cell_count()
	var neighbors := PackedInt32Array()
	_collect_neighbors(idx, width, count, neighbors)
	for cell in neighbors:
		if _next_dist[cell] >= 0:
			_queue.append(cell)


func _is_source(idx: int) -> bool:
	if not _open(idx):
		return false
	if idx == goal_cell:
		return true
	var mask: PackedByteArray = _areas.masks[_group]
	var cells := _world.cells
	var width := _world.width
	var count := _world.cell_count()
	var x := idx % width
	if idx >= width and Materials.is_mineable(cells[idx - width]) and mask[idx - width] == 1:
		return true
	if x < width - 1 and Materials.is_mineable(cells[idx + 1]) and mask[idx + 1] == 1:
		return true
	if idx + width < count and Materials.is_mineable(cells[idx + width]) and mask[idx + width] == 1:
		return true
	if x > 0 and Materials.is_mineable(cells[idx - 1]) and mask[idx - 1] == 1:
		return true
	return false


func _collect_neighbors(idx: int, width: int, count: int, into: PackedInt32Array) -> void:
	into.resize(0)
	var x := idx % width
	if idx >= width:
		into.append(idx - width)
	if x < width - 1:
		into.append(idx + 1)
	if idx + width < count:
		into.append(idx + width)
	if x > 0:
		into.append(idx - 1)


func _restart_patch_from_published() -> void:
	_applied_changes = _published_changes
	_applied_epoch = _published_epoch
	_built_world_revision = _published_revision
	_phase = Phase.IDLE
	_count_rects_on_publish = false
	if generation == 0 or not _can_patch():
		_begin()
	else:
		_begin_patch()


func _apply_rect_deltas() -> void:
	var log := _world.change_log
	var origins := _world.change_from
	if origins.size() != log.size():
		return
	if _published_changes < 0 or _applied_changes > log.size() or _published_changes > _applied_changes:
		return
	var rects: Array[Rect2i] = _areas.rects[_group]
	var width := _world.width
	for n in range(_published_changes, _applied_changes):
		var was := origins[n]
		var idx := log[n]
		var now := _world.cells[idx]
		var delta := 0
		if Materials.is_mineable(was) and not Materials.is_mineable(now):
			delta = -1
		elif Materials.is_mineable(now) and not Materials.is_mineable(was):
			delta = 1
		if delta == 0:
			continue
		var point := Vector2i(idx % width, idx / width)
		var limit := mini(rects.size(), _rect_solid.size())
		for i in limit:
			if rects[i].has_point(point):
				_rect_solid[i] += delta


func _publish() -> void:
	if _count_rects_on_publish:
		_apply_rect_deltas()
		patches += 1
		_count_rects_on_publish = false
	var swap_dist := dist
	dist = _next_dist
	_next_dist = swap_dist
	var swap_dir := dir
	dir = _next_dir
	_next_dir = swap_dir
	generation += 1
	_phase = Phase.IDLE
	_published_changes = _applied_changes
	_published_epoch = _applied_epoch
	_published_revision = _built_world_revision
	var finished := PackedInt32Array()
	for i in _rect_solid.size():
		if _rect_solid[i] == 0:
			finished.append(i)
	if not finished.is_empty():
		_areas.remove_rects(_group, finished)
		for i in range(finished.size() - 1, -1, -1):
			_rect_solid.remove_at(finished[i])

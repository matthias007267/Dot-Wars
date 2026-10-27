class_name FlowField
extends RefCounted

const NATIVE_SEARCH = preload("res://src/sim/native_search.gd")
## Gemeinsame Zielsuche einer Gruppe.
##
## Quellen sind leere Zellen neben festem, markiertem Material und der nächstmögliche Standpunkt
## eines Laufziels. Liegt das Ziel in der erreichbaren Fläche, ist das der Zielpunkt selbst.
## Sonst ist es die erreichbare leere Zelle mit dem kleinsten Manhattan-Abstand. Eine
## Multi-Source-BFS über leere Zellen liefert für jede erreichbare Zelle die Distanz zur nächsten
## Quelle und die Richtung des nächsten Schritts. Das Ergebnis gilt für alle Arbeiter der Gruppe.
##
## Die Berechnung ist in Phasen (Quellen suchen, Ausbreiten, lokale Korrektur) mit festem
## Budget pro Aufruf zerlegt und schreibt in einen Hintergrundpuffer. Erst nach Abschluss
## wird getauscht. Wenige geänderte Zellen korrigieren das letzte veröffentlichte Feld.
## Ein neues Gebiet, ein neues Laufziel oder eine große Änderung bauen es vollständig neu.
## Eine Zelle außerhalb der Reichweite, ohne Markierung und ohne Anschluss an das Feld, lässt es stehen.

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
## Dieselbe Reichweite wie die automatische Front. Darüber hinaus gilt eine Zelle nur,
## wenn sie markiert ist oder an das veröffentlichte Feld grenzt.
const INTEREST_RADIUS := 16
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
var _seed_faces := PackedInt32Array()
var _seed_pos: int = 0
var _seeds_listed: bool = false
var _forced: bool = false
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
## Gewünschter Punkt der Gruppe. Darf fest sein. -1 heißt: kein Laufziel, nur Abbaugebiete.
var goal_cell: int = -1
## Derived from a manual mining march; do not stop at an unrelated nearer wall.
var mining_first := false
var _built_mining_first := false
## Leere Zellen, von denen aus die Gruppe losläuft. Daraus wird der nächstmögliche Standpunkt.
var anchors := PackedInt32Array()
## 1 verbietet die Zelle für Arbeiter. Leer heißt: nichts gesperrt.
var blocked := PackedByteArray()
var _built_goal: int = -2
## Erreichbare Zelle, auf die das veröffentlichte Feld zuläuft. -2 solange noch keines gebaut wurde.
var _stand_cell: int = -2


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
	_areas.attach(world)


func is_building() -> bool:
	return _phase != Phase.IDLE


## Das veröffentlichte Feld gehört zur aktuellen Welt und zum aktuellen Gebiet.
func settled() -> bool:
	return (
		_phase == Phase.IDLE
		and generation > 0
		and _built_area_revision == _area_revision()
		and _built_world_revision == _world.revision
		and _applied_epoch == _world.change_epoch
		and _built_goal == goal_cell
		and _built_mining_first == mining_first
	)


## Führt höchstens `budget` Zellbesuche aus und startet bei veralteten Daten einen neuen Aufbau.
func step(budget: int) -> void:
	var goal_changed := goal_cell != _built_goal or mining_first != _built_mining_first
	var area_changed := _area_revision() != _built_area_revision
	var epoch_gap := _world.change_epoch != _applied_epoch
	var world_changed := _world.revision != _built_world_revision or epoch_gap
	if (
		not _forced
		and _phase == Phase.IDLE
		and generation > 0
		and world_changed
		and not area_changed
		and not goal_changed
		and not epoch_gap
		and not _pending_touches()
	):
		_acknowledge_world()
		world_changed = false
	if _forced and _phase == Phase.IDLE:
		_forced = false
		world_changed = true
	var stand_changed := false
	if _phase == Phase.IDLE and goal_cell >= 0 and (goal_changed or world_changed):
		stand_changed = _nearest_stand() != _stand_cell
	if _phase != Phase.IDLE and (area_changed or goal_changed or world_changed):
		if area_changed or goal_changed:
			_begin()
		elif _phase == Phase.PATCH and (epoch_gap or _pending_touches()):
			_restart_patch_from_published()
		# Ein laufender Vollaufbau liest die Welt mit. Eine geöffnete Zelle setzt ihn nicht zurück.
	elif _phase == Phase.IDLE:
		if not area_changed and not goal_changed and not world_changed and not stand_changed:
			return
		if area_changed or goal_changed or stand_changed or generation == 0 or not _can_patch():
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
	_forced = true
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
	_built_area_revision = _area_revision()
	_next_dist.fill(UNREACHABLE)
	_next_dir.fill(DIR_NONE)
	_queue.clear()
	_head = 0
	_seed_faces = PackedInt32Array()
	_seed_pos = 0
	_seeds_listed = false
	_rect_solid = _areas.sync_counts(_world, _group).duplicate()
	_built_goal = goal_cell
	_built_mining_first = mining_first
	_stand_cell = _nearest_stand()
	_applied_changes = _world.change_log.size()
	_applied_epoch = _world.change_epoch
	_improve = false
	_phase = Phase.SEED


func _scan_seeds(budget: int) -> int:
	if not _seeds_listed:
		_seed_faces = _collect_seed_faces()
		_seeds_listed = true
		_seed_pos = 0
	var w := _world.width
	var remaining := budget
	while _seed_pos < _seed_faces.size():
		if remaining <= 0:
			return 0
		remaining -= 1
		var idx := _seed_faces[_seed_pos]
		_seed_pos += 1
		var x := idx % w
		var y := int(idx / w)
		if x > 0:
			_seed(idx - 1)
		if x < w - 1:
			_seed(idx + 1)
		if y > 0:
			_seed(idx - w)
		if y < _world.height - 1:
			_seed(idx + w)
	if _stand_cell >= 0:
		_seed(_stand_cell)
	_phase = Phase.SPREAD
	return remaining


func _collect_seed_faces() -> PackedInt32Array:
	var result := PackedInt32Array()
	var seen := {}
	var rects: Array[Rect2i] = _areas.rects[_group]
	var mask: PackedByteArray = _areas.masks[_group]
	var lists: Array = _world.face_lists
	var cs := _world.chunk_size
	var w := _world.width
	var cxn := _world.chunks_x
	var cells := _world.cells
	for rect in rects:
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		var batch := PackedInt32Array()
		var x0: int = rect.position.x / cs
		var y0: int = rect.position.y / cs
		var x1: int = (rect.end.x - 1) / cs
		var y1: int = (rect.end.y - 1) / cs
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				var list: PackedInt32Array = lists[cy * cxn + cx]
				for idx in list:
					if seen.has(idx) or mask[idx] != 1:
						continue
					var x := idx % w
					var y := int(idx / w)
					if x < rect.position.x or y < rect.position.y or x >= rect.end.x or y >= rect.end.y:
						continue
					if not Materials.is_mineable(cells[idx]):
						continue
					batch.append(idx)
		batch.sort()
		for idx in batch:
			if seen.has(idx):
				continue
			seen[idx] = true
			result.append(idx)
	return result


func _pending_touches() -> bool:
	var log := _world.change_log
	if _applied_changes > log.size():
		return true
	var mask: PackedByteArray = _areas.masks[_group]
	for n in range(_applied_changes, log.size()):
		if _touches(log[n], mask):
			return true
	return false


func _touches(idx: int, mask: PackedByteArray) -> bool:
	var count := _world.cell_count()
	if idx < 0 or idx >= count:
		return true
	if idx < mask.size() and mask[idx] == 1:
		return true
	if _near_anchor(idx):
		return true
	if idx < dist.size() and dist[idx] >= 0:
		return true
	var width := _world.width
	if idx >= width and dist[idx - width] >= 0:
		return true
	if idx % width < width - 1 and dist[idx + 1] >= 0:
		return true
	if idx + width < count and dist[idx + width] >= 0:
		return true
	if idx % width > 0 and dist[idx - 1] >= 0:
		return true
	return false


func _near_anchor(idx: int) -> bool:
	if anchors.is_empty():
		return false
	var width := _world.width
	var x := idx % width
	var y := int(idx / width)
	for cell in anchors:
		if absi(cell % width - x) + absi(int(cell / width) - y) <= INTEREST_RADIUS:
			return true
	return false


func _acknowledge_world() -> void:
	_built_world_revision = _world.revision
	_applied_changes = _world.change_log.size()
	_applied_epoch = _world.change_epoch
	_published_revision = _built_world_revision
	_published_changes = _applied_changes
	_published_epoch = _applied_epoch


## True, wenn der gewünschte Punkt selbst der nächstmögliche Standpunkt ist.
func goal_is_stand() -> bool:
	return goal_cell >= 0 and _nearest_stand() == goal_cell


## Erreichbare leere Zelle mit dem kleinsten Manhattan-Abstand zum gewünschten Punkt.
## Ohne Anker bleibt ein leeres Ziel der Standpunkt, ein festes Ziel hat keinen.
func _nearest_stand() -> int:
	if mining_first: return -1
	var native := NATIVE_SEARCH.backend()
	if native != null:
		return int(native.nearest_stand(_world.cells, blocked, anchors, _world.width, goal_cell))
	if goal_cell < 0 or goal_cell >= _world.cell_count():
		return -1
	if anchors.is_empty():
		return goal_cell if _open(goal_cell) else -1
	var count := _world.cell_count()
	var seen := PackedByteArray()
	seen.resize(count)
	var queue := PackedInt32Array()
	var best := -1
	var best_rank := 2147483647
	for cell in anchors:
		if cell < 0 or cell >= count or seen[cell] != 0 or not _open(cell):
			continue
		seen[cell] = 1
		queue.append(cell)
		var rank := _manhattan(cell, goal_cell)
		if rank < best_rank:
			best = cell
			best_rank = rank
	var head := 0
	var width := _world.width
	var neighbors := PackedInt32Array()
	while head < queue.size():
		var cell := queue[head]
		head += 1
		_collect_neighbors(cell, width, count, neighbors)
		for next in neighbors:
			if seen[next] != 0 or not _open(next):
				continue
			seen[next] = 1
			queue.append(next)
			var next_rank := _manhattan(next, goal_cell)
			if next_rank < best_rank:
				best = next
				best_rank = next_rank
	return best


func _area_revision() -> int:
	var stamps := _areas.group_revision
	if _group < 0 or _group >= stamps.size():
		return 0
	return stamps[_group]


func _manhattan(a: int, b: int) -> int:
	var width := _world.width
	return absi(a % width - b % width) + absi(a / width - b / width)


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
	var native := NATIVE_SEARCH.backend()
	if native != null:
		var result: Variant = native.flow_spread(_world.cells, blocked, _next_dist, _next_dir, _queue, _head, budget, _improve, _world.width)
		if not result is Array or result.size() != 5:
			push_error("Native Wegfeld-Berechnung fehlgeschlagen")
			return 0
		_next_dist = result[0]
		_next_dir = result[1]
		_queue = result[2]
		_head = int(result[3])
		if _head >= _queue.size():
			_publish()
		return int(result[4])
	var w := _world.width
	var size := _world.cell_count()
	# Dieselbe BFS und dieselben Richtungs-Tiebreaks, aber ohne Hilfsaufruf je Kante.
	var distances := _next_dist
	var directions := _next_dir
	var queue := _queue
	var cells := _world.cells
	var blocked_cells := blocked
	var blocked_count := blocked_cells.size()
	var improve := _improve
	var head := _head
	var tail := queue.size()
	var remaining := budget
	while head < tail:
		if remaining <= 0:
			_head = head
			return 0
		remaining -= 1
		var idx := queue[head]
		head += 1
		var next_distance := distances[idx] + 1
		var x := idx % w
		for edge in 4:
			var next: int
			var direction: int
			match edge:
				0:
					if x <= 0:
						continue
					next = idx - 1
					direction = DIR_RIGHT
				1:
					if x >= w - 1:
						continue
					next = idx + 1
					direction = DIR_LEFT
				2:
					if idx < w:
						continue
					next = idx - w
					direction = DIR_DOWN
				_:
					if idx >= size - w:
						continue
					next = idx + w
					direction = DIR_UP
			if int(cells[next]) != Materials.EMPTY or (next < blocked_count and blocked_cells[next] != 0):
				continue
			var previous := distances[next]
			if improve:
				if previous != UNREACHABLE and previous <= next_distance:
					continue
			elif previous != UNREACHABLE:
				continue
			distances[next] = next_distance
			directions[next] = direction
			queue.append(next)
			tail += 1
	_head = head
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
	if idx == _stand_cell:
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

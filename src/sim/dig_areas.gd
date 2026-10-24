class_name DigAreas
extends RefCounted
## Abbaugebiete je Gruppe: Rechteckliste (für die Zielsuche) und Maske (für O(1)-Abfragen).

var group_count: int
var width: int
var height: int
## Je Gruppe ein Array[Rect2i], bereits auf die Welt zugeschnitten.
var rects: Array = []
## Je Gruppe ein PackedByteArray (1 = Zelle gehört zum Abbaugebiet).
var masks: Array = []
## Ändert sich bei jeder semantischen Änderung der Gebiete (nicht beim Aufräumen).
var revision: int = 0
## Dieselbe Zählung je Gruppe. Ein Auftrag einer Gruppe startet die Wegsuche der anderen nicht neu.
var group_revision := PackedInt32Array()
## Abbaubare Zellen je Rechteck. -1 heißt: noch nicht gezählt. Abgeleitet, nicht im Hash.
var mineable_counts: Array = []
var _world_ref: WeakRef


func _init(p_width: int, p_height: int, p_group_count: int) -> void:
	width = p_width
	height = p_height
	group_count = p_group_count
	group_revision.resize(group_count)
	group_revision.fill(0)
	for g in group_count:
		rects.append([] as Array[Rect2i])
		mineable_counts.append(PackedInt32Array())
		var mask := PackedByteArray()
		mask.resize(width * height)
		mask.fill(0)
		masks.append(mask)


## Fügt ein Abbaugebiet hinzu. Liegt es teilweise außerhalb, wird es zugeschnitten.
## Gibt false zurück, wenn nichts übrig bleibt oder die Gruppe ungültig ist.
func assign_rect(group_id: int, rect: Rect2i) -> bool:
	if group_id < 0 or group_id >= group_count:
		return false
	var clipped := rect.abs().intersection(Rect2i(0, 0, width, height))
	if not clipped.has_area():
		return false
	var group_rects: Array[Rect2i] = rects[group_id]
	group_rects.append(clipped)
	var counts: PackedInt32Array = mineable_counts[group_id]
	var world := _live_world()
	counts.append(_count_rect(world, clipped) if world != null else -1)
	var mask: PackedByteArray = masks[group_id]
	for y in range(clipped.position.y, clipped.end.y):
		var row := y * width
		for x in range(clipped.position.x, clipped.end.x):
			mask[row + x] = 1
	_bump(group_id, 1)
	return true


## Markiert einzelne Zellen und zählt sie wie ebenso viele Rechtecke, aber in einem Schritt.
func assign_cells(group_id: int, cells: PackedInt32Array) -> bool:
	if group_id < 0 or group_id >= group_count or cells.is_empty():
		return false
	var mask: PackedByteArray = masks[group_id]
	var group_rects: Array[Rect2i] = rects[group_id]
	var counts: PackedInt32Array = mineable_counts[group_id]
	var world := _live_world()
	var added := 0
	for cell in cells:
		if cell < 0 or cell >= mask.size() or mask[cell] != 0:
			continue
		mask[cell] = 1
		group_rects.append(Rect2i(cell % width, int(cell / width), 1, 1))
		var solid := 0
		if world == null:
			solid = -1
		elif Materials.is_mineable(world.cells[cell]):
			solid = 1
		counts.append(solid)
		added += 1
	if added == 0:
		return false
	_bump(group_id, added)
	return true


func add_group() -> void:
	rects.append([] as Array[Rect2i])
	var mask := PackedByteArray()
	mask.resize(width * height)
	mask.fill(0)
	masks.append(mask)
	mineable_counts.append(PackedInt32Array())
	group_revision.append(0)
	group_count += 1


func clear_group(group_id: int) -> void:
	if group_id < 0 or group_id >= group_count:
		return
	var group_rects: Array[Rect2i] = rects[group_id]
	if group_rects.is_empty():
		return
	group_rects.clear()
	mineable_counts[group_id] = PackedInt32Array()
	var mask: PackedByteArray = masks[group_id]
	mask.fill(0)
	_bump(group_id, 1)


func is_marked(group_id: int, cell_idx: int) -> bool:
	var mask: PackedByteArray = masks[group_id]
	return mask[cell_idx] == 1


## Entfernt Rechtecke ohne verbleibendes festes Material. Ändert die Semantik nicht
## (leere Zellen sind ohnehin nicht abbaubar) und erhöht deshalb `revision` nicht.
func remove_rects(group_id: int, rect_indices: PackedInt32Array) -> void:
	var group_rects: Array[Rect2i] = rects[group_id]
	var counts: PackedInt32Array = mineable_counts[group_id]
	for i in range(rect_indices.size() - 1, -1, -1):
		group_rects.remove_at(rect_indices[i])
		if i < counts.size():
			counts.remove_at(i)


## Hängt die Zählung an die Welt. Ein erneuter Aufruf mit derselben Welt tut nichts.
func attach(world: WorldState) -> void:
	var current := _live_world()
	if current == world:
		return
	if current != null and current.material_changed.is_connected(note_material):
		current.material_changed.disconnect(note_material)
	world.material_changed.connect(note_material)
	_world_ref = weakref(world)
	for g in group_count:
		sync_counts(world, g)


## Liefert die Zählung und zählt sie neu, wenn sie fehlt oder ein Rechteck noch -1 trägt.
func sync_counts(world: WorldState, group_id: int) -> PackedInt32Array:
	var group_rects: Array[Rect2i] = rects[group_id]
	var counts: PackedInt32Array = mineable_counts[group_id]
	var dirty := counts.size() != group_rects.size()
	if not dirty:
		for n in counts:
			if n < 0:
				dirty = true
				break
	if not dirty:
		return counts
	counts = PackedInt32Array()
	counts.resize(group_rects.size())
	for i in group_rects.size():
		counts[i] = _count_rect(world, group_rects[i])
	mineable_counts[group_id] = counts
	return counts


func tracks_material() -> bool:
	return _live_world() != null


func note_material(idx: int, old: int, now: int) -> void:
	var delta := 0
	if Materials.is_mineable(old) and not Materials.is_mineable(now):
		delta = -1
	elif Materials.is_mineable(now) and not Materials.is_mineable(old):
		delta = 1
	if delta == 0:
		return
	var point := Vector2i(idx % width, int(idx / width))
	for g in group_count:
		var group_rects: Array[Rect2i] = rects[g]
		var counts: PackedInt32Array = mineable_counts[g]
		if counts.size() != group_rects.size():
			continue
		var invalid := false
		for n in counts:
			if n < 0:
				invalid = true
				break
		if invalid:
			continue
		for i in group_rects.size():
			if group_rects[i].has_point(point):
				counts[i] += delta


func state_hash() -> int:
	return hash([hash(rects), hash(masks), revision, hash(group_revision)])


func _bump(group_id: int, amount: int) -> void:
	revision += amount
	group_revision[group_id] += amount


func _live_world() -> WorldState:
	if _world_ref == null:
		return null
	return _world_ref.get_ref() as WorldState


func _count_rect(world: WorldState, rect: Rect2i) -> int:
	if world == null:
		return -1
	var total := 0
	for y in range(rect.position.y, rect.end.y):
		var row := y * width
		for x in range(rect.position.x, rect.end.x):
			if Materials.is_mineable(world.cells[row + x]):
				total += 1
	return total

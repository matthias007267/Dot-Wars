extends RefCounted
## Additive save data for incremental algorithms whose progress affects choices.
const FLOW := ["dist", "dir", "generation", "_next_dist", "_next_dir", "_queue", "_head", "_phase", "_seed_faces", "_seed_pos", "_seeds_listed", "_forced", "_rect_solid", "_built_world_revision", "_built_area_revision", "_applied_changes", "_applied_epoch", "_published_changes", "_published_epoch", "_published_revision", "_count_rects_on_publish", "_improve", "goal_cell", "anchors", "blocked", "_built_goal", "_stand_cell"]
const ENERGY := ["_dist", "_routed", "_revision", "_width", "_exit_stamp", "_last_rebuild_tick"]
const FRONT := ["_band", "_empty", "_grow", "_cursor", "_epoch", "_min_x", "_min_y", "_max_x", "_max_y", "_snap_ids", "_snap_cells"]

static func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary: return value.duplicate(true)
	if value is PackedInt32Array or value is PackedByteArray: return value.duplicate()
	return value

static func _export(source: Object, names: Array) -> Dictionary:
	var result := {}
	for name in names: result[name] = _copy(source.get(name))
	return result

static func snapshot(sim: Simulation) -> Dictionary:
	var flow: Array[Dictionary] = []
	for field in sim.fields: flow.append(_export(field, FLOW))
	return {"world_revision": sim.world.revision, "change_log": sim.world.change_log.duplicate(),
		"change_from": sim.world.change_from.duplicate(), "change_epoch": sim.world.change_epoch,
		"faces": sim.world.face_lists.duplicate(true), "flow": flow,
		"energy": _export(sim.energy_dots, ENERGY), "front": _export(sim.work_front, FRONT)}

static func _types_match(source: Object, names: Array, data: Variant) -> bool:
	if not data is Dictionary: return false
	for name in names:
		if not data.has(name) or typeof(data[name]) != typeof(source.get(name)): return false
	return true

static func _indices(values: PackedInt32Array, count: int) -> bool:
	for value in values:
		if value < 0 or value >= count: return false
	return true

static func _distances(value: Variant, count: int, allow_empty := false) -> bool:
	if not value is PackedInt32Array: return false
	if value.size() != count and not (allow_empty and value.is_empty()): return false
	for distance in value:
		if distance < -1 or distance > count: return false
	return true

static func _assign(source: Object, names: Array, data: Dictionary) -> void:
	for name in names: source.set(name, _copy(data[name]))

static func restore(sim: Simulation, data: Variant) -> bool:
	if not data is Dictionary: return false
	var n := sim.world.cell_count()
	if not data.get("flow") is Array or data.flow.size() != sim.fields.size(): return false
	if not data.get("change_log") is PackedInt32Array or not data.get("change_from") is PackedInt32Array: return false
	if data.change_log.size() != data.change_from.size() or not _indices(data.change_log, n): return false
	if int(data.get("world_revision", -1)) < 0 or int(data.get("change_epoch", -1)) < 0: return false
	for material in data.change_from:
		if material < 0 or material >= Materials.COUNT: return false
	if not data.get("faces") is Array or data.faces.size() != sim.world.face_lists.size(): return false
	var face_slot := PackedInt32Array()
	face_slot.resize(n)
	face_slot.fill(-1)
	var face_count := 0
	for chunk in data.faces.size():
		var faces: Variant = data.faces[chunk]
		if not faces is PackedInt32Array or not _indices(faces, n): return false
		for at in faces.size():
			var cell: int = faces[at]
			var expected_chunk := (cell / sim.world.width / sim.world.chunk_size) * sim.world.chunks_x + (cell % sim.world.width) / sim.world.chunk_size
			if expected_chunk != chunk or face_slot[cell] != -1 or not Materials.is_mineable(sim.world.cells[cell]): return false
			face_slot[cell] = at
			face_count += 1
	for index in sim.fields.size():
		var field: FlowField = sim.fields[index]
		var row: Variant = data.flow[index]
		if not _types_match(field, FLOW, row): return false
		if not _distances(row.dist, n) or not _distances(row._next_dist, n): return false
		if row.dir.size() != n or row._next_dir.size() != n: return false
		for directions in [row.dir, row._next_dir]:
			for direction in directions:
				if direction > FlowField.DIR_ARRIVED: return false
		if not _indices(row._queue, n) or not _indices(row._seed_faces, n) or not _indices(row.anchors, n): return false
		if row._head < 0 or row._head > row._queue.size() or row._phase < 0 or row._phase > FlowField.Phase.PATCH: return false
		if row._seed_pos < 0 or row._seed_pos > row._seed_faces.size() or row.generation < 0: return false
		if row.blocked.size() != 0 and row.blocked.size() != n: return false
		for key in ["goal_cell", "_built_goal", "_stand_cell"]:
			if row[key] < -2 or row[key] >= n: return false
	if not _types_match(sim.energy_dots, ENERGY, data.get("energy")) or not _types_match(sim.work_front, FRONT, data.get("front")): return false
	if not _distances(data.energy._dist, n, true) or data.energy._routed.size() > 4: return false
	for distances in data.energy._routed:
		if not _distances(distances, n): return false
	var front_size: int = data.front._band.size()
	if front_size > sim.fields.size(): return false
	for key in FRONT:
		if data.front[key].size() != front_size: return false
	for index in front_size:
		if data.front._band[index] < 0 or data.front._band[index] >= WorkFront.RADII.size() or data.front._empty[index] > 1 or data.front._grow[index] > 1: return false
		if data.front._cursor[index] < 0: return false
	for key in ["_snap_ids", "_snap_cells"]:
		for values in data.front[key]:
			if not values is PackedInt32Array: return false
	for index in front_size:
		if data.front._snap_ids[index].size() != data.front._snap_cells[index].size() or not _indices(data.front._snap_ids[index], n) or not _indices(data.front._snap_cells[index], n): return false
	if face_count != sim.world.face_count: return false
	if data.energy._width != 0 and data.energy._width != sim.world.width: return false
	# Apply only after validating the entire payload.
	sim.world.revision = int(data.world_revision)
	sim.world.change_log = data.change_log.duplicate()
	sim.world.change_from = data.change_from.duplicate()
	sim.world.change_epoch = int(data.change_epoch)
	sim.world.face_lists = data.faces.duplicate(true)
	sim.world.face_slot = face_slot
	sim.world.face_count = face_count
	for index in sim.fields.size(): _assign(sim.fields[index], FLOW, data.flow[index])
	_assign(sim.energy_dots, ENERGY, data.energy)
	_assign(sim.work_front, FRONT, data.front)
	return true

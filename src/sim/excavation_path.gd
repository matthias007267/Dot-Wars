class_name ExcavationPath
extends RefCounted
## One deterministic group search per order, independent of swarm intelligence.
## Lexicographic cost: mined blocks, material work, walking steps, cell ID.
const Native = preload("res://src/sim/native_search.gd")


static func find(world: WorldState, blocked: PackedByteArray, origins: PackedInt32Array,
		targets: PackedByteArray, reference_only := false) -> PackedInt32Array:
	var native := Native.backend() if not reference_only else null
	if native != null and native.has_method("excavation_path"):
		var result: Variant = native.excavation_path(world.cells, blocked, origins, targets,
			PackedInt32Array(Materials.WORK), world.width)
		if result is PackedInt32Array: return result
	var count := world.cell_count()
	if targets.size() != count: return PackedInt32Array()
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-2)
	var blocks := parent.duplicate()
	var work := parent.duplicate()
	var steps := parent.duplicate()
	var heap: Array[Vector4i] = []
	for cell in origins:
		if cell < 0 or cell >= count or world.cells[cell] != Materials.EMPTY or _blocked(blocked, cell) or parent[cell] != -2:
			continue
		parent[cell] = -1
		blocks[cell] = 0
		work[cell] = 0
		steps[cell] = 0
		_push(heap, Vector4i(0, 0, 0, cell))
	while not heap.is_empty():
		var item := _pop(heap)
		var cell := item.w
		if item.x != blocks[cell] or item.y != work[cell] or item.z != steps[cell]: continue
		if targets[cell] == 1:
			var path := PackedInt32Array()
			while cell >= 0:
				path.append(cell)
				cell = parent[cell]
			return path
		for direction in range(1, 5):
			var next := MovementSystem.neighbor(cell, direction, world.width, count)
			if next < 0 or _blocked(blocked, next): continue
			var material := int(world.cells[next])
			if material != Materials.EMPTY and not Materials.is_mineable(material): continue
			if item.y > 2147483647 - Materials.WORK[material]: continue
			var candidate := Vector4i(item.x + int(material != Materials.EMPTY),
				item.y + Materials.WORK[material], item.z + 1, next)
			var old := Vector4i(blocks[next], work[next], steps[next], next)
			if parent[next] != -2 and not _less(candidate, old): continue
			parent[next] = cell
			blocks[next] = candidate.x
			work[next] = candidate.y
			steps[next] = candidate.z
			_push(heap, candidate)
	return PackedInt32Array()


static func _blocked(blocked: PackedByteArray, cell: int) -> bool:
	return cell < blocked.size() and blocked[cell] != 0


static func _less(a: Vector4i, b: Vector4i) -> bool:
	if a.x != b.x: return a.x < b.x
	if a.y != b.y: return a.y < b.y
	if a.z != b.z: return a.z < b.z
	return a.w < b.w


static func _push(heap: Array[Vector4i], item: Vector4i) -> void:
	var at := heap.size()
	heap.append(item)
	while at > 0:
		var parent := (at - 1) / 2
		if not _less(item, heap[parent]): break
		heap[at] = heap[parent]
		at = parent
	heap[at] = item


static func _pop(heap: Array[Vector4i]) -> Vector4i:
	var result := heap[0]
	var last: Vector4i = heap.pop_back()
	if heap.is_empty(): return result
	var at := 0
	while at * 2 + 1 < heap.size():
		var child := at * 2 + 1
		if child + 1 < heap.size() and _less(heap[child + 1], heap[child]): child += 1
		if not _less(heap[child], last): break
		heap[at] = heap[child]
		at = child
	heap[at] = last
	return result

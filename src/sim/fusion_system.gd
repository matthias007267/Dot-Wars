class_name FusionSystem
extends RefCounted
## Baut Einheiten auf die Wunschgröße der Gruppe um. Masse, Fraktion und Gruppe bleiben.


## Höchstens so viele Verschmelzungen je Gruppe und Takt.
const FUSIONS_PER_TICK := 4


static func step(workers: WorkerStore, world: WorldState, desired: PackedByteArray) -> void:
	var pending := false
	for group_id in desired.size():
		if desired[group_id] != 1:
			pending = true
			break
	if not pending and workers.max_size == 1:
		return
	for group_id in desired.size():
		var target := int(desired[group_id])
		if target < 1:
			target = 1
		_split_mismatches(workers, group_id, target)
		if target > 1:
			_fuse_group(workers, world, group_id, target)


static func _split_mismatches(workers: WorkerStore, group_id: int, target: int) -> void:
	var id := 0
	while id < workers.count:
		if workers.group[id] != group_id or workers.size[id] == target or workers.size[id] == 1:
			id += 1
			continue
		var faction_id := int(workers.faction[id])
		var anchor := workers.cell[id]
		var unit_size := int(workers.size[id])
		var removed := workers.remove_swap(id)
		for dy in unit_size:
			for dx in unit_size:
				workers.add(anchor + dy * workers.world_width + dx, group_id, faction_id)
		if removed < 0:
			id = workers.count
		# Die nachgerückte Einheit liegt auf derselben ID und wird erneut geprüft.


static func _fuse_group(workers: WorkerStore, world: WorldState, group_id: int, target: int) -> void:
	var need := target * target
	var done := 0
	while done < FUSIONS_PER_TICK:
		var parts := PackedInt32Array()
		for id in workers.count:
			if workers.group[id] == group_id and workers.size[id] == 1:
				parts.append(id)
				if parts.size() == need:
					break
		if parts.size() < need:
			return
		var anchor := _find_anchor(workers, world, parts, target)
		if anchor < 0:
			return
		var faction_id := int(workers.faction[parts[0]])
		var doomed := parts.duplicate()
		doomed.sort()
		var cursor := doomed.size() - 1
		while cursor >= 0:
			var removed_id := doomed[cursor]
			var last := workers.count - 1
			workers.remove_swap(removed_id)
			if removed_id != last:
				for earlier in cursor:
					if doomed[earlier] == last:
						doomed[earlier] = removed_id
			cursor -= 1
		workers.add_sized(anchor, group_id, faction_id, target)
		done += 1


static func _find_anchor(
	workers: WorkerStore, world: WorldState, parts: PackedInt32Array, target: int
) -> int:
	var width := world.width
	for id in parts:
		var origin := workers.cell[id]
		var ox := origin % width
		var oy := origin / width
		for dy in range(1 - target, 1):
			for dx in range(1 - target, 1):
				var x := ox + dx
				var y := oy + dy
				if x < 0 or y < 0:
					continue
				var anchor := y * width + x
				if _square_free(workers, world, anchor, target, parts):
					return anchor
	return -1


static func _square_free(
	workers: WorkerStore, world: WorldState, anchor: int, target: int, parts: PackedInt32Array
) -> bool:
	var width := world.width
	var x0 := anchor % width
	var y0 := anchor / width
	if x0 + target > width or y0 + target > world.height:
		return false
	var allowed := {}
	for id in parts:
		allowed[id] = true
	for dy in target:
		for dx in target:
			var idx := anchor + dy * width + dx
			if world.cells[idx] != Materials.EMPTY:
				return false
			var occ := workers.occupant[idx]
			if occ != WorkerStore.NO_WORKER and not allowed.has(occ):
				return false
	return true

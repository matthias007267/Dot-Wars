class_name DigGuidance
extends RefCounted
## Ergänzt Abbauaufträge, wenn das gesetzte Gebiet nicht erreichbar ist oder nichts mehr enthält.
## Ein Laufziel bleibt unangetastet. Die Ergänzung ist ein Pfad oder die nächste Arbeitsfront.

const REACHABLE := 0
const TOWARD := 1
const NEAREST := 2
const EMPTY := 3
## So viele nächste Felszellen sucht sich eine freie Gruppe auf einmal.
const FRONTIER_CAP := 32


## Prüft ein neues Rechteck, bevor das Wegfeld neu gerechnet ist.
static func preview(sim: Simulation, group_id: int, rect: Rect2i) -> int:
	var mineable := _mineable_in_rect(sim.world, rect)
	if mineable.is_empty():
		return EMPTY
	var reached := _empty_component(sim, group_id)
	if _touches_any(sim.world, reached, mineable):
		return REACHABLE
	return TOWARD


## Hängt einen Pfad oder die nächste Ressource an, sobald das Wegfeld fertig und ohne Zugang ist.
static func consider(sim: Simulation, group_id: int) -> int:
	if group_id < 0 or group_id >= sim.fields.size():
		return REACHABLE
	if sim.move_goal(group_id) >= 0:
		return REACHABLE
	if not _has_worker(sim, group_id):
		return REACHABLE
	var field := sim.fields[group_id]
	if not field.settled():
		return REACHABLE
	if _worker_reaches_field(sim, group_id):
		return REACHABLE
	if _has_mineable_order(sim, group_id):
		if _mark_path(sim, group_id):
			return TOWARD
		return REACHABLE
	if sim.command_group == group_id and sim.march_cell >= 0:
		return REACHABLE
	if _mark_nearest(sim, group_id):
		return NEAREST
	return REACHABLE


const ROUTE_BLOCKED := -1
const ROUTE_CLEAR := 0
const ROUTE_MINING := 1


## Markiert abbaubare Zellen auf dem kürzesten Weg der Gruppe zur Zielzelle.
static func mark_route(sim: Simulation, group_id: int, goal: int) -> int:
	var world := sim.world
	var width := world.width
	var count := world.cell_count()
	if goal < 0 or goal >= count:
		return ROUTE_BLOCKED
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-2)
	var queue := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.group[id] != group_id:
			continue
		var cell := sim.workers.cell[id]
		if world.cells[cell] != Materials.EMPTY or parent[cell] != -2:
			continue
		parent[cell] = -1
		queue.append(cell)
	if queue.is_empty():
		return ROUTE_BLOCKED
	var found := -1
	var head := 0
	while head < queue.size() and found < 0:
		var cell := queue[head]
		head += 1
		if cell == goal:
			found = cell
			break
		for next in _neighbors(cell, width, count):
			if parent[next] != -2:
				continue
			if next == goal or world.cells[next] == Materials.EMPTY or Materials.is_mineable(world.cells[next]):
				parent[next] = cell
				if next == goal:
					found = next
					break
				queue.append(next)
	if found < 0:
		return ROUTE_BLOCKED
	var along := PackedInt32Array()
	var step := found
	var mask: PackedByteArray = sim.areas.masks[group_id]
	# Der Arbeitskorridor wird aus den tatsächlich zum Auftrag gehörenden Dots abgeleitet,
	# nicht aus festen Engine-Gruppen. Kleine Trupps graben schmal, große Schwärme parallel.
	var radius := tunnel_radius(sim.workers.group_counts[group_id])
	while step >= 0:
		if Materials.is_mineable(world.cells[step]) and mask[step] == 0:
			along.append(step)
		var previous := int(parent[step])
		if previous >= 0 and radius > 0:
			var horizontal := absi(step % width - previous % width) == 1
			var x := step % width
			var y := int(step / width)
			for offset in range(-radius, radius + 1):
				if offset == 0:
					continue
				var side_x := x if horizontal else x + offset
				var side_y := y + offset if horizontal else y
				if side_x < 0 or side_x >= width or side_y < 0 or side_y >= world.height:
					continue
				var side := side_y * width + side_x
				if mask[side] == 0 and Materials.is_mineable(world.cells[side]):
					along.append(side)
		step = previous
	if along.is_empty():
		return ROUTE_CLEAR
	return ROUTE_MINING if sim.assign_cells(group_id, along) else ROUTE_CLEAR


## Breite 1, 3, 5, 7 oder 9 Zellen je nach aktivem Auftragsschwarm.
static func tunnel_radius(moving_dots: int) -> int:
	if moving_dots < 6:
		return 0
	if moving_dots < 16:
		return 1
	if moving_dots < 40:
		return 2
	if moving_dots < 100:
		return 3
	return 4


static func _worker_reaches_field(sim: Simulation, group_id: int) -> bool:
	var field := sim.fields[group_id]
	for id in sim.workers.count:
		if sim.workers.group[id] != group_id:
			continue
		if field.dist[sim.workers.cell[id]] >= 0:
			return true
	return false


static func _has_worker(sim: Simulation, group_id: int) -> bool:
	for id in sim.workers.count:
		if sim.workers.group[id] == group_id:
			return true
	return false


static func _has_mineable_order(sim: Simulation, group_id: int) -> bool:
	var counts: PackedInt32Array = sim.areas.mineable_counts[group_id]
	var rects: Array = sim.areas.rects[group_id]
	if sim.areas.tracks_material() and counts.size() == rects.size():
		var known := true
		for n in counts:
			if n < 0:
				known = false
				break
			if n > 0:
				return true
		if known:
			return false
	for rect in rects:
		if not _mineable_in_rect(sim.world, rect).is_empty():
			return true
	return false


static func _mineable_in_rect(world: WorldState, rect: Rect2i) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var clipped := rect.abs().intersection(Rect2i(0, 0, world.width, world.height))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			var idx := y * world.width + x
			if Materials.is_mineable(world.cells[idx]):
				cells.append(idx)
	return cells


static func _empty_component(sim: Simulation, group_id: int) -> PackedByteArray:
	var world := sim.world
	var seen := PackedByteArray()
	seen.resize(world.cell_count())
	var queue := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.group[id] != group_id:
			continue
		var cell := sim.workers.cell[id]
		if world.cells[cell] == Materials.EMPTY and seen[cell] == 0:
			seen[cell] = 1
			queue.append(cell)
	var head := 0
	var width := world.width
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for next in _neighbors(cell, width, world.cell_count()):
			if seen[next] == 0 and world.cells[next] == Materials.EMPTY:
				seen[next] = 1
				queue.append(next)
	return seen


static func _touches_any(world: WorldState, reached: PackedByteArray, targets: PackedInt32Array) -> bool:
	var width := world.width
	for target in targets:
		for next in _neighbors(target, width, world.cell_count()):
			if reached[next] == 1:
				return true
	return false


static func _mark_path(sim: Simulation, group_id: int) -> bool:
	var world := sim.world
	var width := world.width
	var count := world.cell_count()
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-2)
	var queue := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.group[id] != group_id:
			continue
		var cell := sim.workers.cell[id]
		if world.cells[cell] == Materials.EMPTY and parent[cell] == -2:
			parent[cell] = -1
			queue.append(cell)
	var mask: PackedByteArray = sim.areas.masks[group_id]
	var goal := -1
	var head := 0
	while head < queue.size() and goal < 0:
		var cell := queue[head]
		head += 1
		for next in _neighbors(cell, width, count):
			if parent[next] != -2:
				continue
			var material := world.cells[next]
			var marked := mask[next] == 1 and Materials.is_mineable(material)
			if marked:
				parent[next] = cell
				goal = next
				break
			if material != Materials.EMPTY and not Materials.is_mineable(material):
				continue
			parent[next] = cell
			queue.append(next)
	if goal < 0:
		return false
	var along := PackedInt32Array()
	var step := goal
	while step >= 0:
		if Materials.is_mineable(world.cells[step]) and mask[step] == 0:
			along.append(step)
		step = parent[step]
	return sim.assign_cells(group_id, along)


static func mineable_left(sim: Simulation, group_id: int) -> bool:
	return _has_mineable_order(sim, group_id)


static func _mark_nearest(sim: Simulation, group_id: int) -> bool:
	return sim.work_front.mark_nearest(sim, group_id)


static func _neighbors(cell: int, width: int, count: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var x := cell % width
	if cell >= width:
		result.append(cell - width)
	if x < width - 1:
		result.append(cell + 1)
	if cell + width < count:
		result.append(cell + width)
	if x > 0:
		result.append(cell - 1)
	return result

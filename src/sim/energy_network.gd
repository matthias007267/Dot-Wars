class_name EnergyNetwork
extends RefCounted
## Explicitly placed, faction-owned energy conduit cells.
## No implicit connection between buildings. Construction and routing use orthogonal adjacency.
const COST := 0
var width := 0
var height := 0
var cells := PackedInt32Array()
var owners := PackedInt32Array()
var revision := 0

func setup(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	cells.clear()
	owners.clear()
	revision = 0

func owner_at(cell: int) -> int:
	var index := cells.find(cell)
	return -1 if index < 0 else owners[index]

func place(sim: Simulation, faction: int, cell: int) -> bool:
	if cell < 0 or cell >= width * height or faction < 0 or faction >= (sim.rules.faction_count if sim._match_live() else 1): return false
	if sim.world.cells[cell] != Materials.EMPTY or owner_at(cell) >= 0: return false
	if sim.construction.at(cell) >= 0 or sim.buildings.occupies(cell): return false
	# Conduits are a non-blocking overlay: workers and warriors may stand on them.
	cells.append(cell)
	owners.append(faction)
	revision += 1
	return true

func remove(faction: int, cell: int) -> bool:
	var index := cells.find(cell)
	if index < 0 or owners[index] != faction: return false
	cells.remove_at(index)
	owners.remove_at(index)
	revision += 1
	return true

func place_path(sim: Simulation, faction: int, path: PackedInt32Array) -> int:
	var placed := 0
	for cell in path:
		if place(sim, faction, cell): placed += 1
	return placed

func plan_path(sim: Simulation, faction: int, start: int, goal: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if start < 0 or goal < 0 or start >= width * height or goal >= width * height: return result
	if not _placeable(sim, faction, start) or not _placeable(sim, faction, goal): return result
	# Dijkstra: existing owned conduits are free, new cells cost one.
	# Stable neighbor ordering ensures reproducible routes and previews.
	var costs := PackedInt32Array()
	costs.resize(width * height)
	costs.fill(2147483647)
	var parents := PackedInt32Array()
	parents.resize(width * height)
	parents.fill(-1)
	var visited := PackedByteArray()
	visited.resize(width * height)
	var frontier: Array[Vector2i] = [Vector2i(_heuristic(start, goal), start)]
	costs[start] = 0
	while not frontier.is_empty():
		var best := 0
		for i in range(1, frontier.size()):
			if frontier[i].x < frontier[best].x or (frontier[i].x == frontier[best].x and frontier[i].y < frontier[best].y): best = i
		var current: int = frontier[best].y
		frontier.remove_at(best)
		if visited[current] != 0: continue
		visited[current] = 1
		if current == goal: break
		for next in neighbors(current):
			if visited[next] != 0 or not _placeable(sim, faction, next): continue
			var cost := costs[current] + (0 if owner_at(next) == faction else 10) + 1
			if cost < costs[next]:
				costs[next] = cost
				parents[next] = current
				frontier.append(Vector2i(cost + _heuristic(next, goal), next))
	if costs[goal] == 2147483647: return result
	var cursor := goal
	while cursor >= 0:
		result.append(cursor)
		cursor = parents[cursor]
	result.reverse()
	return result

func _heuristic(cell: int, goal: int) -> int:
	return absi(cell % width - goal % width) + absi(cell / width - goal / width)

func _placeable(sim: Simulation, faction: int, cell: int) -> bool:
	if cell < 0 or cell >= width * height: return false
	if owner_at(cell) == faction: return true
	return owner_at(cell) < 0 and sim.world.cells[cell] == Materials.EMPTY and sim.construction.at(cell) < 0 and not sim.buildings.occupies(cell)

func connected_path(sim: Simulation, faction: int, source: int, target: int) -> PackedInt32Array:
	var empty := PackedInt32Array()
	if source < 0 or target < 0 or source >= width * height or target >= width * height: return empty
	# Start and end must be actual network cells adjacent to their buildings.
	var queue := PackedInt32Array()
	var parents := {}
	var source_site := sim.construction.at(source)
	var target_site := sim.construction.at(target)
	if source_site < 0 or target_site < 0: return empty
	var start_cells := sim.construction.sites.perimeter(source_site)
	var target_cells := sim.construction.sites.perimeter(target_site)
	for c in start_cells:
		if owner_at(c) == faction:
			queue.append(c)
			parents[c] = -1
	var head := 0
	var end := -1
	while head < queue.size():
		var current := queue[head]
		head += 1
		if target_cells.has(current):
			end = current
			break
		for next in neighbors(current):
			if owner_at(next) != faction or parents.has(next): continue
			parents[next] = current
			queue.append(next)
	if end < 0: return empty
	var reverse := PackedInt32Array()
	var cursor := end
	while cursor >= 0:
		reverse.append(cursor)
		cursor = int(parents[cursor])
	reverse.reverse()
	return reverse

func neighbors(cell: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if cell >= width: result.append(cell - width)
	if cell % width < width - 1: result.append(cell + 1)
	if cell + width < width * height: result.append(cell + width)
	if cell % width > 0: result.append(cell - 1)
	return result

func snapshot() -> Dictionary:
	return {"width": width, "height": height, "cells": cells.duplicate(), "owners": owners.duplicate(), "revision": revision}

func restore(data: Dictionary, sim: Simulation) -> bool:
	if int(data.get("width", -1)) != width or int(data.get("height", -1)) != height: return false
	if not data.get("cells") is PackedInt32Array or not data.get("owners") is PackedInt32Array: return false
	if data.cells.size() != data.owners.size() or typeof(data.get("revision")) != TYPE_INT or data.revision < 0: return false
	var seen := {}
	for i in data.cells.size():
		var cell: int = data.cells[i]
		var owner: int = data.owners[i]
		if cell < 0 or cell >= width * height or seen.has(cell): return false
		if owner < 0 or owner >= (sim.rules.faction_count if sim._match_live() else 1): return false
		if sim.world.cells[cell] != Materials.EMPTY or sim.construction.at(cell) >= 0 or sim.buildings.occupies(cell): return false
		seen[cell] = true
	cells = data.cells.duplicate()
	owners = data.owners.duplicate()
	revision = data.revision
	return true

func state_hash() -> int:
	return hash([cells, owners, revision])

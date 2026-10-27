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
var _owner_index := {}
## Topology cache only: no individual energy units or per-unit pathfinding.
var _power_key := PackedInt64Array()
var _power_geometry: Array = []
var _components: Dictionary = {}
var _component_sources: Dictionary = {}
var _site_sources: Dictionary = {}
var power_rebuilds := 0

func prepare_power(sim: Simulation) -> void:
	var key := PackedInt64Array([revision, sim.world.revision, sim.construction.sites.revision])
	if key == _power_key: return
	_power_key = key
	var geometry: Array = [revision]
	for cell in cells:
		if sim.world.cells[cell] != Materials.EMPTY: geometry.append(cell)
	for row in sim.construction.sites.records:
		geometry.append([row.id, row.kind, row.owner, row.rect, row.ready, row.destroyed])
	if geometry == _power_geometry: return
	_power_geometry = geometry
	_components.clear()
	_component_sources.clear()
	_site_sources.clear()
	power_rebuilds += 1
	var component := 0
	for start in cells:
		if _components.has(start) or sim.world.cells[start] != Materials.EMPTY: continue
		var owner := owner_at(start)
		var queue := PackedInt32Array([start])
		_components[start] = component
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			for next in neighbors(cell):
				if _components.has(next) or owner_at(next) != owner or sim.world.cells[next] != Materials.EMPTY: continue
				_components[next] = component
				queue.append(next)
		component += 1
	# Prefer main cores before outposts, then stable site IDs.
	for kind in [0, 1]:
		for row in sim.construction.sites.records:
			if row.destroyed or not row.ready or int(row.kind) != kind: continue
			_site_sources[row.id] = int(row.id)
			for edge in sim.construction.sites.perimeter(row.id):
				if owner_at(edge) != int(row.owner) or not _components.has(edge): continue
				var group: int = _components[edge]
				if not _component_sources.has(group): _component_sources[group] = int(row.id)
	for row in sim.construction.sites.records:
		if row.destroyed or not row.ready or _site_sources.has(row.id): continue
		for edge in sim.construction.sites.perimeter(row.id):
			if owner_at(edge) != int(row.owner) or not _components.has(edge): continue
			var group: int = _components[edge]
			if _component_sources.has(group):
				_site_sources[row.id] = int(_component_sources[group])
				break

func source_site(sim: Simulation, site: int) -> int:
	prepare_power(sim)
	return int(_site_sources.get(site, -1))

func cell_source(sim: Simulation, cell: int) -> int:
	prepare_power(sim)
	return int(_component_sources.get(int(_components.get(cell, -1)), -1))

func energized_factions(sim: Simulation) -> PackedByteArray:
	var count := sim.rules.faction_count if sim._match_live() else 1
	var active := PackedByteArray()
	active.resize(count)
	for owner in count:
		if sim.rules.wallet(sim, owner).energy > 0: active[owner] = 1
	for job in sim.research.jobs:
		if sim.research.running(sim, job): active[int(job.faction)] = 1
	for site in sim.defense.weapons:
		if sim.defense.is_powered(sim, site): active[int(sim.construction.sites.records[site].owner)] = 1
	return active

func setup(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	cells.clear()
	owners.clear()
	revision = 0
	_owner_index.clear()

func owner_at(cell: int) -> int:
	return int(_owner_index.get(cell, -1))

func place(sim: Simulation, faction: int, cell: int) -> bool:
	if cell < 0 or cell >= width * height or faction < 0 or faction >= (sim.rules.faction_count if sim._match_live() else 1): return false
	if sim.world.cells[cell] != Materials.EMPTY or owner_at(cell) >= 0: return false
	if sim.construction.at(cell) >= 0 or sim.buildings.occupies(cell): return false
	# Conduits are a non-blocking overlay: workers and warriors may stand on them.
	cells.append(cell)
	owners.append(faction)
	_owner_index[cell] = faction
	revision += 1
	return true

func remove(faction: int, cell: int) -> bool:
	var index := cells.find(cell)
	if index < 0 or owners[index] != faction: return false
	_owner_index.erase(cell)
	cells.remove_at(index)
	owners.remove_at(index)
	revision += 1
	return true

func place_path(sim: Simulation, faction: int, path: PackedInt32Array) -> int:
	var placed := 0
	for cell in path:
		if place(sim, faction, cell): placed += 1
	return placed

func plan_path(sim: Simulation, faction: int, start: int, goal: int, viewer := -1) -> PackedInt32Array:
	return _plan(sim, faction, PackedInt32Array([start]), PackedInt32Array([goal]), viewer)

func plan_connection(sim: Simulation, faction: int, source_site: int, target_site: int) -> PackedInt32Array:
	if not sim.construction.sites.valid(source_site) or not sim.construction.sites.valid(target_site): return PackedInt32Array()
	if sim.construction.sites.records[source_site].owner != faction or sim.construction.sites.records[target_site].owner != faction: return PackedInt32Array()
	return _plan(sim, faction, sim.construction.sites.perimeter(source_site), sim.construction.sites.perimeter(target_site))

func _plan(sim: Simulation, faction: int, starts: PackedInt32Array, goals: PackedInt32Array, viewer := -1) -> PackedInt32Array:
	# Multi-source Dijkstra: reuse conduits (cost 1), prefer fewer new cells (11).
	# No terrain carving, cross-faction conduits, or implicit building connections.
	var costs := {}
	var parents := {}
	var targets := {}
	var frontier: Array[Vector2i] = []
	for goal in goals:
		if _known_placeable(sim, faction, goal, viewer): targets[goal] = true
	if targets.is_empty(): return PackedInt32Array()
	for start in starts:
		if not _known_placeable(sim, faction, start, viewer): continue
		costs[start] = 0
		parents[start] = -1
		_heap_push(frontier, Vector2i(0, start))
	var examined := 0
	while not frontier.is_empty() and examined < 65536:
		var item := _heap_pop(frontier)
		var current := item.y
		if item.x != costs[current]: continue
		examined += 1
		if targets.has(current):
			var result := PackedInt32Array()
			while current >= 0:
				result.append(current)
				current = parents[current]
			result.reverse()
			return result
		for next in neighbors(current):
			if not _known_placeable(sim, faction, next, viewer): continue
			var cost: int = item.x + (1 if owner_at(next) == faction else 11)
			if cost < int(costs.get(next, 2147483647)):
				costs[next] = cost
				parents[next] = current
				_heap_push(frontier, Vector2i(cost, next))
	return PackedInt32Array()

static func _less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

static func _heap_push(heap: Array[Vector2i], item: Vector2i) -> void:
	heap.append(item)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if not _less(item, heap[parent]): break
		heap[i] = heap[parent]
		i = parent
	heap[i] = item

static func _heap_pop(heap: Array[Vector2i]) -> Vector2i:
	var result := heap[0]
	var last: Vector2i = heap.pop_back()
	if heap.is_empty(): return result
	var i := 0
	while i * 2 + 1 < heap.size():
		var child := i * 2 + 1
		if child + 1 < heap.size() and _less(heap[child + 1], heap[child]): child += 1
		if not _less(heap[child], last): break
		heap[i] = heap[child]
		i = child
	heap[i] = last
	return result

func _heuristic(cell: int, goal: int) -> int:
	return absi(cell % width - goal % width) + absi(int(cell / width) - int(goal / width))

func _known_placeable(sim: Simulation, faction: int, cell: int, viewer: int) -> bool:
	if viewer >= 0 and sim._match_live() and not sim.fog.is_visible(viewer, cell): return false
	return _placeable(sim, faction, cell)

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
	if sim.construction.sites.records[source_site].owner != faction or sim.construction.sites.records[target_site].owner != faction: return empty
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
	_owner_index.clear()
	for i in cells.size(): _owner_index[cells[i]] = owners[i]
	_power_key = PackedInt64Array()
	_power_geometry.clear()
	_power_key = PackedInt64Array()
	_power_geometry.clear()
	revision = data.revision
	return true

func state_hash() -> int:
	return hash([cells, owners, revision])

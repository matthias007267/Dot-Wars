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

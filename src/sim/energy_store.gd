class_name EnergyStore
extends RefCounted
## Bewegliche Energie-Dots. Arbeiter haben Vorrang, Energiedots warten bei belegten
## Zellen. Für den Weg zum Kern wird ein gemeinsames Distanzfeld verwendet.
## Jeder Punkt ist genau eine Energieeinheit. Keine Nodes je Punkt.

const COLOR := Color8(0x53, 0xC7, 0xFF)
const MOVE_PERIOD := 2

var cells := PackedInt32Array()
var generated: int = 0
var delivered: int = 0
var _dist := PackedInt32Array()
var _revision := -1
var _width := 0
var _goal := -1


func pending() -> int:
	return cells.size()


func enqueue(origin: int, count: int) -> void:
	for _i in count:
		cells.append(origin)
	generated += count


func step(world: WorldState, workers: WorkerStore, core: int, tick: int) -> int:
	if cells.is_empty():
		return 0
	if tick % MOVE_PERIOD != 0:
		return 0
	if _revision != world.revision or _width != world.width or _goal != core:
		_rebuild(world, core)
	var gate := SacrificeSystem.delivery_cells(world, core)
	var exits := {}
	for c in gate:
		exits[c] = true
	var occupied := {}
	for c in cells:
		occupied[c] = int(occupied.get(c, 0)) + 1
	var gained := 0
	var next := PackedInt32Array()
	for c in cells:
		if exits.has(c):
			gained += 1
			occupied[c] -= 1
			continue
		var target := _next_cell(c, world, workers, occupied)
		if target != c:
			occupied[c] -= 1
			occupied[target] = int(occupied.get(target, 0)) + 1
		next.append(target)
	cells = next
	delivered += gained
	return gained


func _next_cell(c: int, world: WorldState, workers: WorkerStore, occupied: Dictionary) -> int:
	if c < 0 or c >= _dist.size() or _dist[c] < 0:
		return c
	var width := world.width
	var x := c % width
	var options := PackedInt32Array()
	if c >= width:
		options.append(c - width)
	if x < width - 1:
		options.append(c + 1)
	if c + width < world.cell_count():
		options.append(c + width)
	if x > 0:
		options.append(c - 1)
	for target in options:
		if _dist[target] >= 0 and _dist[target] < _dist[c] and world.cells[target] == Materials.EMPTY:
			if workers.is_free(target) and int(occupied.get(target, 0)) == 0:
				return target
	return c


func _rebuild(world: WorldState, core: int) -> void:
	_revision = world.revision
	_width = world.width
	_goal = core
	_dist.resize(world.cell_count())
	_dist.fill(-1)
	var frontier := SacrificeSystem.delivery_cells(world, core)
	for c in frontier:
		_dist[c] = 0
	var head := 0
	while head < frontier.size():
		var c := frontier[head]
		head += 1
		var width := world.width
		var x := c % width
		var candidates := PackedInt32Array()
		if c >= width:
			candidates.append(c - width)
		if x < width - 1:
			candidates.append(c + 1)
		if c + width < world.cell_count():
			candidates.append(c + width)
		if x > 0:
			candidates.append(c - 1)
		for n in candidates:
			if _dist[n] == -1 and world.cells[n] == Materials.EMPTY:
				_dist[n] = _dist[c] + 1
				frontier.append(n)


func state_hash() -> int:
	return hash([hash(cells), generated, delivered])

class_name EnergyStore
extends RefCounted
## Bewegliche Energie-Dots. Mehrere Dots teilen eine Zelle. Ein Arbeiter auf der
## nächsten Zelle zum Kern hält sie auf. Für den Weg wird ein gemeinsames Distanzfeld
## verwendet. Jeder Punkt ist genau eine Energieeinheit. Keine Nodes je Punkt.

const COLOR := Color8(0x53, 0xC7, 0xFF)
## Langsamer Start, solange kein Aufrufer eine Stufe übergibt.
const MOVE_PERIOD := 8

var cells := PackedInt32Array()
## Zelle, an der der Dot entstanden ist. -1 ist eine unbekannte Herkunft und wird nicht veredelt.
var birth := PackedInt32Array()
## 1, nachdem ein Veredler diesen Dot verdoppelt hat. Der Zwilling trägt dieselbe Markierung.
var refined := PackedByteArray()
var generated: int = 0
var delivered: int = 0
var refined_delivered: int = 0
var _dist := PackedInt32Array()
var _revision := -1
var _width := 0
var _exit_stamp := 0
var _last_rebuild_tick := -1000


func pending() -> int:
	return cells.size()


func enqueue(origin: int, count: int) -> void:
	for _i in count:
		cells.append(origin)
		birth.append(origin)
		refined.append(0)
	generated += count


## Ältere Stände haben nur die Positionen. Fehlende Herkunft bleibt unveredelbar.
func ensure_tracks() -> void:
	if birth.size() == cells.size() and refined.size() == cells.size():
		return
	var next_birth := PackedInt32Array()
	var next_refined := PackedByteArray()
	next_birth.resize(cells.size())
	next_refined.resize(cells.size())
	next_birth.fill(-1)
	var limit := mini(birth.size(), cells.size())
	for i in limit:
		next_birth[i] = birth[i]
	limit = mini(refined.size(), cells.size())
	for i in limit:
		next_refined[i] = refined[i]
	birth = next_birth
	refined = next_refined


func step(
	world: WorldState, workers: WorkerStore, gate: PackedInt32Array, tick: int, period: int = MOVE_PERIOD
) -> int:
	ensure_tracks()
	if cells.is_empty():
		return 0
	var pace := MOVE_PERIOD if period < 1 else period
	if tick % pace != 0:
		return 0
	var stamp := hash(gate)
	if stamp != _exit_stamp or _width != world.width or (_revision != world.revision and tick - _last_rebuild_tick >= 10):
		_rebuild(world, gate)
		_exit_stamp = stamp
		_last_rebuild_tick = tick
	var exits := {}
	for c in gate:
		exits[c] = true
	var gained := 0
	var next := PackedInt32Array()
	var next_birth := PackedInt32Array()
	var next_refined := PackedByteArray()
	for i in cells.size():
		var c := cells[i]
		if exits.has(c):
			gained += 1
			if refined[i] != 0:
				refined_delivered += 1
			continue
		next.append(_next_cell(c, world, workers))
		next_birth.append(birth[i])
		next_refined.append(refined[i])
	cells = next
	birth = next_birth
	refined = next_refined
	delivered += gained
	return gained


func _next_cell(c: int, world: WorldState, workers: WorkerStore) -> int:
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
			if workers.is_free(target):
				return target
	return c


func _rebuild(world: WorldState, gate: PackedInt32Array) -> void:
	_revision = world.revision
	_width = world.width
	_dist.resize(world.cell_count())
	_dist.fill(-1)
	var frontier := PackedInt32Array()
	for c in gate:
		if c >= 0 and c < world.cell_count() and world.cells[c] == Materials.EMPTY:
			_dist[c] = 0
			frontier.append(c)
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
	return hash([hash(cells), hash(birth), hash(refined), generated, delivered, refined_delivered])

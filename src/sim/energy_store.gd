class_name EnergyStore
extends RefCounted

const NATIVE_SEARCH = preload("res://src/sim/native_search.gd")
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
## Besitzer des Dots. 0 ist der menschliche Spieler. Fehlende Einträge gelten als 0.
var owner := PackedByteArray()
## Gelieferte Einheiten je Fraktion. Leer, solange alle Dots denselben Kern nutzen.
var delivered_to := PackedInt32Array()
var generated: int = 0
var delivered: int = 0
var refined_delivered: int = 0
var _dist := PackedInt32Array()
var _routed: Array = []
var _revision := -1
var _width := 0
var _exit_stamp := 0
var _last_rebuild_tick := -1000


func pending_owned(faction: int) -> int:
	ensure_tracks()
	var total := 0
	for index in cells.size():
		if int(owner[index]) == faction:
			total += 1
	return total


func pending() -> int:
	return cells.size()


func enqueue(origin: int, count: int, faction_id: int = 0) -> void:
	for _i in count:
		cells.append(origin)
		birth.append(origin)
		refined.append(0)
		owner.append(faction_id)
	generated += count


## Ältere Stände haben nur die Positionen. Fehlende Herkunft bleibt unveredelbar.
func ensure_tracks() -> void:
	if birth.size() == cells.size() and refined.size() == cells.size():
		_fit_owner()
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
	_fit_owner()


func step(
	world: WorldState,
	workers: WorkerStore,
	gate: PackedInt32Array,
	tick: int,
	period: int = MOVE_PERIOD,
	gate_owner: PackedByteArray = PackedByteArray(),
	faction_period: PackedByteArray = PackedByteArray(),
) -> int:
	ensure_tracks()
	if cells.is_empty():
		return 0
	if gate_owner.size() == gate.size() and not gate_owner.is_empty():
		return _step_routed(world, workers, gate, gate_owner, tick, period, faction_period)
	var pace := MOVE_PERIOD if period < 1 else period
	if tick % pace != 0:
		return 0
	var stamp := hash(gate)
	if stamp != _exit_stamp or _width != world.width or (_revision != world.revision and tick - _last_rebuild_tick >= 10):
		_rebuild(world, gate)
		_exit_stamp = stamp
		_last_rebuild_tick = tick
	var moved := PackedInt32Array()
	var native := NATIVE_SEARCH.backend()
	if native != null:
		var result: Variant = native.energy_next(cells, world.cells, workers.occupant, _dist, world.width)
		if result is PackedInt32Array:
			moved = result
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
		next.append(moved[i] if moved.size() == cells.size() else _next_cell(c, world, workers))
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
	var native := NATIVE_SEARCH.backend()
	if native != null:
		var directions := PackedByteArray()
		directions.resize(world.cell_count())
		# Nur die Distanzen werden benutzt; beide BFS-Reihenfolgen ergeben dasselbe Feld.
		var result: Variant = native.flow_spread(world.cells, PackedByteArray(), _dist, directions, frontier, 0, 1 << 40, false, world.width)
		if result is Array and result.size() == 5:
			_dist = result[0]
			return
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
	ensure_tracks()
	return hash([
		hash(cells), hash(birth), hash(refined), hash(owner), hash(delivered_to),
		generated, delivered, refined_delivered,
	])


func _fit_owner() -> void:
	if owner.size() == cells.size():
		return
	var next_owner := PackedByteArray()
	next_owner.resize(cells.size())
	var kept := mini(owner.size(), cells.size())
	for i in kept:
		next_owner[i] = owner[i]
	owner = next_owner


func _step_routed(
	world: WorldState,
	workers: WorkerStore,
	gate: PackedInt32Array,
	gate_owner: PackedByteArray,
	tick: int,
	period: int,
	faction_period: PackedByteArray,
) -> int:
	var due := false
	for i in cells.size():
		if tick % _pace_of(int(owner[i]), period, faction_period) == 0:
			due = true
			break
	if not due:
		return 0
	var stamp := hash([hash(gate), hash(gate_owner)])
	if stamp != _exit_stamp or _width != world.width or (_revision != world.revision and tick - _last_rebuild_tick >= 10):
		_rebuild_routed(world, gate, gate_owner)
		_exit_stamp = stamp
		_last_rebuild_tick = tick
	var gained := 0
	var next := PackedInt32Array()
	var next_birth := PackedInt32Array()
	var next_refined := PackedByteArray()
	var next_owner := PackedByteArray()
	for i in cells.size():
		var faction := int(owner[i])
		var cell := cells[i]
		if tick % _pace_of(faction, period, faction_period) != 0:
			next.append(cell)
			next_birth.append(birth[i])
			next_refined.append(refined[i])
			next_owner.append(faction)
			continue
		if _owned_gate(cell, faction, gate, gate_owner):
			gained += 1
			while delivered_to.size() <= faction:
				delivered_to.append(0)
			delivered_to[faction] += 1
			if refined[i] != 0:
				refined_delivered += 1
			continue
		if faction < _routed.size():
			_dist = _routed[faction]
		next.append(_next_cell(cell, world, workers))
		next_birth.append(birth[i])
		next_refined.append(refined[i])
		next_owner.append(faction)
	cells = next
	birth = next_birth
	refined = next_refined
	owner = next_owner
	delivered += gained
	return gained


func _pace_of(faction: int, period: int, faction_period: PackedByteArray) -> int:
	var pace := period
	if faction >= 0 and faction < faction_period.size():
		pace = int(faction_period[faction])
	return MOVE_PERIOD if pace < 1 else pace


func _owned_gate(cell: int, faction: int, gate: PackedInt32Array, gate_owner: PackedByteArray) -> bool:
	for index in gate.size():
		if gate[index] == cell and int(gate_owner[index]) == faction:
			return true
	return false


func _rebuild_routed(world: WorldState, gate: PackedInt32Array, gate_owner: PackedByteArray) -> void:
	var factions := 1
	for owner_id in gate_owner:
		factions = maxi(factions, int(owner_id) + 1)
	_routed = []
	for faction in factions:
		var mine := PackedInt32Array()
		for index in gate.size():
			if int(gate_owner[index]) == faction:
				mine.append(gate[index])
		_rebuild(world, mine)
		_routed.append(_dist.duplicate())

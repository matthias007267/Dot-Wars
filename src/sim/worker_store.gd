class_name WorkerStore
extends RefCounted
## Arbeiter als Struct-of-Arrays plus Zellbelegung. Eine Zelle fasst höchstens einen Arbeiter.
## Größe 1 belegt eine Zelle. Größe 2 und 3 belegen ein Quadrat mit der Ankerzelle oben links.

## Kein erreichbares Ziel (oder veraltetes Feld): wartet.
const STATE_WAITING := 0
const STATE_MOVING := 1
const STATE_MINING := 2
## Nächster Schritt ist durch einen anderen Arbeiter versperrt.
const STATE_BLOCKED := 3
const STATE_COUNT := 4

const NO_WORKER := -1
const NO_TARGET := -1

const SIZE_MASS: Array[int] = [0, 1, 4, 9]
const SIZE_POWER: Array[int] = [0, 1, 6, 15]

var count: int = 0
var cell := PackedInt32Array()
var group := PackedByteArray()
## Fraktion des Besitzers, unabhängig von der Farbgruppe.
var faction := PackedByteArray()
var state := PackedByteArray()
## Zielzelle des Abbaus (nur bei STATE_MINING gültig).
var target := PackedInt32Array()
## Eigener Fels der Schwarm-Intelligenz. -1 heißt: das gemeinsame Wegfeld gilt.
var aim := PackedInt32Array()
## Nächster Schritt zum eigenen Fels. Bleibt, solange Ziel, Standplatz und Nachbarn gleich sind.
## Wird nicht gespeichert.
var aim_step := PackedInt32Array()
## Signatur der letzten Schrittsuche. Nicht im Hash und nicht im Speicherstand.
var aim_watch := PackedInt32Array()
## Takte auf derselben Zelle ohne Abbau.
var idle_ticks := PackedInt32Array()
var idle_cell := PackedInt32Array()
## Tick, in dem sich der Arbeiter zuletzt bewegt hat (verhindert Doppelschritte durch Tausch).
var last_move_tick := PackedInt32Array()
## Kantenlänge des Quadrats. 1 ist der Basis-Arbeiter.
var size := PackedByteArray()
## Masse der Einheit. Bei Größe 1 immer 1.
var mass := PackedInt32Array()
## Bewegungsrest für beschleunigte Einheiten. Der Grundtakt nutzt ihn nicht.
var move_credit := PackedInt32Array()
## Zelle → Arbeiter-ID oder NO_WORKER.
var occupant := PackedInt32Array()
var group_counts := PackedInt32Array()
## Masse je Gruppe, einschließlich verschmolzener Einheiten.
var group_mass := PackedInt32Array()
var world_width: int = 0
var max_size: int = 1


func _init(cell_count: int, group_count: int, p_width: int = 0) -> void:
	occupant.resize(cell_count)
	occupant.fill(NO_WORKER)
	group_counts.resize(group_count)
	group_counts.fill(0)
	group_mass.resize(group_count)
	group_mass.fill(0)
	world_width = cell_count if p_width <= 0 else p_width


func ensure_groups(group_count: int) -> void:
	while group_counts.size() < group_count:
		group_counts.append(0)
		group_mass.append(0)


func is_free(cell_idx: int) -> bool:
	return occupant[cell_idx] == NO_WORKER


func mass_sum() -> int:
	var total := 0
	for id in count:
		total += mass[id]
	return total


## Fügt einen Basis-Arbeiter auf einer freien Zelle hinzu und gibt seine ID zurück.
func add(cell_idx: int, group_id: int, faction_id: int = 0) -> int:
	assert(is_free(cell_idx), "Zelle bereits belegt")
	return _append(cell_idx, group_id, faction_id, 1, 1)


## Fügt eine Einheit mit Quadrat-Fußabdruck ein. Die Fläche muss frei und leer sein.
func add_sized(anchor: int, group_id: int, faction_id: int, unit_size: int) -> int:
	var id := _append(anchor, group_id, faction_id, unit_size, SIZE_MASS[unit_size])
	_fill_footprint(id, anchor, unit_size, id)
	return id


func move_to(id: int, new_cell: int, tick: int) -> void:
	occupant[cell[id]] = NO_WORKER
	occupant[new_cell] = id
	cell[id] = new_cell
	state[id] = STATE_MOVING
	last_move_tick[id] = tick


## Verschiebt ein Quadrat. Der Aufrufer hat die Zielfläche geprüft.
func move_footprint(id: int, new_anchor: int, tick: int) -> void:
	var unit_size := int(size[id])
	_fill_footprint(id, cell[id], unit_size, NO_WORKER)
	_fill_footprint(id, new_anchor, unit_size, id)
	cell[id] = new_anchor
	state[id] = STATE_MOVING
	last_move_tick[id] = tick


## Tauscht die Zellen zweier Basis-Arbeiter (frontaler Gegenverkehr).
func swap_cells(a: int, b: int, tick: int) -> void:
	var cell_a := cell[a]
	var cell_b := cell[b]
	cell[a] = cell_b
	cell[b] = cell_a
	occupant[cell_a] = b
	occupant[cell_b] = a
	state[a] = STATE_MOVING
	state[b] = STATE_MOVING
	last_move_tick[a] = tick
	last_move_tick[b] = tick


## Entfernt eine Einheit und tauscht die letzte ID nach. Gibt die ID zurück, die nachgerückt ist, oder -1.
func remove_swap(id: int) -> int:
	var unit_size := int(size[id])
	_fill_footprint(id, cell[id], unit_size, NO_WORKER)
	var group_id := int(group[id])
	group_counts[group_id] -= 1
	group_mass[group_id] -= mass[id]
	var last := count - 1
	count = last
	if id == last:
		_shrink()
		_refresh_max_size()
		return -1
	_copy_slot(last, id)
	_fill_footprint(id, cell[id], int(size[id]), id)
	_shrink()
	_refresh_max_size()
	return id


func footprint_fits(anchor: int, unit_size: int, allow_id: int) -> bool:
	var origin_x := anchor % world_width
	var origin_y := anchor / world_width
	if origin_x + unit_size > world_width:
		return false
	if anchor + (unit_size - 1) * world_width >= occupant.size():
		return false
	for dy in unit_size:
		for dx in unit_size:
			var idx := anchor + dy * world_width + dx
			var occ := occupant[idx]
			if occ != NO_WORKER and occ != allow_id:
				return false
	return true


func reassign_group(id: int, new_group: int) -> void:
	var old := int(group[id])
	if old == new_group:
		return
	group_counts[old] -= 1
	group_mass[old] -= mass[id]
	group_counts[new_group] += 1
	group_mass[new_group] += mass[id]
	group[id] = new_group


func count_in_state(group_id: int, wanted_state: int) -> int:
	var total := 0
	for id in count:
		if group[id] == group_id and state[id] == wanted_state:
			total += 1
	return total


func state_hash() -> int:
	return hash([
		count,
		hash(cell),
		hash(group),
		hash(faction),
		hash(state),
		hash(target),
		hash(aim),
		hash(idle_ticks),
		hash(idle_cell),
		hash(last_move_tick),
		hash(size),
		hash(mass),
	])


func _append(anchor: int, group_id: int, faction_id: int, unit_size: int, unit_mass: int) -> int:
	var id := count
	count += 1
	cell.append(anchor)
	group.append(group_id)
	faction.append(faction_id)
	state.append(STATE_WAITING)
	target.append(NO_TARGET)
	aim.append(NO_TARGET)
	aim_step.append(NO_TARGET)
	aim_watch.append(0)
	idle_ticks.append(0)
	idle_cell.append(NO_TARGET)
	last_move_tick.append(-1)
	size.append(unit_size)
	mass.append(unit_mass)
	move_credit.append(0)
	if unit_size == 1:
		occupant[anchor] = id
	group_counts[group_id] += 1
	group_mass[group_id] += unit_mass
	if unit_size > max_size:
		max_size = unit_size
	return id


func _fill_footprint(id: int, anchor: int, unit_size: int, value: int) -> void:
	for dy in unit_size:
		var row := anchor + dy * world_width
		for dx in unit_size:
			occupant[row + dx] = value


func _copy_slot(src: int, dst: int) -> void:
	cell[dst] = cell[src]
	group[dst] = group[src]
	faction[dst] = faction[src]
	state[dst] = state[src]
	target[dst] = target[src]
	aim[dst] = aim[src]
	aim_step[dst] = aim_step[src]
	aim_watch[dst] = aim_watch[src]
	idle_ticks[dst] = idle_ticks[src]
	idle_cell[dst] = idle_cell[src]
	last_move_tick[dst] = last_move_tick[src]
	size[dst] = size[src]
	mass[dst] = mass[src]
	move_credit[dst] = move_credit[src]


func _shrink() -> void:
	cell.resize(count)
	group.resize(count)
	faction.resize(count)
	state.resize(count)
	target.resize(count)
	aim.resize(count)
	aim_step.resize(count)
	aim_watch.resize(count)
	idle_ticks.resize(count)
	idle_cell.resize(count)
	last_move_tick.resize(count)
	size.resize(count)
	mass.resize(count)
	move_credit.resize(count)


func _refresh_max_size() -> void:
	max_size = 1
	for id in count:
		if size[id] > max_size:
			max_size = size[id]

class_name WorkerStore
extends RefCounted
## Arbeiter als Struct-of-Arrays plus Zellbelegung. Eine Zelle fasst höchstens einen Arbeiter.

## Kein erreichbares Ziel (oder veraltetes Feld): wartet.
const STATE_WAITING := 0
const STATE_MOVING := 1
const STATE_MINING := 2
## Nächster Schritt ist durch einen anderen Arbeiter versperrt.
const STATE_BLOCKED := 3
const STATE_COUNT := 4

const NO_WORKER := -1
const NO_TARGET := -1

var count: int = 0
var cell := PackedInt32Array()
var group := PackedByteArray()
## Fraktion des Besitzers, unabhängig von der Farbgruppe.
var faction := PackedByteArray()
var state := PackedByteArray()
## Zielzelle des Abbaus (nur bei STATE_MINING gültig).
var target := PackedInt32Array()
## Tick, in dem sich der Arbeiter zuletzt bewegt hat (verhindert Doppelschritte durch Tausch).
var last_move_tick := PackedInt32Array()
## Zelle → Arbeiter-ID oder NO_WORKER.
var occupant := PackedInt32Array()
var group_counts := PackedInt32Array()


func _init(cell_count: int, group_count: int) -> void:
	occupant.resize(cell_count)
	occupant.fill(NO_WORKER)
	group_counts.resize(group_count)
	group_counts.fill(0)


func is_free(cell_idx: int) -> bool:
	return occupant[cell_idx] == NO_WORKER


## Fügt einen Arbeiter auf einer freien Zelle hinzu und gibt seine ID zurück.
func add(cell_idx: int, group_id: int, faction_id: int = 0) -> int:
	assert(is_free(cell_idx), "Zelle bereits belegt")
	var id := count
	count += 1
	cell.append(cell_idx)
	group.append(group_id)
	faction.append(faction_id)
	state.append(STATE_WAITING)
	target.append(NO_TARGET)
	last_move_tick.append(-1)
	occupant[cell_idx] = id
	group_counts[group_id] += 1
	return id


func move_to(id: int, new_cell: int, tick: int) -> void:
	occupant[cell[id]] = NO_WORKER
	occupant[new_cell] = id
	cell[id] = new_cell
	state[id] = STATE_MOVING
	last_move_tick[id] = tick


## Tauscht die Zellen zweier Arbeiter (frontaler Gegenverkehr).
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


func count_in_state(group_id: int, wanted_state: int) -> int:
	var total := 0
	for id in count:
		if group[id] == group_id and state[id] == wanted_state:
			total += 1
	return total


func state_hash() -> int:
	return hash([count, hash(cell), hash(group), hash(faction), hash(state), hash(target), hash(last_move_tick)])

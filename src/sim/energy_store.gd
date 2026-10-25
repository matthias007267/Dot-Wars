class_name EnergyStore
extends RefCounted

const NATIVE_SEARCH = preload("res://src/sim/native_search.gd")
## Bewegliche Energie-Dots. Mehrere Dots teilen eine Zelle. Ein Arbeiter auf der
## nächsten Zelle zum Kern hält sie auf. Für den Weg wird ein gemeinsames Distanzfeld
## verwendet. Jeder Punkt ist genau eine Energieeinheit. Keine Nodes je Punkt.

const Transport = preload("res://src/sim/energy_transport.gd")
const NEUTRAL := 255
var no_route := PackedInt32Array()
var held_by := PackedInt32Array()
var release_at := PackedInt32Array()
var expired := 0
var captured := 0
var neutralized := 0
var _capture_stamp := -1
var _capture_cells := {}

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
		no_route.append(0)
		held_by.append(-1)
		release_at.append(0)
	generated += count


## Ältere Stände haben nur die Positionen. Fehlende Herkunft bleibt unveredelbar.
func ensure_tracks() -> void:
	_fit_transport()
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
	world: WorldState, workers: WorkerStore, gate: PackedInt32Array, tick: int,
	period: int = MOVE_PERIOD, gate_owner: PackedByteArray = PackedByteArray(),
	faction_period: PackedByteArray = PackedByteArray(), sim: Simulation = null,
) -> int:
	return Transport.step(self, world, workers, gate, tick, period, gate_owner, faction_period, sim)


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
		generated, delivered, refined_delivered, expired, captured, neutralized, hash(no_route), hash(held_by), hash(release_at),
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


func _rebuild_routed(world: WorldState, gate: PackedInt32Array, gate_owner: PackedByteArray, min_factions: int = 1) -> void:
	var factions := min_factions
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


func _fit_transport() -> void:
	var previous := held_by.size()
	no_route.resize(cells.size())
	held_by.resize(cells.size())
	release_at.resize(cells.size())
	for i in range(previous, cells.size()): held_by[i] = -1

func neutralize_station(site: int) -> void:
	ensure_tracks()
	for i in cells.size():
		if held_by[i] != site: continue
		owner[i] = NEUTRAL
		held_by[i] = -1
		release_at[i] = 0
		neutralized += 1

func ledger() -> Dictionary:
	ensure_tracks()
	var buffered := 0
	var neutral := 0
	for i in cells.size():
		if held_by[i] >= 0: buffered += 1
		elif owner[i] == NEUTRAL: neutral += 1
	return {"generated": generated, "delivered": delivered, "expired": expired,
		"pending": cells.size(), "buffered": buffered, "neutral": neutral,
		"free_owned": cells.size() - buffered - neutral, "captures": captured, "neutralizations": neutralized}

func transport_snapshot() -> Dictionary:
	ensure_tracks()
	return {"no_route": no_route.duplicate(), "held_by": held_by.duplicate(), "release_at": release_at.duplicate(),
		"expired": expired, "captured": captured, "neutralized": neutralized}

func restore_transport(data: Variant, sim: Simulation) -> bool:
	if not data is Dictionary: return false
	for key in ["no_route", "held_by", "release_at"]:
		if not data.get(key) is PackedInt32Array or data[key].size() != cells.size(): return false
	for key in ["expired", "captured", "neutralized"]:
		if typeof(data.get(key)) != TYPE_INT or data[key] < 0: return false
	var counts := {}
	var factions := sim.rules.faction_count if sim._match_live() else 1
	for i in cells.size():
		if owner[i] != NEUTRAL and owner[i] >= factions: return false
		if cells[i] < 0 or cells[i] >= sim.world.cell_count() or data.no_route[i] < 0 or data.no_route[i] >= Transport.NO_ROUTE_TICKS: return false
		var holder: int = data.held_by[i]
		if holder < -1: return false
		if holder == -1:
			if data.release_at[i] != 0: return false
		else:
			if not sim.construction.sites.valid(holder): return false
			var row: Dictionary = sim.construction.sites.records[holder]
			if row.kind != 2 or not row.ready or owner[i] != row.owner or not sim.construction.receivers_for(sim, holder).has(cells[i]): return false
			if data.release_at[i] < sim.tick_count or data.release_at[i] > sim.tick_count + Transport.HOLD_TICKS: return false
			counts[holder] = int(counts.get(holder, 0)) + 1
			if counts[holder] > Transport.CAPACITY: return false
	no_route = data.no_route.duplicate()
	held_by = data.held_by.duplicate()
	release_at = data.release_at.duplicate()
	expired = data.expired
	captured = data.captured
	neutralized = data.neutralized
	return true

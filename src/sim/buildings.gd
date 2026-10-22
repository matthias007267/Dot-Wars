class_name Buildings
extends RefCounted
## Quelle und Veredler. Eine Zelle, begehbar, kein eigenes Material.
## Die Quelle lässt auf leeren Nachbarzellen echtes Material nachwachsen.
## Der Veredler verdoppelt einen Dot aus seinem Umkreis, höchstens einmal je Dot.

const KIND_SOURCE := 1
const KIND_REFINERY := 2

const SOURCE_MAX := 3
const REFINERY_MAX := 2
const SOURCE_COST: Array[int] = [80, 160, 240]
const REFINERY_COST: Array[int] = [120, 240]
## Takte zwischen zwei Knospen. 20 Takte sind eine Sekunde. Stufe 0 wartet 8 Sekunden, danach 6.
const SOURCE_PERIOD: Array[int] = [160, 120, 120, 120]
const SOURCE_CAP: Array[int] = [4, 6, 6, 6]
const SOURCE_TIER_COST: Array[int] = [40, 80, 120]
const SOURCE_TIER_MAX := 3
## Ein Veredler wertet auf Stufe 0 einen Dot je Sekunde auf, dann zwei, dann vier.
const REFINERY_PERIOD: Array[int] = [20, 10, 5]
const REFINERY_RADIUS: Array[int] = [16, 24, 32]
const REFINERY_TIER_COST: Array[int] = [60, 120]
const REFINERY_TIER_MAX := 2

var source_level: int = 0
var refinery_level: int = 0
var kind := PackedByteArray()
var cell := PackedInt32Array()
var grown := PackedInt32Array()
var elapsed := PackedInt32Array()
var ready_tick := PackedInt32Array()
var buds: Array[PackedInt32Array] = []


func allowed(mode: int, kind_id: int) -> bool:
	if kind_id == KIND_SOURCE:
		return mode == SimConfig.MODE_EXTRACTION
	if kind_id == KIND_REFINERY:
		return mode == SimConfig.MODE_CLEARING or mode == SimConfig.MODE_REFINING
	return false


func count_of(kind_id: int) -> int:
	var total := 0
	for value in kind:
		if value == kind_id:
			total += 1
	return total


func place_cost(kind_id: int) -> int:
	var have := count_of(kind_id)
	if kind_id == KIND_SOURCE:
		if have >= SOURCE_MAX:
			return -1
		return SOURCE_COST[have]
	if kind_id == KIND_REFINERY:
		if have >= REFINERY_MAX:
			return -1
		return REFINERY_COST[have]
	return -1


func tier_cost(kind_id: int) -> int:
	if kind_id == KIND_SOURCE:
		if source_level >= SOURCE_TIER_MAX:
			return -1
		return SOURCE_TIER_COST[source_level]
	if kind_id == KIND_REFINERY:
		if refinery_level >= REFINERY_TIER_MAX:
			return -1
		return REFINERY_TIER_COST[refinery_level]
	return -1


func raise_tier(kind_id: int) -> void:
	if kind_id == KIND_SOURCE:
		source_level += 1
	elif kind_id == KIND_REFINERY:
		refinery_level += 1


func occupies(idx: int) -> bool:
	for c in cell:
		if c == idx:
			return true
	return false


func add(kind_id: int, idx: int) -> void:
	kind.append(kind_id)
	cell.append(idx)
	grown.append(0)
	elapsed.append(0)
	ready_tick.append(0)
	buds.append(PackedInt32Array())


func mask(cell_count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(cell_count)
	for i in cell.size():
		var idx := cell[i]
		if idx >= 0 and idx < cell_count:
			out[idx] = kind[i]
	return out


## Lässt höchstens eine Knospe je Quelle wachsen, wenn der Takt voll ist und eine Zelle frei ist.
func grow(world: WorldState, workers: WorkerStore, energy: EnergyStore, core_mask: PackedByteArray) -> void:
	if count_of(KIND_SOURCE) == 0:
		return
	var busy := {}
	for c in energy.cells:
		busy[c] = true
	var level := clampi(source_level, 0, SOURCE_TIER_MAX)
	var period := SOURCE_PERIOD[level]
	var cap := SOURCE_CAP[level]
	for i in kind.size():
		if kind[i] != KIND_SOURCE:
			continue
		_prune_buds(world, i)
		if buds[i].size() >= cap:
			continue
		var spot := _bud_spot(world, workers, busy, core_mask, cell[i])
		if spot < 0:
			continue
		elapsed[i] += 1
		if elapsed[i] < period:
			continue
		elapsed[i] = 0
		var next_index := grown[i] + 1
		grown[i] = next_index
		world.set_material(spot, _bud_material(level, next_index))
		buds[i].append(spot)
		busy[spot] = true


## Verdoppelt höchstens einen unverdoppelten Dot je bereitem Veredler.
func refine(energy: EnergyStore, world: WorldState, tick: int) -> void:
	energy.ensure_tracks()
	if energy.cells.is_empty() or count_of(KIND_REFINERY) == 0:
		return
	var level := clampi(refinery_level, 0, REFINERY_TIER_MAX)
	var radius := REFINERY_RADIUS[level]
	var period := REFINERY_PERIOD[level]
	var width := world.width
	for i in kind.size():
		if kind[i] != KIND_REFINERY or tick < ready_tick[i]:
			continue
		var here := cell[i]
		var limit := energy.cells.size()
		for d in limit:
			if energy.cells[d] != here or energy.refined[d] != 0:
				continue
			if not _in_radius(width, energy.birth[d], here, radius):
				continue
			energy.refined[d] = 1
			energy.cells.append(here)
			energy.birth.append(energy.birth[d])
			energy.refined.append(1)
			energy.generated += 1
			ready_tick[i] = tick + period
			break


func export_entries() -> Array:
	var entries: Array = []
	for i in kind.size():
		entries.append({
			"kind": int(kind[i]),
			"cell": cell[i],
			"grown": grown[i],
			"elapsed": elapsed[i],
			"ready": ready_tick[i],
			"buds": buds[i].duplicate(),
		})
	return entries


func restore(entries: Array) -> bool:
	kind = PackedByteArray()
	cell = PackedInt32Array()
	grown = PackedInt32Array()
	elapsed = PackedInt32Array()
	ready_tick = PackedInt32Array()
	buds = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var kind_id := int(entry.get("kind", 0))
		var idx := int(entry.get("cell", -1))
		if kind_id != KIND_SOURCE and kind_id != KIND_REFINERY:
			return false
		kind.append(kind_id)
		cell.append(idx)
		grown.append(int(entry.get("grown", 0)))
		elapsed.append(int(entry.get("elapsed", 0)))
		ready_tick.append(int(entry.get("ready", 0)))
		var raw = entry.get("buds", PackedInt32Array())
		var list := PackedInt32Array()
		if raw is PackedInt32Array:
			list = (raw as PackedInt32Array).duplicate()
		buds.append(list)
	return true


func state_hash() -> int:
	var bud_hashes: Array[int] = []
	for list in buds:
		bud_hashes.append(hash(list))
	return hash([
		hash(kind), hash(cell), hash(grown), hash(elapsed), hash(ready_tick),
		source_level, refinery_level, hash(bud_hashes),
	])


func _prune_buds(world: WorldState, index: int) -> void:
	var kept := PackedInt32Array()
	for bud in buds[index]:
		if bud >= 0 and bud < world.cell_count() and Materials.is_mineable(world.cells[bud]):
			kept.append(bud)
	buds[index] = kept


func _bud_spot(
	world: WorldState,
	workers: WorkerStore,
	busy: Dictionary,
	core_mask: PackedByteArray,
	origin: int,
) -> int:
	var width := world.width
	var x := origin % width
	var candidates := PackedInt32Array()
	if origin >= width:
		candidates.append(origin - width)
	if x < width - 1:
		candidates.append(origin + 1)
	if origin + width < world.cell_count():
		candidates.append(origin + width)
	if x > 0:
		candidates.append(origin - 1)
	for idx in candidates:
		if world.cells[idx] != Materials.EMPTY or occupies(idx) or busy.has(idx):
			continue
		if idx < core_mask.size() and core_mask[idx] == 1:
			continue
		if workers.occupant[idx] != WorkerStore.NO_WORKER:
			continue
		return idx
	return -1


func _bud_material(level: int, index: int) -> int:
	if level >= 3 and index % 6 == 0:
		return Materials.HARD
	if level >= 2 and index % 3 == 0:
		return Materials.MEDIUM
	return Materials.SOFT


func _in_radius(width: int, origin: int, here: int, radius: int) -> bool:
	if origin < 0:
		return false
	var dx := absi((origin % width) - (here % width))
	var dy := absi((origin / width) - (here / width))
	return maxi(dx, dy) <= radius

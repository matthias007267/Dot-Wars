extends RefCounted
## Current construction phase: pure state for owned production buildings/sites.
## Geometry, prices, research and defeat policy are supplied by the controller.
enum Kind { MAIN_CORE, OUTPOST, INTERCEPTOR, RESEARCH_CENTER }
const PLANNED := 1
const STARTED := 2
const READY := 4
const ACTIVE := PLANNED | STARTED | READY

var width := 0
var height := 0
var faction_count := 0
var records: Array[Dictionary] = []
var occupant := PackedInt32Array()
var revision := 0

func setup(p_width: int, p_height: int, factions: int) -> bool:
	if p_width <= 0 or p_height <= 0 or factions <= 0 or p_width * p_height > 16777216: return false
	width = p_width
	height = p_height
	faction_count = factions
	records.clear()
	occupant.resize(width * height)
	occupant.fill(-1)
	revision = 0
	return true

func valid(id: int) -> bool:
	return id >= 0 and id < records.size() and not records[id].destroyed

func rect_inside(rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= width and rect.end.y <= height

func space_free(rect: Rect2i) -> bool:
	if not rect_inside(rect): return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if occupant[y * width + x] >= 0: return false
	return true

func add(kind: int, owner: int, rect: Rect2i, max_hp: int, initial_hp: int, required_work: int, finished: bool) -> int:
	if kind < Kind.MAIN_CORE or kind > Kind.RESEARCH_CENTER or owner < 0 or owner >= faction_count: return -1
	if max_hp <= 0 or initial_hp <= 0 or initial_hp > max_hp or required_work <= 0 or not space_free(rect): return -1
	var id := records.size()
	records.append({"id": id, "kind": kind, "owner": owner, "rect": rect, "hp": initial_hp,
		"paid": 0, "max_hp": max_hp, "required": required_work, "work": required_work if finished else 0,
		"started": finished, "ready": finished, "destroyed": false})
	_claim(id, rect, true)
	revision += 1
	return id

func _claim(id: int, rect: Rect2i, reserve: bool) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x): occupant[y * width + x] = id if reserve else -1

## Called only after the controller verifies a living assigned worker's contribution.
func contribute(id: int, owner: int, amount: int) -> int:
	if not valid(id) or amount <= 0: return 0
	var row: Dictionary = records[id]
	if row.owner != owner or row.ready: return 0
	var accepted := mini(amount, int(row.required) - int(row.work))
	row.work = int(row.work) + accepted
	if accepted > 0: row.started = true
	row.ready = row.work == row.required
	if accepted > 0: revision += 1
	return accepted

func damage(id: int, amount: int) -> int:
	if not valid(id) or amount <= 0: return 0
	var row: Dictionary = records[id]
	var accepted := mini(amount, int(row.hp))
	row.hp = int(row.hp) - accepted
	if row.hp == 0:
		row.destroyed = true
		_claim(id, row.rect, false)
	if accepted > 0: revision += 1
	return accepted

func phase(id: int) -> int:
	if not valid(id): return 0
	if records[id].ready: return READY
	return STARTED if records[id].started else PLANNED

func count(owner: int, kind: int, phases: int = ACTIVE) -> int:
	var result := 0
	for id in records.size():
		if records[id].owner == owner and records[id].kind == kind and (phase(id) & phases) != 0: result += 1
	return result

## This is the binding begun-core fact, not a complete defeat condition.
func has_begun_core(owner: int) -> bool:
	return count(owner, Kind.MAIN_CORE, STARTED) > 0

func ready_sites(owner: int, production_only := true) -> PackedInt32Array:
	var result := PackedInt32Array()
	for id in records.size():
		if records[id].owner == owner and phase(id) == READY and (not production_only or records[id].kind != Kind.INTERCEPTOR and records[id].kind != Kind.RESEARCH_CENTER): result.append(id)
	return result

func perimeter(id: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	if not valid(id): return result
	var rect: Rect2i = records[id].rect
	# Orthogonal working/arrival cells only, stable row/column ordering.
	for y in range(maxi(0, rect.position.y - 1), mini(height, rect.end.y + 1)):
		for x in range(maxi(0, rect.position.x - 1), mini(width, rect.end.x + 1)):
			var on_horizontal := (y == rect.position.y - 1 or y == rect.end.y) and x >= rect.position.x and x < rect.end.x
			var on_vertical := (x == rect.position.x - 1 or x == rect.end.x) and y >= rect.position.y and y < rect.end.y
			if on_horizontal or on_vertical: result.append(y * width + x)
	return result

func snapshot() -> Dictionary:
	return {"width": width, "height": height, "factions": faction_count, "revision": revision, "records": records.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if typeof(data.get("width")) != TYPE_INT or typeof(data.get("height")) != TYPE_INT or typeof(data.get("factions")) != TYPE_INT: return false
	if not data.get("records") is Array or typeof(data.get("revision")) != TYPE_INT or data.revision < 0: return false
	var candidate = get_script().new()
	if not candidate.setup(data.width, data.height, data.factions): return false
	for value in data.records:
		if not value is Dictionary: return false
		for key in ["id", "kind", "owner", "hp", "max_hp", "required", "work"]:
			if typeof(value.get(key)) != TYPE_INT: return false
		for key in ["started", "ready", "destroyed"]:
			if typeof(value.get(key)) != TYPE_BOOL: return false
		if not value.get("rect") is Rect2i: return false
		if value.id != candidate.records.size() or value.kind < Kind.MAIN_CORE or value.kind > Kind.RESEARCH_CENTER or value.owner < 0 or value.owner >= data.factions: return false
		if not candidate.rect_inside(value.rect) or value.max_hp <= 0 or value.required <= 0 or value.work < 0 or value.work > value.required: return false
		if value.started != (value.work > 0) or value.ready != (value.work == value.required): return false
		if value.hp < 0 or value.hp > value.max_hp or value.destroyed != (value.hp == 0): return false
		if not value.destroyed:
			if not candidate.space_free(value.rect): return false
			candidate._claim(value.id, value.rect, true)
		if typeof(value.get("paid", 0)) != TYPE_INT or int(value.get("paid", 0)) < 0 or int(value.get("paid", 0)) > 2147483647: return false
		var row: Dictionary = value.duplicate(true)
		row.paid = int(value.get("paid", 0))
		candidate.records.append(row)
	width = candidate.width
	height = candidate.height
	faction_count = candidate.faction_count
	records = candidate.records
	occupant = candidate.occupant
	revision = data.revision
	return true

func state_hash() -> int:
	return hash([width, height, faction_count, records])


func repair(id: int, owner: int, amount: int) -> int:
	if not valid(id) or amount <= 0: return 0
	var row: Dictionary = records[id]
	if row.owner != owner or not row.ready: return 0
	var accepted := mini(amount, int(row.max_hp) - int(row.hp))
	row.hp = int(row.hp) + accepted
	if accepted > 0: revision += 1
	return accepted

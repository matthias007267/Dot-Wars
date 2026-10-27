extends RefCounted
## P5: Spielerwissen ist strikt vom wahren Weltzustand getrennt.
## Vorläufige Reichweiten; keine Freigabe von Sensorgebäuden oder Bündnis-UI.
const WORKER_RADIUS := 7
const WARRIOR_RADIUS := 9
const CORE_RADIUS := 12
const OBSTACLE_DEPTH := 4
const Backend = preload("res://src/sim/native_search.gd")
var reference_only := false
var native_updates := 0

var width := 0
var height := 0
var factions := 0
var visible: Array[PackedByteArray] = []
var explored: Array[PackedByteArray] = []
var known_terrain: Array[PackedByteArray] = []
var known_excavated: Array[PackedByteArray] = []
var known_sites: Array[Dictionary] = []
## alliance[faction] = alliance id; default independent.
var alliance := PackedInt32Array()
var _last_signature := -1
var _last_terrain_signature := -1
var _sight_cache: Dictionary = {}
## Exact terrain change detection without hashing the map every tick: the last
## seen arrays are kept as copies and compared directly, so raw writes are still
## noticed. Not saved; a fresh or restored state starts a new version.
var _seen_cells := PackedByteArray()
var _seen_excavated := PackedByteArray()
var _terrain_version := 0
var _blocking := PackedByteArray()
var _blocking_key := -1
## Per faction: allied visible cells and terrain key of the last published merge.
var _merged_cells: Array[PackedInt32Array] = []
var _merged_terrain: PackedInt64Array = PackedInt64Array()

func setup(world: WorldState, count: int) -> void:
	_last_signature = -1
	_last_terrain_signature = -1
	_sight_cache.clear()
	_forget_merges()
	width = world.width
	height = world.height
	factions = count
	visible.clear()
	explored.clear()
	known_terrain.clear()
	known_excavated.clear()
	known_sites.clear()
	alliance.resize(count)
	for faction in count:
		alliance[faction] = faction
		var empty := PackedByteArray()
		empty.resize(world.cell_count())
		visible.append(empty.duplicate())
		explored.append(empty.duplicate())
		var memory := PackedByteArray()
		memory.resize(world.cell_count())
		memory.fill(255)
		known_terrain.append(memory)
		known_excavated.append(empty.duplicate())
		known_sites.append({})

func _forget_merges() -> void:
	_seen_cells = PackedByteArray()
	_seen_excavated = PackedByteArray()
	_terrain_version += 1
	_blocking = PackedByteArray()
	_blocking_key = -1
	_merged_cells.clear()
	_merged_terrain = PackedInt64Array()

func is_visible(faction: int, cell: int) -> bool:
	return faction >= 0 and faction < factions and cell >= 0 and cell < width * height and visible[faction][cell] == 1

func is_explored(faction: int, cell: int) -> bool:
	return faction >= 0 and faction < factions and cell >= 0 and cell < width * height and explored[faction][cell] == 1

func known_material(faction: int, cell: int) -> int:
	return int(known_terrain[faction][cell]) if is_explored(faction, cell) else -1

func known_building(faction: int, id: int) -> Dictionary:
	if faction < 0 or faction >= factions: return {}
	return known_sites[faction].get(id, {}).duplicate(true)

func remembered_sites(faction: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if faction < 0 or faction >= factions: return result
	for id in known_sites[faction]:
		var row: Dictionary = known_sites[faction][id]
		if not bool(row.get("destroyed", false)): result.append(row.duplicate(true))
	return result

func update(sim: Simulation) -> void:
	if factions != sim.rules.faction_count or width != sim.world.width or height != sim.world.height:
		setup(sim.world, sim.rules.faction_count)
	# Deterministic state signature: unchanged unit positions, blockers, alliances and
	# building state need no new LOS rays or player-knowledge updates.
	var sources: Array = []
	for id in sim.workers.count:
		sources.append([int(sim.workers.faction[id]), int(sim.workers.cell[id]), WORKER_RADIUS])
	for id in sim.army.count:
		sources.append([int(sim.army.owners[id]), int(sim.army.cells[id]), WARRIOR_RADIUS])
	var sites_state: Array = []
	for row in sim.construction.sites.records:
		sites_state.append([row.id, row.owner, row.rect, row.ready, row.destroyed, row.hp, row.work, row.get("weapon_level", 0), row.get("weapon_upgrade", -1)])
		if not row.destroyed and (row.ready or row.started):
			sources.append([int(row.owner), sim.construction.center(int(row.id)), CORE_RADIUS, row.rect])
	if _seen_cells != sim.world.cells or _seen_excavated != sim.world.excavated:
		_seen_cells = sim.world.cells.duplicate()
		_seen_excavated = sim.world.excavated.duplicate()
		_terrain_version += 1
	var terrain_signature := hash(["terrain", _terrain_version])
	var signature := hash([terrain_signature, sources, sites_state, alliance])
	if signature == _last_signature and terrain_signature == _last_terrain_signature:
		return
	_last_signature = signature
	_last_terrain_signature = terrain_signature
	# Materials are already zero for empty / nonzero for opaque. Only building
	# footprints must be added; never scan the entire map through construction.at().
	var footprints: Array = []
	for row in sim.construction.sites.records:
		if not row.destroyed: footprints.append(row.rect)
	var blocking_key := hash([terrain_signature, footprints])
	if blocking_key != _blocking_key or _blocking.size() != sim.world.cell_count():
		_blocking = sim.world.cells.duplicate()
		for rect in footprints:
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x): _blocking[y * width + x] = Materials.INDESTRUCTIBLE
		_blocking_key = blocking_key
	var blocking := _blocking
	var own_cells: Array[PackedInt32Array] = []
	for faction in factions: own_cells.append(PackedInt32Array())
	var native := Backend.backend() if not reference_only and not "--fog-reference" in OS.get_cmdline_user_args() else null
	var native_ok := false
	if native != null and native.has_method("fog_visible_depth"):
		var packed := PackedInt32Array()
		for source in sources:
			if int(source[0]) < 0 or int(source[0]) >= factions: continue
			packed.append(int(source[0]))
			packed.append(int(source[1]))
			packed.append(int(source[2]))
			var footprint: Rect2i = source[3] if source.size() > 3 else Rect2i()
			packed.append(footprint.position.x)
			packed.append(footprint.position.y)
			packed.append(footprint.size.x)
			packed.append(footprint.size.y)
		var result = native.fog_visible_depth(blocking, packed, factions, width)
		if result is Array and result.size() == factions:
			native_ok = true
			for faction in factions: own_cells[faction] = result[faction]
			native_updates += 1
	if not native_ok:
		var own_sight: Array[PackedByteArray] = []
		for faction in factions:
			var mask := PackedByteArray()
			mask.resize(blocking.size())
			own_sight.append(mask)
		var seen_sources: Dictionary = {}
		var active_keys: Dictionary = {}
		for source in sources:
			var owner := int(source[0])
			if owner < 0 or owner >= factions: continue
			var origin := int(source[1])
			var radius := int(source[2])
			var footprint: Rect2i = source[3] if source.size() > 3 else Rect2i()
			var key := [owner, origin, radius, footprint]
			if seen_sources.has(key): continue
			seen_sources[key] = true
			active_keys[Vector2i(origin, radius)] = true
			var mask: PackedByteArray = own_sight[owner]
			var cells: PackedInt32Array = own_cells[owner]
			for cell in _visible_cells(blocking, origin, radius, footprint):
				if mask[cell] == 0:
					mask[cell] = 1
					cells.append(cell)
			own_sight[owner] = mask
			own_cells[owner] = cells
		# Cache memory is proportional to live origins and sight radius, not map area.
		for key in _sight_cache.keys():
			if not active_keys.has(key): _sight_cache.erase(key)
	else:
		_sight_cache.clear()
	var terrain := sim.world.cells
	var merge_native := native != null and native.has_method("fog_merge")
	if _merged_cells.size() != factions:
		_merged_cells.resize(factions)
		_merged_terrain.resize(factions)
		_merged_terrain.fill(-1)
	for faction in factions:
		var merged := false
		if merge_native:
			var allied_cells := PackedInt32Array()
			for ally in factions:
				if alliance[faction] == alliance[ally]: allied_cells.append_array(own_cells[ally])
			# Same cells over unchanged terrain rewrite identical bytes; skip the copy.
			if _merged_terrain[faction] == terrain_signature and _merged_cells[faction] == allied_cells:
				merged = true
			else:
				_merged_terrain[faction] = -1
			var published = null if merged else native.fog_merge(allied_cells, explored[faction], known_terrain[faction], known_excavated[faction], terrain, sim.world.excavated)
			if published is Array and published.size() == 4:
				visible[faction] = published[0]
				explored[faction] = published[1]
				known_terrain[faction] = published[2]
				known_excavated[faction] = published[3]
				merged = true
				_merged_cells[faction] = allied_cells
				_merged_terrain[faction] = terrain_signature
		if not merged:
			var mask := PackedByteArray()
			mask.resize(blocking.size())
			var explored_mask := explored[faction].duplicate()
			var memory := known_terrain[faction].duplicate()
			var floor_memory := known_excavated[faction].duplicate()
			for ally in factions:
				if alliance[faction] != alliance[ally]: continue
				for cell in own_cells[ally]:
					mask[cell] = 1
					explored_mask[cell] = 1
					memory[cell] = terrain[cell]
					floor_memory[cell] = sim.world.excavated[cell]
			visible[faction] = mask
			explored[faction] = explored_mask
			known_terrain[faction] = memory
			known_excavated[faction] = floor_memory
		# Snapshot updates only while a footprint is in view; unseen destruction remains unknown.
		for row in sim.construction.sites.records:
			var id := int(row.id)
			var rect: Rect2i = row.rect
			var seen := false
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					if visible[faction][y * width + x] == 1: seen = true
			if seen:
				known_sites[faction][id] = row.duplicate(true)
		# Sites absent from live records must not remain visible after their footprint is revisited.
		for id in known_sites[faction].keys():
			var present := false
			for row in sim.construction.sites.records:
				if int(row.id) == int(id): present = true
			if present: continue
			var old: Dictionary = known_sites[faction][id]
			var footprint: Rect2i = old.get("rect", Rect2i())
			var revisited := false
			for y in range(maxi(0, footprint.position.y), mini(height, footprint.end.y)):
				for x in range(maxi(0, footprint.position.x), mini(width, footprint.end.x)):
					if visible[faction][y * width + x] == 1: revisited = true
			if revisited: known_sites[faction].erase(id)

func _visible_cells(blocking: PackedByteArray, origin: int, radius: int, footprint := Rect2i()) -> PackedInt32Array:
	var key := Vector2i(origin, radius)
	var x0 := origin % width
	var y0 := origin / width
	var left := maxi(0, x0 - radius)
	var right := mini(width, x0 + radius + 1)
	var top := maxi(0, y0 - radius)
	var bottom := mini(height, y0 + radius + 1)
	# Exact local bytes, not a hash: any changed blocker on a possible ray
	# invalidates this origin. Distant mining keeps unrelated origins cached.
	var patch := PackedByteArray()
	for y in range(top, bottom): patch.append_array(blocking.slice(y * width + left, y * width + right))
	if _sight_cache.has(key) and _sight_cache[key].blocking == patch and _sight_cache[key].footprint == footprint:
		return _sight_cache[key].cells
	var cells := PackedInt32Array()
	for y in range(top, bottom):
		for x in range(left, right):
			if (x - x0) * (x - x0) + (y - y0) * (y - y0) > radius * radius: continue
			if _line_clear(blocking, x0, y0, x, y, footprint): cells.append(y * width + x)
	_sight_cache[key] = {"blocking": patch, "cells": cells, "footprint": footprint}
	return cells

func _reveal(mask: PackedByteArray, blocking: PackedByteArray, origin: int, radius: int, footprint := Rect2i()) -> void:
	if origin < 0 or origin >= mask.size(): return
	var x0 := origin % width
	var y0 := origin / width
	for y in range(maxi(0, y0 - radius), mini(height, y0 + radius + 1)):
		for x in range(maxi(0, x0 - radius), mini(width, x0 + radius + 1)):
			if (x - x0) * (x - x0) + (y - y0) * (y - y0) > radius * radius: continue
			if _line_clear(blocking, x0, y0, x, y, footprint): mask[y * width + x] = 1

func _line_clear(blocking: PackedByteArray, x0: int, y0: int, x1: int, y1: int, footprint := Rect2i()) -> bool:
	# Four raster steps including the first obstacle, with no reset in gaps.
	# A building source ignores only its own footprint, never a neighboring site.
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var error := dx - dy
	var x := x0
	var y := y0
	var depth := 0
	while x != x1 or y != y1:
		var doubled := error * 2
		if doubled > -dy:
			error -= dy
			x += sx
		if doubled < dx:
			error += dx
			y += sy
		if not footprint.has_point(Vector2i(x, y)):
			if depth > 0: depth += 1
			elif blocking[y * width + x] != 0: depth = 1
			if depth > OBSTACLE_DEPTH: return false
		if x == x1 and y == y1: return true
	return true

func snapshot() -> Dictionary:
	return {"width": width, "height": height, "factions": factions,
		"visible": visible.duplicate(true), "explored": explored.duplicate(true),
		"terrain": known_terrain.duplicate(true), "excavated": known_excavated.duplicate(true), "sites": known_sites.duplicate(true),
		"alliance": alliance.duplicate()}

func restore(data: Dictionary, world: WorldState, count: int) -> bool:
	if int(data.get("width", -1)) != world.width or int(data.get("height", -1)) != world.height or int(data.get("factions", -1)) != count: return false
	var v: Array = data.get("visible", [])
	var e: Array = data.get("explored", [])
	var t: Array = data.get("terrain", [])
	var floor_data = data.get("excavated", [])
	if not floor_data is Array: return false
	var has_floor := data.has("excavated")
	if has_floor and floor_data.size() != count: return false
	var s: Array = data.get("sites", [])
	var a: PackedInt32Array = data.get("alliance", PackedInt32Array())
	if v.size() != count or e.size() != count or t.size() != count or s.size() != count or a.size() != count: return false
	for faction in count:
		if not v[faction] is PackedByteArray or not e[faction] is PackedByteArray or not t[faction] is PackedByteArray or not s[faction] is Dictionary: return false
		if v[faction].size() != world.cell_count() or e[faction].size() != world.cell_count() or t[faction].size() != world.cell_count(): return false
		if has_floor and (not floor_data[faction] is PackedByteArray or floor_data[faction].size() != world.cell_count()): return false
		for cell in world.cell_count():
			if int(v[faction][cell]) > 1 or int(e[faction][cell]) > 1 or (v[faction][cell] == 1 and e[faction][cell] == 0): return false
			if has_floor and (floor_data[faction][cell] > 1 or (e[faction][cell] == 0 and floor_data[faction][cell] != 0)): return false
	setup(world, count)
	for faction in count:
		visible[faction] = v[faction].duplicate()
		explored[faction] = e[faction].duplicate()
		known_terrain[faction] = t[faction].duplicate()
		if has_floor: known_excavated[faction] = floor_data[faction].duplicate()
		known_sites[faction] = s[faction].duplicate(true)
	alliance = a.duplicate()
	_last_signature = -1
	_last_terrain_signature = -1
	_sight_cache.clear()
	_forget_merges()
	return true

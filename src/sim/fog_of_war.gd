extends RefCounted
## P5: Spielerwissen ist strikt vom wahren Weltzustand getrennt.
## Vorläufige Reichweiten; keine Freigabe von Sensorgebäuden oder Bündnis-UI.
const WORKER_RADIUS := 7
const WARRIOR_RADIUS := 9
const CORE_RADIUS := 12

var width := 0
var height := 0
var factions := 0
var visible: Array[PackedByteArray] = []
var explored: Array[PackedByteArray] = []
var known_terrain: Array[PackedByteArray] = []
var known_sites: Array[Dictionary] = []
## alliance[faction] = alliance id; default independent.
var alliance := PackedInt32Array()
var _last_signature := -1
var _last_terrain_signature := -1
var _sight_cache: Dictionary = {}
var _blocker_signature := -1

func setup(world: WorldState, count: int) -> void:
	_last_signature = -1
	_last_terrain_signature = -1
	_sight_cache.clear()
	_blocker_signature = -1
	width = world.width
	height = world.height
	factions = count
	visible.clear()
	explored.clear()
	known_terrain.clear()
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
		known_sites.append({})

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
		sites_state.append([row.id, row.owner, row.rect, row.ready, row.destroyed, row.hp, row.work])
		if not row.destroyed and row.ready:
			sources.append([int(row.owner), sim.construction.center(int(row.id)), CORE_RADIUS])
	var terrain_signature := hash(sim.world.cells)
	var signature := hash([terrain_signature, sources, sites_state, alliance])
	if signature == _last_signature and terrain_signature == _last_terrain_signature:
		return
	_last_signature = signature
	_last_terrain_signature = terrain_signature
	var blocking := PackedByteArray()
	blocking.resize(sim.world.cell_count())
	for cell in blocking.size():
		blocking[cell] = 1 if sim.world.cells[cell] != Materials.EMPTY or sim.construction.at(cell) >= 0 else 0
	var blocker_signature := hash(blocking)
	if blocker_signature != _blocker_signature:
		_sight_cache.clear()
		_blocker_signature = blocker_signature
	var own_sight: Array[PackedByteArray] = []
	for faction in factions:
		var mask := PackedByteArray()
		mask.resize(blocking.size())
		own_sight.append(mask)
	# Multiple units at the same cell and radius must not trace the same rays twice.
	var seen_sources: Dictionary = {}
	for id in sim.workers.count:
		var owner := int(sim.workers.faction[id])
		if owner >= 0 and owner < factions:
			var cell := int(sim.workers.cell[id])
			var key := Vector3i(owner, cell, WORKER_RADIUS)
			if not seen_sources.has(key):
				seen_sources[key] = true
				_reveal_cached(own_sight[owner], blocking, cell, WORKER_RADIUS)
	for id in sim.army.count:
		var owner := int(sim.army.owners[id])
		if owner >= 0 and owner < factions:
			var cell := int(sim.army.cells[id])
			var key := Vector3i(owner, cell, WARRIOR_RADIUS)
			if not seen_sources.has(key):
				seen_sources[key] = true
				_reveal_cached(own_sight[owner], blocking, cell, WARRIOR_RADIUS)
	for row in sim.construction.sites.records:
		if row.destroyed or not row.ready: continue
		var owner := int(row.owner)
		if owner >= 0 and owner < factions:
			var cell := sim.construction.center(int(row.id))
			var key := Vector3i(owner, cell, CORE_RADIUS)
			if not seen_sources.has(key):
				seen_sources[key] = true
				_reveal_cached(own_sight[owner], blocking, cell, CORE_RADIUS)
	# Evict masks for moved or removed sources; cache stays bounded by live origins.
	var active_keys: Dictionary = {}
	for source in seen_sources:
		var key: Vector3i = source
		active_keys[Vector2i(key.y, key.z)] = true
	for key in _sight_cache.keys():
		if not active_keys.has(key): _sight_cache.erase(key)
	for faction in factions:
		visible[faction].fill(0)
		for ally in factions:
			if alliance[faction] != alliance[ally]: continue
			for cell in blocking.size():
				if own_sight[ally][cell] == 1: visible[faction][cell] = 1
		for cell in blocking.size():
			if visible[faction][cell] == 0: continue
			explored[faction][cell] = 1
			known_terrain[faction][cell] = sim.world.cells[cell]
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

func _reveal_cached(mask: PackedByteArray, blocking: PackedByteArray, origin: int, radius: int) -> void:
	var key := Vector2i(origin, radius)
	if not _sight_cache.has(key):
		var cells := PackedByteArray()
		cells.resize(blocking.size())
		_reveal(cells, blocking, origin, radius)
		_sight_cache[key] = cells
	var cached: PackedByteArray = _sight_cache[key]
	var x0 := origin % width
	var y0 := origin / width
	for y in range(maxi(0, y0 - radius), mini(height, y0 + radius + 1)):
		for x in range(maxi(0, x0 - radius), mini(width, x0 + radius + 1)):
			var index := y * width + x
			if cached[index] == 1: mask[index] = 1

func _reveal(mask: PackedByteArray, blocking: PackedByteArray, origin: int, radius: int) -> void:
	if origin < 0 or origin >= mask.size(): return
	var x0 := origin % width
	var y0 := origin / width
	for y in range(maxi(0, y0 - radius), mini(height, y0 + radius + 1)):
		for x in range(maxi(0, x0 - radius), mini(width, x0 + radius + 1)):
			if (x - x0) * (x - x0) + (y - y0) * (y - y0) > radius * radius: continue
			if _line_clear(blocking, x0, y0, x, y): mask[y * width + x] = 1

func _line_clear(blocking: PackedByteArray, x0: int, y0: int, x1: int, y1: int) -> bool:
	# Integer Bresenham: endpoint is visible even if opaque, but nothing behind it.
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var error := dx - dy
	var x := x0
	var y := y0
	while x != x1 or y != y1:
		var doubled := error * 2
		if doubled > -dy:
			error -= dy
			x += sx
		if doubled < dx:
			error += dx
			y += sy
		if x == x1 and y == y1: return true
		if blocking[y * width + x] == 1: return false
	return true

func snapshot() -> Dictionary:
	return {"width": width, "height": height, "factions": factions,
		"visible": visible.duplicate(true), "explored": explored.duplicate(true),
		"terrain": known_terrain.duplicate(true), "sites": known_sites.duplicate(true),
		"alliance": alliance.duplicate()}

func restore(data: Dictionary, world: WorldState, count: int) -> bool:
	if int(data.get("width", -1)) != world.width or int(data.get("height", -1)) != world.height or int(data.get("factions", -1)) != count: return false
	var v: Array = data.get("visible", [])
	var e: Array = data.get("explored", [])
	var t: Array = data.get("terrain", [])
	var s: Array = data.get("sites", [])
	var a: PackedInt32Array = data.get("alliance", PackedInt32Array())
	if v.size() != count or e.size() != count or t.size() != count or s.size() != count or a.size() != count: return false
	for faction in count:
		if not v[faction] is PackedByteArray or not e[faction] is PackedByteArray or not t[faction] is PackedByteArray or not s[faction] is Dictionary: return false
		if v[faction].size() != world.cell_count() or e[faction].size() != world.cell_count() or t[faction].size() != world.cell_count(): return false
		for cell in world.cell_count():
			if int(v[faction][cell]) > 1 or int(e[faction][cell]) > 1 or (v[faction][cell] == 1 and e[faction][cell] == 0): return false
	setup(world, count)
	for faction in count:
		visible[faction] = v[faction].duplicate()
		explored[faction] = e[faction].duplicate()
		known_terrain[faction] = t[faction].duplicate()
		known_sites[faction] = s[faction].duplicate(true)
	alliance = a.duplicate()
	_last_signature = -1
	_last_terrain_signature = -1
	_sight_cache.clear()
	_blocker_signature = -1
	return true

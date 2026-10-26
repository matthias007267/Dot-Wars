extends RefCounted
## Approved construction prototype. No rendering and no per-building Nodes.
const REPAIR_PERIOD := 4
const REPAIR_HP := 2
const REPAIR_COST := 1
const Store = preload("res://src/sim/settlement_store.gd")
var sites: Store = Store.new()
var interceptors_unlocked := false
var outposts_unlocked := false # Runtime-only Testlab flag; debug saves remain blocked.
var selected := -1 # UI only.
var _fields := {}
var _terrain := -1

func setup(world: WorldState, factions: int) -> void:
	sites.setup(world.width, world.height, factions)

func price(kind: int, owner: int) -> int:
	if kind == Store.Kind.INTERCEPTOR: return 250
	if kind == Store.Kind.RESEARCH_CENTER: return 300
	return 500 if kind == Store.Kind.MAIN_CORE else 200 + 100 * sites.count(owner, Store.Kind.OUTPOST)

func at(cell: int) -> int:
	return sites.occupant[cell] if cell >= 0 and cell < sites.occupant.size() else -1

func center(id: int) -> int:
	var rect: Rect2i = sites.records[id].rect
	return (rect.position.y + rect.size.y / 2) * sites.width + rect.position.x + rect.size.x / 2

func initial(sim: Simulation, cell: int, owner: int, legacy := false) -> int:
	var pos := Vector2i(cell % sites.width, cell / sites.width)
	var rect := Rect2i(pos if legacy else pos - Vector2i(2, 2), Vector2i.ONE if legacy else Vector2i(5, 5))
	if not sites.rect_inside(rect): return -1
	if not legacy:
		for y in range(pos.y - 4, pos.y + 5):
			for x in range(pos.x - 4, pos.x + 5):
				if sim.world.in_bounds(x, y): sim.world.set_material(y * sites.width + x, Materials.EMPTY)
	var id: int = sites.add(Store.Kind.MAIN_CORE, owner, rect, 600, 600, 600, true)
	if id >= 0: _ground(sim, rect, Materials.INDESTRUCTIBLE)
	return id

func place(sim: Simulation, kind: int, cell: int, builders: PackedInt32Array, owner := 0, dry_run := false) -> int:
	if kind < 0 or kind > Store.Kind.RESEARCH_CENTER or owner < 0 or owner >= sites.faction_count: return -1
	if sim._match_live() and sim.rules.alive[owner] == 0: return -1
	if kind == Store.Kind.OUTPOST and not outposts_unlocked: return -1
	if kind == Store.Kind.INTERCEPTOR and not interceptors_unlocked: return -1
	if kind == Store.Kind.MAIN_CORE and sites.count(owner, kind) > 0: return -1
	if cell < 0 or cell >= sim.world.cell_count(): return -1
	var side := 5 if kind == Store.Kind.MAIN_CORE else 3
	var rect := Rect2i(Vector2i(cell % sites.width, cell / sites.width), Vector2i(side, side))
	if not sites.space_free(rect): return -1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := y * sites.width + x
			if sim.world.cells[c] != Materials.EMPTY or sim.workers.occupant[c] >= 0 or sim.army.occupant[c] >= 0 or sim.buildings.cell.has(c) or (not sim._match_live() and sim._in_core(c)): return -1
	for energy_cell in sim.energy_dots.cells:
		if rect.has_point(Vector2i(energy_cell % sites.width, energy_cell / sites.width)): return -1
	var wallet := sim.rules.wallet(sim, owner)
	var cost := price(kind, owner)
	if wallet.energy < cost: return -1
	if dry_run: return 0
	var hp := 600 if kind == Store.Kind.MAIN_CORE else 150 if kind == Store.Kind.INTERCEPTOR else 200
	var work := 600 if kind == Store.Kind.MAIN_CORE else 300
	var id: int = sites.add(kind, owner, rect, hp, hp, work, false)
	if id < 0: return -1
	wallet.energy -= cost
	sites.records[id].paid = cost
	_ground(sim, rect, Materials.INDESTRUCTIBLE)
	assign(sim, id, builders, owner)
	if owner == 0: selected = id
	return id

func assign(sim: Simulation, site: int, ids: PackedInt32Array, owner := 0, repairing := false) -> int:
	if not sites.valid(site) or sites.records[site].owner != owner: return 0
	var row: Dictionary = sites.records[site]
	if repairing:
		if not row.ready or row.hp >= row.max_hp: return 0
	elif row.ready: return 0
	var assigned := 0
	for id in ids:
		if id < 0 or id >= sim.workers.count or sim.workers.faction[id] != owner: continue
		sim.workers.build_site[id] = site
		sim.workers.build_mode[id] = 1 if repairing else 0
		sim.workers.state[id] = WorkerStore.STATE_BUILDING
		sim.workers.target[id] = -1
		sim.workers.aim[id] = -1
		assigned += 1
	return assigned

func release(sim: Simulation, id: int) -> void:
	sim.workers.build_site[id] = -1
	sim.workers.build_mode[id] = 0
	if sim.workers.state[id] == WorkerStore.STATE_BUILDING: sim.workers.state[id] = WorkerStore.STATE_WAITING

func step(sim: Simulation) -> void:
	# Fields are shared by all builders of one site, rebuilt only after terrain changes.
	if _terrain != sim.world.revision:
		_fields.clear()
		_terrain = sim.world.revision
	var w := sim.workers
	for id in w.count:
		var site := w.build_site[id]
		if site < 0: continue
		if not _work_valid(site, int(w.faction[id]), int(w.build_mode[id])):
			release(sim, id)
			continue
		w.state[id] = WorkerStore.STATE_BUILDING
		if not _fields.has(site): _fields[site] = _field(sim, site)
		var dist: PackedInt32Array = _fields[site]
		var c := w.cell[id]
		if dist[c] == 0:
			if w.build_mode[id] == 1:
				if sim.tick_count % REPAIR_PERIOD == 0:
					var wallet := sim.rules.wallet(sim, w.faction[id])
					if wallet.energy >= REPAIR_COST and sites.repair(site, w.faction[id], REPAIR_HP) > 0:
						wallet.energy -= REPAIR_COST
			else:
				sites.contribute(site, w.faction[id], 1)
			continue
		var period := sim.rules.wallet(sim, w.faction[id]).worker_period(sim.config.move_period_ticks)
		if sim.tick_count % maxi(1, period) != 0 or w.last_move_tick[id] == sim.tick_count: continue
		for direction in range(1, 5):
			var next := MovementSystem.neighbor(c, direction, sites.width, sim.world.cell_count())
			if next < 0 or dist[next] < 0 or (dist[c] >= 0 and dist[next] >= dist[c]): continue
			if w.occupant[next] >= 0 or sim.army.occupant[next] >= 0: continue
			w.move_to(id, next, sim.tick_count)
			w.state[id] = WorkerStore.STATE_BUILDING
			break
	# Release immediately at completion, including workers processed before the final contributor.
	for id in w.count:
		if w.build_site[id] >= 0 and not _work_valid(w.build_site[id], w.faction[id], w.build_mode[id]): release(sim, id)
	_sync(sim)

func _field(sim: Simulation, id: int) -> PackedInt32Array:
	var queue := receivers_for(sim, id)
	if not sim._match_live() and sites.records[id].owner == 0 and sites.records[id].rect.size == Vector2i.ONE and sim.upgrades.core_level > 0:
		queue = _legacy_work_cells(sim, id)
	return distances(sim, queue)

func distances(sim: Simulation, queue: PackedInt32Array) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(sim.world.cell_count())
	dist.fill(-1)
	for c in queue: dist[c] = 0
	var native := preload("res://src/sim/native_search.gd").backend()
	if native != null:
		var directions := PackedByteArray()
		directions.resize(dist.size())
		var forbidden := sim.core_mask if not sim._match_live() else PackedByteArray()
		var result: Variant = native.flow_spread(sim.world.cells, forbidden, dist, directions, queue, 0, 1 << 40, false, sites.width)
		if result is Array and result.size() == 5: return result[0]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for direction in range(1, 5):
			var next := MovementSystem.neighbor(c, direction, sites.width, dist.size())
			if next >= 0 and dist[next] < 0 and sim.world.cells[next] == Materials.EMPTY and (sim._match_live() or not sim._in_core(next)):
				dist[next] = dist[c] + 1
				queue.append(next)
	return dist

func receivers_for(sim: Simulation, id: int) -> PackedInt32Array:
	if sites.records[id].rect.size == Vector2i.ONE: return SacrificeSystem.delivery_cells(sim.world, center(id))
	var cells := PackedInt32Array()
	for c in sites.perimeter(id):
		if sim.world.cells[c] == Materials.EMPTY: cells.append(c)
	return cells

func receivers(sim: Simulation, owner: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for id in sites.ready_sites(owner): cells.append_array(receivers_for(sim, id))
	return cells

func production_site(owner: int, wanted := -1) -> int:
	if wanted >= 0:
		return wanted if sites.valid(wanted) and sites.records[wanted].owner == owner and sites.records[wanted].ready and sites.records[wanted].kind != Store.Kind.INTERCEPTOR else -1
	var ready: PackedInt32Array = sites.ready_sites(owner)
	return -1 if ready.is_empty() else ready[0]

func origin(sim: Simulation, site: int) -> int:
	if not sites.valid(site) or not sites.records[site].ready or sites.records[site].kind == Store.Kind.INTERCEPTOR: return -1
	var cells := receivers_for(sim, site)
	return -1 if cells.is_empty() else cells[0]

func survives(owner: int) -> bool:
	return not sites.ready_sites(owner).is_empty() or sites.has_begun_core(owner)

func damage(sim: Simulation, id: int, amount: int) -> void:
	if not sites.valid(id): return
	var rect: Rect2i = sites.records[id].rect
	sites.damage(id, amount)
	if not sites.valid(id):
		if sites.records[id].kind == Store.Kind.INTERCEPTOR: sim.energy_dots.neutralize_station(id)
		sim.rules.removed_mass += sim.spawner.cancel_site(id)
		for i in range(sim.army.queue.size() - 1, -1, -1):
			if int(sim.army.queue[i].get("site", -1)) == id:
				sim.army.queue.remove_at(i)
				sim.army.lost += 1
		_ground(sim, rect, Materials.EMPTY)
		for worker in sim.workers.count:
			if sim.workers.build_site[worker] == id: release(sim, worker)
	_sync(sim)

func combat(sim: Simulation) -> void:
	var hits := {}
	for row in sites.records:
		if row.destroyed: continue
		for c in sites.perimeter(row.id):
			var uid := sim.army.occupant[c]
			if uid < 0: continue
			var slot: int = sim.army.slots[uid]
			if sim.army.allied(sim.army.owners[slot], row.owner): continue
			if sim.tick_count - 1 - sim.army.last_attack[slot] < ArmyState.ATTACK_PERIOD: continue
			sim.army.last_attack[slot] = sim.tick_count - 1
			hits[row.id] = int(hits.get(row.id, 0)) + ArmyState.DAMAGE
	for id in hits: damage(sim, id, hits[id])

func _sync(sim: Simulation) -> void:
	if not sim._match_live(): return
	for faction in sim.rules.faction_count:
		sim.rules.core_hp[faction] = 0
		for row in sites.records:
			if not row.destroyed and row.owner == faction and row.kind == Store.Kind.MAIN_CORE:
				sim.rules.cores[faction] = center(row.id)
				sim.rules.core_hp[faction] = row.hp

func _ground(sim: Simulation, rect: Rect2i, material: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x): sim.world.set_material(y * sites.width + x, material)
	_fields.clear()

func snapshot(sim: Simulation) -> Dictionary:
	return {"sites": sites.snapshot(), "worker_sites": sim.spawner.site_queue()}

func restore(sim: Simulation, data: Dictionary) -> bool:
	if not data.get("sites") is Dictionary or not sites.restore(data.sites): return false
	for owner in sites.faction_count:
		if sites.count(owner, Store.Kind.MAIN_CORE) > 1: return false
	if sites.width != sim.world.width or sites.height != sim.world.height or sites.faction_count != (sim.rules.faction_count if sim._match_live() else 1): return false
	for row in sites.records:
		if row.destroyed: continue
		var rect: Rect2i = row.rect
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if sim.world.cells[y * sites.width + x] != Materials.INDESTRUCTIBLE: return false
	for id in sim.workers.count:
		var site := sim.workers.build_site[id]
		if site == -1:
			if sim.workers.state[id] == WorkerStore.STATE_BUILDING: return false
		elif not _work_valid(site, sim.workers.faction[id], sim.workers.build_mode[id]) or sim.workers.state[id] != WorkerStore.STATE_BUILDING: return false
		if sim.workers.build_mode[id] > 1 or (site == -1 and sim.workers.build_mode[id] != 0): return false
	var bindings: Variant = data.get("worker_sites", PackedInt32Array())
	if not bindings is PackedInt32Array or bindings.size() != sim.spawner.pending(): return false
	for id in bindings:
		if id != -1 and production_site(0, id) != id: return false
	sim.spawner.import_sites(bindings)
	for item in sim.army.queue:
		var site := int(item.get("site", -1))
		if site != -1 and production_site(int(item.owner), site) != site: return false
	return true


func assign_repair(sim: Simulation, site: int, ids: PackedInt32Array, owner := 0) -> int:
	return assign(sim, site, ids, owner, true)

func _work_valid(site: int, owner: int, mode: int) -> bool:
	if not sites.valid(site) or sites.records[site].owner != owner: return false
	var row: Dictionary = sites.records[site]
	return (row.ready and row.hp < row.max_hp) if mode == 1 else not row.ready

func cancel_refund(site: int, owner := 0) -> int:
	if not sites.valid(site): return 0
	var row: Dictionary = sites.records[site]
	if row.owner != owner or row.ready or row.started or row.hp != row.max_hp: return 0
	return int(row.get("paid", 0))

func cancel(sim: Simulation, site: int, owner := 0) -> bool:
	if not sites.valid(site) or sites.records[site].owner != owner or sites.records[site].ready: return false
	var refund := cancel_refund(site, owner)
	damage(sim, site, sites.records[site].hp)
	sim.rules.wallet(sim, owner).energy += refund
	if selected == site: selected = -1
	return true


func can_place(sim: Simulation, kind: int, cell: int, owner := 0) -> bool:
	return place(sim, kind, cell, PackedInt32Array(), owner, true) >= 0


func _legacy_work_cells(sim: Simulation, site: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var middle := Vector2i(center(site) % sites.width, center(site) / sites.width)
	var radius := sim.upgrades.core_level + 1
	for y in range(maxi(0, middle.y - radius), mini(sites.height, middle.y + radius + 1)):
		for x in range(maxi(0, middle.x - radius), mini(sites.width, middle.x + radius + 1)):
			var cell := y * sites.width + x
			if sim.world.cells[cell] != Materials.EMPTY or sim._in_core(cell): continue
			for direction in range(1, 5):
				var next := MovementSystem.neighbor(cell, direction, sites.width, sim.world.cell_count())
				if next >= 0 and sim._in_core(next):
					cells.append(cell)
					break
	return cells

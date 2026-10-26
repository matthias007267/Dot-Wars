extends RefCounted
## One deterministic physical transport pass. Ownership transfers never mint energy.
const NEUTRAL := 255
const NO_ROUTE_TICKS := 1200
const HOLD_TICKS := 20
const CAPTURE_PER_TICK := 8
const CAPACITY := 256

static func step(e: EnergyStore, world: WorldState, workers: WorkerStore, gates: PackedInt32Array, tick: int, period: int, gate_owners: PackedByteArray, periods: PackedByteArray, sim: Simulation) -> int:
	e.ensure_tracks()
	if e.cells.is_empty(): return 0
	var owners := gate_owners
	if owners.size() != gates.size():
		owners = PackedByteArray()
		owners.resize(gates.size())
	var factions := sim.rules.faction_count if sim != null and sim._match_live() else 1
	for owner in owners:
		if owner < 4: factions = maxi(factions, owner + 1)
	for owner in e.owner:
		if owner < 4: factions = maxi(factions, owner + 1)
	var stamp := hash([hash(gates), hash(owners), factions])
	# Exact topology refresh: unit occupancy is deliberately absent from these fields.
	if stamp != e._exit_stamp or world.width != e._width or world.revision != e._revision or e._routed.size() != factions:
		e._rebuild_routed(world, gates, owners, factions)
		e._exit_stamp = stamp
		e._last_rebuild_tick = tick
	var exits := {}
	for i in gates.size(): exits[gates[i] * 4 + int(owners[i])] = true
	var catchers := _catchers(e, sim, world)
	var buffered := {}
	for id in e.held_by:
		if id >= 0: buffered[id] = int(buffered.get(id, 0)) + 1
	var used := {}
	var moved := PackedInt32Array()
	# Preserve the existing native single-faction movement path.
	if factions == 1 and tick % e._pace_of(0, period, periods) == 0:
		var native := e.NATIVE_SEARCH.backend()
		if native != null:
			var result: Variant = native.energy_next(e.cells, world.cells, workers.occupant, e._routed[0], world.width)
			if result is PackedInt32Array: moved = result
	var gained := 0
	var write := 0
	var original_size := e.cells.size()
	for i in original_size:
		var cell := e.cells[i]
		var owner := int(e.owner[i])
		var holder := e.held_by[i]
		var release_at := e.release_at[i]
		if holder >= 0:
			if sim == null or not sim.construction.sites.valid(holder):
				owner = NEUTRAL
				e.neutralized += 1
				buffered[holder] = maxi(0, int(buffered.get(holder, 0)) - 1)
				holder = -1
				release_at = 0
			elif tick >= release_at:
				buffered[holder] = maxi(0, int(buffered.get(holder, 0)) - 1)
				holder = -1
				release_at = 0
		if holder < 0 and catchers.has(cell):
			for site in catchers[cell]:
				var new_owner: int = sim.construction.sites.records[site].owner
				if owner != NEUTRAL and sim.army.allied(owner, new_owner): continue
				if int(used.get(site, 0)) >= CAPTURE_PER_TICK or int(buffered.get(site, 0)) >= CAPACITY: continue
				owner = new_owner
				holder = site
				release_at = tick + HOLD_TICKS
				used[site] = int(used.get(site, 0)) + 1
				buffered[site] = int(buffered.get(site, 0)) + 1
				e.captured += 1
				break # At most one capture per dot and tick; no lifetime capture limit.
		var route := owner < e._routed.size() and cell >= 0 and cell < world.cell_count() and world.cells[cell] == Materials.EMPTY and (e._routed[owner] as PackedInt32Array)[cell] >= 0
		var age := 0 if route else e.no_route[i] + 1
		if age >= NO_ROUTE_TICKS:
			e.expired += 1
			if holder >= 0: buffered[holder] = maxi(0, int(buffered.get(holder, 0)) - 1)
			continue
		var due := tick % e._pace_of(owner, period, periods) == 0
		if holder < 0 and owner < factions and due:
			if exits.has(cell * 4 + owner):
				var research_site := sim.research.receiver_site(sim, cell, owner) if sim != null else -1
				if research_site >= 0:
					sim.research.deliver(research_site)
				else:
					gained += 1
				if research_site < 0:
					while e.delivered_to.size() <= owner: e.delivered_to.append(0)
					e.delivered_to[owner] += 1
				if e.refined[i] != 0: e.refined_delivered += 1
				continue
			if owner < e._routed.size():
				e._dist = e._routed[owner]
				cell = moved[i] if owner == 0 and moved.size() == original_size else e._next_cell(cell, world, workers)
		# Compact every parallel array together. Held energy stays on its actual capture cell.
		e.cells[write] = cell
		e.birth[write] = e.birth[i]
		e.refined[write] = e.refined[i]
		e.owner[write] = owner
		e.no_route[write] = age
		e.held_by[write] = holder
		e.release_at[write] = release_at
		write += 1
	e.cells.resize(write)
	e.birth.resize(write)
	e.refined.resize(write)
	e.owner.resize(write)
	e.no_route.resize(write)
	e.held_by.resize(write)
	e.release_at.resize(write)
	e.delivered += original_size - write
	return gained

static func _catchers(e: EnergyStore, sim: Simulation, world: WorldState) -> Dictionary:
	if sim == null: return {}
	var shape := [world.revision]
	for row in sim.construction.sites.records:
		if row.kind == 2: shape.append([row.id, row.owner, row.ready, row.destroyed])
	var stamp := hash(shape)
	if stamp == e._capture_stamp: return e._capture_cells
	e._capture_stamp = stamp
	e._capture_cells = {}
	for row in sim.construction.sites.records:
		if row.kind != 2 or not row.ready or row.destroyed: continue
		for cell in sim.construction.receivers_for(sim, row.id):
			if not e._capture_cells.has(cell): e._capture_cells[cell] = PackedInt32Array()
			var ids: PackedInt32Array = e._capture_cells[cell]
			ids.append(row.id)
			e._capture_cells[cell] = ids
	return e._capture_cells

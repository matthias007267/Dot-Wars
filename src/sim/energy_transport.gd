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
		if stamp != e._exit_stamp or world.width != e._width or e._routed.size() != factions or not e._update_routed(world, gates, owners):
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
	var moved_by_owner := {}
	var native := e.NATIVE_SEARCH.backend()
	if native != null:
		for faction in factions:
			if tick % e._pace_of(faction, period, periods) != 0: continue
			var result: Variant = native.energy_next(e.cells, world.cells, workers.occupant, e._routed[faction], world.width)
			if result is PackedInt32Array and result.size() == e.cells.size(): moved_by_owner[faction] = result
	var gained := 0
	var delivered_count := 0
	var write := 0
	var original_size := e.cells.size()
	# Hot loop over every dot: parallel arrays, terrain, routes and per-owner pace
	# live in locals and are written back once; decisions are unchanged.
	var cells := e.cells
	var owners_of := e.owner
	var births := e.birth
	var refined := e.refined
	var ages := e.no_route
	var holders := e.held_by
	var releases := e.release_at
	var routed := e._routed
	var routed_count := routed.size()
	var terrain := world.cells
	var cell_count := world.cell_count()
	var due_of := PackedByteArray()
	due_of.resize(256)
	due_of.fill(2)
	var dist_owner := -1
	for i in original_size:
		var cell := cells[i]
		var owner := int(owners_of[i])
		var holder := holders[i]
		var release_at := releases[i]
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
		var route := owner < routed_count and cell >= 0 and cell < cell_count and terrain[cell] == Materials.EMPTY and (routed[owner] as PackedInt32Array)[cell] >= 0
		var age := 0 if route else ages[i] + 1
		if age >= NO_ROUTE_TICKS:
			e.expired += 1
			if holder >= 0: buffered[holder] = maxi(0, int(buffered.get(holder, 0)) - 1)
			continue
		var due_flag := due_of[owner]
		if due_flag == 2:
			due_flag = 1 if tick % e._pace_of(owner, period, periods) == 0 else 0
			due_of[owner] = due_flag
		if holder < 0 and owner < factions and due_flag == 1:
			if exits.has(cell * 4 + owner):
				delivered_count += 1
				gained += 1
				while e.delivered_to.size() <= owner: e.delivered_to.append(0)
				e.delivered_to[owner] += 1
				if refined[i] != 0: e.refined_delivered += 1
				continue
			if owner < routed_count:
				# Same last-assigned field as before; it is part of the resume state.
				if dist_owner != owner:
					e._dist = routed[owner]
					dist_owner = owner
				cell = moved_by_owner[owner][i] if moved_by_owner.has(owner) else e._next_cell(cell, world, workers)
		# Compact every parallel array together. Held energy stays on its actual capture cell.
		if write != i:
			births[write] = births[i]
			refined[write] = refined[i]
			cells[write] = cell
			owners_of[write] = owner
			ages[write] = age
			holders[write] = holder
			releases[write] = release_at
		else:
			if cells[i] != cell: cells[i] = cell
			if owners_of[i] != owner: owners_of[i] = owner
			if ages[i] != age: ages[i] = age
			if holders[i] != holder: holders[i] = holder
			if releases[i] != release_at: releases[i] = release_at
		write += 1
	e.cells = cells
	e.owner = owners_of
	e.birth = births
	e.refined = refined
	e.no_route = ages
	e.held_by = holders
	e.release_at = releases
	if write < original_size:
		e.cells.resize(write)
		e.birth.resize(write)
		e.refined.resize(write)
		e.owner.resize(write)
		e.no_route.resize(write)
		e.held_by.resize(write)
		e.release_at.resize(write)
	e.delivered += delivered_count
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

extends RefCounted
## Bounded deterministic planning. Uses the same paid placement/worker rules as the player.
## No research bypass, terrain carving, automatic repair or player-knowledge expansion.
const PERIOD := 100
const CANDIDATE_LIMIT := 384

static func step(sim: Simulation, owner: int) -> bool:
	var system := sim.construction
	var store := system.sites
	var level := sim.rules._plan(owner)
	var due := sim.tick_count % PERIOD == owner % PERIOD
	var workers := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.faction[id] == owner: workers.append(id)
	var main_count := store.count(owner, 0)
	# A missing main is a savings priority. The ready outpost still delivers income.
	if main_count == 0:
		if workers.is_empty():
			sim.rules._buy_worker(sim, owner)
			return true
		if due and sim.rules.wallet(sim, owner).energy >= system.price(0, owner):
			_place(sim, owner, 0, workers, level)
		return true
	var pending_main := -1
	var pending_outpost := -1
	var pending_research := -1
	var pending_tower := -1
	for row in store.records:
		if row.destroyed or row.owner != owner or row.ready: continue
		if row.kind == 0: pending_main = row.id
		elif row.kind == 1 and pending_outpost < 0: pending_outpost = row.id
		elif row.kind == 3 and pending_research < 0: pending_research = row.id
		elif row.kind == 4 and pending_tower < 0: pending_tower = row.id
	if pending_main >= 0:
		if workers.is_empty(): sim.rules._buy_worker(sim, owner)
		if due: _staff(sim, pending_main, workers, level)
		return true
	if pending_research >= 0:
		if due: _staff(sim, pending_research, workers, level)
		return false
	if store.count(owner, 3) == 0 and workers.size() >= 3 and due and sim.rules.wallet(sim, owner).energy >= system.price(3, owner) + 30:
		if _place(sim, owner, 3, workers, level): return true
	if pending_outpost >= 0:
		if due: _staff(sim, pending_outpost, workers, level)
		return false
	if pending_tower >= 0:
		if due: _staff(sim, pending_tower, workers, level)
		return false
	if due and system.unlocked(sim, 4, owner):
		for row in store.records:
			if row.destroyed or row.owner != owner or row.kind != 4 or not row.ready: continue
			if sim.research.source_for(sim, owner, row.id) >= 0: continue
			for source in store.ready_sites(owner):
				var route := sim.energy_network.plan_connection(sim, owner, source, row.id)
				if not route.is_empty():
					sim.energy_network.place_path(sim, owner, route)
					break
		var tower_cap := 1 if level == SimConfig.DIFFICULTY_EASY else 3 if level == SimConfig.DIFFICULTY_HARD else 2
		if workers.size() >= 3 and store.count(owner, 4) < tower_cap and sim.rules.wallet(sim, owner).energy >= system.price(4, owner) + 100:
			if _place(sim, owner, 4, workers, level): return true
		for row in store.records:
			if row.destroyed or row.owner != owner or row.kind != 4 or not row.ready: continue
			var price := sim.defense.upgrade_cost(row)
			if price >= 0 and sim.rules.wallet(sim, owner).energy >= price + 100 and sim.defense.upgrade(sim, row.id, owner): return true
	if not due or not system.unlocked(sim, 1, owner): return false
	# Provisional easy/normal/hard expansion caps: 1/2/3, at 3/4/6 workers.
	var cap := 1 if level == SimConfig.DIFFICULTY_EASY else 3 if level == SimConfig.DIFFICULTY_HARD else 2
	var needed := 3 if level == SimConfig.DIFFICULTY_EASY else 6 if level == SimConfig.DIFFICULTY_HARD else 4
	if workers.size() < needed or store.count(owner, 1) >= cap: return false
	if sim.rules.wallet(sim, owner).energy < system.price(1, owner) + 50: return false
	_place(sim, owner, 1, workers, level)
	return false

static func _staff(sim: Simulation, site: int, workers: PackedInt32Array, level: int) -> void:
	var wanted := mini(maxi(1, workers.size() / 2), 2 if level == SimConfig.DIFFICULTY_EASY else 4 if level == SimConfig.DIFFICULTY_HARD else 3)
	var distances: PackedInt32Array = sim.construction._field(sim, site)
	var assigned := 0
	for id in workers:
		if sim.workers.build_site[id] == site and sim.workers.build_mode[id] == 0:
			if distances[sim.workers.cell[id]] >= 0: assigned += 1
			else: sim.construction.release(sim, id)
	if assigned >= wanted: return
	var choices: Array[Vector2i] = []
	for id in workers:
		if sim.workers.build_site[id] >= 0 or distances[sim.workers.cell[id]] < 0: continue
		var c := sim.workers.cell[id]
		var distance := distances[c]
		choices.append(Vector2i(distance, id))
	choices.sort()
	var ids := PackedInt32Array()
	for choice in choices:
		if ids.size() + assigned >= wanted: break
		ids.append(choice.y)
	sim.construction.assign(sim, site, ids, sim.construction.sites.records[site].owner)

static func _place(sim: Simulation, owner: int, kind: int, workers: PackedInt32Array, level: int) -> bool:
	var system := sim.construction
	var anchors := PackedInt32Array()
	for site in system.sites.ready_sites(owner): anchors.append(system.center(site))
	if anchors.is_empty():
		for id in workers: anchors.append(sim.workers.cell[id])
	if anchors.is_empty(): return false
	var seeds := PackedInt32Array()
	for id in workers:
		if sim.workers.build_site[id] < 0: seeds.append(sim.workers.cell[id])
	if seeds.is_empty(): return false
	# One shared reachability field per planning attempt, not per candidate or worker.
	var reachable: PackedInt32Array = system.distances(sim, seeds)
	var examined := 0
	var side := 5 if kind == 0 else 3
	for radius in range(5, 19):
		for anchor in anchors:
			var middle := Vector2i(anchor % sim.world.width, anchor / sim.world.width)
			for dy in range(-radius, radius + 1, 2):
				for dx in range(-radius, radius + 1, 2):
					if absi(dx) != radius and absi(dy) != radius: continue
					examined += 1
					if examined > CANDIDATE_LIMIT: return false
					var pos := middle + Vector2i(dx, dy)
					if not sim.world.in_bounds(pos.x, pos.y): continue
					var cell := pos.y * sim.world.width + pos.x
					if not system.can_place(sim, kind, cell, owner): continue
					if not _reachable_edge(Rect2i(pos, Vector2i(side, side)), reachable, sim.world): continue
					var site: int = system.place(sim, kind, cell, PackedInt32Array(), owner)
					if site < 0: continue
					_staff(sim, site, workers, level)
					return true
	return false

static func _reachable_edge(rect: Rect2i, distances: PackedInt32Array, world: WorldState) -> bool:
	for y in range(rect.position.y - 1, rect.end.y + 1):
		for x in range(rect.position.x - 1, rect.end.x + 1):
			if not world.in_bounds(x, y): continue
			var along_x := x >= rect.position.x and x < rect.end.x
			var along_y := y >= rect.position.y and y < rect.end.y
			if along_x == along_y: continue
			if distances[y * world.width + x] >= 0: return true
	return false

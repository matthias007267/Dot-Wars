extends RefCounted
## Same free-placement and paid-shipment rules as the player. Bounded periodic planning.
const PERIOD := 100

static func step(sim: Simulation, faction: int) -> void:
	if sim.tick_count % PERIOD != faction % PERIOD: return
	var centers := PackedInt32Array()
	for row in sim.construction.sites.records:
		if row.destroyed or not row.ready or row.owner != faction: continue
		if row.kind == 3: centers.append(row.id)
	for site in centers:
		var connected := false
		for source in sim.construction.sites.ready_sites(faction):
			if sim.construction.sites.records[source].kind != 0: continue
			var route := sim.energy_network.connected_path(sim, faction, sim.construction.center(source), sim.construction.center(site))
			if route.is_empty():
				route = sim.energy_network.plan_connection(sim, faction, source, site)
				if not route.is_empty(): sim.energy_network.place_path(sim, faction, route)
			if not route.is_empty():
				connected = true
				break
		if not connected: continue
		# Difficulty changes priorities, not prices or research speed.
		var priorities := ["dig", "speed", "outpost", "energy_speed", "efficiency", "interceptor", "swarm"]
		if (sim.config.victory_mask & MatchRules.VICTORY_RESEARCH) != 0: priorities.push_front("victory")
		for tech in priorities:
			if sim.research.level(faction, tech) == 0 and sim.research.start(sim, faction, site, tech): break

static func reserve(sim: Simulation, faction: int) -> int:
	for job in sim.research.jobs:
		if job.faction == faction: return 1
	return 0

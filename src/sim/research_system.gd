class_name ResearchSystem
extends RefCounted
## Deterministic per-faction, per-research-center research jobs.
## Energy travels from the faction core through conduits into a delivered buffer.
const Store = preload("res://src/sim/settlement_store.gd")
const CATALOG := {
	"dig": {"branch": "Wirtschaft", "label": "Abbaueffizienz", "kind": Upgrades.KIND_DIG, "max": 5, "ticks": 180, "energy": 60, "requires": []},
	"swarm": {"branch": "Wirtschaft", "label": "Schwarmkoordination", "kind": Upgrades.KIND_SWARM, "max": 4, "ticks": 220, "energy": 70, "requires": ["dig"]},
	"speed": {"branch": "Infrastruktur", "label": "Arbeiterbewegung", "kind": Upgrades.KIND_SPEED, "max": 5, "ticks": 180, "energy": 55, "requires": []},
	"core": {"branch": "Infrastruktur", "label": "Kerntechnologie", "kind": Upgrades.KIND_CORE, "max": 4, "ticks": 260, "energy": 90, "requires": ["speed"]},
	"energy_speed": {"branch": "Energietechnik", "label": "Energietransport", "kind": Upgrades.KIND_ENERGY_SPEED, "max": 5, "ticks": 200, "energy": 60, "requires": []},
	"victory": {"branch": "Militär", "label": "Siegforschung", "kind": Upgrades.KIND_RESEARCH, "max": 5, "ticks": 350, "energy": 100, "requires": []},
	"outpost": {"branch": "Infrastruktur", "label": "Außenposten", "kind": -1, "max": 1, "ticks": 260, "energy": 90, "requires": ["speed"]},
	"interceptor": {"branch": "Energietechnik", "label": "Abfangstation", "kind": -1, "max": 1, "ticks": 260, "energy": 90, "requires": ["energy_speed"]},
	"efficiency": {"branch": "Energietechnik", "label": "Energieeffizienz", "kind": -1, "max": 3, "ticks": 240, "energy": 80, "requires": ["energy_speed"]},
}
var levels: Array[Dictionary] = []
var jobs: Array[Dictionary] = []
## Physically delivered energy, held at each research center.
var supply: Dictionary = {}
## Conduit-bound shipments: one paid energy unit travels along a placed path.
var shipments: Array[Dictionary] = []
## Completed simulation tick at which a site actually consumed energy.
var powered_tick: Dictionary = {}
var lost_energy := 0

func setup(factions: int) -> void:
	levels.clear()
	jobs.clear()
	supply.clear()
	shipments.clear()
	powered_tick.clear()
	lost_energy = 0
	for faction in factions:
		levels.append({})

func level(faction: int, tech: String) -> int:
	if faction < 0 or faction >= levels.size(): return 0
	return int(levels[faction].get(tech, 0))

func details(tech: String, next_level: int, faction := -1) -> Dictionary:
	if not CATALOG.has(tech) or next_level < 1: return {}
	var entry: Dictionary = CATALOG[tech]
	if next_level > int(entry["max"]): return {}
	return {"ticks": int(entry["ticks"]) * next_level, "energy": energy_cost(tech, next_level, level(faction, "efficiency"))}

func energy_cost(tech: String, stage: int, efficiency: int) -> int:
	var raw: int = int(CATALOG[tech].energy) * stage
	return maxi(1, ceili(float(raw * (100 - clampi(efficiency, 0, 3) * 10)) / 100.0))

func can_start(sim: Simulation, faction: int, site: int, tech: String) -> bool:
	if not CATALOG.has(tech) or faction < 0 or faction >= levels.size(): return false
	if not sim.construction.sites.valid(site): return false
	var row: Dictionary = sim.construction.sites.records[site]
	if row.kind != Store.Kind.RESEARCH_CENTER or row.owner != faction or not row.ready: return false
	if sim._match_live() and sim.rules.alive[faction] == 0: return false
	for job in jobs:
		if int(job["site"]) == site: return false
		if int(job["faction"]) == faction and str(job["tech"]) == tech: return false
	var entry: Dictionary = CATALOG[tech]
	if level(faction, tech) >= int(entry["max"]): return false
	for dependency in entry["requires"]:
		if level(faction, str(dependency)) < 1: return false
	if tech == "core" and (faction != 0 or not sim.legacy_core_upgrades()): return false
	if tech == "victory" and (sim.config.mode != SimConfig.MODE_MATCH or (sim.config.victory_mask & MatchRules.VICTORY_RESEARCH) == 0): return false
	return true

func start(sim: Simulation, faction: int, site: int, tech: String) -> bool:
	if not can_start(sim, faction, site, tech): return false
	var level_next := level(faction, tech) + 1
	var cost := details(tech, level_next, faction)
	jobs.append({"faction": faction, "site": site, "tech": tech, "elapsed": 0, "ticks": cost["ticks"], "energy": cost["energy"], "spent": 0, "efficiency": level(faction, "efficiency")})
	return true

func receiver_site(sim: Simulation, cell: int, faction: int) -> int:
	for job in jobs:
		if int(job["faction"]) != faction: continue
		var site: int = int(job["site"])
		if sim.construction.sites.valid(site) and sim.construction.receivers_for(sim, site).has(cell):
			return site
	return -1

func receiver_gates(sim: Simulation, faction: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for job in jobs:
		if int(job["faction"]) != faction: continue
		var site: int = int(job["site"])
		if sim.construction.sites.valid(site):
			result.append_array(sim.construction.receivers_for(sim, site))
	return result

func deliver(site: int) -> void:
	supply[site] = int(supply.get(site, 0)) + 1

func is_powered(site: int, tick: int) -> bool:
	return int(powered_tick.get(site, -1)) == tick

func step(sim: Simulation) -> void:
	powered_tick.clear()
	_step_shipments(sim)
	for i in range(jobs.size() - 1, -1, -1):
		var job: Dictionary = jobs[i]
		var faction: int = int(job["faction"])
		var site: int = int(job["site"])
		if not sim.construction.sites.valid(site):
			jobs.remove_at(i)
			supply.erase(site)
			continue
		var row: Dictionary = sim.construction.sites.records[site]
		if row.owner != faction or row.kind != Store.Kind.RESEARCH_CENTER or not row.ready:
			jobs.remove_at(i)
			continue
		var remaining_ticks: int = int(job["ticks"]) - int(job["elapsed"])
		var remaining_energy: int = int(job["energy"]) - int(job["spent"])
		var charge: int = ceili(float(remaining_energy) / float(maxi(1, remaining_ticks)))
		if int(supply.get(site, 0)) < charge: continue
		# Simulation publishes tick_count + 1 after this step, before rendering.
		if charge > 0: powered_tick[site] = sim.tick_count + 1
		supply[site] = int(supply[site]) - charge
		job["spent"] = int(job["spent"]) + charge
		job["elapsed"] = int(job["elapsed"]) + 1
		if int(job["elapsed"]) >= int(job["ticks"]):
			if _apply(sim, faction, str(job["tech"])):
				levels[faction][str(job["tech"])] = level(faction, str(job["tech"])) + 1
				jobs.remove_at(i)
			else:
				# Core expansion can be temporarily blocked; retry without extra charge.
				job["elapsed"] = int(job["ticks"]) - 1

func source_for(sim: Simulation, faction: int, target_site: int) -> int:
	# Prefer own main cores, then a surviving outpost; never a foreign source.
	for kind in [Store.Kind.MAIN_CORE, Store.Kind.OUTPOST]:
		for row in sim.construction.sites.records:
			if row.destroyed or not row.ready or row.owner != faction or row.kind != kind: continue
			var route := sim.energy_network.connected_path(sim, faction, sim.construction.center(row.id), sim.construction.center(target_site))
			if not route.is_empty(): return sim.construction.center(row.id)
	return -1

func _valid_target(sim: Simulation, site: int, faction: int) -> bool:
	if not sim.construction.sites.valid(site): return false
	var row: Dictionary = sim.construction.sites.records[site]
	return row.owner == faction and row.ready and row.kind == Store.Kind.RESEARCH_CENTER

func _step_shipments(sim: Simulation) -> void:
	# Invalidate jobs and buffers before moving or dispatching. No refunds on destruction.
	for i in range(jobs.size() - 1, -1, -1):
		var job: Dictionary = jobs[i]
		if _valid_target(sim, job.site, job.faction): continue
		lost_energy += int(supply.get(job.site, 0))
		supply.erase(job.site)
		jobs.remove_at(i)
	for site in supply.keys():
		if sim.construction.sites.valid(site): continue
		lost_energy += int(supply[site])
		supply.erase(site)
	for i in range(shipments.size() - 1, -1, -1):
		var shipment: Dictionary = shipments[i]
		if not _valid_target(sim, shipment.site, shipment.faction):
			lost_energy += 1
			shipments.remove_at(i)
			continue
		# Continue from the actual position, including after source loss/rerouting.
		# Removing the occupied conduit pauses here until it is rebuilt.
		var route := sim.energy_network.route_to_site(sim, shipment.faction, shipment.cell, shipment.site)
		if route.is_empty(): continue
		if route.size() == 1:
			deliver(shipment.site)
			shipments.remove_at(i)
		else:
			shipment.index = 0
			shipment.cell = route[1]
	if sim.tick_count % 8 != 0: return
	for job in jobs:
		var site: int = job.site
		var faction: int = job.faction
		var incoming := 0
		for shipment in shipments:
			if shipment.site == site: incoming += 1
		var buffered := int(supply.get(site, 0))
		# Never reserve beyond the job's remaining demand.
		if buffered >= 16 or incoming >= 8 or buffered + incoming >= int(job.energy) - int(job.spent): continue
		var source := source_for(sim, faction, site)
		if source < 0: continue
		var route := sim.energy_network.connected_path(sim, faction, source, sim.construction.center(site))
		var wallet := sim.rules.wallet(sim, faction)
		if route.is_empty() or wallet.energy < 1: continue
		wallet.energy -= 1
		shipments.append({"site": site, "faction": faction, "source": source, "index": 0, "cell": route[0]})

func _apply(sim: Simulation, faction: int, tech: String) -> bool:
	var wallet: Upgrades = sim.rules.wallet(sim, faction)
	match tech:
		"dig": wallet.dig_level += 1
		"swarm": wallet.swarm_level += 1
		"speed": wallet.speed_level += 1
		"energy_speed": wallet.energy_speed_level += 1
		"victory": wallet.research_level += 1
		"outpost", "interceptor", "efficiency": pass
		"core":
			if faction != 0 or not sim._bind_core(wallet.core_level + 1, true): return false
			wallet.core_level += 1
		_: return false
	return true

func snapshot() -> Dictionary:
	return {"levels": levels.duplicate(true), "jobs": jobs.duplicate(true), "supply": supply.duplicate(true), "shipments": shipments.duplicate(true), "lost_energy": lost_energy}

func restore(sim: Simulation, data: Dictionary) -> bool:
	var stored_levels: Variant = data.get("levels", [])
	var stored_jobs: Variant = data.get("jobs", [])
	if not stored_levels is Array or not stored_jobs is Array or stored_levels.size() != levels.size(): return false
	var candidate_levels: Array[Dictionary] = []
	for faction in stored_levels.size():
		if not stored_levels[faction] is Dictionary: return false
		var row: Dictionary = stored_levels[faction]
		for tech in row:
			if not CATALOG.has(tech) or typeof(row[tech]) != TYPE_INT or row[tech] < 0 or row[tech] > int(CATALOG[tech]["max"]): return false
		candidate_levels.append(row.duplicate(true))
	var candidate_jobs: Array[Dictionary] = []
	var busy_sites := {}
	var busy_techs := {}
	for job in stored_jobs:
		if not job is Dictionary: return false
		for key in ["faction", "site", "elapsed", "ticks", "energy", "spent"]:
			if typeof(job.get(key)) != TYPE_INT: return false
		var faction: int = job["faction"]
		var site: int = job["site"]
		var tech: String = str(job.get("tech", ""))
		if faction < 0 or faction >= levels.size() or not CATALOG.has(tech): return false
		if not sim.construction.sites.valid(site): return false
		var building: Dictionary = sim.construction.sites.records[site]
		if building.owner != faction or building.kind != Store.Kind.RESEARCH_CENTER or not building.ready: return false
		var expected := details(tech, int(candidate_levels[faction].get(tech, 0)) + 1)
		var efficiency: Variant = job.get("efficiency", 0)
		if typeof(efficiency) != TYPE_INT or efficiency < 0 or efficiency > int(candidate_levels[faction].get("efficiency", 0)): return false
		if expected.is_empty() or job["ticks"] != expected["ticks"]: return false
		if job["energy"] != energy_cost(tech, int(candidate_levels[faction].get(tech, 0)) + 1, efficiency): return false
		if job["elapsed"] < 0 or job["elapsed"] >= job["ticks"] or job["spent"] < 0 or job["spent"] > job["energy"]: return false
		var key := "%d:%s" % [faction, tech]
		if busy_sites.has(site) or busy_techs.has(key): return false
		busy_sites[site] = true
		busy_techs[key] = true
		candidate_jobs.append(job.duplicate(true))
	var stored_supply: Variant = data.get("supply", {})
	if not stored_supply is Dictionary: return false
	var candidate_supply := {}
	for site in stored_supply:
		if typeof(site) != TYPE_INT or typeof(stored_supply[site]) != TYPE_INT or stored_supply[site] < 0: return false
		if not sim.construction.sites.valid(site) or sim.construction.sites.records[site].kind != Store.Kind.RESEARCH_CENTER: return false
		candidate_supply[site] = stored_supply[site]
	var stored_shipments: Variant = data.get("shipments", [])
	if not stored_shipments is Array: return false
	var candidate_shipments: Array[Dictionary] = []
	for shipment in stored_shipments:
		if not shipment is Dictionary: return false
		for key in ["site", "faction", "source", "index", "cell"]:
			if typeof(shipment.get(key)) != TYPE_INT: return false
		if not sim.construction.sites.valid(shipment["site"]): return false
		var target: Dictionary = sim.construction.sites.records[shipment["site"]]
		if target.kind != Store.Kind.RESEARCH_CENTER or not target.ready: return false
		if shipment["faction"] != target.owner or shipment["index"] < 0 or shipment["index"] >= sim.world.cell_count(): return false
		if shipment["source"] < 0 or shipment["source"] >= sim.world.cell_count(): return false
		if shipment["cell"] < 0 or shipment["cell"] >= sim.world.cell_count(): return false
		# A removed conduit (including under the shipment) is a valid paused state.
		# Loading must not require the route whose absence caused that pause.
		# A foreign replacement conduit also leaves paid cargo paused; routing
		# still requires an own conduit and must never transfer its ownership.
		candidate_shipments.append(shipment.duplicate(true))
	var stored_lost: Variant = data.get("lost_energy", 0)
	if typeof(stored_lost) != TYPE_INT or stored_lost < 0: return false
	lost_energy = stored_lost
	levels = candidate_levels
	jobs = candidate_jobs
	supply = candidate_supply
	shipments = candidate_shipments
	powered_tick.clear()
	return true

func state_hash() -> int:
	return hash([levels, jobs, supply, shipments, lost_energy])

class_name ResearchSystem
extends RefCounted
## Deterministic per-faction, per-research-center research jobs.
## Energy is charged incrementally each tick from the faction wallet.
const Store = preload("res://src/sim/settlement_store.gd")
const CATALOG := {
	"dig": {"branch": "Wirtschaft", "label": "Abbaueffizienz", "kind": Upgrades.KIND_DIG, "max": 5, "ticks": 180, "energy": 60, "requires": []},
	"swarm": {"branch": "Wirtschaft", "label": "Schwarmkoordination", "kind": Upgrades.KIND_SWARM, "max": 4, "ticks": 220, "energy": 70, "requires": ["dig"]},
	"speed": {"branch": "Infrastruktur", "label": "Arbeiterbewegung", "kind": Upgrades.KIND_SPEED, "max": 5, "ticks": 180, "energy": 55, "requires": []},
	"core": {"branch": "Infrastruktur", "label": "Kerntechnologie", "kind": Upgrades.KIND_CORE, "max": 4, "ticks": 260, "energy": 90, "requires": ["speed"]},
	"energy_speed": {"branch": "Energietechnik", "label": "Energietransport", "kind": Upgrades.KIND_ENERGY_SPEED, "max": 5, "ticks": 200, "energy": 60, "requires": []},
	"victory": {"branch": "Militär", "label": "Siegforschung", "kind": Upgrades.KIND_RESEARCH, "max": 5, "ticks": 350, "energy": 100, "requires": []},
}
var levels: Array[Dictionary] = []
var jobs: Array[Dictionary] = []
## Physically delivered energy, held at each research center.
var supply: Dictionary = {}
## Conduit-bound shipments: one paid energy unit travels along a placed path.
var shipments: Array[Dictionary] = []

func setup(factions: int) -> void:
	levels.clear()
	jobs.clear()
	supply.clear()
	shipments.clear()
	for faction in factions:
		levels.append({})

func level(faction: int, tech: String) -> int:
	if faction < 0 or faction >= levels.size(): return 0
	return int(levels[faction].get(tech, 0))

func details(tech: String, next_level: int) -> Dictionary:
	if not CATALOG.has(tech) or next_level < 1: return {}
	var entry: Dictionary = CATALOG[tech]
	if next_level > int(entry["max"]): return {}
	return {"ticks": int(entry["ticks"]) * next_level, "energy": int(entry["energy"]) * next_level}

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
	var cost := details(tech, level_next)
	jobs.append({"faction": faction, "site": site, "tech": tech, "elapsed": 0, "ticks": cost["ticks"], "energy": cost["energy"], "spent": 0})
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

func step(sim: Simulation) -> void:
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
		var charge := (remaining_energy + remaining_ticks - 1) / remaining_ticks
		if int(supply.get(site, 0)) < charge: continue
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

func _step_shipments(sim: Simulation) -> void:
	# Shipments never leave the explicitly built conduit cells.
	for i in range(shipments.size() - 1, -1, -1):
		var shipment: Dictionary = shipments[i]
		var site: int = shipment["site"]
		var faction: int = shipment["faction"]
		if not sim.construction.sites.valid(site):
			shipments.remove_at(i)
			continue
		var source: int = shipment["source"]
		var target: int = sim.construction.center(site)
		var route := sim.energy_network.connected_path(sim, faction, source, target)
		if route.is_empty(): continue
		var index: int = int(shipment["index"])
		if index >= route.size() - 1:
			deliver(site)
			shipments.remove_at(i)
		else:
			shipment["index"] = index + 1
	# Dispatch at most one unit per active center every eight ticks.
	if sim.tick_count % 8 != 0: return
	for job in jobs:
		var site: int = job["site"]
		var faction: int = job["faction"]
		if not sim.construction.sites.valid(site): continue
		if int(supply.get(site, 0)) >= 16: continue
		var incoming := 0
		for shipment in shipments:
			if shipment["site"] == site: incoming += 1
		if incoming >= 8: continue
		var source := -1
		for building in sim.construction.sites.records:
			if not building.destroyed and building.ready and building.owner == faction and building.kind == Store.Kind.MAIN_CORE:
				source = sim.construction.center(int(building.id))
				break
		if source < 0: continue
		var route := sim.energy_network.connected_path(sim, faction, source, sim.construction.center(site))
		if route.is_empty(): continue
		var wallet := sim.rules.wallet(sim, faction)
		if wallet.energy < 1: continue
		wallet.energy -= 1
		shipments.append({"site": site, "faction": faction, "source": source, "index": 0})

func _apply(sim: Simulation, faction: int, tech: String) -> bool:
	var wallet: Upgrades = sim.rules.wallet(sim, faction)
	match tech:
		"dig": wallet.dig_level += 1
		"swarm": wallet.swarm_level += 1
		"speed": wallet.speed_level += 1
		"energy_speed": wallet.energy_speed_level += 1
		"victory": wallet.research_level += 1
		"core":
			if faction != 0 or not sim._bind_core(wallet.core_level + 1, true): return false
			wallet.core_level += 1
		_: return false
	return true

func snapshot() -> Dictionary:
	return {"levels": levels.duplicate(true), "jobs": jobs.duplicate(true), "supply": supply.duplicate(true), "shipments": shipments.duplicate(true)}

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
		if expected.is_empty() or job["ticks"] != expected["ticks"] or job["energy"] != expected["energy"]: return false
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
	levels = candidate_levels
	jobs = candidate_jobs
	supply = candidate_supply
	var stored_shipments: Variant = data.get("shipments", [])
	if not stored_shipments is Array: return false
	var candidate_shipments: Array[Dictionary] = []
	for shipment in stored_shipments:
		if not shipment is Dictionary: return false
		for key in ["site", "faction", "source", "index"]:
			if typeof(shipment.get(key)) != TYPE_INT: return false
		if not sim.construction.sites.valid(shipment["site"]): return false
		if shipment["faction"] != sim.construction.sites.records[shipment["site"]].owner or shipment["index"] < 0: return false
		var route := sim.energy_network.connected_path(sim, shipment["faction"], shipment["source"], sim.construction.center(shipment["site"]))
		if route.is_empty() or shipment["index"] >= route.size(): return false
		candidate_shipments.append(shipment.duplicate(true))
	shipments = candidate_shipments
	return true

func state_hash() -> int:
	return hash([levels, jobs, supply, shipments])

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

func setup(factions: int) -> void:
	levels.clear()
	jobs.clear()
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

func step(sim: Simulation) -> void:
	for i in range(jobs.size() - 1, -1, -1):
		var job: Dictionary = jobs[i]
		var faction: int = int(job["faction"])
		var site: int = int(job["site"])
		if not sim.construction.sites.valid(site):
			jobs.remove_at(i)
			continue
		var row: Dictionary = sim.construction.sites.records[site]
		if row.owner != faction or row.kind != Store.Kind.RESEARCH_CENTER or not row.ready:
			jobs.remove_at(i)
			continue
		var remaining_ticks: int = int(job["ticks"]) - int(job["elapsed"])
		var remaining_energy: int = int(job["energy"]) - int(job["spent"])
		var charge := (remaining_energy + remaining_ticks - 1) / remaining_ticks
		var wallet: Upgrades = sim.rules.wallet(sim, faction)
		if wallet.energy < charge: continue
		wallet.energy -= charge
		job["spent"] = int(job["spent"]) + charge
		job["elapsed"] = int(job["elapsed"]) + 1
		if int(job["elapsed"]) >= int(job["ticks"]):
			if _apply(sim, faction, str(job["tech"])):
				levels[faction][str(job["tech"])] = level(faction, str(job["tech"])) + 1
				jobs.remove_at(i)
			else:
				# Core expansion can be temporarily blocked; retry without extra charge.
				job["elapsed"] = int(job["ticks"]) - 1

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
	return {"levels": levels.duplicate(true), "jobs": jobs.duplicate(true)}

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
	levels = candidate_levels
	jobs = candidate_jobs
	return true

func state_hash() -> int:
	return hash([levels, jobs])

class_name ResearchSystem
extends RefCounted
## Research is paid once from the faction wallet and progresses while connected.
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
	"defense": {"branch": "Militär", "label": "Verteidigungstechnik", "kind": -1, "max": 1, "ticks": 360, "energy": 120, "requires": ["energy_speed"]},
}
var levels: Array[Dictionary] = []
var jobs: Array[Dictionary] = []
var powered_tick: Dictionary = {}
var lost_energy := 0

func setup(factions: int) -> void:
	levels.clear()
	jobs.clear()
	powered_tick.clear()
	lost_energy = 0
	for faction in factions: levels.append({})

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

func source_for(sim: Simulation, faction: int, site: int) -> int:
	if not sim.construction.sites.valid(site) or int(sim.construction.sites.records[site].owner) != faction: return -1
	var source := sim.energy_network.source_site(sim, site)
	return sim.construction.center(source) if source >= 0 else -1

func can_start(sim: Simulation, faction: int, site: int, tech: String) -> bool:
	if not CATALOG.has(tech) or faction < 0 or faction >= levels.size(): return false
	if not sim.construction.sites.valid(site): return false
	var row: Dictionary = sim.construction.sites.records[site]
	if row.kind != Store.Kind.RESEARCH_CENTER or row.owner != faction or not row.ready: return false
	if sim._match_live() and sim.rules.alive[faction] == 0: return false
	for job in jobs:
		if int(job.site) == site or (int(job.faction) == faction and str(job.tech) == tech): return false
	var entry: Dictionary = CATALOG[tech]
	if level(faction, tech) >= int(entry.max): return false
	for dependency in entry.requires:
		if level(faction, str(dependency)) < 1: return false
	if tech == "core" and (faction != 0 or not sim.legacy_core_upgrades()): return false
	if tech == "victory" and (not sim._match_live() or (sim.config.victory_mask & MatchRules.VICTORY_RESEARCH) == 0): return false
	return source_for(sim, faction, site) >= 0 and sim.rules.wallet(sim, faction).energy >= int(details(tech, level(faction, tech) + 1, faction).energy)

func start(sim: Simulation, faction: int, site: int, tech: String) -> bool:
	if not can_start(sim, faction, site, tech): return false
	var cost := details(tech, level(faction, tech) + 1, faction)
	sim.rules.wallet(sim, faction).energy -= int(cost.energy)
	jobs.append({"faction": faction, "site": site, "tech": tech, "elapsed": 0, "ticks": int(cost.ticks), "energy": int(cost.energy), "paid": int(cost.energy), "efficiency": level(faction, "efficiency")})
	return true

func is_powered(site: int, tick: int) -> bool:
	return int(powered_tick.get(site, -1)) == tick

func remove_site(site: int) -> void:
	for index in range(jobs.size() - 1, -1, -1):
		if int(jobs[index].site) == site:
			lost_energy += int(jobs[index].paid)
			jobs.remove_at(index)
	powered_tick.erase(site)

func running(sim: Simulation, job: Dictionary) -> bool:
	return int(job.paid) == int(job.energy) and source_for(sim, int(job.faction), int(job.site)) >= 0

func step(sim: Simulation) -> void:
	powered_tick.clear()
	for index in range(jobs.size() - 1, -1, -1):
		var job := jobs[index]
		var site := int(job.site)
		if not sim.construction.sites.valid(site):
			lost_energy += int(job.paid)
			jobs.remove_at(index)
			continue
		if source_for(sim, int(job.faction), site) < 0: continue
		# Legacy partially paid jobs make one remaining payment, never another shipment.
		var remaining := int(job.energy) - int(job.paid)
		if remaining > 0:
			var wallet := sim.rules.wallet(sim, int(job.faction))
			if wallet.energy < remaining: continue
			wallet.energy -= remaining
			job.paid = int(job.energy)
		powered_tick[site] = sim.tick_count + 1
		job.elapsed = int(job.elapsed) + 1
		if int(job.elapsed) >= int(job.ticks):
			if _apply(sim, int(job.faction), str(job.tech)):
				levels[int(job.faction)][str(job.tech)] = level(int(job.faction), str(job.tech)) + 1
				jobs.remove_at(index)
			else: job.elapsed = int(job.ticks) - 1

func _apply(sim: Simulation, faction: int, tech: String) -> bool:
	var wallet: Upgrades = sim.rules.wallet(sim, faction)
	match tech:
		"dig": wallet.dig_level += 1
		"swarm": wallet.swarm_level += 1
		"speed": wallet.speed_level += 1
		"energy_speed": wallet.energy_speed_level += 1
		"victory": wallet.research_level += 1
		"outpost", "interceptor", "efficiency", "defense": pass
		"core":
			if faction != 0 or not sim._bind_core(wallet.core_level + 1, true): return false
			wallet.core_level += 1
		_: return false
	return true

func snapshot() -> Dictionary:
	return {"payment_mode": 2, "levels": levels.duplicate(true), "jobs": jobs.duplicate(true), "lost_energy": lost_energy}

func restore(sim: Simulation, data: Dictionary) -> bool:
	var modern: bool = data.get("payment_mode", 1) == 2
	if data.has("payment_mode") and (typeof(data.payment_mode) != TYPE_INT or int(data.payment_mode) not in [1, 2]): return false
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
		for key in ["faction", "site", "elapsed", "ticks", "energy"]:
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
		if job["elapsed"] < 0 or job["elapsed"] >= job["ticks"] or typeof(job.get("paid" if modern else "spent")) != TYPE_INT or int(job.get("paid" if modern else "spent", -1)) < 0 or int(job.get("paid" if modern else "spent", -1)) > job["energy"]: return false
		var key := "%d:%s" % [faction, tech]
		if busy_sites.has(site) or busy_techs.has(key): return false
		busy_sites[site] = true
		busy_techs[key] = true
		var copy: Dictionary = job.duplicate(true)
		copy.paid = int(job.get("paid" if modern else "spent", 0))
		copy.erase("spent")
		candidate_jobs.append(copy)
	var stored_supply: Variant = data.get("supply", {})
	if not stored_supply is Dictionary: return false
	var candidate_supply := {}
	for site in stored_supply:
		if typeof(site) != TYPE_INT or typeof(stored_supply[site]) != TYPE_INT or stored_supply[site] < 0 or stored_supply[site] > 2147483647: return false
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
	if modern and (not candidate_supply.is_empty() or not candidate_shipments.is_empty()): return false
	var refunds := {}
	if not modern:
		var credits := candidate_supply.duplicate()
		for cargo in candidate_shipments: credits[cargo.site] = int(credits.get(cargo.site, 0)) + 1
		for job in candidate_jobs:
			var available := int(credits.get(job.site, 0))
			var accepted := mini(int(job.energy) - int(job.paid), available)
			job.paid = int(job.paid) + accepted
			credits[job.site] = available - accepted
		for site in credits:
			var owner: int = sim.construction.sites.records[site].owner
			refunds[owner] = int(refunds.get(owner, 0)) + int(credits[site])
	levels = candidate_levels
	jobs = candidate_jobs
	lost_energy = stored_lost
	powered_tick.clear()
	for owner in refunds: sim.rules.wallet(sim, owner).energy += int(refunds[owner])
	return true

func state_hash() -> int:
	return hash([levels, jobs, lost_energy])

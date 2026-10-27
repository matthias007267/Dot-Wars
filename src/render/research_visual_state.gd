class_name ResearchVisualState
extends RefCounted
## Ephemeral presentation state. Hidden centers are forgotten, never read live.
const COMPLETE_TICKS := 40
var _tick := -1
var _jobs := {}
var _completed_until := {}
var _sim_id := 0

func sync(sim: Simulation) -> void:
	if sim.get_instance_id() != _sim_id or sim.tick_count < _tick:
		_jobs.clear()
		_completed_until.clear()
		_tick = -1
		_sim_id = sim.get_instance_id()
	var observed := {}
	for job in sim.research.jobs:
		if not sim.construction.sites.valid(job.site): continue
		var site: Dictionary = sim.construction.sites.records[job.site]
		if not CavernLighting.site_visible(sim, site): continue
		observed[job.site] = {"tech": job.tech, "level": sim.research.level(job.faction, job.tech), "job": job}
	for id in _jobs:
		if not sim.construction.sites.valid(id): continue
		var site: Dictionary = sim.construction.sites.records[id]
		if not CavernLighting.site_visible(sim, site): continue
		var previous: Dictionary = _jobs[id]
		if sim.tick_count - _tick <= 4 and sim.research.level(site.owner, previous.tech) > int(previous.level):
			_completed_until[id] = sim.tick_count + COMPLETE_TICKS
	for id in _completed_until.keys():
		if sim.tick_count >= int(_completed_until[id]) or not sim.construction.sites.valid(id):
			_completed_until.erase(id)
		elif not CavernLighting.site_visible(sim, sim.construction.sites.records[id]):
			_completed_until.erase(id)
	_jobs = observed
	_tick = sim.tick_count

func state(sim: Simulation, site: Dictionary) -> String:
	# Always test knowledge first: even construction/readiness must use the snapshot.
	if not CavernLighting.site_visible(sim, site): return "idle"
	if not site.ready: return "construction"
	if _jobs.has(site.id):
		return "active" if sim.research.running(sim, _jobs[site.id].job) else "waiting"
	return "complete" if _completed_until.has(site.id) else "idle"

extends SceneTree
const Scenarios = preload("res://bench/stability_scenarios.gd")

func _init() -> void:
	var sim: Simulation = Scenarios.create("mixed_reserve")
	sim.upgrades.energy += 1000
	sim.construction.outposts_unlocked = true
	var ids := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.faction[id] == 0 and ids.size() < 10: ids.append(id)
	var site: int = sim.construction.place(sim, 1, sim.world.index(56, 128), ids)
	if site < 0:
		printerr("Construction fixture failed")
		quit(2)
		return
	var all_times := PackedInt64Array()
	var build_times := PackedInt64Array()
	var errors := PackedStringArray()
	var finished := -1
	for tick in 1200:
		Scenarios.commands(sim, "mixed_reserve", tick)
		var building: bool = not sim.construction.sites.records[site].ready
		var start := Time.get_ticks_usec()
		sim.tick_once()
		var usec := Time.get_ticks_usec() - start
		all_times.append(usec)
		if building: build_times.append(usec)
		if finished < 0 and sim.construction.sites.records[site].ready: finished = sim.tick_count
		if tick % 100 == 0: errors.append_array(sim.check_invariants())
	var result := {"ticks": sim.tick_count, "finished_at": finished, "work": sim.construction.sites.records[site].work,
		"warriors": sim.army.count, "workers": sim.workers.count, "all": _stats(all_times), "during_build": _stats(build_times), "errors": errors}
	print("CONSTRUCTION_BENCH ", JSON.stringify(result))
	quit(0 if finished >= 0 and errors.is_empty() else 1)

func _stats(values: PackedInt64Array) -> Dictionary:
	if values.is_empty(): return {}
	var total := 0
	for value in values: total += value
	values.sort()
	return {"ticks": values.size(), "mean_ms": float(total) / values.size() / 1000.0, "p95_ms": values[ceili(values.size() * 0.95) - 1] / 1000.0, "max_ms": values[-1] / 1000.0}

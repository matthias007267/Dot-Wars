extends SceneTree
const Scenarios = preload("res://bench/stability_scenarios.gd")

func _init() -> void:
	var sim: Simulation = Scenarios.create("mixed_reserve")
	sim.upgrades.energy += 1000
	sim.construction.damage(sim, 0, 500)
	var ids := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.faction[id] == 0 and ids.size() < 10: ids.append(id)
	sim.construction.assign_repair(sim, 0, ids)
	var times := PackedInt64Array()
	var repair_times := PackedInt64Array()
	var errors := PackedStringArray()
	var finished := -1
	for tick in 1200:
		Scenarios.commands(sim, "mixed_reserve", tick)
		var working: bool = sim.construction.sites.records[0].hp < 600
		var start := Time.get_ticks_usec()
		sim.tick_once()
		var usec := Time.get_ticks_usec() - start
		times.append(usec)
		if working: repair_times.append(usec)
		if finished < 0 and sim.construction.sites.records[0].hp == 600: finished = sim.tick_count
		if tick % 100 == 0: errors.append_array(sim.check_invariants())
	print("MAINTENANCE_BENCH ", JSON.stringify({"ticks": sim.tick_count, "finished_at": finished, "hp": sim.construction.sites.records[0].hp,
		"warriors": sim.army.count, "workers": sim.workers.count, "all": _stats(times), "during_repair": _stats(repair_times), "errors": errors}))
	quit(0 if finished >= 0 and errors.is_empty() else 1)

func _stats(values: PackedInt64Array) -> Dictionary:
	if values.is_empty(): return {}
	var total := 0
	for value in values: total += value
	values.sort()
	return {"ticks": values.size(), "mean_ms": float(total) / values.size() / 1000.0, "p95_ms": values[ceili(values.size() * 0.95) - 1] / 1000.0, "max_ms": values[-1] / 1000.0}

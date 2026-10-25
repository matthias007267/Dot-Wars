extends SceneTree
const Scenarios = preload("res://bench/stability_scenarios.gd")

func _init() -> void:
	var sim: Simulation = Scenarios.create("mixed_reserve")
	var ticks := 6000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="): ticks = maxi(1200, arg.get_slice("=", 1).to_int())
	sim.upgrades.energy += 2000
	sim.rules.wallet(sim, 1).energy += 2000
	sim.construction.interceptors_unlocked = true
	var a: int = sim.construction.place(sim, 2, sim.world.index(126, 100), PackedInt32Array(), 0)
	var b: int = sim.construction.place(sim, 2, sim.world.index(130, 100), PackedInt32Array(), 1)
	if a < 0 or b < 0:
		printerr("Energy benchmark fixture failed")
		quit(2)
		return
	sim.construction.sites.contribute(a, 0, 300)
	sim.construction.sites.contribute(b, 1, 300)
	sim.energy_dots.enqueue(sim.world.index(129, 100), 1024, 1)
	sim.energy_dots.enqueue(sim.world.index(24, 40), 256, EnergyStore.NEUTRAL)
	var samples := PackedInt64Array()
	var errors := PackedStringArray()
	var minimum := sim.army.count
	for tick in ticks:
		Scenarios.commands(sim, "mixed_reserve", tick)
		if tick == 1010: sim.construction.damage(sim, a, 150)
		var start := Time.get_ticks_usec()
		sim.tick_once()
		samples.append(Time.get_ticks_usec() - start)
		minimum = mini(minimum, sim.army.count)
		if tick % 100 == 0: errors.append_array(sim.check_invariants())
		if not errors.is_empty(): break
	var total := 0
	for value in samples: total += value
	samples.sort()
	var ledger := sim.energy_dots.ledger()
	var result := {"ticks": sim.tick_count, "simulated_minutes": sim.tick_count / 1200.0, "min_warriors": minimum,
		"warriors_end": sim.army.count, "workers_end": sim.workers.count,
		"mean_ms": float(total) / samples.size() / 1000.0, "p95_ms": samples[ceili(samples.size() * 0.95) - 1] / 1000.0,
		"max_ms": samples[-1] / 1000.0, "ledger": ledger, "errors": errors}
	print("ENERGY_BENCH ", JSON.stringify(result))
	quit(0 if errors.is_empty() and ledger.captures > 0 and ledger.neutralizations > 0 and ledger.expired >= 256 else 1)

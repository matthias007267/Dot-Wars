extends SceneTree
const Scenarios = preload("res://bench/stability_scenarios.gd")
func _init() -> void:
	var kind := "unique"
	var ticks := 120
	var population := 10000
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): kind = arg.get_slice("=", 1)
		if arg.begins_with("--ticks="): ticks = maxi(1, arg.get_slice("=", 1).to_int())
		if arg.begins_with("--warriors="): population = clampi(arg.get_slice("=", 1).to_int(), 1, 10000)
		if arg.begins_with("--out="): output = arg.substr(6)
	var sim: Simulation = Scenarios.create(kind, population)
	if sim == null:
		printerr("Fixture konnte nicht gestartet werden")
		quit(2)
		return
	var samples := PackedInt64Array()
	var errors := PackedStringArray()
	var checkpoints: Array[Dictionary] = []
	var min_population := sim.army.count
	var min_workers := sim.workers.count
	var moved_ticks := 0
	var previous := sim.army.cells.duplicate()
	var overall := Time.get_ticks_usec()
	for tick in ticks:
		Scenarios.commands(sim, kind, tick)
		var start := Time.get_ticks_usec()
		sim.tick_once()
		samples.append(Time.get_ticks_usec() - start)
		if previous != sim.army.cells: moved_ticks += 1
		previous = sim.army.cells.duplicate()
		min_population = mini(min_population, sim.army.count)
		min_workers = mini(min_workers, sim.workers.count)
		if tick % 100 == 0 or tick == ticks - 1:
			errors.append_array(sim.check_invariants())
			if sim.worker_population() > 50 or sim.worker_population(1) > 50: errors.append("Arbeiterlimit überschritten")
			if not errors.is_empty(): break
		if tick % 1200 == 0:
			var checkpoint := {"tick": sim.tick_count, "warriors": sim.army.count, "workers": sim.workers.count,
				"generated": sim.energy_dots.generated, "delivered": sim.energy_dots.delivered, "pending": sim.energy_dots.pending(), "mined": sim.world.mined_count, "losses": sim.army.lost}
			checkpoints.append(checkpoint)
			print("CHECKPOINT ", JSON.stringify(checkpoint))
	var elapsed := (Time.get_ticks_usec() - overall) / 1000000.0
	var total := 0
	for value in samples: total += value
	samples.sort()
	var result := {"case": kind, "ticks_requested": ticks, "ticks_executed": sim.tick_count,
		"simulated_minutes": sim.tick_count / 1200.0, "wall_seconds": elapsed,
		"initial_warriors_requested": population, "min_warriors": min_population, "warriors_end": sim.army.count,
		"min_workers": min_workers, "workers_end": sim.workers.count, "warrior_losses": sim.army.lost,
		"mean_ms": float(total) / samples.size() / 1000.0, "p95_ms": samples[mini(samples.size() - 1, ceili(samples.size() * 0.95) - 1)] / 1000.0,
		"max_ms": samples[-1] / 1000.0, "p99_ms": samples[mini(samples.size() - 1, ceili(samples.size() * 0.99) - 1)] / 1000.0, "native_fog_updates": sim.fog.native_updates, "native_steps": sim.army.native_steps, "moved_ticks": moved_ticks,
		"generated": sim.energy_dots.generated, "delivered": sim.energy_dots.delivered, "energy_pending": sim.energy_dots.pending(), "energy_expired": sim.energy_dots.expired,
		"mined": sim.world.mined_count, "hash": sim.state_hash(), "invariant_errors": errors, "checkpoints": checkpoints}
	if kind.begins_with("mixed") and (sim.world.mined_count <= 0 or sim.energy_dots.delivered <= 0 or sim.army.lost <= 0):
		errors.append("Gemischte Last hatte nicht alle erforderlichen Aktivitäten")
		result.invariant_errors = errors
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  "))
	print("STABILITY ", JSON.stringify(result))
	quit(0 if errors.is_empty() and sim.tick_count == ticks else 1)

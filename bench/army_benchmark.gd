extends SceneTree
## Synthetic open-field march/contact benchmark, no render-FPS claim.
func _init() -> void:
	var ok := true
	var sustained := "--sustained-contact" in OS.get_cmdline_user_args()
	for population in [2000, 10000]:
		for fighting in [false, true]:
			if sustained and not fighting: continue
			ok = _run(population, fighting, sustained) and ok
	quit(0 if ok else 1)

func _run(population: int, fighting: bool, sustained := false) -> bool:
	var config := SimConfig.new()
	config.world_size = 256
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = 0
	var sim := Simulation.from_world(config, WorldState.new(256, 256, 1337, Materials.EMPTY))
	sim.debug_mode = true
	sim.army.profile_enabled = "--profile-army" in OS.get_cmdline_user_args()
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	var placed := 0
	for y in range(30, 230):
		for x in range(30, 230):
			if placed >= population: break
			var cell := sim.world.index(x, y)
			if sim.world.cells[cell] != Materials.EMPTY or sim.workers.occupant[cell] >= 0: continue
			var owner := x % 2 if fighting else int(placed >= population / 2)
			var uid: int = sim.army.add(cell, owner)
			if uid < 0: continue
			sim.army.goals[sim.army.slots[uid]] = sim.world.index(220, 220) if owner == 0 else sim.world.index(30, 220)
			placed += 1
		if placed >= population: break
	var samples: Array[int] = []
	var ticks := 40 if sustained else 120
	var warmup := 10 if sustained else 20
	for tick in ticks:
		var start := Time.get_ticks_usec()
		sim.tick_once()
		if tick >= warmup: samples.append(Time.get_ticks_usec() - start)
	var total := 0
	for value in samples: total += value
	samples.sort()
	var errors := sim.check_invariants()
	print(JSON.stringify({"initial_warriors": placed, "contact": fighting, "remaining": sim.army.count, "losses": sim.army.lost, "ticks": ticks, "warmup_ticks": warmup, "sustained_contact": sustained, "mean_ms": float(total) / samples.size() / 1000.0, "p95_ms": samples[mini(samples.size() - 1, ceili(samples.size() * 0.95) - 1)] / 1000.0, "max_ms": samples[-1] / 1000.0, "invariants": errors, "hash": sim.state_hash(), "army_profile_usec": sim.army.profile_usec, "native_army_steps": sim.army.native_steps}))
	return errors.is_empty() and (not sustained or sim.army.count == population)

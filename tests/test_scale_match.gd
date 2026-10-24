extends TestCase


func _large_match() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 128
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	config.initial_workers = 1
	var world := WorldState.new(128, 128, 32, Materials.EMPTY)
	var sim := Simulation.from_world(config, world)
	for cell in world.cell_count():
		if sim.workers.count >= 10000:
			break
		if world.cells[cell] == Materials.EMPTY and sim.workers.is_free(cell):
			var faction := sim.workers.count % 4
			sim.workers.add(cell, sim.rules.group_of[faction], faction)
	sim.initial_mass = sim.workers.mass_sum()
	sim.peak_mass = sim.initial_mass
	return sim


func test_ten_thousand_combat_matches_full_scan_reference() -> void:
	var sim := _large_match()
	check_eq(sim.workers.count, 10000, "10.000 Einheiten auf vier Fraktionen")
	sim.rules.core_hp.fill(100000)
	var damage := PackedInt32Array([0, 0, 0, 0])
	for id in sim.workers.count:
		for other in sim.rules.faction_count:
			if int(sim.workers.faction[id]) != other and sim.rules._touches_core(sim, id, sim.rules.cores[other], sim.world.width):
				damage[other] += 1
	sim.rules._combat(sim)
	for faction in sim.rules.faction_count:
		check_eq(sim.rules.core_hp[faction], 100000 - damage[faction], "identischer Kernschaden")
	check_no_errors(sim.check_invariants(), "Belegung und Massenbilanz")


func test_elimination_keeps_original_swap_order_at_ten_thousand() -> void:
	var sim := _large_match()
	var expected := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	expected.rules.alive[2] = 0
	while true:
		var found := -1
		for id in expected.workers.count:
			if int(expected.workers.faction[id]) == 2:
				found = id
				break
		if found < 0:
			break
		expected.rules.removed_mass += expected.workers.mass[found]
		expected.workers.remove_swap(found)
	sim.rules._eliminate(sim, 2)
	check_eq(sim.state_hash(), expected.state_hash(), "gleiches Ergebnis wie ursprüngliche Swap-Schleife")
	check_eq(sim.workers.count, 7500, "nur eine Fraktion entfernt")
	check_no_errors(sim.check_invariants(), "Bilanz nach Massenauslöschung")

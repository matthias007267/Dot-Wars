extends TestCase


func _prepared_sim(size: int) -> Simulation:
	var config := SimConfig.new()
	config.world_size = size
	var sim := Simulation.create(config)
	var c := size / 2
	sim.assign_area(0, Rect2i(c - 20, c - 12, 40, 24))
	sim.assign_area(1, Rect2i(c - 12, c - 20, 24, 40))
	return sim


func test_mass_is_traceable_every_tick() -> void:
	var sim := _prepared_sim(128)
	check_eq(sim.initial_mass, 5, "Startmasse")
	for tick in 1500:
		sim.tick_once()
		check_eq(sim.total_mass(), sim.initial_mass + sim.purchased_workers, "Masse nur durch Kauf (Tick %d)" % tick)
		check_eq(sim.energy_dots.generated, sim.energy_dots.delivered + sim.energy_dots.pending(), "Energiebilanz")
	check(sim.world.mined_count > 0, "es wurde abgebaut (%d)" % sim.world.mined_count)
	check_no_errors(sim.check_invariants(), "Invarianten am Ende")


func test_group_counts_always_sum_to_worker_count() -> void:
	var sim := _prepared_sim(128)
	for block in 30:
		sim.run_ticks(50)
		var total := 0
		for count in sim.workers.group_counts:
			total += count
		check_eq(total, sim.workers.count, "Gruppensumme in Block %d" % block)
		var stats := sim.stats()
		check_eq(stats["mass_total"], stats["mass_expected"], "Statistik meldet gleiche Masse")


func test_pending_spawns_count_as_mass() -> void:
	var sim := TestHelpers.sim_from_ascii(["#####", "#w###", "#####"], TestHelpers.default_config())
	sim.spawner.enqueue(sim.world.index(1, 1))
	check_eq(sim.total_mass(), 2, "wartende Entstehung zählt")
	check(not sim.check_invariants().is_empty(), "ohne passenden Abbau ist die Bilanz verletzt")


func test_invariant_check_detects_corruption() -> void:
	var sim := TestHelpers.sim_from_ascii(["#####", "#ww.#", "#####"], TestHelpers.default_config())
	check_no_errors(sim.check_invariants(), "intakt")
	sim.workers.cell[1] = sim.workers.cell[0]
	check(not sim.check_invariants().is_empty(), "doppelte Belegung wird erkannt")
	var other := TestHelpers.sim_from_ascii(["#####", "#w..#", "#####"], TestHelpers.default_config())
	other.world.set_material(other.workers.cell[0], Materials.SOFT)
	check(not other.check_invariants().is_empty(), "Arbeiter im Material wird erkannt")


func test_stats_report_waiting_and_fraction() -> void:
	var sim := TestHelpers.sim_from_ascii(["w..##", "...##"], TestHelpers.default_config())
	var stats := sim.stats()
	check_eq(stats["workers"], 1, "ein Arbeiter")
	check_eq(stats["mined_fraction"], 0.0, "nichts abgebaut")
	sim.run_ticks(5)
	check_eq(sim.stats()["group_waiting"][0], 1, "wartet ohne Gebiet")

extends TestCase

const FOUR_SIDES := [
	".w.",
	"w#w",
	".w.",
]


func _config(dig_power: int) -> SimConfig:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	config.dig_power = dig_power
	return config


func test_four_workers_finish_one_cell_exactly_once() -> void:
	var sim := TestHelpers.sim_from_ascii(FOUR_SIDES, _config(1))
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	for tick in 10:
		sim.tick_once()
		check(sim.world.mined_count <= 1, "höchstens eine Zelle abgebaut")
		check_eq(sim.total_mass(), sim.expected_mass(), "Massenbilanz in Tick %d" % tick)
	check_eq(sim.world.mined_count, 1, "genau eine abgebaute Zelle")
	check_eq(sim.workers.count, 5, "genau ein neuer Arbeiter")
	check_eq(sim.world.progress[sim.world.index(1, 1)], 0, "Fortschritt der leeren Zelle zurückgesetzt")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_overkill_in_a_single_tick_creates_only_one_worker() -> void:
	# dig_power 100 > Haltbarkeit 10: jeder der vier Arbeiter könnte die Zelle allein abschließen.
	var sim := TestHelpers.sim_from_ascii(FOUR_SIDES, _config(100))
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	sim.tick_once()
	check_eq(sim.world.mined_count, 1, "nur ein Abbau")
	check_eq(sim.workers.count, 5, "nur ein neuer Arbeiter")
	check_eq(sim.spawner.pending(), 0, "nichts in der Warteschlange")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_losing_workers_retarget_or_wait_after_cell_vanishes() -> void:
	var sim := TestHelpers.sim_from_ascii(FOUR_SIDES, _config(100))
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	sim.run_ticks(3)
	for id in 4:
		check(sim.workers.state[id] != WorkerStore.STATE_MINING, "Arbeiter %d baut nichts Verschwundenes ab" % id)
	check_eq(sim.world.mined_count, 1, "weiterhin genau ein Abbau")


func test_many_workers_on_a_shared_wall_conserve_mass() -> void:
	var rows := ["###########"]
	rows.append("#wwwwwwwww#")
	rows.append("###########")
	var sim := TestHelpers.sim_from_ascii(rows, _config(1))
	sim.assign_area(0, Rect2i(1, 0, 9, 1))
	sim.assign_area(0, Rect2i(1, 2, 9, 1))
	for tick in 400:
		sim.tick_once()
		check_eq(sim.total_mass(), sim.expected_mass(), "Massenbilanz in Tick %d" % tick)
	check_eq(sim.world.mined_count, 18, "alle 18 Randzellen genau einmal abgebaut")
	check_eq(sim.workers.count, 9 + 18, "Arbeiter = Start + abgebaut")
	check_no_errors(sim.check_invariants(), "Invarianten")

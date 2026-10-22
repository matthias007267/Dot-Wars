extends TestCase

const MAP := [
	"...",
	"w#.",
	"...",
]


func _config() -> SimConfig:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	return config


func _ticks_to_mine_first_cell(material_char: String, config: SimConfig) -> int:
	var rows := MAP.duplicate()
	rows[1] = "w%s." % material_char
	var sim := TestHelpers.sim_from_ascii(rows, config)
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	for tick in 1000:
		sim.tick_once()
		if sim.world.mined_count == 1:
			return tick + 1
	return -1


func test_material_hardness_values() -> void:
	check_eq(Materials.hardness(Materials.SOFT), 1, "weich")
	check_eq(Materials.hardness(Materials.MEDIUM), 3, "mittel")
	check_eq(Materials.hardness(Materials.HARD), 8, "hart")
	check_eq(Materials.durability(Materials.HARD, 10), 80, "Haltbarkeit hart")


func test_mining_duration_scales_with_hardness() -> void:
	var config := _config()
	var soft := _ticks_to_mine_first_cell("#", config)
	var medium := _ticks_to_mine_first_cell("M", config)
	var hard := _ticks_to_mine_first_cell("H", config)
	check_eq(soft, 10, "weich: 1 × 10 Arbeitspunkte")
	check_eq(medium, 30, "mittel: 3 × 10 Arbeitspunkte")
	check_eq(hard, 80, "hart: 8 × 10 Arbeitspunkte")


func test_work_per_hardness_is_configurable() -> void:
	var config := _config()
	config.work_per_hardness = 4
	check_eq(_ticks_to_mine_first_cell("M", config), 12, "3 × 4 Arbeitspunkte")
	config.dig_power = 3
	check_eq(_ticks_to_mine_first_cell("M", config), 4, "12 Punkte bei 3 pro Tick")


func test_progress_is_kept_on_the_cell_and_partial_cells_stay_solid() -> void:
	var sim := TestHelpers.sim_from_ascii(MAP, _config())
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	sim.run_ticks(5)
	var idx := sim.world.index(1, 1)
	check_eq(sim.world.progress[idx], 5, "5 Arbeitspunkte")
	check(sim.world.is_solid(idx), "noch fest")
	check_eq(sim.world.mined_count, 0, "noch nichts abgebaut")


func test_workers_cooperate_on_one_cell() -> void:
	var sim := TestHelpers.sim_from_ascii(["...", "w#w", "..."], _config())
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	var ticks := 0
	while sim.world.mined_count == 0 and ticks < 100:
		sim.tick_once()
		ticks += 1
	check_eq(ticks, 5, "zwei Arbeiter bauen doppelt so schnell ab")


func test_only_marked_cells_are_mined() -> void:
	var sim := TestHelpers.sim_from_ascii(["#w#", "###"], _config())
	sim.assign_area(0, Rect2i(2, 0, 1, 1))
	sim.run_ticks(200)
	check_eq(sim.world.cells[sim.world.index(0, 0)], Materials.SOFT, "unmarkierte Zelle bleibt")
	check_eq(sim.world.cells[sim.world.index(2, 0)], Materials.EMPTY, "markierte Zelle abgebaut")
	check_eq(sim.world.cells[sim.world.index(1, 1)], Materials.SOFT, "Zelle unter dem Arbeiter bleibt")


func test_no_diagonal_mining() -> void:
	var sim := TestHelpers.sim_from_ascii(["w..", ".#.", "..."], _config())
	sim.assign_area(0, Rect2i(1, 1, 1, 1))
	sim.tick_once()
	check_eq(sim.world.progress[sim.world.index(1, 1)], 0, "von der Diagonale aus gibt es keinen Fortschritt")
	check(sim.workers.state[0] != WorkerStore.STATE_MINING, "Arbeiter baut nicht diagonal ab")
	check_eq(TestHelpers.worker_xy(sim, 0), Vector2i(1, 0) if TestHelpers.worker_xy(sim, 0).x == 1 else Vector2i(0, 1), "Arbeiter geht erst auf ein orthogonal angrenzendes Feld")

extends TestCase
## Neue Kernökonomie: Härte wird zu transportierbarer Energie statt Arbeitermasse.


func test_mining_hardness_yields_exact_energy() -> void:
	for material in [Materials.SOFT, Materials.MEDIUM, Materials.HARD]:
		var config := TestHelpers.default_config()
		config.dig_power = 1000
		var world := WorldState.new(16, 16, 8, Materials.EMPTY)
		var origin := world.index(7, 7)
		var target := world.index(8, 7)
		world.set_material(target, material)
		var sim := Simulation.from_world(config, world, PackedInt32Array([origin]))
		sim.assign_area(0, Rect2i(8, 7, 1, 1))
		sim.tick_once()
		check_eq(sim.energy_dots.generated, Materials.hardness(material), "Energie entspricht Härte")
		check_eq(sim.total_mass(), 1, "Abbau erzeugt keine Arbeiter")
		check_no_errors(sim.check_invariants(), "Bilanzen")


func test_energy_moves_without_blocking_workers() -> void:
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array([world.index(8, 8)]))
	var source := world.index(4, 8)
	sim.energy_dots.enqueue(source, 8)
	var original := sim.workers.cell[0]
	for tick in 50:
		sim.tick_once()
		check_eq(sim.workers.cell[0], original, "Arbeiter wird durch Energie nicht verschoben")
		check_no_errors(sim.check_invariants(), "Bilanzen bei Transport")
	check(sim.upgrades.energy > 0, "Energie wurde zum Kern geliefert")
	check_eq(sim.energy_dots.generated, 8, "keine Energie dupliziert")


func test_purchased_worker_uses_center_spawn_and_energy_cost() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := Simulation.create(config)
	sim.upgrades.energy = 20
	check(sim.buy_worker(), "Kauf")
	check_eq(sim.upgrades.energy, 10, "zehn Energie bezahlt")
	check_eq(sim.purchased_workers, 1, "gekaufte Arbeitermasse")
	check_eq(sim.spawner.pending(), 1, "Spawn wird am Kern vorgemerkt")
	sim.tick_once()
	check_eq(sim.total_mass(), sim.initial_mass + 1, "keine Masse erschaffen oder verloren")
	check_no_errors(sim.check_invariants(), "Bilanz nach Spawn")


func test_narrow_tunnel_delivers_every_dot_after_the_worker_steps_aside() -> void:
	var world := WorldState.new(16, 16, 8, Materials.HARD)
	var core := WorldGenerator.sacrifice_cell(world)
	world.set_material(world.index(core.x, core.y), Materials.INDESTRUCTIBLE)
	for x in range(1, core.x):
		world.set_material(world.index(x, core.y), Materials.EMPTY)
	var block_x := 4
	world.set_material(world.index(block_x, core.y + 1), Materials.EMPTY)
	var worker_cell := world.index(block_x, core.y)
	var pocket := world.index(block_x, core.y + 1)
	var sim := Simulation.from_world(TestHelpers.default_config(), world, PackedInt32Array([worker_cell]))
	var count := 24
	sim.energy_dots.enqueue(world.index(1, core.y), count)
	sim.run_ticks(40)
	check_eq(sim.energy_dots.delivered, 0, "der Arbeiter hält den einzigen Gang")
	check_eq(sim.workers.cell[0], worker_cell, "Energie verschiebt den Arbeiter nicht")
	check_eq(sim.energy_dots.pending(), count, "die Dots warten vollständig")
	sim.workers.move_to(0, pocket, sim.tick_count)
	sim.clear_area(0)
	check(sim.set_move_goal(0, pocket), "Laufziel hält die Nische")
	sim.run_ticks(96)
	check_eq(sim.energy_dots.delivered, count, "danach kommt jede Einheit an")
	check_eq(sim.energy_dots.pending(), 0, "nichts bleibt im Gang")
	check_eq(sim.upgrades.energy, count, "Guthaben entspricht der Lieferung")
	check_eq(sim.workers.cell[0], pocket, "der Arbeiter bleibt in der Nische")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_victory_lines_use_the_recorded_numbers() -> void:
	var sim := Simulation.create(TestHelpers.default_config())
	sim.won = true
	sim.win_tick = 20 * 125
	sim.peak_mass = 12
	sim.purchased_workers = 7
	sim.max_units = 9
	sim.upgrades.purchased = 2
	sim.energy_dots.delivered = 80
	sim.world.mined_count = 40
	var lines := sim.victory_lines()
	check_eq(lines[0], "Spielzeit  2:05", "Simulationszeit bis zum Sieg")
	check_eq(lines[1], "Abgebaut  40", "Zellen")
	check_eq(lines[2], "Höchste Masse  12", "Höchstmasse")
	check_eq(lines[3], "Gekaufte Arbeiter  7", "Käufe")
	check_eq(lines[4], "Gelieferte Energie  80", "Energie am Kern")
	check_eq(lines[5], "Upgrades  2", "Käufe der Verbesserungen")
	check_eq(lines[6], "Einheiten zugleich  9", "höchste gleichzeitige Zahl")


func test_energy_save_roundtrip_preserves_in_transit_dots() -> void:
	var sim := Simulation.create(TestHelpers.default_config())
	var origin := sim.workers.cell[0]
	sim.energy_dots.enqueue(origin, 8)
	sim.upgrades.energy = 10
	check(sim.buy_worker(), "Arbeiter gekauft")
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Version 2 wird geladen")
	if restored == null:
		return
	check_eq(restored.energy_dots.cells, sim.energy_dots.cells, "Energiepositionen erhalten")
	check_eq(restored.purchased_workers, 1, "gekaufte Masse erhalten")
	check_eq(restored.state_hash(), sim.state_hash(), "identischer Zustand")


func test_core_technology_cannot_be_bought_without_research() -> void:
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.upgrades.energy = 1000
	var before := sim.upgrades.energy
	check(not sim.buy(Upgrades.KIND_CORE), "Kernausbau benötigt Forschungszentrum")
	check_eq(sim.upgrades.core_level, 0, "kein sofortiger Ausbau")
	check_eq(sim.upgrades.energy, before, "kein Kaufpreis abgezogen")
	check(not sim.research.start(sim, 0, -1, "core"), "ohne Forschungszentrum kein Auftrag")


func _park_off_approach(sim: Simulation, pit: Vector2i, source: int) -> void:
	var approach := {}
	for x in range(0, pit.x):
		approach[sim.world.index(x, pit.y - 1)] = true
	approach[source] = true
	var parking := PackedInt32Array()
	for idx in sim.world.cell_count():
		if sim.core_mask[idx] == 1 or sim.world.cells[idx] != Materials.EMPTY or not sim.workers.is_free(idx):
			continue
		if approach.has(idx):
			continue
		parking.append(idx)
	var cursor := 0
	for id in sim.workers.count:
		if not approach.has(sim.workers.cell[id]):
			continue
		check(cursor < parking.size(), "Platz neben dem Gang")
		if cursor >= parking.size():
			return
		sim.workers.move_to(id, parking[cursor], sim.tick_count)
		cursor += 1


func test_energy_starts_slow_and_each_purchase_is_faster() -> void:
	var upgrades := Upgrades.new()
	check_eq(upgrades.energy_period(), 8, "Energie startet alle 8 Takte")
	check_eq(upgrades.worker_period(8), 8, "Arbeiter starten alle 8 Takte")
	check_eq(upgrades.energy_speed_cost(), 30, "erste Energiekosten")
	check_eq(upgrades.speed_cost(), 25, "erste Arbeiterkosten")
	upgrades.energy = 30
	check(upgrades.try_buy(Upgrades.KIND_ENERGY_SPEED), "erste Energiestufe")
	check_eq(upgrades.energy_period(), 6, "danach alle 6 Takte")
	check_eq(upgrades.energy, 0, "30 Energie bezahlt")
	var slow := _energy_run(0)
	var fast := _energy_run(Upgrades.ENERGY_SPEED_MAX)
	check(fast > slow, "höhere Stufe liefert in derselben Zeit mehr (%d > %d)" % [fast, slow])
	var filled := Upgrades.new()
	filled.energy = 10000
	while filled.energy_speed_cost() >= 0:
		check(filled.try_buy(Upgrades.KIND_ENERGY_SPEED), "weitere Energiestufe")
	check_eq(filled.energy_period(), 1, "letzte Stufe ist ein Schritt je Takt")
	check(not filled.try_buy(Upgrades.KIND_ENERGY_SPEED), "danach kein weiterer Kauf")
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(_sim_with_energy_speed(3)))
	check(restored != null, "Stufe wird gespeichert")
	if restored != null:
		check_eq(restored.upgrades.energy_speed_level, 3, "Energiestufe bleibt erhalten")


func _energy_run(level: int) -> int:
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array([world.index(8, 8)]))
	sim.upgrades.energy_speed_level = level
	sim.energy_dots.enqueue(world.index(2, 8), 6)
	sim.run_ticks(40)
	return sim.energy_dots.delivered


func _sim_with_energy_speed(level: int) -> Simulation:
	var sim := Simulation.create(TestHelpers.default_config())
	sim.upgrades.energy_speed_level = level
	return sim

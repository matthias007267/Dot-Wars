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
	sim.run_ticks(40)
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

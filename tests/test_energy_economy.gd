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


func test_core_upgrade_clears_the_gate_and_grows() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 5
	var sim := Simulation.create(config)
	check(sim != null, "Welt entsteht")
	if sim == null:
		return
	var pit := WorldGenerator.sacrifice_cell(sim.world)
	var gates := sim.energy_exits()
	check(gates.size() >= 2, "zwei Zugänge auf dem Kreuz")
	var spare: Array[int] = []
	for id in sim.workers.count:
		var on_gate := false
		for gate in gates:
			if sim.workers.cell[id] == gate:
				on_gate = true
		if not on_gate:
			spare.append(id)
	for gate in gates:
		var taken := false
		for id in sim.workers.count:
			if sim.workers.cell[id] == gate:
				taken = true
		if taken:
			continue
		check(not spare.is_empty(), "ein Arbeiter kann den Zugang besetzen")
		if spare.is_empty():
			return
		sim.workers.move_to(spare.pop_back(), gate, 0)
	var source := sim.world.index(pit.x - 3, pit.y - 1)
	var count := 6
	sim.energy_dots.enqueue(source, count)
	sim.run_ticks(30)
	check_eq(sim.energy_dots.delivered, 0, "belegte Zugänge lassen keine Energie durch")
	var mined_before := sim.world.mined_count
	var fraction_before := sim.world.mined_fraction()
	sim.upgrades.energy = 0
	check(not sim.buy(Upgrades.KIND_CORE), "ohne Energie kein Kern")
	check_eq(sim.world.opened_count, 0, "fehlgeschlagener Kauf gräbt nicht")
	sim.upgrades.energy = 120
	check(sim.buy(Upgrades.KIND_CORE), "erste Stufe")
	check_eq(sim.upgrades.core_level, 1, "Stufe 1")
	check_eq(sim.upgrades.energy, 80, "40 Energie bezahlt")
	check_eq(sim.upgrades.purchased, 1, "zählt als Fähigkeit")
	check_eq(sim.world.mined_count, mined_before, "Kernfläche ist kein Abbau")
	check(sim.world.opened_count > 0, "Ring wird geöffnet")
	check_eq(sim.world.mined_fraction(), fraction_before, "Abbauanteil bleibt stabil")
	for id in sim.workers.count:
		check(sim.core_mask[sim.workers.cell[id]] == 0, "Arbeiter verlassen die Fläche")
	_park_off_approach(sim, pit, source)
	for _tick in 80:
		sim.tick_once()
		for id in sim.workers.count:
			check(sim.core_mask[sim.workers.cell[id]] == 0, "Arbeiter betreten die Fläche nicht")
	check_eq(sim.energy_dots.delivered, count, "danach kommt die Energie an")
	check_eq(sim.energy_dots.pending(), 0, "nichts bleibt liegen")
	check(sim.buy_worker(), "Arbeiter neben der Fläche")
	sim.tick_once()
	for id in sim.workers.count:
		check(sim.core_mask[sim.workers.cell[id]] == 0, "neuer Arbeiter entsteht außerhalb")
	var first_cells := 0
	for flag in sim.core_mask:
		first_cells += int(flag)
	sim.upgrades.energy = 80
	check(sim.buy(Upgrades.KIND_CORE), "zweite Stufe")
	check_eq(sim.upgrades.core_level, 2, "Stufe 2")
	check_eq(sim.upgrades.energy, 0, "80 Energie bezahlt")
	check_eq(sim.upgrades.purchased, 2, "zweiter Kauf")
	var second_cells := 0
	for flag in sim.core_mask:
		second_cells += int(flag)
	check(second_cells > first_cells, "die Fläche wächst")
	for id in sim.workers.count:
		check(sim.core_mask[sim.workers.cell[id]] == 0, "auch die größere Fläche bleibt frei")
	check_no_errors(sim.check_invariants(), "Bilanzen")
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Speicherstand")
	if restored == null:
		return
	check_eq(restored.upgrades.core_level, 2, "Stufe bleibt erhalten")
	check_eq(restored.world.opened_count, sim.world.opened_count, "geöffnete Zellen bleiben")
	check_eq(restored.state_hash(), sim.state_hash(), "identischer Zustand")
	var data := SaveGame.snapshot(sim)
	data.erase("core_level")
	data.erase("opened")
	var legacy := SaveGame.from_snapshot(data)
	check(legacy != null, "ältere Version 2 bleibt ladbar")
	if legacy == null:
		return
	check_eq(legacy.upgrades.core_level, 0, "fehlende Stufe ist null")
	check_eq(legacy.world.opened_count, 0, "fehlende Öffnung ist null")


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

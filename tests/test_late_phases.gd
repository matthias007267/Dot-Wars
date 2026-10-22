extends TestCase


func test_new_group_can_be_removed_without_losing_mass() -> void:
	var sim := TestHelpers.sim_from_ascii([
		"######",
		"#ww..#",
		"######",
	])
	var before := sim.total_mass()
	var created := sim.add_group("Rosa")
	check_eq(created, 2, "dritte Gruppe")
	check_eq(sim.quotas[2], 0, "neue Gruppe startet bei 0 %")
	check(sim.set_quotas(PackedInt32Array([0, 0, 100])), "Quote auf die neue Gruppe")
	sim.run_ticks(1)
	check_eq(sim.workers.group[0], 0, "bestehende Arbeiter bleiben")
	check(sim.remove_group(0), "Gruppe löschen")
	check_eq(sim.total_mass(), before, "keine Masse verloren")
	check_eq(sim.workers.group[0], 1, "Arbeiter wandern zur verbleibenden Gruppe")
	check(sim.remove_group(2), "leere Gruppe löschen")
	check(not sim.remove_group(1), "die letzte Gruppe bleibt")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_zero_quota_still_receives_nobody_after_a_third_group() -> void:
	var config := TestHelpers.default_config()
	config.group_quotas = PackedInt32Array([0, 50, 50])
	var sim := TestHelpers.sim_from_ascii([
		"###",
		"#w#",
		"###",
	], config)
	sim.assign_area(1, Rect2i(0, 0, 3, 1))
	sim.run_ticks(80)
	check_eq(sim.workers.group_counts[0], 0, "0 % bekommt niemanden")
	check_eq(sim.workers.group_counts[1] + sim.workers.group_counts[2], 1, "Abbau erzeugt keine Arbeiter")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_four_workers_fuse_and_split_without_losing_mass() -> void:
	var world := WorldState.new(6, 4, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	for x in 4:
		sim.workers.add(world.index(1 + x, 1), 0, 0)
	sim.initial_mass = sim.workers.mass_sum()
	sim.peak_mass = sim.initial_mass
	sim.upgrades.fusion2 = true
	check(sim.set_desired_size(0, 2), "Wunschgröße 2")
	check(not sim.set_desired_size(0, 3), "3×3 ist noch gesperrt")
	sim.tick_once()
	check_eq(sim.workers.count, 1, "eine Einheit")
	check_eq(sim.workers.size[0], 2, "2×2")
	check_eq(sim.workers.mass[0], 4, "Masse 4")
	check_eq(sim.total_mass(), 4, "Masse erhalten")
	check(sim.set_desired_size(0, 1), "wieder klein")
	sim.tick_once()
	check_eq(sim.workers.count, 4, "vier Basis-Arbeiter")
	check_eq(sim.total_mass(), 4, "Aufteilung erhält die Masse")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_large_unit_cannot_enter_a_one_wide_gap() -> void:
	var world := WorldState.new(9, 5, 8, Materials.SOFT)
	world.carve_rect(Rect2i(1, 1, 3, 2))
	world.carve_rect(Rect2i(4, 1, 4, 1))
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add_sized(world.index(1, 1), 0, 0, 2)
	sim.initial_mass = 4
	sim.upgrades.fusion2 = true
	check(sim.set_desired_size(0, 2), "Größe halten")
	sim.peak_mass = 4
	var goal := world.index(6, 1)
	check(sim.set_move_goal(0, goal), "Ziel jenseits der Engstelle")
	sim.run_ticks(30)
	check(sim.workers.cell[0] % world.width < 4, "bleibt vor der Engstelle")
	check_eq(sim.workers.size[0], 2, "Größe bleibt")
	check_eq(sim.world.mined_count, 0, "kein Abbau ohne Auftrag")
	check_no_errors(sim.check_invariants(), "Invarianten")


func test_large_unit_mines_faster() -> void:
	var small := _mining_ticks(1)
	var large := _mining_ticks(2)
	check(large > 0 and large < small, "2×2 ist schneller als ein Basis-Arbeiter (%d < %d)" % [large, small])


func test_energy_replaces_worker_sacrifice() -> void:
	var sim := _empty_sim()
	check(not sim.set_sacrifice(0, true), "Arbeiteropfer sind deaktiviert")
	sim.energy_dots.enqueue(sim.workers.cell[0], 8)
	check_eq(sim.energy_dots.generated, 8, "Härte 8 erzeugt acht Energie")
	check_eq(sim.workers.count, 1, "keine Arbeiter werden geopfert")
	check_no_errors(sim.check_invariants(), "Energiebilanz")


func test_dig_upgrade_is_exactly_one_quarter_faster() -> void:
	var plain := _mining_ticks(1)
	var upgraded := _mining_ticks(1, true)
	check_eq(plain, 20, "Härte 1 dauert 20 Takte")
	check_eq(upgraded, 16, "mit +25 % sind es 16 Takte")


func test_double_speed_produces_about_forty_ticks_per_second() -> void:
	var clock := TickClock.new()
	clock.speed = 2
	var ticks := 0
	for _frame in 60:
		ticks += clock.advance(1.0 / 60.0)
	check(ticks >= 38 and ticks <= 42, "2× ergibt etwa 40 Takte, erhalten %d" % ticks)


func test_failed_purchase_keeps_energy() -> void:
	var sim := _empty_sim()
	sim.upgrades.energy = 10
	check(not sim.buy(Upgrades.KIND_DIG), "zu wenig Energie")
	check_eq(sim.upgrades.energy, 10, "Energie unverändert")
	sim.upgrades.energy = 50
	check(sim.buy(Upgrades.KIND_DIG), "Kauf")
	check_eq(sim.upgrades.energy, 0, "Kosten abgezogen")
	check_eq(sim.upgrades.purchased, 1, "gezählt")


func test_victory_requires_all_three_goals() -> void:
	var sim := _empty_sim()
	sim.tick_once()
	check(not sim.won, "zu Beginn kein Sieg")
	var placed := sim.workers.count
	for y in sim.world.height:
		for x in sim.world.width:
			var cell := sim.world.index(x, y)
			if cell == 0 or placed >= 100 or not sim.workers.is_free(cell):
				continue
			sim.workers.add(cell, 0, 0)
			placed += 1
	sim.initial_mass = sim.workers.mass_sum()
	sim.world.set_material(0, Materials.SOFT)
	sim.world.mined_count = 9
	sim.upgrades.purchased = 2
	sim.tick_once()
	check(sim.total_mass() >= 100, "Masse")
	check(sim.world.mined_fraction() >= 0.9, "Fortschritt")
	check(sim.won, "alle drei Ziele")
	check(sim.win_tick > 0, "Siegtick")


func test_save_roundtrip_continues_identically() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 4
	var sim := Simulation.create(config)
	sim.assign_area(0, Rect2i(0, 0, 8, 8))
	sim.run_ticks(30)
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Laden")
	check_eq(restored.total_mass(), sim.total_mass(), "Masse")
	check_eq(restored.world.mined_count, sim.world.mined_count, "Abbau")
	check_eq(restored.workers.count, sim.workers.count, "Anzahl")
	check_eq(restored.tick_count, sim.tick_count, "Tick")
	sim.run_ticks(20)
	restored.run_ticks(20)
	check_eq(restored.state_hash(), sim.state_hash(), "gleiche Fortsetzung")
	check(SaveGame.from_bytes(var_to_bytes({"version": 99})) == null, "fremde Version")
	check(SaveGame.from_bytes(var_to_bytes("kaputt")) == null, "kein Speicherstand")
	var path := "user://dotwars-test-save.dw"
	check(SaveGame.write_file(path, sim), "Schreiben")
	var loaded := SaveGame.read_file(path)
	check(loaded != null, "Datei")
	check_eq(loaded.total_mass(), sim.total_mass(), "Datei-Masse")


func _mining_ticks(unit_size: int, upgrade: bool = false) -> int:
	var rows := ["###", "#w#", "###"] if unit_size == 1 else ["####", "#ww#", "#ww#", "####"]
	var sim := TestHelpers.sim_from_ascii(rows)
	if unit_size == 2:
		while sim.workers.count > 0:
			sim.workers.remove_swap(0)
		sim.workers.add_sized(sim.world.index(1, 1), 0, 0, 2)
		sim.initial_mass = 4
		sim.peak_mass = 4
	if upgrade:
		sim.upgrades.dig_level = 1
	sim.assign_area(0, Rect2i(0, 0, sim.world.width, 1))
	for tick in 80:
		sim.tick_once()
		if sim.world.mined_count > 0:
			return tick + 1
	return -1


func _empty_sim() -> Simulation:
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add(world.index(1, 1), 0, 0)
	sim.initial_mass = 1
	sim.peak_mass = 1
	return sim

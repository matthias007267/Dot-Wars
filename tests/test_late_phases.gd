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


func test_four_workers_remain_individual_without_fusion() -> void:
	var world := WorldState.new(6, 4, 8, Materials.EMPTY)
	var sim := Simulation.from_world(TestHelpers.default_config(), world, PackedInt32Array(), false)
	for x in 4: sim.workers.add(world.index(1 + x, 1), 0, 0)
	sim.initial_mass = 4
	sim.upgrades.fusion2 = true
	check(not sim.set_desired_size(0, 2), "Fusion entfernt")
	sim.tick_once()
	check_eq(sim.workers.count, 4, "vier einzelne Arbeiter")
	check_eq(sim.workers.max_size, 1, "nur Größe eins")
	check_eq(sim.total_mass(), 4, "Masse bleibt erhalten")
	check_no_errors(sim.check_invariants(), "Belegung")

func test_large_unit_cannot_enter_a_one_wide_gap() -> void:
	var world := WorldState.new(9, 5, 8, Materials.SOFT)
	world.carve_rect(Rect2i(1, 1, 3, 2))
	world.carve_rect(Rect2i(4, 1, 4, 1))
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add_sized(world.index(1, 1), 0, 0, 2)
	sim.initial_mass = 4
	sim.upgrades.fusion2 = true
	check(not sim.set_desired_size(0, 2), "Legacy-Geometrie darf keine neue Fusion anfordern")
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


func test_high_dig_levels_keep_mining() -> void:
	check_eq(_mining_ticks(1, false, 13), 2, "Stufe 13 braucht zwei Takte")
	check_eq(_mining_ticks(1, false, 14), 1, "Stufe 14 baut in einem Takt")
	check_eq(_mining_ticks(1, false, 16), 1, "Stufe 16 teilt nicht durch null")
	check_eq(_mining_ticks(1, false, 31), 1, "Stufe 31 bleibt exakt")
	check_eq(_mining_ticks(1, false, 16, "H"), 5, "harte Zelle auf Stufe 16 dauert fünf Takte")


func test_high_dig_remainder_survives_a_save() -> void:
	var world := WorldState.new(16, 16, 32, Materials.EMPTY)
	var cell := world.index(8, 7)
	world.set_material(cell, Materials.HARD)
	var config := TestHelpers.default_config()
	config.world_size = 16
	config.move_period_ticks = 1
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add(world.index(8, 8), 0, 0)
	sim.initial_mass = 1
	sim.peak_mass = 1
	sim.upgrades.dig_level = 16
	sim.assign_area(0, Rect2i(8, 7, 1, 1))
	sim.tick_once()
	check_eq(int(sim.world.progress[cell]), 35, "erster Takt setzt 35 Punkte")
	check_eq(int(sim.world.progress_frac[cell]), 116551617, "niederes Restglied")
	check_eq(int(sim.world.progress_frac_high[cell][0]), 1, "hohes Restglied")
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Laden")
	check_eq(restored.state_hash(), sim.state_hash(), "Rest bleibt erhalten")
	for _tick in 4:
		sim.tick_once()
		restored.tick_once()
	check_eq(sim.world.mined_count, 1, "nach fünf Takten abgebaut")
	check_eq(restored.world.mined_count, 1, "geladener Stand baut gleich ab")
	check_eq(restored.state_hash(), sim.state_hash(), "gleiche Fortsetzung")
	check(sim.world.progress_frac_high.is_empty(), "abgeschlossene Zelle verwirft den Rest")


func test_dig_level_past_64_bit_fraction_still_finishes() -> void:
	var sim := _dig_world(40, "#", 10000)
	sim.tick_once()
	check_eq(sim.world.mined_count, 0, "erster Takt reicht nicht")
	check(not sim.world.progress_frac_high.is_empty(), "Rest braucht weitere Glieder")
	sim.tick_once()
	check_eq(sim.world.mined_count, 1, "zweiter Takt schließt die Zelle")


func test_large_unit_high_dig_does_not_stall() -> void:
	var world := WorldState.new(8, 8, 8, Materials.EMPTY)
	world.set_material(world.index(4, 1), Materials.SOFT)
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	var id := sim.workers.add_sized(world.index(1, 1), 0, 0, 3)
	sim.workers.state[id] = WorkerStore.STATE_MINING
	sim.assign_area(0, Rect2i(4, 1, 1, 1))
	MiningSystem.step_scaled(
		sim.workers, sim.world, sim.areas, sim.energy_dots, config.work_per_hardness, config.dig_power, 13
	)
	check_eq(sim.world.mined_count, 1, "3×3 auf Stufe 13 trägt die volle Leistung")


func test_faction_dig_level_does_not_overflow() -> void:
	var config := TestHelpers.default_config()
	var sim := TestHelpers.sim_from_ascii(["###", "#w#", "###"], config)
	sim.assign_area(0, Rect2i(0, 0, 3, 1))
	sim.workers.state[0] = WorkerStore.STATE_MINING
	var levels := PackedInt32Array([16])
	MiningSystem.step_scaled(
		sim.workers, sim.world, sim.areas, sim.energy_dots, config.work_per_hardness, config.dig_power, 0, levels
	)
	check_eq(sim.world.mined_count, 1, "Fraktion mit Stufe 16 baut ab")
	var plain := TestHelpers.sim_from_ascii(["###", "#w#", "###"], config)
	plain.assign_area(0, Rect2i(0, 0, 3, 1))
	plain.workers.state[0] = WorkerStore.STATE_MINING
	MiningSystem.step_scaled(
		plain.workers, plain.world, plain.areas, plain.energy_dots,
		config.work_per_hardness, config.dig_power, 0, PackedInt32Array([0])
	)
	check_eq(plain.world.mined_count, 0, "Stufe 0 baut die Zelle nicht in einem Takt")
	check_eq(int(plain.world.progress[plain.world.index(1, 0)]), 1, "Stufe 0 setzt einen Punkt")


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


func test_old_clearing_goals_remain_disabled_even_when_all_are_met() -> void:
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
	check(not sim.won, "alte Solo-Ziele deaktiviert")
	check_eq(sim.win_tick, -1, "kein Solo-Siegtick")


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
	check_eq(restored.areas.state_hash(), sim.areas.state_hash(), "Abbaugebiete inklusive Masken bleiben identisch")
	check_eq(restored.areas.revision, sim.areas.revision, "Abbaugebiet-Revision bleibt erhalten")
	check_eq(restored.areas.group_revision, sim.areas.group_revision, "Gruppenrevisionen bleiben erhalten")
	check_eq(restored.state_hash(), sim.state_hash(), "identischer Zustand direkt nach dem Laden")
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


func _mining_ticks(unit_size: int, upgrade: bool = false, dig_level: int = -1, material := "#") -> int:
	var sim: Simulation
	if unit_size == 1:
		sim = _dig_world(1 if upgrade else 0, material)
	else:
		var config := TestHelpers.default_config()
		config.move_period_ticks = 1
		sim = TestHelpers.sim_from_ascii(["####", "#ww#", "#ww#", "####"], config)
		while sim.workers.count > 0:
			sim.workers.remove_swap(0)
		sim.workers.add_sized(sim.world.index(1, 1), 0, 0, 2)
		sim.initial_mass = 4
		sim.peak_mass = 4
		sim.assign_area(0, Rect2i(0, 0, sim.world.width, 1))
		if upgrade:
			sim.upgrades.dig_level = 1
	if dig_level >= 0:
		sim.upgrades.dig_level = dig_level
	for tick in 200:
		sim.tick_once()
		if sim.world.mined_count > 0:
			return tick + 1
	return -1


func _dig_world(dig_level: int, material := "#", work_per_hardness := 20) -> Simulation:
	var rock := material if material.length() == 1 else "#"
	var rows := [rock + rock + rock, rock + "w" + rock, rock + rock + rock]
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	config.work_per_hardness = work_per_hardness
	var sim := TestHelpers.sim_from_ascii(rows, config)
	sim.upgrades.dig_level = dig_level
	sim.assign_area(0, Rect2i(0, 0, sim.world.width, 1))
	return sim


func _empty_sim() -> Simulation:
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add(world.index(1, 1), 0, 0)
	sim.initial_mass = 1
	sim.peak_mass = 1
	return sim

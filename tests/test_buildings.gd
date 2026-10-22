extends TestCase
## Modi, Quelle und Veredler. Räumung behält die drei bisherigen Ziele.


func _empty(mode: int) -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.mode = mode
	config.initial_workers = 1
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	return Simulation.from_world(config, world, PackedInt32Array(), false)


func test_clearing_ignores_delivered_energy_and_refuses_a_source() -> void:
	var sim := _empty(SimConfig.MODE_CLEARING)
	sim.energy_dots.delivered = SimConfig.EXTRACTION_GOAL
	sim.energy_dots.generated = SimConfig.EXTRACTION_GOAL
	sim.tick_once()
	check(not sim.won, "gelieferte Energie gewinnt die Räumung nicht")
	sim.upgrades.energy = 500
	var cell := sim.world.index(8, 8)
	check(not sim.place_building(Buildings.KIND_SOURCE, cell), "Räumung hat keine Quelle")
	check(sim.place_building(Buildings.KIND_REFINERY, cell), "Veredler ist Wirtschaft")
	check_eq(sim.upgrades.energy, 380, "120 Energie bezahlt")
	check_eq(sim.upgrades.purchased, 1, "der Kauf zählt als Fähigkeit")
	check(not sim.place_building(Buildings.KIND_REFINERY, cell), "die Zelle ist belegt")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_extraction_wins_on_delivered_energy() -> void:
	var sim := _empty(SimConfig.MODE_EXTRACTION)
	sim.energy_dots.delivered = SimConfig.EXTRACTION_GOAL - 1
	sim.energy_dots.generated = SimConfig.EXTRACTION_GOAL - 1
	sim.tick_once()
	check(not sim.won, "unter dem Ziel kein Sieg")
	sim.energy_dots.delivered = SimConfig.EXTRACTION_GOAL
	sim.energy_dots.generated = SimConfig.EXTRACTION_GOAL
	sim.tick_once()
	check(sim.won, "1.000 gelieferte Energie gewinnen die Förderung")
	check(not sim.place_building(Buildings.KIND_REFINERY, sim.world.index(4, 4)), "Förderung hat keinen Veredler")


func test_source_grows_real_material_and_waits_at_the_cap() -> void:
	var sim := _empty(SimConfig.MODE_EXTRACTION)
	var origin := sim.world.index(16, 16)
	sim.upgrades.energy = 80
	check(sim.place_building(Buildings.KIND_SOURCE, origin), "Quelle gesetzt")
	sim.run_ticks(159)
	check_eq(sim.buildings.buds[0].size(), 0, "vor 8 Sekunden wächst nichts")
	sim.tick_once()
	check_eq(sim.buildings.buds[0].size(), 1, "nach 160 Takten eine Knospe")
	check_eq(sim.world.cells[origin - 32], Materials.SOFT, "die nördliche Zelle ist weich")
	for _step in 3:
		sim.buildings.elapsed[0] = 159
		sim.tick_once()
	check_eq(sim.buildings.buds[0].size(), 4, "höchstens vier Knospen")
	sim.buildings.elapsed[0] = 159
	sim.tick_once()
	check_eq(sim.buildings.buds[0].size(), 4, "volle Quelle wartet")
	var bud := sim.buildings.buds[0][0]
	check(sim.world.mine_cell(bud), "Knospe abgebaut")
	sim.buildings.elapsed[0] = 159
	sim.tick_once()
	check_eq(sim.buildings.buds[0].size(), 4, "eine freie Stelle wird wieder besetzt")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_source_tiers_change_every_third_and_sixth_bud() -> void:
	var sim := _empty(SimConfig.MODE_EXTRACTION)
	var origin := sim.world.index(16, 16)
	sim.upgrades.energy = 80 + 40 + 80 + 120
	check(sim.place_building(Buildings.KIND_SOURCE, origin), "Quelle")
	check(sim.upgrade_building(Buildings.KIND_SOURCE), "Stufe 1")
	check(sim.upgrade_building(Buildings.KIND_SOURCE), "Stufe 2")
	check(sim.upgrade_building(Buildings.KIND_SOURCE), "Stufe 3")
	check_eq(sim.buildings.source_level, 3, "drei Stufen")
	for _step in 4:
		sim.buildings.elapsed[0] = 119
		sim.tick_once()
	check_eq(sim.world.cells[sim.buildings.buds[0][2]], Materials.MEDIUM, "die dritte Knospe ist mittel")
	for bud in sim.buildings.buds[0]:
		sim.world.mine_cell(bud)
	for _step in 2:
		sim.buildings.elapsed[0] = 119
		sim.tick_once()
	check_eq(sim.buildings.grown[0], 6, "sechs Knospen insgesamt")
	check_eq(sim.world.cells[sim.buildings.buds[0][sim.buildings.buds[0].size() - 1]], Materials.HARD, "die sechste Knospe ist hart")


func test_refinery_doubles_a_nearby_dot_once() -> void:
	var sim := _empty(SimConfig.MODE_REFINING)
	var here := sim.world.index(8, 20)
	var near := sim.world.index(8, 4)
	var far := sim.world.index(8, 2)
	sim.buildings.add(Buildings.KIND_REFINERY, here)
	_dot(sim, here, far)
	sim.buildings.refine(sim.energy_dots, sim.world, 0)
	check_eq(sim.energy_dots.generated, 1, "außerhalb des Umkreises bleibt der Dot")
	sim.energy_dots.birth[0] = near
	sim.buildings.refine(sim.energy_dots, sim.world, 0)
	check_eq(sim.energy_dots.generated, 2, "ein Dot im Umkreis wird verdoppelt")
	check_eq(int(sim.energy_dots.refined[0]), 1, "das Original ist veredelt")
	check_eq(int(sim.energy_dots.refined[1]), 1, "der Zwilling ist veredelt")
	sim.buildings.refine(sim.energy_dots, sim.world, 20)
	check_eq(sim.energy_dots.generated, 2, "derselbe Dot wird nicht noch einmal geteilt")
	_dot(sim, here, near)
	sim.buildings.refine(sim.energy_dots, sim.world, 19)
	check_eq(sim.energy_dots.generated, 3, "vor Ablauf der Sekunde bleibt der nächste Dot")
	sim.buildings.refine(sim.energy_dots, sim.world, 20)
	check_eq(sim.energy_dots.generated, 4, "nach einer Sekunde folgt der nächste Dot")
	var other := sim.world.index(12, 20)
	sim.buildings.add(Buildings.KIND_REFINERY, other)
	for i in sim.energy_dots.cells.size():
		sim.energy_dots.cells[i] = other
	sim.buildings.refine(sim.energy_dots, sim.world, 0)
	check_eq(sim.energy_dots.generated, 4, "ein zweiter Veredler teilt denselben Dot nicht")
	check_no_errors(sim.check_invariants(), "Energiebilanz")


func test_refining_goal_counts_only_refined_deliveries() -> void:
	var sim := _empty(SimConfig.MODE_REFINING)
	sim.energy_dots.delivered = 400
	sim.energy_dots.generated = 400
	sim.tick_once()
	check(not sim.won, "rohe Energie schließt die Veredelung nicht ab")
	sim.energy_dots.refined_delivered = 400
	sim.tick_once()
	check(sim.won, "400 veredelte Dots gewinnen")


func test_a_refined_dot_is_credited_as_one_and_counted() -> void:
	var sim := _empty(SimConfig.MODE_REFINING)
	var gate := sim.world.index(3, 3)
	_dot(sim, gate, gate)
	sim.energy_dots.refined[0] = 1
	var gained := sim.energy_dots.step(sim.world, sim.workers, PackedInt32Array([gate]), 0)
	check_eq(gained, 1, "eine Einheit im Guthaben")
	check_eq(sim.energy_dots.refined_delivered, 1, "dieselbe Einheit zählt für den Modus")
	check_eq(sim.energy_dots.pending(), 0, "der Dot ist angekommen")


func test_save_keeps_mode_and_old_saves_stay_clearing() -> void:
	var sim := _empty(SimConfig.MODE_EXTRACTION)
	var origin := sim.world.index(10, 10)
	sim.upgrades.energy = 80
	check(sim.place_building(Buildings.KIND_SOURCE, origin), "Quelle")
	sim.buildings.elapsed[0] = 159
	sim.tick_once()
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Stand mit Quelle")
	if restored == null:
		return
	check_eq(restored.config.mode, SimConfig.MODE_EXTRACTION, "Modus")
	check_eq(restored.buildings.cell[0], origin, "Quelle bleibt")
	check_eq(restored.world.cells[origin - 32], Materials.SOFT, "Knospe bleibt")
	check_eq(restored.state_hash(), sim.state_hash(), "identischer Zustand")
	var data := SaveGame.snapshot(sim)
	data.erase("mode")
	data.erase("buildings")
	data.erase("source_level")
	data.erase("refinery_level")
	data.erase("energy_birth")
	data.erase("energy_refined")
	data.erase("refined_delivered")
	var legacy := SaveGame.from_snapshot(data)
	check(legacy != null, "fehlende Felder bleiben lesbar")
	if legacy == null:
		return
	check_eq(legacy.config.mode, SimConfig.MODE_CLEARING, "ohne Modus ist es Räumung")
	check_eq(legacy.buildings.cell.size(), 0, "ohne Liste gibt es keine Gebäude")
	check_no_errors(legacy.check_invariants(), "alter Stand bleibt gültig")


func test_hud_shows_the_mode_goal_and_its_building() -> void:
	var sim := _empty(SimConfig.MODE_EXTRACTION)
	var hud := GameHud.new()
	hud.sim = sim
	hud.clock = TickClock.new()
	var layer := Control.new()
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	hud._build_upgrade_panel(layer)
	hud.refresh()
	check_eq(hud._goal_heading.text, "FÖRDERUNG", "Modus in der Zielkarte")
	check_eq(hud._goal_names[0].text, "1.000 Energie liefern", "Förderziel")
	check(not hud._goal_sections[2].visible, "der 90-Prozent-Balken ist weg")
	check(hud._source_place_button.visible, "Quelle wird angeboten")
	check(not hud._refinery_place_button.visible, "Veredler bleibt in diesem Modus aus")
	sim.config.mode = SimConfig.MODE_CLEARING
	hud.refresh()
	check_eq(hud._goal_heading.text, "RÄUMUNG", "Rückkehr zur Räumung")
	check(hud._goal_sections[2].visible, "Abbauziel wieder sichtbar")
	check(hud._refinery_place_button.visible, "Veredler in der Räumung")
	check(not hud._source_place_button.visible, "keine Quelle in der Räumung")
	layer.free()
	hud.free()


func _dot(sim: Simulation, cell: int, birth: int) -> void:
	sim.energy_dots.cells.append(cell)
	sim.energy_dots.birth.append(birth)
	sim.energy_dots.refined.append(0)
	sim.energy_dots.generated += 1

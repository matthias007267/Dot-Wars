extends TestCase
## UI-Befehle ohne aktive Szene. Die Farbgruppen bleiben intern und erhalten gemeinsame Ziele.

func _new_hud() -> GameHud:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 5
	config.group_quotas = PackedInt32Array([40, 30, 30])
	var sim := Simulation.create(config)
	var hud := GameHud.new()
	hud.sim = sim
	hud.clock = TickClock.new()
	return hud


func test_mining_area_is_sent_to_every_working_group() -> void:
	var hud := _new_hud()
	var rect := Rect2i(1, 1, 8, 8)
	check(hud.issue_dig_area(rect), "globaler Abbauauftrag")
	for g in hud.sim.group_open.size():
		check_eq(hud.sim.areas.rects[g].size(), 1, "jede aktive Gruppe hat genau ein Gebiet")
		check_eq(hud.sim.areas.rects[g][0], rect, "alle erhalten dasselbe Gebiet")
	check_no_errors(hud.sim.check_invariants(), "Befehle verändern keine Masse")
	hud.free()


func test_move_goal_replaces_mining_for_all_groups() -> void:
	var hud := _new_hud()
	hud.issue_dig_area(Rect2i(0, 0, 10, 10))
	var pit_neighbor := hud.sim.world.find_nearest_empty(16, 16)
	check(pit_neighbor >= 0, "eine Tunnelzelle ist vorhanden")
	check(hud.issue_move_goal(pit_neighbor), "globaler Laufbefehl")
	for g in hud.sim.group_open.size():
		check_eq(hud.sim.move_goal(g), pit_neighbor, "gemeinsames Laufziel")
		check_eq(hud.sim.areas.rects[g].size(), 0, "Abbauauftrag ersetzt")
	check_no_errors(hud.sim.check_invariants(), "Befehle verändern keine Masse")
	hud.free()


func test_buy_worker_requires_energy() -> void:
	var hud := _new_hud()
	check(not hud.sim.buy_worker(), "ohne Energie kein Arbeiter")
	hud.sim.upgrades.energy = Simulation.WORKER_COST
	check(hud.sim.buy_worker(), "Arbeiter gekauft")
	check_eq(hud.sim.upgrades.energy, 0, "Energie abgebucht")
	check_eq(hud.sim.spawner.pending(), 1, "gekaufter Arbeiter wartet am Kern")
	check_no_errors(hud.sim.check_invariants(), "Bilanz nach Kauf")
	hud.free()


func test_fusion_size_is_applied_to_all_working_groups() -> void:
	var hud := _new_hud()
	check(not hud.set_size_all(2), "gesperrte Größe wird abgewiesen")
	hud.sim.upgrades.fusion2 = true
	check(hud.set_size_all(2), "Größe zwei gesetzt")
	for g in hud.sim.group_open.size():
		check_eq(hud.sim.desired_size[g], 2, "interne Gruppen nutzen dieselbe Größe")
	check(hud.set_size_all(1), "Größe gilt für alle Gruppen")
	check_eq(hud.sim.desired_size[2], 1, "alle internen Gruppen gleich")
	check_no_errors(hud.sim.check_invariants(), "keine Masse durch Größeneinstellung verloren")
	hud.free()

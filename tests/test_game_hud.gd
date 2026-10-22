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


func test_sacrifice_uses_only_internal_reserve_group() -> void:
	var hud := _new_hud()
	var rect := Rect2i(0, 0, 8, 8)
	hud.issue_dig_area(rect)
	check(hud.toggle_sacrifice(), "Opfern wird eingeschaltet")
	check_eq(hud.sim.sacrifice_on[2], 1, "letzte aktive Gruppe opfert")
	check_eq(hud.sim.sacrifice_on[0], 0, "erste Gruppe arbeitet weiter")
	check_eq(hud.sim.sacrifice_on[1], 0, "zweite Gruppe arbeitet weiter")
	check_eq(hud.sim.areas.rects[2].size(), 0, "Opfergruppe baut nicht mehr ab")
	check(hud.toggle_sacrifice(), "Opfern wird ausgeschaltet")
	check_eq(hud.sim.sacrifice_on[2], 0, "Opferauftrag aufgehoben")
	check_eq(hud.sim.areas.rects[2].size(), 1, "Abbauauftrag wiederhergestellt")
	check_no_errors(hud.sim.check_invariants(), "keine Masse durch UI verloren")
	hud.free()


func test_fusion_size_is_applied_to_all_working_groups() -> void:
	var hud := _new_hud()
	check(not hud.set_size_all(2), "gesperrte Größe wird abgewiesen")
	hud.sim.upgrades.fusion2 = true
	check(hud.set_size_all(2), "Größe zwei gesetzt")
	for g in hud.sim.group_open.size():
		check_eq(hud.sim.desired_size[g], 2, "interne Gruppen nutzen dieselbe Größe")
	check(hud.toggle_sacrifice(), "Opfern für die Größenprüfung")
	check(hud.set_size_all(1), "Größe gilt auch für die opfernde Gruppe")
	check_eq(hud.sim.desired_size[2], 1, "Opfergruppe behält die gemeinsame Größe")
	check_no_errors(hud.sim.check_invariants(), "keine Masse durch Größeneinstellung verloren")
	hud.free()

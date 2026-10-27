extends TestCase
const Backend = preload("res://src/sim/native_search.gd")


func _worker_world(top: Array, bottom: Array) -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 16
	config.move_period_ticks = 1
	config.dig_power = 1000
	var world := WorldState.new(16, 16, 8, Materials.INDESTRUCTIBLE)
	world.carve_rect(Rect2i(1, 1, 9, 1))
	world.carve_rect(Rect2i(1, 5, 9, 1))
	world.carve_rect(Rect2i(1, 1, 1, 5))
	world.carve_rect(Rect2i(9, 1, 1, 5))
	for x in top: world.set_material(world.index(int(x), 1), Materials.ROCK)
	for x in bottom: world.set_material(world.index(int(x), 5), Materials.ROCK)
	return Simulation.from_world(config, world, PackedInt32Array([world.index(1, 1)]))


func _march(sim: Simulation) -> GameHud:
	var hud := GameHud.new()
	hud.sim = sim
	hud.select_at(sim.workers.cell[0])
	check(hud.issue_march(sim.world.index(9, 1)), "echter HUD-Marschauftrag")
	return hud


func _until_arrival(sim: Simulation) -> void:
	for tick in 120:
		if sim.workers.cell[0] == sim.world.index(9, 1): break
		sim.tick_once()
	check_eq(sim.workers.cell[0], sim.world.index(9, 1), "Ziel erreicht, nicht an falscher Wand geparkt")
	check_no_errors(sim.check_invariants(), "Arbeiter-/Energiebilanzen")


func test_unresearched_worker_chooses_longer_route_with_fewer_blocks() -> void:
	var sim := _worker_world([3, 4, 5], [5])
	check_eq(sim.upgrades.swarm_level, 0, "keine Schwarmforschung")
	var hud := _march(sim)
	check(sim.areas.is_marked(sim.command_group, sim.world.index(5, 5)), "Umweg mit einem Block gewählt")
	check(not sim.areas.is_marked(sim.command_group, sim.world.index(3, 1)), "kürzere Drei-Block-Route nicht markiert")
	_until_arrival(sim)
	check_eq(sim.world.mined_count, 1, "nur ein Block bis zur Ankunft")
	for x in [3, 4, 5]: check_eq(sim.world.cells[sim.world.index(x, 1)], Materials.ROCK, "direkte Wand bleibt")
	hud.free()


func test_open_detour_is_preferred_over_any_mining() -> void:
	var sim := _worker_world([5], [])
	var hud := _march(sim)
	_until_arrival(sim)
	check_eq(sim.world.mined_count, 0, "freier Umweg ohne Abbau")
	hud.free()


func test_equal_block_count_prefers_softer_material_then_shorter_walk() -> void:
	var sim := _worker_world([5], [5])
	sim.world.set_material(sim.world.index(5, 1), Materials.DIAMOND)
	var hud := _march(sim)
	_until_arrival(sim)
	check_eq(sim.world.cells[sim.world.index(5, 1)], Materials.DIAMOND, "Diamant bleibt bei gleicher Blockzahl")
	check_eq(sim.world.mined_count, 1, "weicherer Block gewählt")
	hud.free()
	var equal := _worker_world([5], [5])
	var equal_hud := _march(equal)
	check(equal.areas.is_marked(equal.command_group, equal.world.index(5, 1)), "bei gleicher Härte kürzerer Laufweg")
	equal_hud.free()


func test_fewer_blocks_remains_primary_even_for_harder_material() -> void:
	var sim := _worker_world([5], [4, 5])
	sim.world.set_material(sim.world.index(5, 1), Materials.DIAMOND)
	var targets := PackedByteArray()
	targets.resize(sim.world.cell_count())
	targets[sim.world.index(9, 1)] = 1
	var path := ExcavationPath.find(sim.world, sim.core_mask, sim.workers.cell, targets)
	check(path.has(sim.world.index(5, 1)), "ein Block hat Vorrang vor zwei Blöcken")
	check(not path.has(sim.world.index(5, 5)), "keine abweichende Härte-Priorität")


func test_unreachable_mining_area_uses_the_same_excavation_priority() -> void:
	var sim := _worker_world([3, 4, 5], [5])
	var target := sim.world.index(9, 1)
	sim.world.set_material(target, Materials.ROCK)
	sim.assign_area(0, Rect2i(9, 1, 1, 1))
	for tick in 120:
		if sim.world.cells[target] == Materials.EMPTY: break
		sim.tick_once()
	check_eq(sim.world.cells[target], Materials.EMPTY, "markiertes Gebiet erreicht")
	check_eq(sim.world.cells[sim.world.index(3, 1)], Materials.ROCK, "teure direkte Verbindung bleibt")
	check_eq(sim.world.mined_count, 2, "Verbindungsblock und Zielblock")


func test_worker_route_resumes_exactly_during_incremental_field_build() -> void:
	var sim := _worker_world([3, 4, 5], [5])
	var hud := _march(sim)
	sim._refresh_flow_anchors()
	sim.fields[sim.command_group].step(3)
	check(sim.fields[sim.command_group].is_building(), "Speicherpunkt liegt tatsächlich mitten im Aufbau")
	var restored := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(restored != null, "Marsch im inkrementellen Wegaufbau ladbar")
	if restored != null:
		for tick in 60:
			sim.tick_once()
			restored.tick_once()
			check_eq(sim.state_hash(), restored.state_hash(), "identische Fortsetzung Takt %d" % tick)
	hud.free()


func test_obsidian_and_forbidden_cells_never_enter_excavation_paths() -> void:
	var world := WorldState.new(5, 1, 8, Materials.EMPTY)
	world.set_material(2, Materials.INDESTRUCTIBLE)
	var targets := PackedByteArray([0, 0, 0, 0, 1])
	check(ExcavationPath.find(world, PackedByteArray(), PackedInt32Array([0]), targets).is_empty(), "Obsidian trennt")
	world.set_material(2, Materials.ROCK)
	check(ExcavationPath.find(world, PackedByteArray([0, 0, 1, 0, 0]), PackedInt32Array([0]), targets).is_empty(), "Kernmaske trennt")
	check(not ExcavationPath.find(world, PackedByteArray(), PackedInt32Array([-1, 0, 0, 99]), targets).is_empty(), "gültige Ursprünge trotz Duplikaten/Randwerten")


func _army_world() -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 0
	var world := WorldState.new(32, 32, 8, Materials.INDESTRUCTIBLE)
	world.carve_rect(Rect2i(1, 1, 13, 30))
	world.carve_rect(Rect2i(16, 1, 15, 30))
	return Simulation.from_world(config, world, PackedInt32Array(), false)


func _army_ticks(sim: Simulation, ticks: int) -> void:
	for tick in ticks:
		sim.army.step(sim)
		sim.tick_count += 1


func test_warrior_approaches_unreachable_goal_in_its_own_component() -> void:
	var sim := _army_world()
	var left := sim.army.add(sim.world.index(2, 2), 0)
	var right := sim.army.add(sim.world.index(17, 2), 0)
	var goal := sim.world.index(25, 20)
	check(sim.army.command(PackedInt32Array([ArmyState.TAG + left, ArmyState.TAG + right]), goal), "gemeinsames Ziel aus getrennten Höhlen")
	_army_ticks(sim, 100)
	check_eq(sim.army.cells[sim.army.slots[left]], sim.world.index(13, 20), "linker Krieger am nächsten erreichbaren Punkt")
	check_eq(sim.army.cells[sim.army.slots[right]], goal, "rechter Krieger erreicht das Ziel selbst")
	check_eq(sim.army.hp, PackedInt32Array([ArmyState.HEALTH, ArmyState.HEALTH]), "eigene Lebensleisten bleiben")
	check_eq(sim.world.mined_count, 0, "Krieger graben nicht")
	check_no_errors(sim.check_invariants(), "Belegung/Bilanzen")


func test_solid_and_fully_surrounded_goal_still_has_reachable_stand() -> void:
	var sim := _army_world()
	var uid := sim.army.add(sim.world.index(2, 2), 0)
	sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), sim.world.index(15, 20))
	_army_ticks(sim, 100)
	check_eq(sim.army.cells[0], sim.world.index(13, 20), "auch komplett ummauerter Zielblock wird angenähert")
	check(not sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), sim.world.cell_count()), "ungültiges Ziel abgelehnt")


func test_warrior_replans_after_breakthrough_and_survives_save_load() -> void:
	var sim := _army_world()
	var uid := sim.army.add(sim.world.index(2, 20), 0)
	var goal := sim.world.index(25, 20)
	sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), goal)
	_army_ticks(sim, 30)
	check_eq(sim.army.cells[0], sim.world.index(13, 20), "zuerst an der Wand")
	var restored := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(restored != null, "Warteposition mit ursprünglichem Ziel ladbar")
	if restored == null: return
	restored.army.reference_only = true
	for state in [sim, restored]:
		state.world.set_material(state.world.index(14, 20), Materials.EMPTY)
		state.world.set_material(state.world.index(15, 20), Materials.EMPTY)
	for tick in 32:
		_army_ticks(sim, 1)
		_army_ticks(restored, 1)
		check_eq(sim.state_hash(), restored.state_hash(), "Durchbruch nativ/Referenz nach Laden %d" % tick)
	check_eq(sim.army.cells[0], goal, "alter Auftrag läuft nach Durchbruch weiter")


func test_dark_goal_does_not_reveal_map_or_enemy_information() -> void:
	var sim := _army_world()
	var goal := sim.world.index(25, 20)
	sim.fog.setup(sim.world, 2)
	var before := sim.fog.snapshot()
	var uid := sim.army.add(sim.world.index(2, 20), 0)
	sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), goal)
	_army_ticks(sim, 30)
	check_eq(sim.army.cells[0], sim.world.index(13, 20), "Auftrag in schwarzen Nebel funktioniert")
	check(not sim.fog.is_explored(0, goal), "Ziel bleibt unerforscht")
	check_eq(sim.fog.snapshot(), before, "Wegsuche ändert keinerlei Sicht-/Erinnerungsdaten")


func test_many_warriors_share_one_route_and_keep_individual_damage() -> void:
	var sim := _army_world()
	sim.world.set_material(sim.world.index(3, 29), Materials.ROCK)
	var selected := PackedInt32Array()
	for y in range(2, 12):
		for x in range(2, 12): selected.append(ArmyState.TAG + sim.army.add(sim.world.index(x, y), 0))
	sim.army.command(selected, sim.world.index(25, 20))
	var backend := Backend.backend()
	var before: PackedInt64Array = backend.army_route_stats() if backend != null else PackedInt64Array([0, 0, 0, 0])
	_army_ticks(sim, 10)
	if backend != null:
		var after: PackedInt64Array = backend.army_route_stats()
		check_eq(after[2] - before[2], 1, "100 Krieger teilen genau einen nativen Feldaufbau")
	else:
		check_eq(sim.army.field_builds, 1, "100 Krieger teilen genau ein Referenzfeld")
	var victim := selected[3] - ArmyState.TAG
	sim.army._apply_damage(sim, {}, {victim: 3}, false)
	check_eq(sim.army.hp[sim.army.slots[victim]], ArmyState.HEALTH - 3, "Schaden gilt nur dem getroffenen Dot")
	check_eq(sim.army.hp[sim.army.slots[selected[4] - ArmyState.TAG]], ArmyState.HEALTH, "Nachbar bleibt unversehrt")
	check_no_errors(sim.check_invariants(), "keine überlappenden Dots")


func test_native_excavation_matches_reference_for_all_materials_and_targets() -> void:
	var backend := Backend.backend()
	if backend == null:
		check(true, "GDScript-only Installation")
		return
	check(backend.has_method("excavation_path"), "aktueller nativer Pfad verfügbar")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8403
	for scenario in 35:
		var world := WorldState.new(8, 8, 8, Materials.EMPTY)
		var targets := PackedByteArray()
		targets.resize(64)
		var blocked := targets.duplicate()
		for cell in 64:
			world.set_material(cell, rng.randi_range(0, Materials.COUNT - 1))
			if rng.randi_range(0, 5) == 0: targets[cell] = 1
			if rng.randi_range(0, 12) == 0: blocked[cell] = 1
		world.set_material(0, Materials.EMPTY)
		world.set_material(63, Materials.EMPTY)
		blocked[0] = 0
		var origins := PackedInt32Array([0, 63])
		var native_path := ExcavationPath.find(world, blocked, origins, targets)
		var reference := ExcavationPath.find(world, blocked, origins, targets, true)
		check_eq(native_path, reference, "identischer optimaler Pfad/Mehrfachziel %d" % scenario)
	check(backend.excavation_path(PackedByteArray([0]), PackedByteArray(), PackedInt32Array([0]), PackedByteArray(), PackedInt32Array(Materials.WORK), 1) == null, "fehlerhafte Zielmaske abgelehnt")


func test_many_disconnected_goals_match_reference_through_cache_eviction() -> void:
	var sim := _army_world()
	for y in range(2, 30):
		var uid := sim.army.add(sim.world.index(2, y), 0)
		sim.army.goals[sim.army.slots[uid]] = sim.world.index(25, y)
	var restored := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(restored != null, "getrennte Höhlen mit vielen Zielen ladbar")
	if restored == null: return
	restored.army.reference_only = true
	for tick in 32:
		_army_ticks(sim, 1)
		_army_ticks(restored, 1)
		check_eq(sim.state_hash(), restored.state_hash(), "getrennte Ziele nativ/Referenz %d" % tick)
	for cell in sim.army.cells: check_eq(cell % 32, 13, "jede Reihe erreicht ihre eigene nächste Wandposition")


func test_closing_a_passage_replaces_the_old_route_with_a_nearby_stand() -> void:
	var sim := _army_world()
	for x in [14, 15]: sim.world.set_material(sim.world.index(x, 20), Materials.EMPTY)
	var uid := sim.army.add(sim.world.index(2, 20), 0)
	sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), sim.world.index(25, 20))
	_army_ticks(sim, 4)
	check_eq(sim.army.cells[0], sim.world.index(4, 20), "anfangs auf offenem Weg")
	sim.world.set_material(sim.world.index(14, 20), Materials.INDESTRUCTIBLE)
	_army_ticks(sim, 32)
	check_eq(sim.army.cells[0], sim.world.index(13, 20), "nach Schließung neu berechneter Haltepunkt")
	check_eq(sim.army.goals[0], sim.world.index(25, 20), "ursprünglicher Auftrag bleibt erhalten")


func test_optional_resume_flags_preserve_old_saves_and_reject_wrong_types() -> void:
	var sim := _worker_world([5], [])
	var old := SaveGame.snapshot(sim)
	for row in old.resume.flow:
		row.erase("mining_first")
		row.erase("built_mining_first")
	var restored := SaveGame.from_snapshot(old)
	check(restored != null, "alter Version-2-Resume ohne neue Flags bleibt lesbar")
	if restored != null:
		for tick in 8:
			sim.tick_once()
			restored.tick_once()
			check_eq(sim.state_hash(), restored.state_hash(), "alter Stand setzt unveränderten Auftrag fort")
	for key in ["mining_first", "built_mining_first"]:
		var invalid := SaveGame.snapshot(sim)
		invalid.resume.flow[0][key] = "true"
		check(SaveGame.from_snapshot(invalid) == null, "falscher Bool-Typ %s abgelehnt" % key)


func test_building_click_chooses_nearest_side_instead_of_first_perimeter_cell() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 16
	config.initial_workers = 0
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	var site := sim.construction.initial(sim, world.index(5, 5), 0, true)
	check(site >= 0, "echter Kern mit unzerstörbarem Fundament")
	var row: Dictionary = sim.construction.sites.records[site]
	var rect: Rect2i = row.rect
	var center := world.index(rect.position.x + rect.size.x / 2, rect.position.y + rect.size.y / 2)
	var east := world.index(rect.end.x, center / world.width)
	var uid := sim.army.add(east + 3, 0)
	var hud := GameHud.new()
	hud.sim = sim
	hud.select_at(east + 3)
	check(hud.issue_march(center), "HUD-Marsch auf Gebäudezentrum")
	check_eq(sim.army.goals[0], center, "angeklicktes Ziel bleibt unverändert")
	_army_ticks(sim, 32)
	check_eq(sim.army.cells[sim.army.slots[uid]], east, "von Osten auf kürzestem freien Weg zur Ostseite")
	var before := sim.army.cells[0]
	_army_ticks(sim, 12)
	check_eq(sim.army.cells[0], before, "kein unnötiger Wechsel zu gleich nahem Nordrand")
	hud.free()

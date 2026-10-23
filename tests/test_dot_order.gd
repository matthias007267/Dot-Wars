extends TestCase
## Auswahl, Zehntel und der gemeinsame Marsch.


func test_highest_priority_kind_is_kept() -> void:
	var ids := PackedInt32Array([4, 7, 2])
	var kinds := PackedByteArray([DotOrder.KIND_WORKER, DotOrder.KIND_WARRIOR, DotOrder.KIND_WORKER])
	var kept := DotOrder.filter_highest(ids, kinds)
	check_eq(kept.size(), 1, "nur die höhere Fraktion")
	check_eq(kept[0], 7, "der Krieger")


func test_nearest_tenth_breaks_ties_by_id() -> void:
	var world := WorldState.new(20, 20, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	config.initial_workers = 10
	var starts := PackedInt32Array()
	for x in 10:
		starts.append(world.index(x, 1))
	var sim := Simulation.from_world(config, world, starts)
	var share := DotOrder.nearest_share(sim, 0, world.index(19, 1), Rect2i())
	check_eq(share.size(), 1, "zehn Arbeiter schicken einen")
	check_eq(sim.workers.cell[share[0]], world.index(9, 1), "der nächste")
	var five := DotOrder.nearest_share(sim, 0, world.index(0, 1), Rect2i())
	check_eq(sim.workers.cell[five[0]], world.index(0, 1), "am Ziel selbst")


func test_march_toward_a_sealed_cell_approaches() -> void:
	var world := WorldState.new(9, 5, 8, Materials.INDESTRUCTIBLE)
	world.carve_rect(Rect2i(1, 1, 7, 1))
	world.carve_rect(Rect2i(1, 3, 7, 1))
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add(world.index(1, 1), 0, 0)
	sim.initial_mass = 1
	sim.peak_mass = 1
	var hud := GameHud.new()
	hud.sim = sim
	var layer := Control.new()
	hud._build_stats(layer)
	var goal := world.index(7, 3)
	check(hud.issue_march(goal), "Marsch zur abgeschnittenen Zelle")
	check(hud._message.text.contains("nächstmöglichen"), "Hinweis nennt den nächsten Punkt")
	sim.run_ticks(10)
	check_eq(TestHelpers.worker_xy(sim, 0), Vector2i(7, 1), "so nah wie möglich")
	check_eq(sim.world.mined_count, 0, "unzerstörbare Wand bleibt")
	check_no_errors(sim.check_invariants(), "Bilanz")
	layer.free()
	hud.free()


func test_march_mines_the_rock_on_the_way() -> void:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	config.dig_power = 1000
	var sim := TestHelpers.sim_from_ascii([
		"#####",
		"#w#.#",
		"#####",
	], config)
	var hud := GameHud.new()
	hud.sim = sim
	var goal := sim.world.index(3, 1)
	check(hud.issue_march(goal), "Marsch durch die Wand")
	check(sim.areas.is_marked(sim.command_group, sim.world.index(2, 1)), "der Fels auf dem Weg")
	sim.tick_once()
	check_eq(sim.world.cells[sim.world.index(2, 1)], Materials.EMPTY, "der Fels ist weg")
	sim.run_ticks(6)
	check_eq(sim.workers.cell[0], goal, "am Ziel")
	check_eq(sim.world.mined_count, 1, "nur der Fels auf dem Weg")
	check_no_errors(sim.check_invariants(), "Bilanz")
	hud.free()


func test_selection_keeps_one_worker_and_ignores_the_rest() -> void:
	var hud := _hud_row()
	var sim := hud.sim
	hud.select_in_rect(Rect2i(8, 1, 1, 1))
	check_eq(hud.selection.size(), 1, "eine Zelle, ein Arbeiter")
	check_eq(sim.workers.cell[hud.selection[0]], sim.world.index(8, 1), "der getroffene")
	check(hud.issue_march(sim.world.index(12, 1)), "nur die Auswahl")
	check_eq(sim.workers.group_counts[sim.command_group], 1, "einer geht")
	check_eq(sim.workers.count - 1, _outside(sim), "die anderen bleiben")
	hud.free()


func test_war_order_does_not_move_workers() -> void:
	var hud := _hud_row()
	var layer := Control.new()
	hud._build_stats(layer)
	var before := hud.sim.workers.group.duplicate()
	check(not hud.issue_war(hud.sim.world.index(12, 1)), "keine Krieger")
	check(hud._message.text.contains("Krieger"), "Hinweis")
	check_eq(hud.sim.workers.group, before, "Arbeiter bleiben")
	layer.free()
	hud.free()


func test_command_group_survives_a_save() -> void:
	var hud := _hud_row()
	var goal := hud.sim.world.index(12, 1)
	check(hud.issue_march(goal), "Marsch")
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(hud.sim))
	check(restored != null, "Stand lesbar")
	if restored == null:
		return
	check_eq(restored.command_group, hud.sim.command_group, "Befehlsgruppe")
	check_eq(restored.march_cell, goal, "Marschziel")
	check_eq(restored.state_hash(), hud.sim.state_hash(), "gleicher Zustand")
	hud.free()


func _hud_row() -> GameHud:
	var world := WorldState.new(20, 20, 8, Materials.EMPTY)
	var config := TestHelpers.default_config()
	config.initial_workers = 10
	var starts := PackedInt32Array()
	for x in 10:
		starts.append(world.index(x, 1))
	var hud := GameHud.new()
	hud.sim = Simulation.from_world(config, world, starts)
	return hud


func _outside(sim: Simulation) -> int:
	var total := 0
	for id in sim.workers.count:
		if sim.workers.group[id] != sim.command_group:
			total += 1
	return total

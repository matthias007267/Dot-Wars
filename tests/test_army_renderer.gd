extends TestCase

func test_army_pixels_keep_palette_and_clear_vacated_cells() -> void:
	var config := SimConfig.new()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	var view := ArmyRenderer.new()
	view.sim = sim
	for owner in 4: sim.army.add(sim.world.index(10 + owner, 10), owner)
	var before := sim.state_hash()
	view.show_tick(0)
	for owner in 4:
		var cell := sim.world.index(10 + owner, 10)
		var expected := Color8(245, 78, 80) if owner == 0 else MatchRules.FACTION_COLORS[owner]
		check_eq(view._bytes[cell * 4], int(expected.r * 255), "Rotkanal")
		check_eq(view._bytes[cell * 4 + 1], int(expected.g * 255), "Grünkanal")
		check_eq(view._bytes[cell * 4 + 2], int(expected.b * 255), "Blaukanal")
		check_eq(view._bytes[cell * 4 + 3], 255, "Deckkraft")
	check_eq(sim.state_hash(), before, "Renderer ändert Simulation nicht")
	while sim.army.count > 0: sim.army.remove(sim.army.ids[0])
	view.show_tick(1)
	for owner in 4:
		var cell := sim.world.index(10 + owner, 10)
		check_eq(view._bytes[cell * 4 + 3], 0, "toter Krieger vollständig gelöscht")
	view.free()

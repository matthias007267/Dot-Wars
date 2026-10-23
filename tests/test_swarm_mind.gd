extends TestCase
## Schwarm-Intelligenz. Stufe 0 teilt sich das Ziel. Ab Stufe 1 sucht jeder Dot einen freien Fels.


func _lane() -> Simulation:
	var world := WorldState.new(9, 3, 8, Materials.EMPTY)
	world.set_material(world.index(0, 1), Materials.SOFT)
	world.set_material(world.index(8, 1), Materials.SOFT)
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.workers.add(world.index(2, 1), 0, 0)
	sim.workers.add(world.index(3, 1), 0, 0)
	sim.initial_mass = 2
	sim.peak_mass = 2
	sim.assign_cells(0, PackedInt32Array([world.index(0, 1), world.index(8, 1)]))
	return sim


func test_level_zero_shares_the_near_rock() -> void:
	var sim := _lane()
	sim.run_ticks(6)
	check(TestHelpers.worker_xy(sim, 0).x <= 2, "der vordere geht zum nahen Fels")
	check(TestHelpers.worker_xy(sim, 1).x <= 3, "der zweite folgt demselben Fels")
	check_eq(sim.workers.aim[0], WorkerStore.NO_TARGET, "Stufe 0 hat kein eigenes Ziel")
	check_eq(sim.workers.aim[1], WorkerStore.NO_TARGET, "auch der zweite nicht")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_a_stable_aim_keeps_its_step() -> void:
	var sim := _lane()
	sim.config.move_period_ticks = 100
	sim.upgrades.swarm_level = 1
	sim.tick_once()
	sim.tick_once()
	check(sim.workers.aim[0] >= 0, "der erste hat ein Ziel")
	check(sim.workers.aim[1] >= 0, "der zweite hat ein Ziel")
	var builds := SwarmMind.path_builds
	var step0 := sim.workers.aim_step[0]
	var step1 := sim.workers.aim_step[1]
	var home := sim.workers.cell[0]
	sim.run_ticks(3)
	check_eq(SwarmMind.path_builds, builds, "unveränderte Nachbarn suchen den Schritt nicht neu")
	check_eq(sim.workers.aim_step[0], step0, "der erste Schritt bleibt")
	check_eq(sim.workers.aim_step[1], step1, "der zweite Schritt bleibt")
	check_eq(sim.workers.cell[0], home, "er steht noch")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_level_one_sends_the_second_dot_to_a_free_rock() -> void:
	var sim := _lane()
	sim.upgrades.swarm_level = 1
	sim.tick_once()
	var near := sim.world.index(0, 1)
	var far := sim.world.index(8, 1)
	check_eq(sim.workers.aim[0], near, "der erste nimmt den nahen Fels")
	check_eq(sim.workers.aim[1], far, "der zweite nimmt den freien Fels")
	sim.run_ticks(6)
	check(TestHelpers.worker_xy(sim, 1).x >= 5, "er läuft zu seinem eigenen Fels")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_standing_too_long_picks_another_rock() -> void:
	var sim := _lane()
	sim.workers.remove_swap(1)
	sim.initial_mass = 1
	sim.peak_mass = 1
	sim.upgrades.swarm_level = 1
	var home := sim.workers.cell[0]
	sim.workers.aim[0] = sim.world.index(0, 1)
	sim.workers.idle_cell[0] = home
	sim.workers.idle_ticks[0] = SwarmMind.PATIENCE[1]
	sim.tick_once()
	check_eq(sim.workers.aim[0], sim.world.index(8, 1), "nach dem Warten kommt der andere Fels")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_a_boxed_dot_waits_for_a_free_neighbor() -> void:
	var world := WorldState.new(5, 5, 8, Materials.EMPTY)
	world.set_material(world.index(0, 0), Materials.SOFT)
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	var center := world.index(2, 2)
	sim.workers.add(center, 0, 0)
	for cell in [world.index(2, 1), world.index(3, 2), world.index(2, 3), world.index(1, 2)]:
		sim.workers.add(cell, 0, 0)
	sim.initial_mass = 5
	sim.peak_mass = 5
	sim.assign_cells(0, PackedInt32Array([world.index(0, 0)]))
	sim.upgrades.swarm_level = 2
	var rock := world.index(0, 0)
	sim.workers.aim[0] = rock
	sim.workers.idle_cell[0] = center
	sim.workers.idle_ticks[0] = 999
	sim.tick_once()
	check_eq(sim.workers.aim[0], rock, "eingekreist bleibt das alte Ziel")
	check_eq(sim.workers.cell[0], center, "er sucht nicht, solange alles voll ist")
	sim.workers.move_to(1, world.index(4, 4), 0)
	sim.workers.idle_ticks[0] = 999
	sim.workers.idle_cell[0] = center
	sim.tick_once()
	check(sim.workers.cell[0] != center, "eine freie Nachbarzelle gibt den nächsten Schritt frei")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_a_move_goal_keeps_the_shared_march() -> void:
	var sim := _lane()
	sim.upgrades.swarm_level = Upgrades.SWARM_MAX
	var goal := sim.world.index(5, 1)
	check(sim.set_move_goal(0, goal), "Laufziel")
	sim.run_ticks(8)
	check_eq(sim.workers.aim[0], WorkerStore.NO_TARGET, "das Laufziel hat kein eigenes Abbauziel")
	check_eq(sim.world.mined_count, 0, "unterwegs wird nicht abgebaut")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_swarm_upgrade_is_bought_and_saved() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 16
	var sim := Simulation.create(config)
	check(not sim.buy(Upgrades.KIND_SWARM), "ohne Energie kein Kauf")
	sim.upgrades.energy = 39
	check(not sim.buy(Upgrades.KIND_SWARM), "39 reichen nicht")
	sim.upgrades.energy = 40
	check(sim.buy(Upgrades.KIND_SWARM), "Stufe 1")
	check_eq(sim.upgrades.swarm_level, 1, "Stufe")
	check_eq(sim.upgrades.energy, 0, "bezahlt")
	check_eq(sim.upgrades.purchased, 1, "zählt als Fähigkeit")
	sim.upgrades.energy = 1000
	for _i in 3:
		check(sim.buy(Upgrades.KIND_SWARM), "weitere Stufe")
	check(not sim.buy(Upgrades.KIND_SWARM), "Stufe 4 ist voll")
	check_eq(sim.upgrades.swarm_level, Upgrades.SWARM_MAX, "Anschlag")
	sim.workers.aim[0] = sim.workers.cell[0]
	sim.workers.idle_ticks[0] = 7
	sim.workers.idle_cell[0] = sim.workers.cell[0]
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Stand lesbar")
	if restored == null:
		return
	check_eq(restored.upgrades.swarm_level, Upgrades.SWARM_MAX, "Stufe bleibt")
	check_eq(restored.workers.idle_ticks[0], 7, "Wartezeit bleibt")
	check_eq(restored.state_hash(), sim.state_hash(), "gleicher Zustand")
	var hud := GameHud.new()
	hud.sim = sim
	var layer := Control.new()
	hud._build_upgrade_panel(layer)
	hud._refresh_upgrades()
	var label := ""
	for index in hud._upgrade_kinds.size():
		if hud._upgrade_kinds[index] == Upgrades.KIND_SWARM:
			label = hud._upgrade_buttons[index].text
	check(label.contains("INTELLIGENZ"), "Knopf im Fähigkeiten-Fenster")
	check(label.contains("VOLL"), "volle Stufe")
	layer.free()
	hud.free()

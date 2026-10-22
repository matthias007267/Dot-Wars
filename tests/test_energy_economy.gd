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

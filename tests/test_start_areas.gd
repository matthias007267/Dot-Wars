extends TestCase
## Startlichtungen: kein Kreuz, genügend Randabstand und gleiche Bedingungen für alle Fraktionen.


func test_solo_start_has_a_small_rounded_clearing() -> void:
	for size in [16, 64, 256]:
		for seed in [3, 17]:
			var config := SimConfig.new()
			config.world_size = size
			config.world_seed = seed
			var sim := Simulation.create(config)
			check(sim != null, "Einzelspieler %d/%d startet" % [size, seed])
			if sim == null:
				continue
			var pit := WorldGenerator.sacrifice_cell(sim.world)
			_check_clearing(sim.world, pit, "Solo %d/%d" % [size, seed])
			check_eq(sim.workers.count, config.initial_workers, "Startarbeiter vorhanden")
			check_no_errors(sim.check_invariants(), "Solo-Invarianten")


func test_match_starts_have_room_and_equal_clearings() -> void:
	for size in [32, 64, 256]:
		for ai in [1, 2, 3]:
			var config := SimConfig.new()
			config.mode = SimConfig.MODE_MATCH
			config.world_size = size
			config.world_seed = 42
			config.ai_count = ai
			var sim := Simulation.create(config)
			check(sim != null, "Match %d/%d startet" % [size, ai])
			if sim == null:
				continue
			check_eq(sim.rules.cores.size(), ai + 1, "alle Fraktionen erhalten Kerne")
			var positions := {}
			for core in sim.rules.cores:
				var x: int = int(core) % size
				var y: int = int(core) / size
				var point := Vector2i(x, y)
				check(not positions.has(core), "Kerne eindeutig")
				positions[core] = true
				_check_clearing(sim.world, point, "Match %d/%d" % [size, ai])
				var radius := WorldGenerator.START_CLEARING_RADIUS
				var border: int = mini(mini(x - radius, size - 1 - x - radius), mini(y - radius, size - 1 - y - radius))
				check(border >= maxi(6, size / 6), "Basis mit Ausbauplatz: %d Zellen zum Rand" % border)
			check_no_errors(sim.check_invariants(), "Match-Invarianten")


func test_match_start_is_reproducible() -> void:
	var config := SimConfig.new()
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	config.world_size = 64
	config.world_seed = 771
	var first := Simulation.create(config)
	var second := Simulation.create(config)
	check(first != null and second != null, "beide Starts gültig")
	if first == null or second == null:
		return
	check_eq(first.rules.cores, second.rules.cores, "gleiche Kernpositionen")
	check_eq(first.world.cells, second.world.cells, "gleiche Welt")
	check_eq(first.state_hash(), second.state_hash(), "gleicher Simulationszustand")


func _check_clearing(world: WorldState, center: Vector2i, context: String) -> void:
	var radius := WorldGenerator.START_CLEARING_RADIUS
	var empty := 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := center.x + dx
			var y := center.y + dy
			check(world.in_bounds(x, y), "%s: Lichtung innerhalb der Karte" % context)
			if not world.in_bounds(x, y):
				continue
			var material := world.cells[world.index(x, y)]
			if dx == 0 and dy == 0:
				check_eq(material, Materials.INDESTRUCTIBLE, "%s: Kern" % context)
			elif absi(dx) == radius and absi(dy) == radius:
				check(material != Materials.EMPTY, "%s: Ecke bleibt Fels" % context)
			else:
				check_eq(material, Materials.EMPTY, "%s: Lichtung" % context)
				empty += 1
	check_eq(empty, 20, "%s: genau 20 freie Zellen" % context)

extends TestCase


func _config(size: int, world_seed: int) -> SimConfig:
	var config := SimConfig.new()
	config.world_size = size
	config.world_seed = world_seed
	return config


func test_same_seed_gives_identical_world() -> void:
	var a := WorldGenerator.generate(_config(128, 42))
	var b := WorldGenerator.generate(_config(128, 42))
	check_eq(a.cells, b.cells, "Zellen identisch")
	check_eq(a.state_hash(), b.state_hash(), "Hash identisch")


func test_different_seed_gives_different_world() -> void:
	var a := WorldGenerator.generate(_config(128, 42))
	var b := WorldGenerator.generate(_config(128, 43))
	check(a.cells != b.cells, "Andere Seeds erzeugen andere Welten")


func test_default_world_is_256_and_configurable() -> void:
	check_eq(SimConfig.new().world_size, 256, "Standardgröße")
	for size in [16, 64, 100, 300]:
		var world := WorldGenerator.generate(_config(size, 7))
		check_eq(world.width, size, "Breite")
		check_eq(world.height, size, "Höhe")
		check_eq(world.cells.size(), size * size, "Zellenzahl")


func test_three_materials_with_requested_hardness() -> void:
	var world := WorldGenerator.generate(_config(256, 1))
	var counts := PackedInt32Array([0, 0, 0, 0, 0])
	for c in world.cells:
		counts[c] += 1
	check(counts[Materials.SOFT] > 0 and counts[Materials.MEDIUM] > 0 and counts[Materials.HARD] > 0, "alle Materialien vorhanden")
	check(counts[Materials.INDESTRUCTIBLE] > 0, "unzerstörbare Zellen vorhanden")
	check_eq(Materials.hardness(Materials.SOFT), 1, "Härte weich")
	check_eq(Materials.hardness(Materials.MEDIUM), 3, "Härte mittel")
	check_eq(Materials.hardness(Materials.HARD), 8, "Härte hart")
	var solid := counts[1] + counts[2] + counts[3]
	check(absf(float(counts[Materials.SOFT]) / solid - 0.45) < 0.02, "Anteil weich ≈ 45 %")
	check(absf(float(counts[Materials.MEDIUM]) / solid - 0.35) < 0.02, "Anteil mittel ≈ 35 %")


func test_start_tunnel_is_connected_and_inside_world() -> void:
	var config := _config(256, 99)
	var world := WorldGenerator.generate(config)
	var center := world.index(128, 128)
	check_eq(world.cells[center], Materials.EMPTY, "Mitte ist leer")
	var tunnel_cells := 4 * config.tunnel_arm_length + 1
	check_eq(world.solid_count, 256 * 256 - tunnel_cells, "Nur der Tunnel ist leer")
	check_eq(TestHelpers.reachable_empty_cells(world, center), tunnel_cells, "Tunnel zusammenhängend")
	check_eq(world.mined_count, 0, "Aushub zählt nicht als Abbau")


func test_world_is_one_connected_solid_mass() -> void:
	var world := WorldGenerator.generate(_config(64, 5))
	var seen := {0: true}
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var c: int = stack.pop_back()
		for n in [c - 1 if c % 64 > 0 else -1, c + 1 if c % 64 < 63 else -1, c - 64, c + 64]:
			if n >= 0 and n < 64 * 64 and world.cells[n] != Materials.EMPTY and not seen.has(n):
				seen[n] = true
				stack.append(n)
	check_eq(seen.size(), world.solid_count, "Alle festen Zellen hängen zusammen")


func test_initial_workers_have_valid_distinct_positions() -> void:
	var sim := Simulation.create(_config(256, 3))
	check_eq(sim.workers.count, 5, "fünf Startarbeiter")
	var seen := {}
	for id in sim.workers.count:
		var c := sim.workers.cell[id]
		check_eq(sim.world.cells[c], Materials.EMPTY, "Startzelle leer")
		check(not seen.has(c), "Startzellen eindeutig")
		seen[c] = true
	check_no_errors(sim.check_invariants(), "Invarianten nach Start")


func test_config_validation() -> void:
	check(SimConfig.new().validate().is_empty(), "Standard ist gültig")
	var bad := SimConfig.new()
	bad.world_size = 4
	check(not bad.validate().is_empty(), "zu kleine Welt")
	bad = SimConfig.new()
	bad.group_quotas = PackedInt32Array([60, 30])
	check(not bad.validate().is_empty(), "Quotensumme ≠ 100")
	bad = SimConfig.new()
	bad.soft_percent = 70
	bad.medium_percent = 40
	check(not bad.validate().is_empty(), "Materialanteile > 100")
	check_eq(Simulation.create(bad), null, "Ungültige Konfiguration erzeugt keine Simulation")
	var args := SimConfig.from_cmdline(PackedStringArray(["--size=64", "--seed=9"]))
	check_eq(args.world_size, 64, "Größe aus Kommandozeile")
	check_eq(args.world_seed, 9, "Seed aus Kommandozeile")


func test_sacrifice_cell_is_unbreakable_and_next_to_the_tunnel() -> void:
	var world := WorldGenerator.generate(_config(256, 99))
	var pit := WorldGenerator.sacrifice_cell(world)
	var center := Vector2i(128, 128)
	check_eq(world.cells[world.index(center.x, center.y)], Materials.EMPTY, "Tunnelmitte bleibt leer")
	check_eq(world.cells[world.index(pit.x, pit.y)], Materials.INDESTRUCTIBLE, "Opferlochzelle")
	check_eq(absi(pit.x - center.x) + absi(pit.y - center.y), 2, "diagonal zur Mitte, nicht auf dem Kreuz")
	check_eq(world.cells[world.index(pit.x, pit.y - 1)], Materials.EMPTY, "orthogonal an den Tunnel angrenzend")
	check(not world.mine_cell(world.index(pit.x, pit.y)), "Abbau der Opferlochzelle scheitert")
	check_eq(world.cells[world.index(pit.x, pit.y)], Materials.INDESTRUCTIBLE, "Zelle bleibt")


func test_material_colors_are_distinct() -> void:
	check_eq(Materials.COLORS.size(), Materials.COUNT, "eine Farbe je Zustand")
	for a in Materials.COUNT:
		for b in range(a + 1, Materials.COUNT):
			var left := Materials.COLORS[a]
			var right := Materials.COLORS[b]
			var distance := absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)
			check(distance > 0.25, "Farbe %d und %d sind getrennt (%.2f)" % [a, b, distance])
	var backdrop := Materials.BACKDROP
	var tunnel := Materials.COLORS[Materials.EMPTY]
	var separated := absf(backdrop.r - tunnel.r) + absf(backdrop.g - tunnel.g) + absf(backdrop.b - tunnel.b)
	check(separated > 0.08, "Tunnel hebt sich vom Hintergrund ab")


func test_material_colors_match_the_premium_palette() -> void:
	var expected := [
		[0x16, 0x1C, 0x24],
		[0x57, 0xC9, 0x6D],
		[0xD3, 0x82, 0x2C],
		[0x5C, 0x86, 0xDB],
		[0x39, 0x3F, 0x49],
	]
	var bytes := WorldRenderer.palette_bytes()
	for material in Materials.COUNT:
		var offset := material * 4
		check_eq(int(bytes[offset]), expected[material][0], "Rot %d" % material)
		check_eq(int(bytes[offset + 1]), expected[material][1], "Grün %d" % material)
		check_eq(int(bytes[offset + 2]), expected[material][2], "Blau %d" % material)
	check_eq(WorldRenderer._channel(Materials.PIT_COLOR.r), 0xC7, "Opferloch Rot")
	check_eq(WorldRenderer._channel(Materials.PIT_COLOR.g), 0x7A, "Opferloch Grün")
	check_eq(WorldRenderer._channel(Materials.PIT_COLOR.b), 0xFF, "Opferloch Blau")
	check_eq(WorldRenderer._channel(Materials.BACKDROP.r), 0x0D, "Hintergrund")


func test_standard_and_target_world_sizes() -> void:
	for size in [500, 1000]:
		var started := Time.get_ticks_usec()
		var world := WorldGenerator.generate(_config(size, 11))
		var elapsed := (Time.get_ticks_usec() - started) / 1000.0
		check_eq(world.width, size, "Breite %d" % size)
		check_eq(world.cells.size(), size * size, "Zellen %d" % size)
		check_eq(world.cells[world.index(size / 2, size / 2)], Materials.EMPTY, "Starttunnel %d" % size)
		var pit := WorldGenerator.sacrifice_cell(world)
		check_eq(world.cells[world.index(pit.x, pit.y)], Materials.INDESTRUCTIBLE, "Opferloch %d" % size)
		var again := WorldGenerator.generate(_config(size, 11))
		check_eq(again.state_hash(), world.state_hash(), "gleicher Seed %d" % size)
		print("Welt %d erzeugt in %.0f ms" % [size, elapsed])


func test_mined_fraction_ignores_unbreakable_cells() -> void:
	var world := WorldState.new(2, 1, 8, Materials.SOFT)
	world.set_material(1, Materials.INDESTRUCTIBLE)
	check(world.mine_cell(0), "weiche Zelle")
	check_eq(world.mined_fraction(), 1.0, "nur abbaubare Zellen zählen")
	check_eq(world.indestructible_count, 1, "unzerstörbar bleibt")

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


func test_new_world_uses_stone_sparse_ores_and_permanent_obstacles() -> void:
	var totals := PackedInt32Array()
	totals.resize(Materials.COUNT)
	for seed_value in range(20):
		var world := WorldGenerator.generate(_config(128, seed_value))
		for material in world.cells: totals[material] += 1
		check_eq(world.mined_count, 0, "Generator zahlt keinen Abbau aus")
		check(not world.excavated.has(1), "Generatorhöhlen sind ursprünglich frei")
	check(totals[Materials.ROCK] > totals[Materials.EMPTY], "gewöhnliches Gestein bleibt Hauptanteil")
	check(totals[Materials.EMPTY] > 0 and totals[Materials.INDESTRUCTIBLE] > 0, "Tunnel und dauerhafte Struktur")
	check(totals[Materials.COPPER] > totals[Materials.IRON], "Kupfer häufiger als Eisen")
	check(totals[Materials.IRON] > totals[Materials.GOLD], "wertvollere Erze seltener")
	check(totals[Materials.GOLD] > totals[Materials.TITANIUM], "Titan deutlich seltener")
	check_eq(totals[Materials.MEDIUM] + totals[Materials.HARD], 0, "Altmaterialien werden nicht neu generiert")

func test_solo_tunnel_system_is_connected_and_not_counted_as_mining() -> void:
	var world := WorldGenerator.generate(_config(64, 99))
	var center := world.index(32, 32)
	check_eq(world.cells[center], Materials.EMPTY, "Startzentrum frei")
	var free := world.cell_count() - world.solid_count
	check(free > 20, "freie Gänge gehen über alte Startlichtung hinaus")
	check_eq(TestHelpers.reachable_empty_cells(world, center), free, "gesamtes freies Solonetz erreichbar")
	check_eq(world.mined_count, 0, "Generation ist kein Abbau")

func test_permanent_structure_survives_mining() -> void:
	var world := WorldGenerator.generate(_config(64, 5))
	var permanent := world.indestructible_count
	for cell in world.cell_count():
		if Materials.is_mineable(world.cells[cell]): world.mine_cell(cell)
	check_eq(world.solid_count, permanent, "nur die dauerhafte Karte bleibt")
	check_eq(world.indestructible_count, permanent, "kein Obsidian verschwindet")


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


func test_sacrifice_cell_is_unbreakable_and_inside_the_clearing() -> void:
	var world := WorldGenerator.generate(_config(256, 99))
	var pit := WorldGenerator.sacrifice_cell(world)
	var center := Vector2i(128, 128)
	check_eq(world.cells[world.index(center.x, center.y)], Materials.EMPTY, "Weltmitte bleibt frei")
	check_eq(world.cells[world.index(pit.x, pit.y)], Materials.INDESTRUCTIBLE, "Opferlochzelle")
	check_eq(absi(pit.x - center.x) + absi(pit.y - center.y), 2, "Energiekern bleibt an der bisherigen Position")
	check_eq(world.cells[world.index(pit.x, pit.y - 1)], Materials.EMPTY, "orthogonal an die Lichtung angrenzend")
	check(not world.mine_cell(world.index(pit.x, pit.y)), "Abbau der Opferlochzelle scheitert")
	check_eq(world.cells[world.index(pit.x, pit.y)], Materials.INDESTRUCTIBLE, "Zelle bleibt")


func test_material_colors_are_distinct() -> void:
	check_eq(Materials.COLORS.size(), Materials.COUNT, "eine Farbe je Zustand")
	for a in Materials.COUNT:
		for b in range(a + 1, Materials.COUNT):
			var left := Materials.COLORS[a]
			var right := Materials.COLORS[b]
			var distance := absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)
			check(distance > 0.02, "Farbe %d und %d sind getrennt (%.2f)" % [a, b, distance])
	var backdrop := Materials.BACKDROP
	var tunnel := Materials.COLORS[Materials.EMPTY]
	var separated := absf(backdrop.r - tunnel.r) + absf(backdrop.g - tunnel.g) + absf(backdrop.b - tunnel.b)
	check(separated > 0.08, "Tunnel hebt sich vom Hintergrund ab")


func test_material_colors_match_the_premium_palette() -> void:
	var expected := [
		[0x16, 0x1C, 0x24],
		[0x5F, 0x6B, 0x78],
		[0xD3, 0x82, 0x2C],
		[0x5C, 0x86, 0xDB],
		[0x39, 0x3F, 0x49],
		[0xb9,0x6b,0x36], [0x8e,0x92,0x9b], [0xd9,0xe1,0xef], [0xe8,0xbc,0x39],
		[0x27,0x4d,0xe0], [0x22,0xae,0x78], [0xab,0x87,0xcb], [0x63,0xe0,0xf0],
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
		check_eq(world.cells[world.index(size / 2, size / 2)], Materials.EMPTY, "Startlichtung %d" % size)
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

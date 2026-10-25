extends TestCase


func test_screen_and_world_roundtrip() -> void:
	var viewport := Vector2(200, 100)
	var camera := Vector2(50, 40)
	var zoom := 2.0
	var screen := Vector2(120, 70)
	var world := WorldCoordinates.screen_to_world(screen, camera, zoom, viewport)
	var back := WorldCoordinates.world_to_screen(world, camera, zoom, viewport)
	check(back.distance_to(screen) < 0.001, "Bildschirm bleibt stabil")
	var center := WorldCoordinates.screen_to_world(viewport * 0.5, camera, zoom, viewport)
	check(center.distance_to(camera) < 0.001, "Bildmitte ist die Kameraposition")


func test_cell_mapping_stays_inside_the_world() -> void:
	check_eq(WorldCoordinates.world_to_cell(Vector2(3.2, 4.9), 10, 10), Vector2i(3, 4), "Zelle")
	check_eq(WorldCoordinates.world_to_cell(Vector2(-0.1, 1), 10, 10), Vector2i(-1, -1), "links außerhalb")
	check_eq(WorldCoordinates.world_to_cell(Vector2(10, 1), 10, 10), Vector2i(-1, -1), "rechter Rand gehört nicht mehr dazu")
	check_eq(WorldCoordinates.cell_origin(Vector2i(3, 4)), Vector2(3, 4), "Ursprung")


func test_fit_zoom_for_the_supported_world_sizes() -> void:
	var full_hd := Vector2(1920, 1080)
	var hd := Vector2(1280, 720)
	check(WorldCoordinates.fit_zoom(Vector2(256, 256), full_hd) > 3.5, "256 auf 1080p")
	check(WorldCoordinates.fit_zoom(Vector2(500, 500), full_hd) > 1.8, "500 auf 1080p")
	check(WorldCoordinates.fit_zoom(Vector2(1000, 1000), full_hd) > 0.9, "1000 auf 1080p")
	check(WorldCoordinates.fit_zoom(Vector2(256, 256), hd) < WorldCoordinates.fit_zoom(Vector2(256, 256), full_hd), "kleineres Fenster zoomt weiter heraus")


func test_visible_rect_follows_the_camera() -> void:
	var rect := WorldCoordinates.visible_world_rect(Vector2(100, 80), 4.0, Vector2(80, 40))
	check_eq(rect.size, Vector2(20, 10), "sichtbare Weltgröße")
	check(rect.has_point(Vector2(100, 80)), "Kamera liegt in der Sicht")


func test_pixels_use_the_material_colors() -> void:
	var world := WorldGenerator.generate(SimConfig.new())
	var palette := WorldRenderer.palette_bytes()
	var bytes := PackedByteArray()
	bytes.resize(world.cell_count() * 4)
	var pit := WorldGenerator.sacrifice_cell(world)
	var pit_index := world.index(pit.x, pit.y)
	WorldRenderer.paint_all(bytes, world, palette, pit_index)
	var image := Image.create_from_data(world.width, world.height, false, Image.FORMAT_RGBA8, bytes)
	var pit_pixel := image.get_pixel(pit.x, pit.y)
	var pit_distance := absf(pit_pixel.r - Materials.PIT_COLOR.r) + absf(pit_pixel.g - Materials.PIT_COLOR.g) + absf(pit_pixel.b - Materials.PIT_COLOR.b)
	check(pit_distance < 0.02, "Opferloch hebt sich ab (Abstand %.3f)" % pit_distance)
	_check_pixel(image, Vector2i(world.width / 2, world.height / 2), Materials.EMPTY, "Tunnel")
	var seen := {}
	for idx in world.cell_count():
		if idx == pit_index:
			continue
		seen[world.cells[idx]] = Vector2i(idx % world.width, idx / world.width)
		if seen.size() == Materials.COUNT:
			break
	for material in seen:
		_check_pixel(image, seen[material], material, "Material %d" % material)


func test_core_plaza_is_tinted_and_the_pit_stays_bright() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := TestHelpers.legacy_core_sim(config)
	sim.upgrades.energy = 40
	check(sim.buy(Upgrades.KIND_CORE), "Kernkauf")
	var palette := WorldRenderer.palette_bytes()
	var bytes := PackedByteArray()
	bytes.resize(sim.world.cell_count() * 4)
	var pit := WorldGenerator.sacrifice_cell(sim.world)
	var pit_index := sim.pit_index()
	WorldRenderer.paint_all(bytes, sim.world, palette, pit_index, sim.core_mask)
	var image := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, bytes)
	_check_color(image, pit, Materials.PIT_COLOR, "Kern bleibt hell")
	var plaza := Vector2i(-1, -1)
	for idx in sim.core_mask.size():
		if sim.core_mask[idx] == 1 and sim.world.cells[idx] == Materials.EMPTY:
			plaza = Vector2i(idx % sim.world.width, idx / sim.world.width)
			break
	check(plaza.x >= 0, "eine freie Kernzelle")
	_check_color(image, plaza, Materials.PLAZA_COLOR, "Kernfläche")
	var outside := Vector2i(pit.x - 2, pit.y - 1)
	check_eq(sim.core_mask[sim.world.index(outside.x, outside.y)], 0, "die äußere Lichtung bleibt frei")
	_check_color(image, outside, Materials.COLORS[Materials.EMPTY], "Lichtung außerhalb")
	var chunk_id := (plaza.y / sim.world.chunk_size) * sim.world.chunks_x + plaza.x / sim.world.chunk_size
	WorldRenderer.paint_rect(bytes, sim.world, palette, sim.world.chunk_rect(chunk_id), pit_index, sim.core_mask)
	var repainted := Image.create_from_data(sim.world.width, sim.world.height, false, Image.FORMAT_RGBA8, bytes)
	_check_color(repainted, plaza, Materials.PLAZA_COLOR, "Chunk-Nachmalung behält die Fläche")


func test_chunk_repaint_leaves_other_chunks_unchanged() -> void:
	var world := WorldState.new(64, 64, 32, Materials.SOFT)
	var palette := WorldRenderer.palette_bytes()
	var bytes := PackedByteArray()
	bytes.resize(world.cell_count() * 4)
	WorldRenderer.paint_all(bytes, world, palette)
	var untouched := world.index(1, 1)
	var before := bytes[untouched * 4]
	var changed := world.index(40, 5)
	world.set_material(changed, Materials.HARD)
	WorldRenderer.paint_rect(bytes, world, palette, world.chunk_rect(1))
	check_eq(bytes[untouched * 4], before, "anderer Chunk bleibt")
	var variance := WorldRenderer.material_variation(changed, Materials.HARD)
	check_eq(bytes[changed * 4], clampi(int(palette[Materials.HARD * 4]) + variance, 0, 255), "geänderte Zelle")
	check_eq(bytes[changed * 4 + 2], clampi(int(palette[Materials.HARD * 4 + 2]) + variance, 0, 255), "Blaukanal")


func _check_color(image: Image, cell: Vector2i, expected: Color, label: String) -> void:
	var pixel := image.get_pixel(cell.x, cell.y)
	var distance := absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b)
	check(distance < 0.02, "%s Farbe (Abstand %.3f)" % [label, distance])


func _check_pixel(image: Image, cell: Vector2i, material: int, label: String) -> void:
	var pixel := image.get_pixel(cell.x, cell.y)
	var expected := Materials.COLORS[material]
	var distance := absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b)
	var tolerance := 0.085 if Materials.is_mineable(material) else 0.02
	check(distance < tolerance, "%s Farbe (Abstand %.3f)" % [label, distance])


func test_material_variation_is_bounded_and_reproducible() -> void:
	for material in [Materials.SOFT, Materials.MEDIUM, Materials.HARD]:
		for index in [0, 17, 1024, 65535, 999999]:
			var a := WorldRenderer.material_variation(index, material)
			var b := WorldRenderer.material_variation(index, material)
			check_eq(a, b, "Zellvariation deterministisch")
			check(a >= -6 and a <= 6, "Variation bleibt subtil")

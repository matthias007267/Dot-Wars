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
	check_eq(bytes[changed * 4], palette[Materials.HARD * 4], "geänderte Zelle")
	check_eq(bytes[changed * 4 + 2], palette[Materials.HARD * 4 + 2], "Blaukanal")


func _check_pixel(image: Image, cell: Vector2i, material: int, label: String) -> void:
	var pixel := image.get_pixel(cell.x, cell.y)
	var expected := Materials.COLORS[material]
	var distance := absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b)
	check(distance < 0.02, "%s Farbe (Abstand %.3f)" % [label, distance])

extends SceneTree
var failures: Array[String] = []
var game: Node

func _init() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("FOG DEPTH ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func pixel(image: Image, world: Vector2) -> Color:
	var p: Vector2 = game.get_viewport().get_canvas_transform() * world
	return image.get_pixel(clampi(int(p.x), 0, image.get_width() - 1), clampi(int(p.y), 0, image.get_height() - 1))

func brightness(color: Color) -> float: return color.r + color.g + color.b

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.debug_modified = true
	sim.upgrades.energy = 1000
	for group in sim.group_open.size(): sim.clear_area(group)
	for y in range(36, 56):
		for x in range(49, 59): sim.world.set_material(sim.world.index(x, y), Materials.ROCK if x % 3 != 0 else Materials.COPPER)
	var concealed := sim.world.index(53, 44)
	sim.world.set_material(concealed, Materials.EMPTY)
	sim.army.add(concealed, 1)
	sim.energy_dots.enqueue(concealed, 1, 1)
	# Genuine exploration followed by loss of sight, without an all-map reveal.
	sim.world.set_material(sim.world.index(32, 27), Materials.ROCK)
	var scout := sim.army.add(sim.world.index(34, 27), 0)
	sim.fog.update(sim)
	sim.army.remove(scout)
	var site: int = sim.construction.place(sim, 3, sim.world.index(44, 43), PackedInt32Array(), 0)
	check(site >= 0, "idle building fixture")
	if site < 0:
		quit(1)
		return
	sim.construction.sites.contribute(site, 0, 300)
	sim.fog.update(sim)
	check(sim.fog.is_visible(0, sim.world.index(52, 44)), "fourth obstacle field visible")
	check(not sim.fog.is_visible(0, concealed), "fifth field hidden, including a free gap")
	check(sim.fog.is_explored(0, sim.world.index(32, 27)) and not sim.fog.is_visible(0, sim.world.index(32, 27)), "genuine remembered terrain")
	var base := 0.0
	for source in CavernLighting.sources(sim):
		if source.cell == sim.construction.center(site): base = source.strength
	check(base > 0 and not sim.research.is_powered(site, sim.tick_count), "idle research center emits base light")
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	game.camera.zoom = Vector2.ONE * 32
	game.camera.position = Vector2(40, 40)
	game.hud.select_at(sim.construction.center(site))
	game.hud._message.text = "NEBEL · Gebäude mit Grundlicht · vier Felder ab der ersten Barriere · erkundete Flächen bleiben heller sichtbar"
	var before := sim.state_hash()
	# Allow the existing throttled light-map refresh to run once while paused.
	await create_timer(0.25).timeout
	var brighter := await frame()
	check(brighter.save_png("/tmp/fog-four-cells.png") == OK, "screenshot own light and four-cell boundary")
	check(brightness(pixel(brighter, Vector2(53.5, 44.5))) < 0.005, "unexplored fifth cell renders black without hidden dots")
	check(brightness(pixel(brighter, Vector2(52.5, 44.5))) > 0.05, "fourth resource layer is rendered")
	check(game.energy_view._bytes[concealed * 4 + 3] == 0, "hidden energy has no sprite or halo")
	for chunk in game.fog_view._chunks:
		chunk.material.set_shader_parameter("ambient_multiplier", 0.38)
	var previous := await frame()
	check(previous.save_png("/tmp/fog-memory-before.png") == OK, "screenshot previous memory shade")
	var old_light := brightness(pixel(previous, Vector2(32.5, 27.5)))
	var new_light := brightness(pixel(brighter, Vector2(32.5, 27.5)))
	check(new_light > old_light + 0.02, "actual remembered terrain is brighter")
	for chunk in game.fog_view._chunks:
		chunk.material.set_shader_parameter("ambient_multiplier", FogOverlay.MEMORY_SHADE)
	var restored := await frame()
	check(restored.save_png("/tmp/fog-memory-after.png") == OK, "screenshot brighter memory")
	check(sim.state_hash() == before, "drawing does not change simulation or knowledge")
	print("FOG DEPTH SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

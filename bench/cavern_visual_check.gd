extends SceneTree
## Deterministic art-review fixture only: terrain carving/resources are not game rules.
var game: Node
var sim: Simulation
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	print("CAVERN ", "OK " if ok else "FAIL ", message)
	if not ok: failures.append(message)

func _road(a: Vector2i, b: Vector2i, width := 4) -> void:
	sim.world.carve_rect(Rect2i(mini(a.x, b.x) - width / 2, a.y - width / 2, absi(a.x - b.x) + width, width))
	sim.world.carve_rect(Rect2i(b.x - width / 2, mini(a.y, b.y) - width / 2, width, absi(a.y - b.y) + width))

func _site(kind: int, pos: Vector2i, owner := 0) -> int:
	sim.world.carve_rect(Rect2i(pos - Vector2i(2, 2), Vector2i(7, 7)))
	var id := sim.construction.place(sim, kind, sim.world.index(pos.x, pos.y), PackedInt32Array(), owner)
	check(id >= 0, "fixture site %d" % kind)
	if id >= 0: sim.construction.sites.contribute(id, owner, 300)
	return id

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/cavern-" + label + ".png") == OK, "screenshot " + label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.world_seed = 17
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	sim = Simulation.create(config)
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 3200
	sim.rules.wallet(sim, 1).energy = 3200
	sim.debug_mode = false
	sim.debug_modified = true
	sim.construction.outposts_unlocked = true
	sim.construction.interceptors_unlocked = true
	_road(Vector2i(12, 32), Vector2i(23, 20))
	_road(Vector2i(23, 20), Vector2i(36, 26))
	_road(Vector2i(36, 26), Vector2i(42, 19))
	_road(Vector2i(51, 32), Vector2i(52, 15))
	_road(Vector2i(36, 26), Vector2i(51, 32))
	_road(Vector2i(12, 32), Vector2i(8, 41))
	var research := _site(3, Vector2i(22, 17))
	var outpost := _site(1, Vector2i(34, 25))
	var station := _site(2, Vector2i(40, 17))
	var enemy := _site(1, Vector2i(51, 16), 1)
	if research < 0 or outpost < 0 or station < 0 or enemy < 0:
		quit(1)
		return
	for site in [research, outpost, station]:
		var path := sim.energy_network.plan_connection(sim, 0, 0, site)
		sim.energy_network.place_path(sim, 0, path)
	var enemy_path := sim.energy_network.plan_connection(sim, 1, 1, enemy)
	sim.energy_network.place_path(sim, 1, enemy_path)
	for row in sim.construction.sites.records:
		sim.construction._ground(sim, row.rect, Materials.INDESTRUCTIBLE)
	var selected := PackedInt32Array()
	for y in range(18, 40, 3):
		for x in range(7, 48, 3):
			var cell := sim.world.index(x, y)
			if sim.workers.count >= 32 or sim.world.cells[cell] != Materials.EMPTY or not sim.workers.is_free(cell): continue
			var id := sim.workers.add(cell, 0, 0)
			if selected.size() < 7: selected.append(id)
	sim.initial_mass = sim.workers.mass_sum()
	for x in range(39, 48):
		var cell := sim.world.index(x, 31)
		if sim.world.cells[cell] == Materials.EMPTY and sim.workers.is_free(cell): sim.army.add(cell, 1)
	for x in range(30, 38):
		var cell := sim.world.index(x, 28)
		if sim.world.cells[cell] == Materials.EMPTY and sim.workers.is_free(cell): sim.army.add(cell, 0)
	sim.upgrades.dig_level = 4
	check(sim.research.start(sim, 0, research, "speed"), "real research job")
	sim.run_ticks(32)
	sim.picked = selected
	sim.construction.selected = research
	sim.fog.update(sim)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	game.camera.zoom = Vector2.ONE * 28.0
	game.camera.position = Vector2(32, 26)
	await create_timer(0.4).timeout
	var before := sim.state_hash()
	game.hud.refresh()
	check(game.hud._bottom_strip.get_global_rect().position.y > root.size.y * 0.65, "HUD reserved to bottom")
	check(game.hud._map != null, "minimap integrated")
	check(game.hud._selection_caption.text.contains(str(selected.size())), "selection portraits bound to actual selection")
	await _capture("overview")
	game.hud._toggle_upgrades()
	await _capture("research")
	game.hud._toggle_upgrades()
	check(sim.state_hash() == before, "drawing and HUD do not mutate simulation")
	# Camera/zoom and minimap navigation remain functional with the bottom strip.
	var original: Vector2 = game.camera.position
	game.camera.focus_world(Vector2(40, 25))
	check(game.camera.position != original, "camera navigation")
	game.camera.zoom = Vector2.ONE * 40
	await _capture("detail")
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	game.hud._resize_hud()
	await process_frame
	var compact: Rect2 = game.hud._bottom_strip.get_global_rect()
	check(compact.end.x <= root.size.x + 1 and compact.end.y <= root.size.y + 1, "dock fits 1280x720")
	await _capture("compact")
	print("CAVERN SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

extends SceneTree
var failures: Array[String] = []
var game: Node
var sim: Simulation

func _init() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("HUD REF ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/hud-" + name + ".png") == OK, "screenshot " + name)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 2
	config.initial_workers = 1
	sim = Simulation.create(config)
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.army.teams[2] = 0
	sim.rules.hill_score[2] = 60
	sim.upgrades.energy = 5000
	for group in sim.group_open.size(): sim.clear_area(group)
	sim.world.carve_rect(Rect2i(9, 22, 20, 14))
	var research: int = sim.construction.place(sim, 3, sim.world.index(22, 24), PackedInt32Array(), 0)
	check(research >= 0, "research fixture placed")
	if research < 0:
		quit(1)
		return
	sim.construction.sites.contribute(research, 0, 300)
	var path := sim.energy_network.plan_connection(sim, 0, 0, research)
	sim.energy_network.place_path(sim, 0, path)
	check(sim.research.start(sim, 0, research, "dig"), "real research started")
	sim.run_ticks(40)
	var construction: int = sim.construction.place(sim, 3, sim.world.index(26, 32), PackedInt32Array(), 0)
	check(construction >= 0, "construction fixture placed")
	if construction >= 0: sim.construction.sites.contribute(construction, 0, 75)
	check(sim.buy_worker(0), "real worker purchase queued")
	check(sim.buy_warrior(0, 0) and sim.buy_warrior(0, 0), "real warrior production queued")
	sim.fog.update(sim)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	game.camera.position = Vector2(30, 28)
	game.camera.zoom = Vector2.ONE * 16
	var worker := -1
	for id in sim.workers.count:
		if sim.workers.faction[id] == 0:
			worker = id
			break
	game.hud.select_at(sim.workers.cell[worker])
	game.hud.refresh()
	check(game.hud._research_center_button.visible and not game.hud._buy_worker_button.visible, "worker actions only")
	check(game.hud._task_icons.size() == 4, "global icon overview of four own task groups")
	for icon in game.hud._task_icons: check(icon.text.is_empty() and icon.icon != null, "global task is icon only")
	check(game.hud._team_labels[1].visible and not game.hud._team_labels[2].visible, "own player and ally only")
	var before := sim.state_hash()
	await capture("workers")
	game.hud._research_center_button.mouse_entered.emit()
	check(game.hud._info_description.text.contains("300"), "hover explains actual action in info panel")
	await capture("hover")
	game.hud._research_center_button.mouse_exited.emit()
	game.hud.select_at(sim.construction.center(0))
	check(game.hud._buy_worker_button.visible and game.hud._buy_warrior_button.visible, "selected core production")
	check(not game.hud._research_center_button.visible, "core hides worker construction")
	await capture("core")
	game.hud.select_at(sim.construction.center(research))
	check(game.hud._context_buttons.technology.visible and not game.hud._buy_warrior_button.visible, "selected research center context")
	await capture("research")
	game.hud._toggle_orders()
	await capture("orders")
	check(game.hud._order_buttons.size() == 4, "full own task overview")
	game.hud._toggle_orders()
	check(sim.state_hash() == before, "HUD layout, hover and panels preserve simulation")
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	game.hud._resize_hud()
	await process_frame
	var left: Rect2 = game.hud._bottom_strip.get_global_rect()
	var map: Rect2 = game.hud._map_slot.get_global_rect()
	var stats: Rect2 = game.hud._stats_slot.get_global_rect()
	var menu: Rect2 = game.hud._top_menu.get_global_rect()
	check(not left.intersects(map), "bottom panels do not overlap at 1280x720")
	check(not stats.intersects(menu), "top bars do not overlap at 1280x720")
	check(left.end.y <= 720 and map.end.x <= 1280 and map.end.y <= 720, "panels stay inside viewport")
	check(map.position.x > 1280 * 0.7 and stats.position.y < 60, "reference corner placement")
	await capture("compact")
	print("HUD REF SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

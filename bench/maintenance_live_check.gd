extends "res://bench/live_benchmark.gd"

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var capture_dir := "res://bench/results/maintenance"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.substr(14)
	if DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		quit(2)
		return
	var config := SimConfig.new()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 8
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.debug_mode = true
	sim.debug_modified = true
	sim.army.teams[1] = 0 # Keep the diagnostic focused on maintenance rather than winning combat.
	sim.upgrades.energy = 5000
	sim.rules.wallet(sim, 1).energy = 250
	sim.upgrades.swarm_level = 4
	sim.construction.damage(sim, 0, 200)
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var app := BenchApp.new()
	root.add_child(app)
	app._attach(sim)
	app.camera.position = Vector2(30, 30)
	app.camera.zoom = Vector2(11, 11)
	app.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.camera.set_process_unhandled_input(false)
	app.hud._unlock_outposts()
	var ids := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.faction[id] == 0: ids.append(id)
	app.hud._set_selection(ids)
	app.hud.select_at(sim.rules.cores[0])
	app.hud._repair_selected()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("repair.png"))
	app.hud._set_selection(PackedInt32Array())
	app.hud._begin_settlement(1)
	var placed := app.hud.issue_build(22 * 64 + 25)
	var plan: int = sim.construction.at(22 * 64 + 25)
	if not placed or plan < 0:
		printerr("MAINTENANCE_GRAPHIC: placement failed")
		quit(1)
		return
	app.hud.select_at(22 * 64 + 25)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("cancel.png"))
	var before := sim.upgrades.energy
	app.hud._cancel_selected()
	var cancelled: bool = not sim.construction.sites.valid(plan) and sim.upgrades.energy == before + 200
	await create_timer(25.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("finished.png"))
	var errors := sim.check_invariants()
	var repaired: bool = sim.construction.sites.records[0].hp == 600
	var ai_ready: int = sim.construction.sites.count(1, 1, 4)
	print("MAINTENANCE_GRAPHIC ", {"repaired": repaired, "cancelled": cancelled, "ai_ready": ai_ready, "tick": sim.tick_count, "errors": errors})
	quit(0 if repaired and cancelled and ai_ready == 1 and errors.is_empty() else 1)

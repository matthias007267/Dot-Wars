extends "res://bench/live_benchmark.gd"

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var capture_dir := "res://bench/results/construction"
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
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.debug_mode = true
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 5000
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var app := BenchApp.new()
	root.add_child(app)
	app._attach(sim)
	app.camera.position = Vector2(25, 28)
	app.camera.zoom = Vector2(13, 13)
	app.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.camera.set_process_unhandled_input(false)
	app.hud._unlock_outposts()
	var ids := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.faction[id] == 0: ids.append(id)
	app.hud._set_selection(ids)
	app.hud._begin_settlement(1)
	if not app.hud.issue_build(22 * 64 + 25):
		printerr("GRAPHIC: placement failed")
		quit(1)
		return
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("building.png"))
	await create_timer(22.0).timeout
	var site: int = sim.construction.at(22 * 64 + 25)
	var ready: bool = sim.construction.sites.valid(site) and sim.construction.sites.records[site].ready
	if ready:
		app.hud.select_at(22 * 64 + 25)
		app.hud._buy_worker()
		sim.buy_warrior(0, site)
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("finished.png"))
	var errors := sim.check_invariants()
	print("CONSTRUCTION_GRAPHIC ", {"ready": ready, "tick": sim.tick_count, "workers": sim.worker_population(), "warriors": sim.army.count, "work": sim.construction.sites.records[site].work, "errors": errors})
	quit(0 if ready and sim.army.count == 1 and errors.is_empty() else 1)

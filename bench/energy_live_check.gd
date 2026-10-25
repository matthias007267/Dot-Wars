extends "res://bench/live_benchmark.gd"

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var capture_dir := "res://bench/results/energy"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir = arg.substr(14)
	if DirAccess.make_dir_recursive_absolute(capture_dir) != OK:
		quit(2)
		return
	var config := SimConfig.new()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 4
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.debug_mode = true
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 5000
	sim.rules.wallet(sim, 1).energy = 5000
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var app := BenchApp.new()
	root.add_child(app)
	app._attach(sim)
	app.camera.position = Vector2(28, 28)
	app.camera.zoom = Vector2(12, 12)
	app.set_process_unhandled_input(false)
	app.camera.set_process(false)
	app.camera.set_process_unhandled_input(false)
	app.hud._unlock_interceptors()
	var ids := PackedInt32Array()
	for id in sim.workers.count:
		if sim.workers.faction[id] == 0: ids.append(id)
	app.hud._set_selection(ids)
	app.hud._begin_settlement(2)
	var cell := 27 * 64 + 26
	if not app.hud.issue_build(cell):
		printerr("ENERGY_GRAPHIC: placement failed")
		quit(1)
		return
	var first: int = sim.construction.at(cell)
	# Production build uses actual workers. The opposing station is an explicit diagnostic fixture.
	var second: int = sim.construction.place(sim, 2, cell + 4, PackedInt32Array(), 1)
	sim.construction.sites.contribute(second, 1, 300)
	await create_timer(30.0).timeout
	var ready: bool = sim.construction.sites.records[first].ready
	if not ready:
		printerr("ENERGY_GRAPHIC: workers did not finish station")
		quit(1)
		return
	app.hud.select_at(cell)
	var edge := cell + 3
	sim.energy_dots.enqueue(edge, 16, 1)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("buffer.png"))
	app.hud._toggle_upgrades()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("controls.png"))
	app.hud._toggle_upgrades()
	await create_timer(2.0).timeout
	var captures_before := sim.energy_dots.captured
	# Pause at a point where the first station actually holds energy, then destroy it.
	for tick in 100:
		if sim.energy_dots.held_by.has(first): break
		await process_frame
	app.clock.paused = true
	sim.construction.damage(sim, first, 150)
	app.energy_view.show_energy()
	app.renderer.sync_match(sim)
	app.hud.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("neutral.png"))
	var neutralized := sim.energy_dots.neutralized
	app.clock.paused = false
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("recaptured.png"))
	var errors := sim.check_invariants()
	print("ENERGY_GRAPHIC ", {"built": ready, "captures_before_destruction": captures_before, "neutralized": neutralized, "ledger": sim.energy_dots.ledger(), "errors": errors})
	quit(0 if ready and captures_before >= 24 and neutralized > 0 and errors.is_empty() else 1)

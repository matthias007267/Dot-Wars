extends SceneTree
## Automated graphical interaction check. Run with a real display (or Xvfb), not --headless.
var failures: Array[String] = []
var game: Node
var sim: Simulation

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	print("P6 LIVE ", "OK " if ok else "FAIL ", message)
	if not ok: failures.append(message)

func _screen(cell: int) -> Vector2:
	return (Vector2(cell % sim.world.width, cell / sim.world.width) + Vector2(0.5, 0.5) - game.camera.position) * game.camera.zoom + Vector2(root.size) * 0.5

func _mouse(pressed: bool, cell: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _screen(cell)
	game._unhandled_input(event)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_input(event)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/p6-" + name + ".png"
	check(root.get_texture().get_image().save_png(path) == OK, "Screenshot " + path)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This check requires graphical rendering.")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1440, 1000))
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	sim = Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 2
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 10000
	var worker := sim.workers.add(68, 0, 0)
	sim.workers.add(69, 0, 0)
	sim.fog.update(sim)
	game._attach(sim)
	await process_frame
	await process_frame
	game.hud.select_in_rect(Rect2i(4, 2, 2, 1))
	game.hud._begin_settlement(3)
	check(game.hud.issue_build(100), "Forschungszentrum durch HUD platziert")
	var site := sim.construction.at(100)
	check(site >= 0, "Baustelle vorhanden")
	if site < 0:
		quit(1)
		return
	sim.run_ticks(180)
	check(sim.construction.sites.records[site].ready, "Arbeiter haben gebaut")
	sim.construction.damage(sim, site, 20)
	game.hud.select_at(sim.construction.center(site))
	game.hud._repair_selected()
	sim.run_ticks(40)
	check(sim.construction.sites.records[site].hp == 200, "Reparatur über HUD")
	var path := sim.energy_network.plan_connection(sim, 0, 0, site)
	check(not path.is_empty(), "Netzvorschlag")
	if path.is_empty():
		quit(1)
		return
	# Reveal our local planning corridor using an own warrior, not global fog disabling.
	for cell in path: sim.army.add(cell, 0)
	sim.fog.update(sim)
	_key(KEY_E)
	_mouse(true, path[0])
	var motion := InputEventMouseMotion.new()
	motion.position = _screen(path[path.size() - 1])
	game._unhandled_input(motion)
	check(sim.energy_network.cells.is_empty(), "E-Zug ist vor Loslassen nur Vorschau")
	_mouse(false, path[path.size() - 1])
	check(not sim.energy_network.connected_path(sim, 0, sim.construction.center(0), sim.construction.center(site)).is_empty(), "E-Zug bei Loslassen verbunden")
	while sim.army.count > 0: sim.army.remove(sim.army.ids[0])
	sim.fog.update(sim)
	game.army_view.show_tick(sim.tick_count)
	_key(KEY_E)
	check(not game.hud.energy_network_active(), "E beendet Werkzeug")
	game.hud._toggle_upgrades()
	game.hud._research_tree_view.select_tech("dig")
	game.hud._research_tree_view.start_button.pressed.emit()
	check(sim.research.jobs.size() == 1, "Knoten und Startknopf erzeugen Auftrag")
	sim.run_ticks(8)
	game.hud.refresh()
	game.hud._research_tree_view.reset_view()
	await _capture("research-tree")
	game.hud._research_tree_view.set_zoom(1.25)
	check(game.hud._research_tree_view.zoom == 1.25, "Baumzoom")
	game.hud._toggle_upgrades()
	var cut := path[path.size() - 1]
	_key(KEY_Q)
	_mouse(true, cut)
	_mouse(false, cut)
	check(sim.energy_network.owner_at(cut) == -1, "Q entfernt Leitung sofort")
	_key(KEY_Q)
	check(not game.hud.demolition_active(), "Q beendet Werkzeug")
	sim.energy_network.place(sim, 0, cut)
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "laufende Partie mit Netz gespeichert")
	for tick in 80:
		sim.tick_once()
		if sim.research.is_powered(site, sim.tick_count): break
	check(sim.research.is_powered(site, sim.tick_count), "Aktivitätsglow bei realem Energieverbrauch")
	game.hud.refresh()
	await _capture("powered")
	sim.run_ticks(800)
	check(sim.research.level(0, "dig") == 1, "Forschung nach echten Lieferungen abgeschlossen")
	game.hud.refresh()
	game.workers_view.show_tick(sim.tick_count)
	game.army_view.show_tick(sim.tick_count)
	await _capture("world")
	# Explicit building demolition through the same Q/HUD path, after builders are released.
	for id in sim.workers.count: sim.construction.release(sim, id)
	check(game.hud.demolish_at(sim.construction.center(site)), "Arbeiterabriss beauftragt")
	sim.run_ticks(180)
	check(not sim.construction.sites.valid(site), "Gebäude durch Arbeiter abgerissen")
	check_no_leaks()
	print("P6 LIVE SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func check_no_leaks() -> void:
	var hidden := sim.world.index(31, 31)
	check(not game.renderer.overlay_visible(hidden, 1), "fremde Netzaktivität im unbekannten Gebiet verborgen")

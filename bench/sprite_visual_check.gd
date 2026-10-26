extends SceneTree
## Visual asset review + real GPU checks. This fixture is never a saved match.
var failures: Array[String] = []

class AtlasReview extends Control:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color("08121c"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(40, 45), "DOT WARS  /  SPRITES UND ZUSTÄNDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("90e4fa"))
		draw_string(font, Vector2(40, 78), "Originalgrafiken · 16-Pixel-Raster · Körper und Fraktionsfarbe getrennt · vier Animationsbilder", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9db3c0"))
		var groups := [
			{"x": 40, "keys": ["worker.idle", "worker.move", "worker.mine", "worker.build", "worker.blocked", "warrior.idle", "warrior.move", "warrior.attack"],
			"labels": ["Arbeiter / Bereit", "Bewegung", "Abbau", "Bau / Reparatur", "Weg blockiert", "Krieger / Bereit", "Bewegung", "Angriff"]},
			{"x": 1000, "keys": ["research.idle", "research.active", "research.waiting", "research.complete", "research.construction"],
			"labels": ["Forschung / Bereit", "Forschung läuft", "Versorgung fehlt", "Abgeschlossen", "Baustelle"]}]
		for group in groups:
			for index in range(group["keys"].size()):
				var y: int = 126 + index * 108
				draw_string(font, Vector2(group.x, y + 20), group.labels[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d0dfe7"))
				for frame in SpriteCatalog.ATLAS.frames:
					var area := Rect2(group.x + 230 + frame * 108, y, 80, 80)
					draw_rect(area, Color("172736"))
					SpriteCatalog.draw(self, group["keys"][index], area, SpriteCatalog.team_color(0), frame * SpriteCatalog.ATLAS.frame_ticks)
				SpriteCatalog.draw(self, group["keys"][index], Rect2(group.x + 700, y, 80, 80), SpriteCatalog.team_color(1))
		var icons := ["worker", "warrior", "research", "core", "outpost", "interceptor", "network", "repair", "demolish", "research_tree"]
		for index in icons.size():
			draw_texture_rect(SpriteCatalog.icon(icons[index]), Rect2(1000 + index * 76, 780, 56, 56), false)
		draw_string(font, Vector2(1000, 880), "HUD-Porträts stammen aus demselben Atlas.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("90e4fa"))
		draw_string(font, Vector2(1000, 912), "Keine zusätzlichen Einheiten- oder Gebäudestufen.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9db3c0"))

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("SPRITE ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func capture(path: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(path) == OK, path)
	return image

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var gallery := AtlasReview.new()
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(gallery)
	await capture("/tmp/sprite-catalog.png")
	gallery.queue_free()
	await process_frame
	# Render the actual batched unit shader without glow against a fixed background.
	var config := TestHelpers.default_config()
	config.mode = SimConfig.MODE_MATCH
	config.world_size = 32
	config.ai_count = 1
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.debug_modified = true
	sim.fog.visible[0].fill(1) # explicit asset fixture, not a gameplay visibility change
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	for state in WorkerStore.STATE_COUNT:
		var id := sim.workers.add(sim.world.index(3 + state * 3, 3), 0, 0)
		sim.workers.state[id] = state
		sim.workers.target[id] = sim.workers.cell[id] - sim.world.width
		sim.workers.aim[id] = sim.workers.target[id]
	for owner in 4: sim.army.add(sim.world.index(3 + owner * 3, 7), owner)
	var view := WorkerRenderer.new()
	view.sim = sim
	view.world = sim.world
	view.workers = sim.workers
	view.glow_enabled = false
	var army := ArmyRenderer.new()
	army.sim = sim
	army.glow_enabled = false
	var stage := Node2D.new()
	stage.scale = Vector2.ONE * 64
	root.add_child(stage)
	stage.add_child(view)
	stage.add_child(army)
	view.show_tick(0)
	army.show_tick(0)
	# Force detailed sampling in this fixed diagnostic transform (there is no camera).
	view.set_process(false)
	army.set_process(false)
	var before := sim.state_hash()
	var first := await capture("/tmp/sprite-units.png")
	var paused := await capture("/tmp/sprite-paused.png")
	check(first.get_data() == paused.get_data(), "pause freezes all sprite frames")
	view.show_tick(4)
	var next := await capture("/tmp/sprite-motion.png")
	check(first.get_data() != next.get_data(), "simulation tick changes working/moving sprite frames")
	check(sim.state_hash() == before, "sprite animation preserves simulation hash")
	# Inspect known helmet/shield pixels: faction tint comes from owner, not old palette.
	var helmet := first.get_pixel(3 * 64 + 8 * 4 + 2, 3 * 64 + 4 * 4 + 2)
	check(helmet.r > 0.75 and helmet.g > 0.5 and helmet.b < 0.5, "worker helmet is visible without glow")
	var visor := first.get_pixel(3 * 64 + 6 * 4 + 2, 3 * 64 + 8 * 4 + 2)
	check(visor.b > 0.6 and visor.g > 0.5 and visor.r < 0.5, "visor detail remains separate from faction mask")
	var red_shield := first.get_pixel(6 * 64 + 6 * 4 + 2, 7 * 64 + 11 * 4 + 2)
	check(red_shield.r > red_shield.g * 2.0, "enemy shield uses red faction mask")
	view.material.set_shader_parameter("sprite_detail", false)
	army.material.set_shader_parameter("sprite_detail", false)
	await capture("/tmp/sprite-overview-symbols.png")
	# Hidden/dead pixels must clear both original and added metadata on the GPU.
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	while sim.army.count > 0: sim.army.remove(sim.army.ids[0])
	view.show_tick(5)
	army.show_tick(5)
	var cleared := await capture("/tmp/sprite-cleared.png")
	check(cleared.get_pixel(3 * 64 + 6 * 4 + 2, 3 * 64 + 5 * 4 + 2).r < 0.2, "removed unit leaves no sprite")
	# Check the actual building overlay, not only isolated atlas samples.
	sim.upgrades.energy = 300
	var site := sim.construction.place(sim, 3, sim.world.index(15, 10), PackedInt32Array())
	check(site >= 0, "research fixture placed through construction API")
	if site >= 0:
		sim.construction.sites.contribute(site, 0, 300)
		check(sim.research.start(sim, 0, site, "dig"), "research fixture starts real job")
		var overlay := OrderOverlay.new()
		overlay.sim = sim
		stage.add_child(overlay)
		sim.research.deliver(site)
		sim.tick_once()
		var active := await capture("/tmp/sprite-research-active.png")
		check(overlay.research_visuals.state(sim, sim.construction.sites.records[site]) == "active", "building follows real consumption")
		sim.tick_once()
		var waiting := await capture("/tmp/sprite-research-waiting.png")
		check(overlay.research_visuals.state(sim, sim.construction.sites.records[site]) == "waiting", "building follows supply interruption")
		check(active.get_data() != waiting.get_data(), "supply interruption changes rendered building")
	print("SPRITE SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

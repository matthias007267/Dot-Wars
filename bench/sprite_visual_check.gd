extends SceneTree
## Visual asset review + real GPU checks. This fixture is never a saved match.
var failures: Array[String] = []

class AtlasReview extends Control:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1920, 1080), Color("08121c"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(40, 45), "DOT WARS  /  QUADRATISCHE EINHEITEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("90e4fa"))
		draw_string(font, Vector2(40, 82), "Freigegebener Entwurf · gleiche Grundform · feste Ausrichtung · Teamrand bleibt sichtbar", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("9db3c0"))
		var keys := ["worker.idle", "warrior.1", "warrior.2", "warrior.3"]
		var names := ["ARBEITER", "KRIEGER 1", "KRIEGER 2", "KRIEGER 3"]
		for column in 4:
			draw_string(font, Vector2(340 + column * 370, 138), names[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("d0dfe7"))
		for owner in 3:
			var y := 160 + owner * 178
			draw_string(font, Vector2(40, y + 75), ["TEAM GELB", "TEAM ROT", "TEAM BLAU"][owner], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, SpriteCatalog.team_color(owner))
			for column in 4:
				var area := Rect2(340 + column * 370, y, 136, 136)
				draw_rect(area.grow(8), Color("172736"))
				SpriteCatalog.draw(self, keys[column], area, SpriteCatalog.team_color(owner))
		draw_string(font, Vector2(40, 750), "LESBARKEIT BEI 32 UND 16 PIXELN", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("90e4fa"))
		for owner in 3:
			for column in 4:
				SpriteCatalog.draw(self, keys[column], Rect2(340 + owner * 480 + column * 74, 780, 32, 32), SpriteCatalog.team_color(owner))
				SpriteCatalog.draw(self, keys[column], Rect2(340 + owner * 480 + column * 74, 828, 16, 16), SpriteCatalog.team_color(owner))
		draw_string(font, Vector2(40, 905), "FORSCHUNGSZENTRUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("90e4fa"))
		var states := ["idle", "active", "waiting", "complete", "construction"]
		for index in states.size():
			SpriteCatalog.draw(self, "research." + states[index], Rect2(340 + index * 180, 880, 80, 80), SpriteCatalog.team_color(0))
		draw_string(font, Vector2(40, 1015), "Krieger 2/3: fertige Grafikvarianten. Reguläre Partien verwenden den vorhandenen Basiskrieger (1).", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("9db3c0"))

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
	check(first.get_data() != next.get_data(), "simulation tick changes only the working core glint")
	check(sim.state_hash() == before, "sprite animation preserves simulation hash")
	# Inspect team band and neutral core in the actual shader without a halo.
	var band := first.get_pixel(3 * 64 + 3 * 2 + 1, 3 * 64 + 16 * 2 + 1)
	check(band.r > 0.75 and band.g > 0.5 and band.b < 0.5, "worker team band is visible without glow")
	var core := first.get_pixel(3 * 64 + 16 * 2 + 1, 3 * 64 + 16 * 2 + 1)
	check(core.r > 0.65 and core.b > 0.65, "worker keeps a neutral bright square core")
	var red := first.get_pixel(6 * 64 + 3 * 2 + 1, 7 * 64 + 16 * 2 + 1)
	check(red.r > red.g * 2.0, "enemy team band uses red faction mask")
	# Changing targets does not rotate either square; rendering still never mutates sim.
	view.show_tick(8)
	army.show_tick(8)
	var upright := await capture("/tmp/sprite-upright.png")
	for id in sim.workers.count:
		sim.workers.target[id] = sim.workers.cell[id] + 1
		sim.workers.aim[id] = sim.workers.cell[id] + 1
	for index in sim.army.count: sim.army.goals[index] = sim.army.cells[index] + 1
	view.show_tick(16)
	army.show_tick(16)
	var redirected := await capture("/tmp/sprite-redirected.png")
	check(upright.get_data() == redirected.get_data(), "target direction does not rotate any unit")
	# Explicit visual-only tier preview exercises the same batched shader.
	army.visual_level = 2
	army.show_tick(17)
	var tier2 := await capture("/tmp/sprite-warrior-2.png")
	army.visual_level = 3
	army.show_tick(18)
	var tier3 := await capture("/tmp/sprite-warrior-3.png")
	check(tier2.get_data() != tier3.get_data(), "warrior armor tiers have different rendered details")
	view.material.set_shader_parameter("sprite_detail", false)
	army.material.set_shader_parameter("sprite_detail", false)
	await capture("/tmp/sprite-overview-symbols.png")
	# Hidden/dead pixels must clear both original and added metadata on the GPU.
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	while sim.army.count > 0: sim.army.remove(sim.army.ids[0])
	view.show_tick(19)
	army.show_tick(19)
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

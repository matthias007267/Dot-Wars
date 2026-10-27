extends SceneTree
var failures: Array[String] = []

class Sight extends RefCounted:
	func is_visible(_viewer: int, cell: int) -> bool: return cell != 6

class Labels extends Control:
	func _draw() -> void:
		var names := ["Gold", "Rot", "Blau", "Grün", "Neutral", "Puffer", "Verdeckt", "Leer"]
		for index in names.size():
			draw_string(ThemeDB.fallback_font, Vector2(index * 64 + 3, 27), names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d3e9f1"))

func _init() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("ENERGY ART ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func rendered() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(512, 192)
	RenderingServer.set_default_clear_color(Color("08121c"))
	var view := EnergyRenderer.new()
	view.world = WorldState.new(8, 2, 8, Materials.EMPTY)
	view.energy = EnergyStore.new()
	view.fog = Sight.new()
	for owner in 4: view.energy.enqueue(owner, 1, owner)
	view.energy.enqueue(4, 1, EnergyStore.NEUTRAL)
	view.energy.enqueue(5, 1, 2)
	view.energy.held_by[5] = 7
	view.energy.enqueue(6, 1, 1)
	view.scale = Vector2.ONE * 64
	view.position.y = 48
	root.add_child(view)
	var labels := Labels.new()
	root.add_child(labels)
	var image := await rendered()
	check(image.save_png("/tmp/energy-dot-colors.png") == OK, "screenshot team colors")
	for owner in 4:
		var core := image.get_pixel(owner * 64 + 32, 80)
		check(core.r > 0.9 and core.g > 0.9 and core.b > 0.9, "white core %d" % owner)
		var rim := image.get_pixel(owner * 64 + 46, 80)
		check(rim.is_equal_approx(MatchRules.FACTION_COLORS[owner]), "actual team rim %d" % owner)
	var backdrop := image.get_pixel(7 * 64 + 32, 80)
	check(image.get_pixel(6 * 64 + 32, 80).is_equal_approx(backdrop), "hidden energy has no body")
	check(image.get_pixel(6 * 64 + 12, 80).is_equal_approx(backdrop), "hidden energy has no halo")
	check(image.get_pixel(5 * 64 + 46, 80).is_equal_approx(MatchRules.FACTION_COLORS[2]), "buffer retains team rim")
	var amber := image.get_pixel(5 * 64 + 38, 80)
	check(amber.r > amber.g and amber.g > amber.b, "buffer has amber inner light")
	view.material.set_shader_parameter("glow_strength", 0.0)
	var flat := await rendered()
	check(flat.get_pixel(12, 80).is_equal_approx(backdrop), "halo can be disabled")
	check(flat.get_pixel(32, 80).is_equal_approx(image.get_pixel(32, 80)), "core survives disabled halo")
	view.material.set_shader_parameter("sprite_detail", false)
	view.set_process(false)
	var compact := await rendered()
	for owner in 4:
		var color := compact.get_pixel(owner * 64 + 32, 80)
		var team: Color = MatchRules.FACTION_COLORS[owner]
		check(Vector3(color.r, color.g, color.b).distance_to(Vector3(team.r, team.g, team.b)) < 0.3, "overview retains team %d" % owner)
	check(compact.save_png("/tmp/energy-dot-compact.png") == OK, "screenshot overview style")
	view.queue_free()
	labels.queue_free()
	await process_frame
	root.size = Vector2i(1920, 1080)
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.create(config)
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	for group in sim.group_open.size(): sim.clear_area(group)
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.world.carve_rect(Rect2i(6, 30, 4, 5))
	var target := sim.world.index(8, 32)
	sim.world.set_material(target, Materials.DIAMOND)
	sim.workers.add(sim.world.index(7, 32), 0, 0)
	sim.initial_mass = 1
	sim.assign_area(0, Rect2i(8, 32, 1, 1))
	sim.run_ticks(64)
	var before := sim.state_hash()
	var game: Node = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	game.camera.zoom = Vector2.ONE * 42
	game.camera.position = Vector2(12, 32)
	game.hud._message.text = "ENERGIE-DOTS · Weißer Kern, goldener Teamrand · laufender Diamantabbau"
	image = await rendered()
	check(image.save_png("/tmp/energy-dot-game.png") == OK, "screenshot real mining")
	check(sim.energy_dots.delivered > 0 and sim.world.cells[target] == Materials.DIAMOND, "real stream during mining")
	check(sim.state_hash() == before, "drawing preserves full simulation")
	print("ENERGY ART SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

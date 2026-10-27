extends SceneTree
var failures: Array[String] = []
var game: Node

func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	print("COMBAT ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func pixel(image: Image, world: Vector2) -> Color:
	var p: Vector2 = game.get_viewport().get_canvas_transform() * world
	return image.get_pixel(int(p.x), int(p.y))

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
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	for group in sim.group_open.size(): sim.clear_area(group)
	# Real melee: surviving warriors, a worker death and simultaneous warrior deaths.
	for y in [27, 35]:
		sim.army.add(sim.world.index(28, y), 0)
		sim.army.add(sim.world.index(29, y), 1)
		if y == 35:
			sim.army.hp[2] = 1
			sim.army.hp[3] = 1
	sim.army.add(sim.world.index(28, 31), 0)
	var worker := sim.workers.add(sim.world.index(29, 31), sim.rules.group_of[1], 1)
	sim.workers.health[worker] = 1
	sim.initial_mass = 1
	sim.fog.update(sim)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	game.camera.zoom = Vector2.ONE * 56
	game.camera.position = Vector2(29, 32)
	game.combat_view.set_process(false)
	game.hud._message.text = "KAMPF · oben: Angriff/Treffer · Mitte: Arbeiterzerfall · unten: gleichzeitiger Kriegerzerfall"
	await create_timer(0.25).timeout
	var baseline := await frame()
	sim.tick_once()
	game.army_view.show_tick(sim.tick_count)
	game.workers_view.show_tick(sim.tick_count)
	game.fog_view.show_tick(sim.tick_count)
	check(sim.army.count == 3 and sim.worker_losses == 1, "actual worker and simultaneous warrior deaths")
	check(not game.combat_view.effects.is_empty(), "actual simulation events reached renderer")
	var sequence: Array[Dictionary] = game.combat_view.effects.duplicate(true)
	var before := sim.state_hash()
	game.combat_view.advance(0.025)
	game.combat_view.compose()
	var attack := await frame()
	check(attack.save_png("/tmp/combat-strike.png") == OK, "attack and hit screenshot")
	var hit := pixel(attack, Vector2(29.5, 27.5))
	var unhit := pixel(baseline, Vector2(29.5, 27.5))
	check(hit.r + hit.g + hit.b > unhit.r + unhit.g + unhit.b + 0.3, "actual white hit flash pixels")
	# Compare the exact same post-combat scene with and without the overlay.
	game.combat_view.advance(0.135)
	game.combat_view.compose()
	var burst := await frame()
	check(burst.save_png("/tmp/combat-burst.png") == OK, "team-colored square particle screenshot")
	game.combat_view.visible = false
	var no_effects := await frame()
	no_effects.save_png("/tmp/combat-no-effects.png")
	game.combat_view.visible = true
	var colored := 0
	for y in range(34 * 10, 37 * 10):
		for x in range(27 * 10, 31 * 10):
			var point := Vector2(x / 10.0, y / 10.0)
			var a := pixel(burst, point)
			var b := pixel(no_effects, point)
			if a.r > b.r + 0.03: colored += 1
	check(colored > 5, "actual particle pixels outside defeated warrior cells")
	# Reviewed stronger pattern uses existing catalog art, not a new playable level.
	game.combat_view.effects.clear()
	game.army_view.visual_level = 3
	game.army_view.show_tick(sim.tick_count + 1)
	game.combat_view.visual_level = 3
	game.combat_view._strike(sim.world.index(28, 27), sim.world.index(29, 27), 0)
	game.combat_view._on_hit(sim.world.index(29, 27), 1)
	game.combat_view.advance(0.04)
	game.combat_view.compose()
	var level := await frame()
	check(level.save_png("/tmp/combat-level-preview.png") == OK, "catalog level 3 pattern, review only")
	check(sim.state_hash() == before, "all drawing and catalog previews preserve simulation state")
	game.combat_view.advance(1)
	game.combat_view.compose()
	check(game.combat_view.quad_count == 0, "effects fully expire")
	if "--combat-record" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("/tmp/combat-frames")
		game.army_view.visual_level = 1
		game.army_view.show_tick(sim.tick_count + 2)
		game.combat_view.effects = sequence
		for index in 24:
			game.combat_view.compose()
			var image := await frame()
			image.save_png("/tmp/combat-frames/%03d.png" % index)
			game.combat_view.advance(0.025)
		check(sim.state_hash() == before, "recording real event sequence preserves simulation")
	# Hidden adjacent cell must remain exactly unchanged even beside a visible burst.
	var visible := sim.world.index(28, 31)
	var concealed := sim.world.index(29, 31)
	sim.fog.visible[0].fill(0)
	sim.fog.visible[0][visible] = 1
	game.combat_view._on_death(visible, 0, true)
	game.combat_view.advance(0.18)
	game.combat_view.compose()
	var clipped := await frame()
	game.combat_view.visible = false
	var clean := await frame()
	var leaks := 0
	for y in 10:
		for x in 10:
			var p := Vector2(concealed % 64 + (x + 0.5) / 10.0, concealed / 64 + (y + 0.5) / 10.0)
			if pixel(clipped, p) != pixel(clean, p): leaks += 1
	check(leaks == 0, "actual hidden neighbor pixels unchanged, including halos")
	print("COMBAT SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

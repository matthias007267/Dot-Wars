extends SceneTree
var failures: Array[String] = []
var game: Node

func _init() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	print("DEFENSE ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)
func frame() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func pixel(image: Image, world: Vector2) -> Color:
	var p: Vector2 = game.get_viewport().get_canvas_transform() * world
	return image.get_pixel(int(p.x), int(p.y))
func energy(color: Color) -> float: return color.r + color.g + color.b

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
	sim.upgrades.energy = 5000
	sim.research.levels[0] = {"speed": 1, "outpost": 1, "energy_speed": 1, "defense": 1}
	var outpost: int = sim.construction.place(sim, 1, sim.world.index(13, 23), PackedInt32Array())
	check(outpost >= 0, "outpost fixture")
	if outpost < 0:
		quit(1)
		return
	sim.construction.sites.contribute(outpost, 0, 300)
	var towers := PackedInt32Array()
	for y in [20, 27, 34]:
		var site: int = sim.construction.place(sim, 4, sim.world.index(23, y), PackedInt32Array())
		check(site >= 0, "tower placed")
		if site < 0:
			quit(1)
			return
		sim.construction.sites.contribute(site, 0, 300)
		towers.append(site)
		var route := sim.energy_network.plan_connection(sim, 0, 0, site)
		check(sim.energy_network.place_path(sim, 0, route) > 0 or not sim.energy_network.connected_path(sim, 0, sim.construction.center(0), sim.construction.center(site)).is_empty(), "physical supply conduit")
	check(sim.defense.upgrade(sim, towers[1]) and sim.defense.upgrade(sim, towers[2]), "paid level II upgrades")
	sim.run_ticks(201)
	check(sim.defense.upgrade(sim, towers[2]), "paid beam upgrade")
	sim.run_ticks(201)
	for site in [0, outpost, towers[0], towers[1], towers[2]]:
		check(sim.defense.is_powered(sim, site), "connected and prepaid weapon")
	var targets := PackedInt32Array()
	for y in [21, 28, 35]: targets.append(sim.army.add(sim.world.index(30, y), 1))
	var core_target := sim.army.add(sim.world.index(16, 32), 1)
	var outpost_target := sim.army.add(sim.world.index(18, 24), 1)
	sim.fog.update(sim)
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	game.camera.zoom = Vector2.ONE * 40
	game.camera.position = Vector2(28, 31)
	game.combat_view.set_process(false)
	sim.run_ticks(7)
	game.army_view.show_tick(sim.tick_count)
	game.fog_view.show_tick(sim.tick_count)
	game.workers_view.show_tick(sim.tick_count)
	game.combat_view.effects.clear()
	game.combat_view.compose()
	game.hud.select_at(sim.construction.center(towers[2]))
	game.hud._message.text = "VERTEIDIGUNG · rechts: Einzelschuss / Schnellfeuer / Strahl · links: schwächere Kern-/Außenpostenwaffen"
	var before := sim.state_hash()
	await create_timer(0.25).timeout
	var armed := await frame()
	check(armed.save_png("/tmp/defense-weapons.png") == OK, "weapons and contextual HUD screenshot")
	await create_timer(0.25).timeout
	var pulsing := await frame()
	var flow_changed := 0
	for x in range(16, 23):
		var p := Vector2(x + 0.5, 34.5)
		if absf(energy(pixel(armed, p)) - energy(pixel(pulsing, p))) > 0.015: flow_changed += 1
	check(flow_changed > 0, "real energized conduit pixels pulse without transported units")
	check(sim.defense.beams.size() == 1, "one actual paid beam")
	var origins := {}
	for shot in sim.defense.projectiles: origins[shot.site] = true
	check(origins.has(0) and origins.has(outpost), "core and outpost really launch shots")
	check(origins.has(towers[0]) and origins.has(towers[1]), "single and rapid towers launch physical projectiles")
	game.combat_view.visible = false
	var clean := await frame()
	game.combat_view.visible = true
	check(energy(pixel(armed, Vector2(27.5, 35.5))) > energy(pixel(clean, Vector2(27.5, 35.5))) + 0.4, "actual continuous beam pixels")
	check(energy(pixel(armed, Vector2(15.5, 32.5))) > energy(pixel(clean, Vector2(15.5, 32.5))) + 0.2, "actual core projectile pixels")
	check(energy(pixel(armed, Vector2(17.5, 24.5))) > energy(pixel(clean, Vector2(17.5, 24.5))) + 0.2, "actual outpost projectile pixels")
	check(game.hud._selection_detail.text.contains("Stufe 3/3") and game.hud._selection_detail.text.contains("Energie/Minute"), "selected turret shows tier and upkeep")
	check(not game.hud._context_buttons.tower_upgrade.visible or game.hud._context_buttons.tower_upgrade.disabled, "no fourth upgrade")
	check(sim.state_hash() == before, "rendering preserves full defense state")
	sim.run_ticks(6)
	check(sim.army.hp[sim.army.slots[core_target]] == ArmyState.HEALTH - 1, "weak core impact is one damage")
	check(sim.army.hp[sim.army.slots[outpost_target]] == ArmyState.HEALTH - 1, "weak outpost impact is one damage")
	check(sim.army.hp[sim.army.slots[targets[0]]] == ArmyState.HEALTH - 2, "base tower impact is two damage")
	# Actual local upgrade button and own overview job.
	game.hud.select_at(sim.construction.center(towers[0]))
	game.hud._context_buttons.tower_upgrade.pressed.emit()
	check(int(sim.construction.sites.records[towers[0]].weapon_upgrade) > sim.tick_count, "HUD starts real individual upgrade")
	check(HudOverview.jobs(sim).any(func(job: Dictionary) -> bool: return str(job.key) == "tower_upgrade:%d" % towers[0]), "upgrade appears in own task overview")
	game.hud.refresh()
	var upgrading := await frame()
	check(upgrading.save_png("/tmp/defense-upgrade.png") == OK, "upgrade progress screenshot")
	var worker_cell := sim.world.index(19, 26)
	var worker := sim.workers.add(worker_cell, 0, 0)
	sim.initial_mass += 1
	sim.fog.update(sim)
	game.hud.select_at(worker_cell)
	check(game.hud._context_buttons.tower.visible and not game.hud._context_buttons.tower.disabled, "worker context offers researched tower")
	var menu := await frame()
	check(menu.save_png("/tmp/defense-build-menu.png") == OK, "worker build menu screenshot")
	root.size = Vector2i(1280, 720)
	await process_frame
	var compact := await frame()
	check(compact.save_png("/tmp/defense-compact.png") == OK, "compact HUD screenshot")
	check(not game.hud._bottom_strip.get_global_rect().intersects(game.hud._map.get_global_rect()), "compact selection and map do not overlap")
	check(game.hud._context_buttons.demolish.get_global_rect().end.y <= root.size.y, "three rows of worker actions fit compact HUD")
	game.hud._context_buttons.tower.pressed.emit()
	check(game.hud.issue_build(sim.world.index(17, 37)), "HUD places paid tower with selected worker")
	check(sim.workers.build_site[worker] >= 0, "actual construction worker assigned")
	check(game.hud._research_tree_view.buttons.has("defense"), "military technology visible in research graph")
	# Let the actual paid periods expire with no income, rather than forging buffers.
	sim.upgrades.energy = 0
	sim.run_ticks(1200)
	game.combat_view.effects.clear()
	game.combat_view.compose()
	game.army_view.show_tick(sim.tick_count)
	game.workers_view.show_tick(sim.tick_count)
	game.fog_view.show_tick(sim.tick_count)
	game.hud.refresh()
	root.size = Vector2i(1920, 1080)
	await create_timer(0.25).timeout
	var off := await frame()
	check(off.save_png("/tmp/grid-unpowered.png") == OK, "expired upkeep and dark conduits screenshot")
	check(not sim.defense.is_powered(sim, towers[2]), "weapon shuts down after unpaid renewal")
	check(sim.energy_network.energized_factions(sim)[0] == 0, "no funded supply remains")
	check(energy(pixel(off, Vector2(21.5, 34.5))) + 0.15 < energy(pixel(armed, Vector2(21.5, 34.5))), "actual unpowered conduit is darker")
	await create_timer(0.25).timeout
	var still_off := await frame()
	check(pixel(off, Vector2(21.5, 34.5)) == pixel(still_off, Vector2(21.5, 34.5)), "unpowered conduit has no flow animation")
	# Render masks, not a simulation mutation: both particle bodies and beam halos disappear.
	game.combat_view.visible = true
	sim.fog.visible[0].fill(0)
	game.combat_view.advance(0)
	game.combat_view.compose()
	check(game.combat_view.quad_count == 0, "hidden projectiles and beam emit no quads or halos")
	print("DEFENSE SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

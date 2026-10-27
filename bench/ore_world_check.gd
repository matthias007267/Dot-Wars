extends SceneTree
var failures: Array[String] = []
var game: Node

class Catalog extends Control:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1920, 1080), Color("08121c"))
		draw_string(font, Vector2(45, 55), "DOT WARS / GESTEIN UND ERZADERN", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("c9eaf3"))
		var materials := [1, 5, 6, 7, 8, 9, 10, 11, 12, 4]
		for index in 10:
			var material: int = materials[index]
			var x := 50 + (index % 5) * 375
			var y := 130 + (index / 5) * 435
			draw_string(font, Vector2(x, y), Materials.NAMES[material], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("d1dfe7"))
			draw_texture_rect_region(WorldRenderer.ORE_TEXTURE, Rect2(x, y + 20, 240, 240), Rect2(0, index * 32, 32, 32))
			var detail := "NICHT ABBAUBAR" if material == 4 else "Härte %d · %d s · %d Energie" % [Materials.hardness(material), Materials.WORK[material], Materials.energy(material)]
			draw_string(font, Vector2(x, y + 290), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("9db4c5"))
		draw_string(font, Vector2(45, 1040), "Basiswerte je Arbeiter · Forschung beschleunigt · Energie fließt bereits während des Abbaus", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("9db4c5"))

func _init() -> void: call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("ORE ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("/tmp/ore-" + name + ".png") == OK, "screenshot " + name)

func reveal(sim: Simulation) -> void:
	sim.fog.visible[0].fill(1)
	sim.fog.explored[0].fill(1)
	sim.fog.known_terrain[0] = sim.world.cells.duplicate()
	sim.fog.known_excavated[0] = sim.world.excavated.duplicate()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1920, 1080)
	var catalog := Catalog.new()
	catalog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(catalog)
	await capture("catalog")
	catalog.queue_free()
	await process_frame
	var config := TestHelpers.default_config()
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 3
	config.initial_workers = 1
	config.world_size = 128
	config.world_seed = 17
	var sim := Simulation.create(config)
	check(sim != null, "generated map")
	if sim == null:
		quit(1)
		return
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.debug_modified = true
	reveal(sim) # explicit diagnostic overview only, never a normal match/save
	game = load("res://src/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	game._attach(sim)
	game.clock.paused = true
	var ids: PackedByteArray = game.renderer._material_texture.get_image().get_data()
	var first: Dictionary = sim.construction.sites.records[0]
	var foundation: Rect2i = first.rect
	check(ids[foundation.position.y * sim.world.width + foundation.position.x] == 254, "foundation differs from obsidian on first upload")
	game.camera.zoom = Vector2.ONE * 6
	game.camera.position = Vector2(64, 64)
	game.hud._message.text = "DIAGNOSEKARTE · Gesamtansicht der getrennten Start-Tunnelnetze"
	await capture("map-overview")
	var before := sim.state_hash()
	game.camera.zoom = Vector2.ONE * 24
	game.camera.position = Vector2(48, 55)
	await capture("map-detail")
	check(sim.state_hash() == before, "camera/drawing preserve simulation")
	# Controlled live mining fixture in the real main scene.
	config.world_size = 64
	config.ai_count = 1
	var demo := Simulation.create(config)
	demo.rules.control.fill(MatchRules.CONTROL_REMOTE)
	demo.debug_modified = true
	for group in demo.group_open.size(): demo.clear_area(group)
	while demo.workers.count > 0: demo.workers.remove_swap(0)
	demo.world.carve_rect(Rect2i(6, 30, 4, 5))
	var target := demo.world.index(8, 32)
	demo.world.set_material(target, Materials.DIAMOND)
	var worker := demo.workers.add(demo.world.index(7, 32), 0, 0)
	demo.initial_mass = 1
	demo.assign_area(0, Rect2i(8, 32, 1, 1))
	demo.picked = PackedInt32Array([worker])
	demo.run_ticks(64)
	check(demo.world.cells[target] == Materials.DIAMOND, "diamond still solid during stream")
	check(demo.energy_dots.generated > 0 and demo.energy_dots.generated < 20000, "partial energy stream")
	check(demo.energy_dots.delivered > 0, "energy reaches core before block finishes")
	check(demo.energy_dots.generated == demo.energy_dots.delivered + demo.energy_dots.pending() + demo.energy_dots.expired, "exact energy ledger")
	reveal(demo)
	game._attach(demo)
	game.clock.paused = true
	game.camera.zoom = Vector2.ONE * 42
	game.camera.position = Vector2(12, 32)
	game.hud._message.text = "DIAGNOSE · Diamant wird abgebaut; einzelne Energie-Dots erreichen bereits den Kern"
	await capture("diamond-flow")
	print("ORE SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

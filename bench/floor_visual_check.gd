extends SceneTree
var failures: Array[String] = []
var views: Array[WorldRenderer] = []
var worlds: Array[WorldState] = []

class FloorView extends WorldRenderer:
	func _pit_index() -> int:
		return -1 # comparison fixture contains no gameplay markers

class Captions extends Control:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(100, 70), "DOT WARS / STEINBODEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("d4edf7"))
		draw_string(font, Vector2(100, 135), "VON ANFANG AN FREI", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("a3c4dd"))
		draw_string(font, Vector2(720, 135), "FREIGERABEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("d8c8b5"))
		draw_string(font, Vector2(100, 675), "Gleiche Steintextur · kühler Grundton / dezent wärmer nach Ressourcenabbau", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("9db3c0"))

func _init() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	print("FLOOR ", "OK " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1340, 760)
	for index in 2:
		var world := WorldState.new(8, 8, 8, Materials.EMPTY if index == 0 else Materials.SOFT)
		if index == 1:
			for cell in world.cell_count(): world.mine_cell(cell)
		worlds.append(world)
		var view := FloorView.new()
		view.world = world
		view.vignette_strength = 0.0
		view.position = Vector2(100 + index * 620, 170)
		view.scale = Vector2.ONE * 60
		root.add_child(view)
		views.append(view)
	root.add_child(Captions.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png("/tmp/floor-comparison.png") == OK, "comparison screenshot")
	var cold := Vector3.ZERO
	var warm := Vector3.ZERO
	for y in range(180, 640, 5):
		for x in range(110, 570, 5):
			var a := image.get_pixel(x, y)
			var b := image.get_pixel(x + 620, y)
			cold += Vector3(a.r, a.g, a.b)
			warm += Vector3(b.r, b.g, b.b)
	check(warm.x > cold.x and warm.z < cold.z, "mined floor has warmer tint on identical texture coordinates")
	var first := image.get_data()
	var before := worlds[1].state_hash()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().get_data() == first, "floor stays stable while paused")
	check(worlds[1].state_hash() == before, "drawing preserves world state")
	check(views[1]._floor_stamp == worlds[1].mined_count, "live renderer uses real mining history")
	print("FLOOR SUMMARY: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

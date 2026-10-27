extends TestCase
const Fog = preload("res://src/sim/fog_of_war.gd")
const Backend = preload("res://src/sim/native_search.gd")

func test_four_raster_steps_stop_at_fifth_even_after_a_thin_wall() -> void:
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var fog := Fog.new()
	fog.setup(world, 2)
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
		for material in [Materials.ROCK, Materials.DIAMOND, Materials.INDESTRUCTIBLE]:
			var blockers := world.cells.duplicate()
			var origin := Vector2i(12, 12)
			var wall: Vector2i = origin + direction
			blockers[world.index(wall.x, wall.y)] = material
			for step in range(1, 7):
				var target: Vector2i = origin + direction * step
				check_eq(fog._line_clear(blockers, origin.x, origin.y, target.x, target.y), step <= 4, "exact depth for direction/material/step %s/%d/%d" % [direction, material, step])

func test_building_ignores_only_its_own_foundation_and_cache_tracks_footprint() -> void:
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var fog := Fog.new()
	fog.setup(world, 2)
	var footprint := Rect2i(8, 8, 5, 5)
	world.carve_rect(footprint)
	for y in range(8, 13):
		for x in range(8, 13): world.set_material(world.index(x, y), Materials.INDESTRUCTIBLE)
	world.set_material(world.index(14, 10), Materials.INDESTRUCTIBLE)
	var origin := world.index(10, 10)
	var fourth := world.index(17, 10)
	var fifth := world.index(18, 10)
	check(not fog._visible_cells(world.cells, origin, 12).has(fourth), "ordinary origin does not ignore a footprint")
	var cells := fog._visible_cells(world.cells, origin, 12, footprint)
	check(cells.has(fourth), "source escapes own foundation, then sees four cells into next obstacle")
	check(not cells.has(fifth), "neighboring structure is not exempt")
	check(not fog._visible_cells(world.cells, origin, 12).has(fourth), "cache invalidates when footprint exemption changes")
	var native := Backend.backend()
	if native != null and native.has_method("fog_visible_depth"):
		var result: Array = native.fog_visible_depth(world.cells, PackedInt32Array([0, origin, 12, 8, 8, 5, 5]), 2, 32)
		var actual := PackedByteArray()
		actual.resize(world.cell_count())
		var expected := actual.duplicate()
		for cell in result[0]: actual[cell] = 1
		for cell in cells: expected[cell] = 1
		check_eq(actual, expected, "native footprint/depth equals reference")
		check_eq(native.fog_visible_depth(world.cells, PackedInt32Array([0, origin, 12, 20, 20, 5, 5]), 2, 32), null, "cannot exempt an unrelated remote building")

func test_started_building_supplies_sight_and_light_without_a_worker_nearby() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.upgrades.energy = 300
	var site: int = sim.construction.place(sim, 3, sim.world.index(40, 44), PackedInt32Array())
	check(site >= 0, "distant building fixture")
	if site < 0: return
	var center := sim.construction.center(site)
	var outside := center + 6
	sim.fog.update(sim)
	check(not sim.fog.is_visible(0, outside), "unstarted plan is not a free scout")
	sim.construction.sites.contribute(site, 0, 1)
	sim.fog.update(sim)
	check(sim.fog.is_visible(0, outside), "started building supplies its own sight")
	var started_light := 0.0
	for source in CavernLighting.sources(sim):
		if source.cell == center: started_light = source.strength
	check(started_light > 0, "started construction emits light")
	sim.construction.sites.contribute(site, 0, 299)
	sim.fog.update(sim)
	var before := sim.state_hash()
	var ready_light := 0.0
	for source in CavernLighting.sources(sim):
		if source.cell == center: ready_light = source.strength
	check(ready_light > started_light, "idle completed research center has stable base light")
	check_eq(sim.state_hash(), before, "light does not consume or create simulation energy")
	sim.construction.damage(sim, site, 200)
	sim.fog.update(sim)
	check(not sim.fog.is_visible(0, outside), "destroyed building loses sight source")
	check(sim.fog.is_explored(0, outside), "knowledge remains after losing the source")
	for source in CavernLighting.sources(sim): check(source.cell != center, "destroyed building has no light")

func test_unit_visibility_ends_at_the_same_four_cell_boundary() -> void:
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var fog := Fog.new()
	fog.setup(world, 2)
	world.set_material(world.index(11, 10), Materials.ROCK)
	fog._reveal(fog.visible[0], world.cells, world.index(10, 10), 9)
	var energy := EnergyStore.new()
	energy.enqueue(world.index(14, 10), 1, 1)
	energy.enqueue(world.index(15, 10), 1, 1)
	var view := EnergyRenderer.new()
	view.world = world
	view.energy = energy
	view.fog = fog
	view._ready()
	check(view._bytes[world.index(14, 10) * 4 + 3] > 0, "fourth field is truly visible")
	check_eq(view._bytes[world.index(15, 10) * 4 + 3], 0, "fifth field does not leak a hidden unit or dot")
	view.free()

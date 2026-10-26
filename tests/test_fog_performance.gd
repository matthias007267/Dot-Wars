extends TestCase
const Fog = preload("res://src/sim/fog_of_war.gd")

func _sim(size := 32) -> Simulation:
	var config := TestHelpers.default_config()
	config.mode = SimConfig.MODE_MATCH
	config.world_size = size
	config.ai_count = 1
	config.initial_workers = 2
	var sim := Simulation.from_world(config, WorldState.new(size, size, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	return sim

func test_cached_visibility_matches_fresh_rays_after_blocker_and_alliance_changes() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	sim.army.add(10 * 32 + 10, 0)
	sim.army.add(20 * 32 + 20, 1)
	for step in 24:
		# Also mutate raw cells: no reliance on dirty flags or material revision.
		var changed := rng.randi_range(0, sim.world.cell_count() - 1)
		sim.world.cells[changed] = rng.randi_range(0, Materials.COUNT - 1)
		sim.workers.cell[0] = rng.randi_range(0, sim.world.cell_count() - 1)
		fog.alliance[1] = 0 if step % 3 == 0 else 1
		fog.update(sim)
		var blockers := sim.world.cells.duplicate()
		var sources := []
		for id in sim.workers.count: sources.append([int(sim.workers.faction[id]), int(sim.workers.cell[id]), Fog.WORKER_RADIUS])
		for id in sim.army.count: sources.append([int(sim.army.owners[id]), int(sim.army.cells[id]), Fog.WARRIOR_RADIUS])
		for row in sim.construction.sites.records:
			if row.destroyed: continue
			var rect: Rect2i = row.rect
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x): blockers[y * sim.world.width + x] = 1
			if row.ready: sources.append([int(row.owner), sim.construction.center(row.id), Fog.CORE_RADIUS])
		for faction in 2:
			var expected := PackedByteArray()
			expected.resize(sim.world.cell_count())
			for source in sources:
				if fog.alliance[faction] == fog.alliance[source[0]]: fog._reveal(expected, blockers, source[1], source[2])
			check_eq(fog.visible[faction], expected, "cached sight equals fresh rays at step %d faction %d" % [step, faction])

func test_overlay_updates_knowledge_pixels_and_chunk_edges_without_live_terrain_leak() -> void:
	var sim := _sim(128)
	var view := FogOverlay.new()
	view.sim = sim
	view.show_tick(0)
	check_eq(view._chunks.size(), 4, "four 64x64 chunks")
	var changes := PackedInt32Array([63, 64, 63 * 128 + 63, 64 * 128 + 64, 127 * 128 + 127])
	for cell in changes:
		sim.fog.visible[0][cell] = 1
		sim.fog.explored[0][cell] = 1
		sim.fog.known_terrain[0][cell] = Materials.HARD
	view.show_tick(1)
	for cell in changes: check_eq(view._bytes[cell * 4 + 3], 0, "new visible cell immediately transparent")
	for cell in changes: sim.fog.visible[0][cell] = 0
	view.show_tick(2)
	var blue := int(Materials.COLORS[Materials.HARD].b * 255.0)
	for cell in changes:
		check_eq(view._bytes[cell * 4 + 3], 255, "lost sight immediately opaque")
		check_eq(view._bytes[cell * 4 + 2], blue, "last known terrain retained")
	var before := view._minimap_bytes.duplicate()
	for cell in changes: sim.world.cells[cell] = Materials.SOFT
	view.show_tick(3)
	check_eq(view._minimap_bytes, before, "hidden terrain mutations do not leak to minimap")
	# Every chunk texture must represent its exact rectangle after edge changes.
	for index in view._chunks.size():
		var pixels := PackedByteArray()
		var cx := index % 2
		var cy := index / 2
		for y in 64:
			var offset := ((cy * 64 + y) * 128 + cx * 64) * 4
			pixels.append_array(view._bytes.slice(offset, offset + 256))
		check_eq(view._chunk_pixels[index], pixels, "chunk boundary pixels agree")
	view.cavern_style = false
	view.show_tick(4)
	check(view._chunks[0].material == null, "plain fog style applied")
	view.cavern_style = true
	view.show_tick(5)
	check(view._chunks[0].material != null, "cavern fog style restored")
	view.free()

func test_marker_refresh_does_not_repaint_terrain_for_visibility_or_hp() -> void:
	var sim := _sim()
	var view := WorldRenderer.new()
	view.world = sim.world
	view.core_mask = sim.core_mask
	view.sync_match(sim)
	view._bytes.resize(sim.world.cell_count() * 4)
	view._paint_everything()
	var expected := view._bytes.duplicate()
	# Deliberately change a raw terrain cell without dirty processing; sync_match
	# must leave terrain refresh to its normal dirty-chunk consumer.
	var cell := 0
	sim.world.cells[cell] = Materials.HARD
	sim.fog.visible[0][cell] = 1
	sim.fog.known_sites[0][0].hp -= 1
	view.sync_match(sim)
	check_eq(view._bytes, expected, "sight/HP alone do not repaint terrain")
	# Discover an enemy core: only its marker changes, preserving all other pixels.
	var enemy: Dictionary = sim.construction.sites.records[1]
	sim.fog.known_sites[0][1] = enemy.duplicate(true)
	view.sync_match(sim)
	var incremental := view._bytes.duplicate()
	# Bring the deferred terrain cell back in sync before a full-reference repaint.
	sim.world.cells[cell] = Materials.EMPTY
	view._paint_everything()
	check_eq(incremental, view._bytes, "incremental marker discovery equals full repaint")
	view.free()

func test_local_cache_reacts_immediately_to_opened_and_closed_rays() -> void:
	var fog := Fog.new()
	var world := WorldState.new(32, 32, 1, Materials.EMPTY)
	fog.setup(world, 2)
	var origin := 10 * 32 + 10
	var wall := origin + 1
	var behind := origin + 2
	var blockers := world.cells.duplicate()
	check(fog._visible_cells(blockers, origin, 7).has(behind), "initial free ray")
	blockers[wall] = Materials.HARD
	check(not fog._visible_cells(blockers, origin, 7).has(behind), "new opaque material blocks cached ray immediately")
	blockers[wall] = Materials.EMPTY
	check(fog._visible_cells(blockers, origin, 7).has(behind), "removed wall reveals behind immediately")
	blockers[wall] = Materials.SOFT
	check(fog._visible_cells(blockers, origin, 7).has(wall), "opaque endpoint itself stays visible")
	check(not fog._visible_cells(blockers, origin, 7).has(behind), "soft material blocks too")

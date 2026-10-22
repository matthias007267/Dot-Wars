extends TestCase


func _scenario() -> Dictionary:
	var config := SimConfig.new()
	config.world_size = 64
	config.world_seed = 17
	var world := WorldGenerator.generate(config)
	world.carve_rect(Rect2i(10, 10, 30, 6))
	world.carve_rect(Rect2i(36, 10, 3, 30))
	world.carve_rect(Rect2i(50, 50, 5, 5))
	var areas := DigAreas.new(64, 64, 2)
	areas.assign_rect(0, Rect2i(20, 20, 20, 12))
	areas.assign_rect(0, Rect2i(48, 48, 12, 12))
	return {"world": world, "areas": areas}


## Unabhängige Referenzberechnung: BFS auf Dictionary-Basis.
func _reference_distances(world: WorldState, areas: DigAreas, group: int) -> Dictionary:
	var dist := {}
	var queue: Array[int] = []
	var w := world.width
	for rect in areas.rects[group]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if world.cells[y * w + x] == Materials.EMPTY:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if world.in_bounds(nx, ny) and world.cells[ny * w + nx] == Materials.EMPTY and not dist.has(ny * w + nx):
						dist[ny * w + nx] = 0
						queue.append(ny * w + nx)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var x := c % w
		var y := c / w
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if world.in_bounds(nx, ny) and world.cells[ny * w + nx] == Materials.EMPTY and not dist.has(ny * w + nx):
				dist[ny * w + nx] = dist[c] + 1
				queue.append(ny * w + nx)
	return dist


func test_distances_match_independent_reference_bfs() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var reference := _reference_distances(world, areas, 0)
	var reachable := 0
	for c in world.cell_count():
		var expected: int = reference.get(c, FlowField.UNREACHABLE)
		if expected != FlowField.UNREACHABLE:
			reachable += 1
		check_eq(field.dist[c], expected, "Distanz Zelle %d" % c)
	check(reachable > 100, "Szenario ist nicht trivial (%d)" % reachable)


func test_following_directions_leads_to_a_work_position() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var field := FlowField.new(world, s["areas"], 0)
	field.rebuild_blocking()
	var checked := 0
	for start in world.cell_count():
		if field.dist[start] <= 0:
			continue
		var c := start
		var steps := 0
		while field.dir[c] != FlowField.DIR_ARRIVED and steps < 5000:
			var n := MovementSystem.neighbor(c, field.dir[c], world.width, world.cell_count())
			check(n >= 0 and world.cells[n] == Materials.EMPTY, "Schritt führt über leere Zellen")
			check_eq(field.dist[n], field.dist[c] - 1, "Distanz sinkt je Schritt um 1")
			c = n
			steps += 1
		check_eq(steps, field.dist[start], "Weglänge = Distanz")
		checked += 1
		if checked >= 200:
			break
	check(checked > 0, "Zellen geprüft")


func test_budgeted_build_equals_blocking_build() -> void:
	var s := _scenario()
	var blocking := FlowField.new(s["world"], s["areas"], 0)
	blocking.rebuild_blocking()
	var stepped := FlowField.new(s["world"], s["areas"], 0)
	var calls := 0
	stepped.step(37)
	check(stepped.is_building(), "kleines Budget braucht mehrere Takte")
	check_eq(stepped.generation, 0, "halbfertiges Feld ist nicht sichtbar")
	check_eq(stepped.dist.count(FlowField.UNREACHABLE), s["world"].cell_count(), "veröffentlichte Daten unverändert")
	while stepped.is_building() and calls < 100000:
		stepped.step(37)
		calls += 1
	check(calls > 10, "mehrere Schritte nötig (%d)" % calls)
	check_eq(stepped.dist, blocking.dist, "gleiche Distanzen")
	check_eq(stepped.dir, blocking.dir, "gleiche Richtungen")


func test_field_only_rebuilds_after_changes() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.step(1 << 30)
	var generation := field.generation
	check_eq(generation, 1, "erster Aufbau")
	field.step(1 << 30)
	field.step(1 << 30)
	check_eq(field.generation, generation, "keine Änderung → kein Neuaufbau")
	var solid_cell := -1
	for c in world.cell_count():
		if world.cells[c] != Materials.EMPTY and areas.is_marked(0, c):
			solid_cell = c
			break
	world.mine_cell(solid_cell)
	field.step(1 << 30)
	check_eq(field.generation, generation + 1, "Weltänderung → Neuaufbau")
	areas.assign_rect(0, Rect2i(0, 0, 4, 4))
	field.step(1 << 30)
	check_eq(field.generation, generation + 2, "neues Gebiet → Neuaufbau")


func test_area_change_during_build_restarts_it() -> void:
	var s := _scenario()
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(s["world"], areas, 0)
	field.step(100)
	check(field.is_building(), "Aufbau läuft")
	areas.clear_group(0)
	field.step(1 << 30)
	check(not field.is_building(), "Aufbau abgeschlossen")
	check_eq(field.dist.count(FlowField.UNREACHABLE), field.dist.size(), "ohne Gebiet gibt es keine Quellen")


func test_groups_have_independent_fields() -> void:
	var s := _scenario()
	var areas: DigAreas = s["areas"]
	areas.assign_rect(1, Rect2i(45, 5, 10, 10))
	var a := FlowField.new(s["world"], areas, 0)
	var b := FlowField.new(s["world"], areas, 1)
	a.rebuild_blocking()
	b.rebuild_blocking()
	check(a.dist != b.dist, "unterschiedliche Ziele → unterschiedliche Felder")

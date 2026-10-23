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
	check(calls > 2, "mehrere Schritte nötig (%d)" % calls)
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


func test_one_opened_cell_matches_a_fresh_field() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var opened := _marked_solids(world, areas, 6)
	var rebuilds := field.full_rebuilds
	var local := field.patches
	for cell in opened:
		world.mine_cell(cell)
		field.step(1 << 30)
		var fresh := FlowField.new(world, areas, 0)
		fresh.rebuild_blocking()
		check_eq(field.dist, fresh.dist, "lokale Korrektur, Zelle %d" % cell)
		var walked := 0
		for start in world.cell_count():
			if field.dist[start] <= 0:
				continue
			var step := MovementSystem.neighbor(start, field.dir[start], world.width, world.cell_count())
			check(step >= 0, "Richtung bleibt in der Welt")
			check_eq(field.dist[step], field.dist[start] - 1, "Richtung senkt die Distanz")
			walked += 1
			if walked == 30:
				break
	check_eq(field.patches, local + opened.size(), "jede einzelne Zelle bleibt eine lokale Korrektur")
	check_eq(field.full_rebuilds, rebuilds, "eine Zelle startet keinen vollständigen Neuaufbau")
	check(field.generation > 1, "jede Öffnung veröffentlicht ein Feld")


func test_patch_stays_local_when_another_cell_opens_midway() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var opened := _marked_solids(world, areas, 2)
	var rebuilds := field.full_rebuilds
	var before := field.dist.duplicate()
	world.mine_cell(opened[0])
	field.step(0)
	check(field.is_building(), "ohne Budget bleibt die Korrektur unsichtbar")
	check_eq(field.generation, 1, "halbfertige Korrektur ist nicht veröffentlicht")
	check_eq(field.dist, before, "veröffentlichtes Feld bleibt das alte")
	world.mine_cell(opened[1])
	field.step(1 << 30)
	check(not field.is_building(), "Korrektur schließt ab")
	check_eq(field.full_rebuilds, rebuilds, "weitere Zelle während der Korrektur bleibt lokal")
	check_eq(field.patches, 1, "beide Zellen landen in einer Korrektur")
	var fresh := FlowField.new(world, areas, 0)
	fresh.rebuild_blocking()
	check_eq(field.dist, fresh.dist, "zwei Zellen entsprechen einem frischen Feld")


func test_several_opened_cells_patch_in_one_step() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var opened := _marked_solids(world, areas, 8)
	var rebuilds := field.full_rebuilds
	for cell in opened:
		world.mine_cell(cell)
	field.step(1 << 30)
	check_eq(field.patches, 1, "acht Zellen sind eine Korrektur")
	check_eq(field.full_rebuilds, rebuilds, "acht Zellen bleiben unter der Grenze")
	var fresh := FlowField.new(world, areas, 0)
	fresh.rebuild_blocking()
	check_eq(field.dist, fresh.dist, "Sammelkorrektur entspricht einem frischen Feld")


func test_many_opened_cells_fall_back_to_a_full_rebuild() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var opened := _marked_solids(world, areas, FlowField.PATCH_CELL_LIMIT + 1)
	check_eq(opened.size(), FlowField.PATCH_CELL_LIMIT + 1, "genug abbaubare Zellen")
	var rebuilds := field.full_rebuilds
	for cell in opened:
		world.mine_cell(cell)
	field.step(1 << 30)
	check_eq(field.full_rebuilds, rebuilds + 1, "über der Grenze wird vollständig neu aufgebaut")
	check_eq(field.patches, 0, "der Fallback ist keine lokale Korrektur")
	var fresh := FlowField.new(world, areas, 0)
	fresh.rebuild_blocking()
	check_eq(field.dist, fresh.dist, "Fallback entspricht einem frischen Feld")


func test_empty_rect_is_dropped_by_a_patch() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var lone := -1
	for c in world.cell_count():
		if world.cells[c] != Materials.EMPTY and not areas.is_marked(0, c):
			lone = c
			break
	check(lone >= 0, "einzelne feste Zelle außerhalb der Gebiete")
	var x := lone % world.width
	var y := lone / world.width
	areas.assign_rect(0, Rect2i(x, y, 1, 1))
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var rects: Array[Rect2i] = areas.rects[0]
	var before := rects.size()
	var rebuilds := field.full_rebuilds
	world.mine_cell(lone)
	field.step(1 << 30)
	check_eq(rects.size(), before - 1, "leeres Gebiet verschwindet ohne Neuaufbau")
	check_eq(field.full_rebuilds, rebuilds, "das Leeren eines Gebiets bleibt lokal")
	check_eq(field.patches, 1, "das Leeren zählt als Korrektur")
	var fresh := FlowField.new(world, areas, 0)
	fresh.rebuild_blocking()
	check_eq(field.dist, fresh.dist, "nach dem Entfernen stimmen die Distanzen")


func _marked_solids(world: WorldState, areas: DigAreas, limit: int) -> PackedInt32Array:
	var opened := PackedInt32Array()
	for c in world.cell_count():
		if Materials.is_mineable(world.cells[c]) and areas.is_marked(0, c):
			opened.append(c)
			if opened.size() == limit:
				break
	return opened


func test_groups_have_independent_fields() -> void:
	var s := _scenario()
	var areas: DigAreas = s["areas"]
	areas.assign_rect(1, Rect2i(45, 5, 10, 10))
	var a := FlowField.new(s["world"], areas, 0)
	var b := FlowField.new(s["world"], areas, 1)
	a.rebuild_blocking()
	b.rebuild_blocking()
	check(a.dist != b.dist, "unterschiedliche Ziele → unterschiedliche Felder")


func test_world_change_during_build_does_not_restart_it() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.step(80)
	check(field.is_building(), "Aufbau läuft")
	var rebuilds := field.full_rebuilds
	var solid := -1
	for cell in world.cell_count():
		if Materials.is_mineable(world.cells[cell]):
			solid = cell
			break
	check(world.mine_cell(solid), "eine Zelle öffnet sich währenddessen")
	field.step(40)
	check_eq(field.full_rebuilds, rebuilds, "die Weltänderung setzt den Aufbau nicht zurück")
	check(field.is_building(), "der Aufbau läuft weiter")
	field.step(1 << 30)
	field.step(1 << 30)
	var fresh := FlowField.new(world, areas, 0)
	fresh.rebuild_blocking()
	check_eq(field.dist, fresh.dist, "danach stimmt das Feld mit der neuen Welt")


func test_a_far_cell_does_not_rebuild_the_field() -> void:
	var s := _scenario()
	var world: WorldState = s["world"]
	var areas: DigAreas = s["areas"]
	var field := FlowField.new(world, areas, 0)
	field.rebuild_blocking()
	var corner := -1
	var width := world.width
	var count := world.cell_count()
	for cell in count:
		if areas.is_marked(0, cell) or not Materials.is_mineable(world.cells[cell]):
			continue
		if field.dist[cell] >= 0:
			continue
		var near := false
		if cell >= width and field.dist[cell - width] >= 0:
			near = true
		if cell % width < width - 1 and field.dist[cell + 1] >= 0:
			near = true
		if cell + width < count and field.dist[cell + width] >= 0:
			near = true
		if cell % width > 0 and field.dist[cell - 1] >= 0:
			near = true
		if not near:
			corner = cell
			break
	check(corner >= 0, "eine abgelegene feste Zelle")
	var generation := field.generation
	var rebuilds := field.full_rebuilds
	var before := field.dist.duplicate()
	var next := Materials.HARD if world.cells[corner] != Materials.HARD else Materials.MEDIUM
	world.set_material(corner, next)
	field.step(1 << 30)
	check_eq(field.generation, generation, "ferne Zelle lässt das veröffentlichte Feld stehen")
	check_eq(field.full_rebuilds, rebuilds, "ferne Zelle baut nicht neu")
	check_eq(field.dist, before, "Distanzen bleiben")

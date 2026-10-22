class_name Simulation
extends RefCounted
## Orchestriert alle Systeme in fester Reihenfolge. Enthält keinerlei Darstellung oder Eingabe.
##
## Takt: Zielsuche → Bewegung → Abbau → Entstehung → Verschmelzung → Opferung.

enum Stage { TARGET_SEARCH, MOVEMENT, MINING, SPAWN }

var config: SimConfig
var world: WorldState
var workers: WorkerStore
var areas: DigAreas
var spawner: SpawnSystem
var fields: Array[FlowField] = []
var quotas: PackedInt32Array
var tick_count: int = 0
## Arbeiter zu Beginn (Basis der Massenbilanz).
var initial_mass: int = 0
var sacrificed_mass: int = 0
var peak_mass: int = 0
var max_units: int = 0
var won: bool = false
var win_tick: int = -1
var upgrades := Upgrades.new()
var group_names := PackedStringArray()
var group_colors: Array[Color] = []
var group_open := PackedByteArray()
var desired_size := PackedByteArray()
var sacrifice_on := PackedByteArray()
var selected_group: int = 0

## Die ersten vier Farben stehen in der Vorlage. Fünf bis acht bleiben hell und getrennt,
## damit die Tasten 1–8 lesbar bleiben.
const GROUP_PALETTE: Array[Color] = [
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0x53, 0xC7, 0xFF),
	Color8(0xFF, 0x6A, 0x76),
	Color8(0x7E, 0xFF, 0x93),
	Color8(0xF4, 0xF7, 0xFB),
	Color8(0xFF, 0x9A, 0xD5),
	Color8(0x3E, 0xE0, 0xC7),
	Color8(0xD6, 0xF2, 0x6A),
]

## Kumulierte Laufzeit je Stufe in Mikrosekunden (Profiling, Benchmark, HUD).
var stage_usec := PackedInt64Array([0, 0, 0, 0])
var last_tick_usec: int = 0


## Erzeugt Welt aus der Konfiguration. Gibt bei ungültiger Konfiguration oder fehlenden
## Startpositionen null zurück.
static func create(p_config: SimConfig) -> Simulation:
	var errors := p_config.validate()
	if not errors.is_empty():
		push_error("Ungültige Konfiguration: " + ", ".join(errors))
		return null
	return from_world(p_config, WorldGenerator.generate(p_config))


## Erzeugt eine Simulation für eine vorhandene Welt. Ohne `start_cells` werden
## `config.initial_workers` Arbeiter deterministisch um die Weltmitte platziert.
static func from_world(
	p_config: SimConfig,
	p_world: WorldState,
	start_cells: PackedInt32Array = PackedInt32Array(),
	place_workers: bool = true,
) -> Simulation:
	var sim := Simulation.new()
	if not sim._setup(p_config, p_world, start_cells, place_workers):
		return null
	return sim


func tick_once() -> void:
	var t0 := Time.get_ticks_usec()
	for g in fields.size():
		fields[g].step(config.field_budget_per_tick)
	var t1 := Time.get_ticks_usec()
	var speed_points := 0 if upgrades.speed_level == 0 else upgrades.move_points(config.move_period_ticks)
	MovementSystem.step(tick_count, workers, world, areas, fields, config.move_period_ticks, speed_points)
	var t2 := Time.get_ticks_usec()
	if upgrades.dig_level == 0 and workers.max_size == 1:
		MiningSystem.step(workers, world, areas, spawner, config.work_per_hardness, config.dig_power)
	else:
		var fraction := upgrades.dig_fraction()
		MiningSystem.step_scaled(
			workers, world, areas, spawner, config.work_per_hardness, config.dig_power, fraction.x, fraction.y
		)
	var t3 := Time.get_ticks_usec()
	spawner.process(world, workers, quotas)
	FusionSystem.step(workers, world, desired_size)
	var gained := SacrificeSystem.step(workers, sacrifice_on, _delivery_cells(), total_mass())
	sacrificed_mass += gained
	upgrades.energy += gained
	var mass_now := total_mass()
	if mass_now > peak_mass:
		peak_mass = mass_now
	if workers.count > max_units:
		max_units = workers.count
	var t4 := Time.get_ticks_usec()
	stage_usec[Stage.TARGET_SEARCH] += t1 - t0
	stage_usec[Stage.MOVEMENT] += t2 - t1
	stage_usec[Stage.MINING] += t3 - t2
	stage_usec[Stage.SPAWN] += t4 - t3
	last_tick_usec = t4 - t0
	tick_count += 1
	if not won and total_mass() >= 100 and upgrades.purchased >= 2 and world.mined_fraction() >= 0.9:
		won = true
		win_tick = tick_count


func run_ticks(count: int) -> void:
	for i in count:
		tick_once()


## Weist einer Gruppe ein Abbaugebiet zu (Weltzellkoordinaten). Gibt false zurück, wenn nichts zugewiesen wurde.
func assign_area(group_id: int, rect: Rect2i) -> bool:
	return areas.assign_rect(group_id, rect)


func clear_area(group_id: int) -> void:
	areas.clear_group(group_id)


## Setzt ein Laufziel auf eine leere Zelle. Die Gruppe läuft dorthin, ohne abzubauen.
## Gibt false zurück, wenn Gruppe oder Zelle ungültig sind oder Material auf der Zelle liegt.
func set_move_goal(group_id: int, cell_idx: int) -> bool:
	if group_id < 0 or group_id >= fields.size():
		return false
	if cell_idx < 0 or cell_idx >= world.cell_count() or world.cells[cell_idx] != Materials.EMPTY:
		return false
	fields[group_id].goal_cell = cell_idx
	return true


func clear_move_goal(group_id: int) -> void:
	if group_id < 0 or group_id >= fields.size():
		return
	fields[group_id].goal_cell = -1


func move_goal(group_id: int) -> int:
	if group_id < 0 or group_id >= fields.size():
		return -1
	return fields[group_id].goal_cell


## Ändert die Zielquoten. Gibt false zurück, wenn sie ungültig sind (Zustand bleibt unverändert).
func set_quotas(new_quotas: PackedInt32Array) -> bool:
	if new_quotas.size() != quotas.size() or not GroupQuotas.validate(new_quotas).is_empty():
		return false
	quotas = new_quotas.duplicate()
	return true


## Gesamtmasse: lebende Arbeiter plus noch nicht platzierte Entstehungen.
func total_mass() -> int:
	return workers.mass_sum() + spawner.pending()


func expected_mass() -> int:
	return initial_mass + world.mined_count - sacrificed_mass


func stats() -> Dictionary:
	var group_total := quotas.size()
	var waiting := PackedInt32Array()
	waiting.resize(group_total)
	for id in workers.count:
		if workers.state[id] == WorkerStore.STATE_WAITING:
			waiting[workers.group[id]] += 1
	return {
		"tick": tick_count,
		"workers": workers.count,
		"pending_spawns": spawner.pending(),
		"group_counts": workers.group_counts.duplicate(),
		"group_waiting": waiting,
		"quotas": quotas.duplicate(),
		"mined": world.mined_count,
		"mined_fraction": world.mined_fraction(),
		"mass_total": total_mass(),
		"mass_expected": expected_mass(),
		"last_tick_usec": last_tick_usec,
	}


## Prüft alle Invarianten. Leeres Ergebnis = alles konsistent.
func check_invariants() -> PackedStringArray:
	var errors := PackedStringArray()
	if total_mass() != expected_mass():
		errors.append("Massenbilanz verletzt: %d != %d" % [total_mass(), expected_mass()])
	var recount := PackedInt32Array()
	recount.resize(quotas.size())
	var occupied := 0
	var footprint_cells := 0
	for id in workers.count:
		var c := workers.cell[id]
		var unit_size := int(workers.size[id])
		recount[workers.group[id]] += 1
		footprint_cells += unit_size * unit_size
		if c < 0 or c >= world.cell_count():
			errors.append("Arbeiter %d außerhalb der Welt" % id)
			continue
		if not _footprint_consistent(id):
			errors.append("Arbeiter %d hat einen ungültigen Fußabdruck" % id)
		if workers.state[id] == WorkerStore.STATE_MINING and not _touches_target(id, workers.target[id]):
			errors.append("Arbeiter %d baut nicht an einer Nachbarzelle ab" % id)
	for o in workers.occupant:
		if o != WorkerStore.NO_WORKER:
			occupied += 1
	if occupied != footprint_cells:
		errors.append("Belegte Zellen (%d) != Fußabdruck (%d)" % [occupied, footprint_cells])
	if recount != workers.group_counts:
		errors.append("Gruppenzähler inkonsistent")
	return errors


func state_hash() -> int:
	return hash([
		tick_count,
		world.state_hash(),
		workers.state_hash(),
		areas.state_hash(),
		spawner.pending(),
		sacrificed_mass,
		upgrades.state_hash(),
		hash(desired_size),
		hash(sacrifice_on),
		won,
	])


func _setup(
	p_config: SimConfig, p_world: WorldState, start_cells: PackedInt32Array, place_workers: bool = true
) -> bool:
	config = p_config
	world = p_world
	quotas = config.group_quotas.duplicate()
	areas = DigAreas.new(world.width, world.height, quotas.size())
	workers = WorkerStore.new(world.cell_count(), quotas.size(), world.width)
	spawner = SpawnSystem.new(world.cell_count(), config.spawn_search_limit)
	for g in quotas.size():
		fields.append(FlowField.new(world, areas, g))
		_append_group_meta(g)
	if place_workers and not _place_initial_workers(start_cells):
		return false
	initial_mass = workers.mass_sum()
	peak_mass = initial_mass
	max_units = workers.count
	return true


func _place_initial_workers(start_cells: PackedInt32Array) -> bool:
	if not start_cells.is_empty():
		for c in start_cells:
			if c < 0 or c >= world.cell_count() or world.cells[c] != Materials.EMPTY or not workers.is_free(c):
				push_error("Ungültige Startposition %d" % c)
				return false
			workers.add(c, GroupQuotas.pick_group(workers.group_mass, quotas))
		return true
	var origin := world.find_nearest_empty(world.width / 2, world.height / 2)
	if origin < 0:
		push_error("Die Welt enthält keine leere Zelle für Startarbeiter")
		return false
	var cells := spawner.find_free_cells(world, workers, origin, config.initial_workers, world.cell_count())
	if cells.size() < config.initial_workers:
		push_error("Nicht genug freie Startpositionen für %d Arbeiter" % config.initial_workers)
		return false
	for c in cells:
		workers.add(c, GroupQuotas.pick_group(workers.group_mass, quotas))
	return true


func add_group(group_name: String = "") -> int:
	if quotas.size() >= SimConfig.MAX_GROUPS:
		return -1
	var id := quotas.size()
	quotas.append(0)
	_append_group_meta(id)
	if not group_name.is_empty():
		group_names[id] = group_name
	areas.add_group()
	fields.append(FlowField.new(world, areas, id))
	workers.ensure_groups(quotas.size())
	return id


func remove_group(group_id: int) -> bool:
	if not _group_is_open(group_id):
		return false
	var dest := -1
	var alive := 0
	for g in group_open.size():
		if group_open[g] == 0:
			continue
		alive += 1
		if g != group_id and dest < 0:
			dest = g
	if alive < 2 or dest < 0:
		return false
	var id := 0
	while id < workers.count:
		if workers.group[id] == group_id:
			workers.reassign_group(id, dest)
		id += 1
	quotas[dest] += quotas[group_id]
	quotas[group_id] = 0
	group_open[group_id] = 0
	desired_size[group_id] = 1
	sacrifice_on[group_id] = 0
	areas.clear_group(group_id)
	clear_move_goal(group_id)
	if selected_group == group_id:
		selected_group = dest
	return true


func rename_group(group_id: int, group_name: String) -> bool:
	if not _group_is_open(group_id) or group_name.is_empty():
		return false
	group_names[group_id] = group_name
	return true


func set_group_color(group_id: int, color: Color) -> bool:
	if not _group_is_open(group_id):
		return false
	group_colors[group_id] = color
	return true


func set_desired_size(group_id: int, unit_size: int) -> bool:
	if not _group_is_open(group_id) or unit_size < 1 or unit_size > upgrades.max_size():
		return false
	desired_size[group_id] = unit_size
	return true


func set_sacrifice(group_id: int, enabled: bool) -> bool:
	if not _group_is_open(group_id):
		return false
	if not enabled:
		sacrifice_on[group_id] = 0
		return true
	var delivery := _delivery_cells()
	if delivery.is_empty():
		return false
	sacrifice_on[group_id] = 1
	fields[group_id].goal_cell = delivery[0]
	return true


func buy(kind: int) -> bool:
	var before := upgrades.max_size()
	if not upgrades.try_buy(kind):
		return false
	if upgrades.max_size() < before:
		return true
	for g in desired_size.size():
		if desired_size[g] > upgrades.max_size():
			desired_size[g] = upgrades.max_size()
	return true


func open_group_count() -> int:
	var total := 0
	for flag in group_open:
		total += int(flag)
	return total


func pit_index() -> int:
	var pit := WorldGenerator.sacrifice_cell(world)
	if not world.in_bounds(pit.x, pit.y):
		return -1
	return world.index(pit.x, pit.y)


func _append_group_meta(group_id: int) -> void:
	group_names.append("Gruppe %d" % [group_id + 1])
	group_colors.append(GROUP_PALETTE[group_id % GROUP_PALETTE.size()])
	group_open.append(1)
	desired_size.append(1)
	sacrifice_on.append(0)


func _group_is_open(group_id: int) -> bool:
	return group_id >= 0 and group_id < group_open.size() and group_open[group_id] == 1


func _delivery_cells() -> PackedInt32Array:
	var pit := pit_index()
	if pit < 0:
		return PackedInt32Array()
	return SacrificeSystem.delivery_cells(world, pit)


func _footprint_consistent(id: int) -> bool:
	var unit_size := int(workers.size[id])
	var anchor := workers.cell[id]
	var width := world.width
	var x0 := anchor % width
	var y0 := anchor / width
	if x0 + unit_size > width or y0 + unit_size > world.height:
		return false
	if workers.mass[id] != WorkerStore.SIZE_MASS[unit_size]:
		return false
	for dy in unit_size:
		for dx in unit_size:
			var idx := anchor + dy * width + dx
			if world.cells[idx] != Materials.EMPTY or workers.occupant[idx] != id:
				return false
	return true


func _touches_target(id: int, target: int) -> bool:
	var unit_size := int(workers.size[id])
	var anchor := workers.cell[id]
	var width := world.width
	for dy in unit_size:
		for dx in unit_size:
			if _is_adjacent(anchor + dy * width + dx, target):
				return true
	return false


func _is_adjacent(a: int, b: int) -> bool:
	if b < 0:
		return false
	var w := world.width
	var delta := absi(a - b)
	return delta == w or (delta == 1 and a / w == b / w)

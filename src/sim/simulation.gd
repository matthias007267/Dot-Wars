class_name Simulation
extends RefCounted
## Orchestriert alle Systeme in fester Reihenfolge. Enthält keinerlei Darstellung oder Eingabe.
##
## Takt: Zielsuche → Bewegung → Abbau → Entstehung.

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
	p_config: SimConfig, p_world: WorldState, start_cells: PackedInt32Array = PackedInt32Array()
) -> Simulation:
	var sim := Simulation.new()
	if not sim._setup(p_config, p_world, start_cells):
		return null
	return sim


func tick_once() -> void:
	var t0 := Time.get_ticks_usec()
	for g in fields.size():
		fields[g].step(config.field_budget_per_tick)
	var t1 := Time.get_ticks_usec()
	MovementSystem.step(tick_count, workers, world, areas, fields, config.move_period_ticks)
	var t2 := Time.get_ticks_usec()
	MiningSystem.step(workers, world, areas, spawner, config.work_per_hardness, config.dig_power)
	var t3 := Time.get_ticks_usec()
	spawner.process(world, workers, quotas)
	var t4 := Time.get_ticks_usec()
	stage_usec[Stage.TARGET_SEARCH] += t1 - t0
	stage_usec[Stage.MOVEMENT] += t2 - t1
	stage_usec[Stage.MINING] += t3 - t2
	stage_usec[Stage.SPAWN] += t4 - t3
	last_tick_usec = t4 - t0
	tick_count += 1


func run_ticks(count: int) -> void:
	for i in count:
		tick_once()


## Weist einer Gruppe ein Abbaugebiet zu (Weltzellkoordinaten). Gibt false zurück, wenn nichts zugewiesen wurde.
func assign_area(group_id: int, rect: Rect2i) -> bool:
	return areas.assign_rect(group_id, rect)


func clear_area(group_id: int) -> void:
	areas.clear_group(group_id)


## Ändert die Zielquoten. Gibt false zurück, wenn sie ungültig sind (Zustand bleibt unverändert).
func set_quotas(new_quotas: PackedInt32Array) -> bool:
	if new_quotas.size() != quotas.size() or not GroupQuotas.validate(new_quotas).is_empty():
		return false
	quotas = new_quotas.duplicate()
	return true


## Gesamtmasse: lebende Arbeiter plus noch nicht platzierte Entstehungen.
func total_mass() -> int:
	return workers.count + spawner.pending()


func expected_mass() -> int:
	return initial_mass + world.mined_count


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
	for id in workers.count:
		var c := workers.cell[id]
		recount[workers.group[id]] += 1
		if c < 0 or c >= world.cell_count():
			errors.append("Arbeiter %d außerhalb der Welt" % id)
			continue
		if world.cells[c] != Materials.EMPTY:
			errors.append("Arbeiter %d steht in Material" % id)
		if workers.occupant[c] != id:
			errors.append("Belegung von Zelle %d inkonsistent (Arbeiter %d)" % [c, id])
		if workers.state[id] == WorkerStore.STATE_MINING and not _is_adjacent(c, workers.target[id]):
			errors.append("Arbeiter %d baut nicht an einer Nachbarzelle ab" % id)
	for o in workers.occupant:
		if o != WorkerStore.NO_WORKER:
			occupied += 1
	if occupied != workers.count:
		errors.append("Belegte Zellen (%d) != Arbeiter (%d)" % [occupied, workers.count])
	if recount != workers.group_counts:
		errors.append("Gruppenzähler inkonsistent")
	return errors


func state_hash() -> int:
	return hash([tick_count, world.state_hash(), workers.state_hash(), areas.state_hash(), spawner.pending()])


func _setup(p_config: SimConfig, p_world: WorldState, start_cells: PackedInt32Array) -> bool:
	config = p_config
	world = p_world
	quotas = config.group_quotas.duplicate()
	areas = DigAreas.new(world.width, world.height, quotas.size())
	workers = WorkerStore.new(world.cell_count(), quotas.size())
	spawner = SpawnSystem.new(world.cell_count(), config.spawn_search_limit)
	for g in quotas.size():
		fields.append(FlowField.new(world, areas, g))
	if not _place_initial_workers(start_cells):
		return false
	initial_mass = workers.count
	return true


func _place_initial_workers(start_cells: PackedInt32Array) -> bool:
	if not start_cells.is_empty():
		for c in start_cells:
			if c < 0 or c >= world.cell_count() or world.cells[c] != Materials.EMPTY or not workers.is_free(c):
				push_error("Ungültige Startposition %d" % c)
				return false
			workers.add(c, GroupQuotas.pick_group(workers.group_counts, quotas))
		return true
	var origin := world.find_nearest_empty(world.width / 2, world.height / 2)
	if origin < 0:
		push_error("Die Welt enthält keine leere Zelle für Startarbeiter")
		return false
	for i in config.initial_workers:
		var c := spawner.find_free_cell(world, workers, origin)
		if c < 0:
			push_error("Nicht genug freie Startpositionen für %d Arbeiter" % config.initial_workers)
			return false
		workers.add(c, GroupQuotas.pick_group(workers.group_counts, quotas))
	return true


func _is_adjacent(a: int, b: int) -> bool:
	if b < 0:
		return false
	var w := world.width
	var delta := absi(a - b)
	return delta == w or (delta == 1 and a / w == b / w)

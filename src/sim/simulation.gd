class_name Simulation
extends RefCounted
## Orchestriert alle Systeme in fester Reihenfolge. Enthält keinerlei Darstellung oder Eingabe.
##
## Takt: Zielsuche → Bewegung → Abbau → Entstehung → Verschmelzung → Nachwuchs → Veredelung → Energietransport → Mehrspieler.

enum Stage { TARGET_SEARCH, MOVEMENT, MINING, SPAWN }
enum SearchStage { GUIDANCE, ANCHORS, FIELDS, SWARM }

var config: SimConfig
var world: WorldState
const Army = preload("res://src/sim/army_state.gd")
var army: ArmyState = Army.new()
var worker_losses := 0
var workers: WorkerStore
var areas: DigAreas
var spawner: SpawnSystem
var energy_dots := EnergyStore.new()
const Construction = preload("res://src/sim/construction_system.gd")
var construction: Construction = Construction.new()
var buildings := Buildings.new()
var rules := MatchRules.new()
var research := ResearchSystem.new()
var energy_network := EnergyNetwork.new()
const Fog = preload("res://src/sim/fog_of_war.gd")
var fog = Fog.new()
var purchased_workers: int = 0
const WORKER_COST := 10
var fields: Array[FlowField] = []
var work_front := WorkFront.new()
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
## 1 verbietet die Zelle für Arbeiter. Leer, solange der Kern noch nicht erweitert wurde.
var core_mask := PackedByteArray()
var group_names := PackedStringArray()
var group_colors: Array[Color] = []
var group_open := PackedByteArray()
var desired_size := PackedByteArray()
var sacrifice_on := PackedByteArray()
var selected_group: int = 0
## Gruppe, die den aktuellen Marsch oder die Eroberung ausführt. -1, solange kein Befehl lief.
var command_group := -1
## Zielzelle eines Marsches. -1, wenn die Gruppe ein Gebiet erobert oder keinen Marsch hat.
var march_cell := -1
## Vom Spieler markierte Arbeiter. Zählt nicht in den Zustandshash.
var picked := PackedInt32Array()
## Testlabor: nur laufzeitlokal, kein regulärer Spielmodus und nicht im SaveGame enthalten.
var debug_mode: bool = false
## Bleibt bis zum Neustart gesetzt, damit Debug-Werte auch nach Deaktivierung nie gespeichert werden.
var debug_modified: bool = false

## Alle internen Gruppen verwenden dieselbe Arbeiterfarbe. Rot bleibt für spätere Krieger reserviert.
const GROUP_PALETTE: Array[Color] = [
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0xE4, 0x5E),
]

## Kumulierte Laufzeit je Stufe in Mikrosekunden (Profiling, Benchmark, HUD).
var stage_usec := PackedInt64Array([0, 0, 0, 0])
var search_usec := PackedInt64Array([0, 0, 0, 0])
var last_tick_usec: int = 0
## Messungen seit Erzeugung/Laden, unabhängig vom gespeicherten Spieltakt.
var profiled_ticks: int = 0


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


var approach_text := ""


func tick_once() -> void:
	var t0 := Time.get_ticks_usec()
	construction.step(self)
	_guide_digging()
	var search_guidance := Time.get_ticks_usec()
	_refresh_flow_anchors()
	var search_anchors := Time.get_ticks_usec()
	for g in fields.size():
		fields[g].step(config.field_budget_per_tick)
	var search_fields := Time.get_ticks_usec()
	SwarmMind.step(self)
	var t1 := Time.get_ticks_usec()
	search_usec[SearchStage.GUIDANCE] += search_guidance - t0
	search_usec[SearchStage.ANCHORS] += search_anchors - search_guidance
	search_usec[SearchStage.FIELDS] += search_fields - search_anchors
	search_usec[SearchStage.SWARM] += t1 - search_fields
	var move_forbidden := army.blockers(core_mask)
	var move_periods := PackedByteArray()
	if _match_live():
		move_forbidden = army.blockers(PackedByteArray())
		move_periods = rules.worker_periods(self)
	MovementSystem.step(
		tick_count, workers, world, areas, fields,
		upgrades.worker_period(config.move_period_ticks), 0, move_forbidden, move_periods
	)
	var t2 := Time.get_ticks_usec()
	if _match_live():
		var levels := PackedInt32Array()
		for faction in rules.faction_count:
			levels.append(rules.wallet(self, faction).dig_level)
		MiningSystem.step_scaled(
			workers, world, areas, energy_dots, config.work_per_hardness, config.dig_power, 0, levels
		)
	elif upgrades.dig_level == 0 and workers.max_size == 1:
		MiningSystem.step(workers, world, areas, energy_dots, config.work_per_hardness, config.dig_power)
	else:
		MiningSystem.step_scaled(
			workers, world, areas, energy_dots, config.work_per_hardness, config.dig_power, upgrades.dig_level
		)
	var t3 := Time.get_ticks_usec()
	spawner.process(world, workers, quotas, army.blockers(core_mask), self)
	# Fusion ist aus dem Spiel entfernt.
	buildings.grow(world, workers, energy_dots, army.blockers(core_mask))
	buildings.refine(energy_dots, world, tick_count)
	if _match_live():
		var route: Dictionary = rules.gates(self)
		var gate_cells: PackedInt32Array = route.cells
		var gate_owners: PackedByteArray = route.owners
		var before := energy_dots.delivered_to.duplicate()
		energy_dots.step(
			world, workers, gate_cells, tick_count, upgrades.energy_period(), gate_owners, rules.energy_periods(self), self
		)
		rules.credit_energy(self, before)
	else:
		var gates := energy_exits()
		upgrades.energy += energy_dots.step(world, workers, gates, tick_count, upgrades.energy_period(), PackedByteArray(), PackedByteArray(), self)
	research.step(self)
	var mass_now := total_mass()
	if mass_now > peak_mass:
		peak_mass = mass_now
	if workers.count > max_units:
		max_units = workers.count
	army.step(self)
	var t4 := Time.get_ticks_usec()
	stage_usec[Stage.TARGET_SEARCH] += t1 - t0
	stage_usec[Stage.MOVEMENT] += t2 - t1
	stage_usec[Stage.MINING] += t3 - t2
	stage_usec[Stage.SPAWN] += t4 - t3
	tick_count += 1
	if _match_live():
		rules.pulse(self)
	elif not won and _goals_met():
		won = true
		win_tick = tick_count
	if _match_live(): fog.update(self)
	# Auch KI, Kampf und Siegprüfung gehören zur vollständigen Taktzeit.
	last_tick_usec = Time.get_ticks_usec() - t0
	profiled_ticks += 1


func run_ticks(count: int) -> void:
	for i in count:
		tick_once()


func _guide_digging() -> void:
	_release_finished_command()
	var note := ""
	for group_id in fields.size():
		if not _group_is_open(group_id):
			continue
		var kind := DigGuidance.consider(self, group_id)
		if kind != DigGuidance.TOWARD:
			continue
		var human := rules.group_faction.is_empty() or group_id >= rules.group_faction.size() or rules.group_faction[group_id] == 0
		if human:
			note = "Das Gebiet ist nicht erreichbar. Der Schwarm gräbt sich dorthin."
	_settle_march()
	approach_text = note


## Ein erledigter Handbefehl gibt die Befehlsgruppe wieder für die eigene Arbeitssuche frei.
## Laufziele der KI bleiben. Solange jemand noch auf das Marschziel zuläuft, bleibt der Befehl.
func _release_finished_command() -> void:
	var group_id := command_group
	if group_id < 0 or not _group_is_open(group_id):
		return
	var goal := move_goal(group_id)
	var group_rects: Array = areas.rects[group_id]
	if march_cell < 0 and goal < 0 and group_rects.is_empty():
		return
	var field := fields[group_id]
	if not field.settled():
		return
	if DigGuidance.mineable_left(self, group_id):
		return
	if not _party_is_holding(group_id):
		return
	clear_area(group_id)
	clear_move_goal(group_id)
	march_cell = -1


func _party_is_holding(group_id: int) -> bool:
	var field := fields[group_id]
	var width := world.width
	var count := world.cell_count()
	for id in workers.count:
		if int(workers.group[id]) != group_id:
			continue
		var cell := int(workers.cell[id])
		if cell < 0 or cell >= count or field.dist[cell] <= 0:
			continue
		var next := _step_cell(cell, int(field.dir[cell]), width, count)
		if next >= 0 and world.cells[next] == Materials.EMPTY and workers.occupant[next] == WorkerStore.NO_WORKER:
			return false
	return true


func _step_cell(cell: int, direction: int, width: int, count: int) -> int:
	if direction == FlowField.DIR_UP and cell >= width:
		return cell - width
	if direction == FlowField.DIR_DOWN and cell + width < count:
		return cell + width
	if direction == FlowField.DIR_RIGHT and cell % width < width - 1:
		return cell + 1
	if direction == FlowField.DIR_LEFT and cell % width > 0:
		return cell - 1
	return -1


func _settle_march() -> void:
	if command_group < 0 or march_cell < 0 or move_goal(command_group) >= 0:
		return
	if march_cell >= world.cell_count():
		return
	if world.cells[march_cell] != Materials.EMPTY or _in_core(march_cell):
		return
	set_move_goal(command_group, march_cell)


## Weist einer Gruppe ein Abbaugebiet zu (Weltzellkoordinaten). Gibt false zurück, wenn nichts zugewiesen wurde.
func assign_area(group_id: int, rect: Rect2i) -> bool:
	return areas.assign_rect(group_id, rect)


func assign_cells(group_id: int, cells: PackedInt32Array) -> bool:
	return areas.assign_cells(group_id, cells)


func clear_area(group_id: int) -> void:
	areas.clear_group(group_id)


## Setzt ein Laufziel auf eine leere Zelle. Die Gruppe läuft dorthin, ohne abzubauen.
## Ist die Zelle nicht erreichbar, läuft sie zum nächstmöglichen Punkt in ihrer Fläche.
## Gibt false zurück, wenn Gruppe oder Zelle ungültig sind oder Material auf der Zelle liegt.
func set_move_goal(group_id: int, cell_idx: int) -> bool:
	if group_id < 0 or group_id >= fields.size():
		return false
	if cell_idx < 0 or cell_idx >= world.cell_count() or world.cells[cell_idx] != Materials.EMPTY:
		return false
	if _in_core(cell_idx):
		return false
	fields[group_id].goal_cell = cell_idx
	_refresh_flow_anchors()
	return true


## Merkt sich einen Wunschpunkt, auch wenn er fest oder gesperrt ist.
## Die Wegsuche läuft dann zum nächstmöglichen erreichbaren Punkt.
func set_approach(group_id: int, cell_idx: int) -> bool:
	if group_id < 0 or group_id >= fields.size():
		return false
	if cell_idx < 0 or cell_idx >= world.cell_count():
		return false
	fields[group_id].goal_cell = cell_idx
	_refresh_flow_anchors()
	return true


## True, wenn der Wunschpunkt der Gruppe selbst der nächstmögliche Standpunkt ist.
func reaches_move_goal(group_id: int) -> bool:
	if group_id < 0 or group_id >= fields.size():
		return false
	_refresh_flow_anchors()
	return fields[group_id].goal_is_stand()


func _refresh_flow_anchors() -> void:
	var buckets: Array = []
	buckets.resize(fields.size())
	for g in fields.size():
		buckets[g] = PackedInt32Array()
	for id in workers.count:
		var group_id := int(workers.group[id])
		if group_id < 0 or group_id >= buckets.size():
			continue
		var cell := int(workers.cell[id])
		if world.cells[cell] != Materials.EMPTY:
			continue
		buckets[group_id].append(cell)
	for g in fields.size():
		fields[g].anchors = buckets[g]


func clear_move_goal(group_id: int) -> void:
	if group_id < 0 or group_id >= fields.size():
		return
	fields[group_id].goal_cell = -1


func move_goal(group_id: int) -> int:
	if group_id < 0 or group_id >= fields.size():
		return -1
	return fields[group_id].goal_cell


## Legt bei Bedarf die Befehlsgruppe an und setzt genau diese Arbeiter hinein.
func take_party(ids: PackedInt32Array) -> int:
	var group_id := ensure_command_group()
	if group_id < 0:
		return -1
	var keep := {}
	for id in ids:
		if id < 0 or id >= workers.count:
			continue
		if int(workers.faction[id]) != 0:
			continue
		keep[id] = true
	var member := 0
	while member < workers.count:
		if workers.group[member] == group_id and not keep.has(member):
			var home := GroupQuotas.pick_group(workers.group_mass, quotas)
			if home >= 0:
				workers.reassign_group(member, home)
		member += 1
	for id in keep:
		construction.release(self, int(id))
		workers.reassign_group(int(id), group_id)
	clear_area(group_id)
	clear_move_goal(group_id)
	march_cell = -1
	return group_id


func ensure_command_group() -> int:
	if command_group >= 0 and _group_is_open(command_group):
		return command_group
	var id := add_group("Befehl")
	if id < 0:
		return -1
	command_group = id
	if rules.group_faction.size() > 0:
		rules.group_faction.append(0)
	return id


## Ändert die Zielquoten. Gibt false zurück, wenn sie ungültig sind (Zustand bleibt unverändert).
func set_quotas(new_quotas: PackedInt32Array) -> bool:
	if new_quotas.size() != quotas.size() or not GroupQuotas.validate(new_quotas).is_empty():
		return false
	quotas = new_quotas.duplicate()
	return true


## Gesamtmasse: lebende Arbeiter plus noch nicht platzierte Entstehungen.
func total_mass() -> int:
	return workers.mass_sum() + spawner.pending()


## Masse einer Fraktion. Wartende Käufe des Spielers zählen zu Fraktion 0.
func faction_mass(faction: int) -> int:
	var total := 0
	for id in workers.count:
		if int(workers.faction[id]) == faction:
			total += int(workers.mass[id])
	if faction == 0:
		total += spawner.pending()
	return total


func opponent_mass() -> int:
	var total := 0
	for id in workers.count:
		if int(workers.faction[id]) != 0:
			total += int(workers.mass[id])
	return total


func expected_mass() -> int:
	return initial_mass + purchased_workers + rules.match_bought - rules.removed_mass - worker_losses


## Zeilen der Sieganzeige. Die Zeit ist die Simulationszeit bis zum Sieg, 20 Takte je Sekunde.
func victory_lines() -> PackedStringArray:
	var ticks := tick_count
	if won and win_tick >= 0:
		ticks = win_tick
	var seconds := ticks / 20
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	return PackedStringArray([
		"Spielzeit  %s" % clock,
		"Abgebaut  %d" % world.mined_count,
		"Höchste Masse  %d" % peak_mass,
		"Gekaufte Arbeiter  %d" % purchased_workers,
		"Gelieferte Energie  %d" % energy_dots.delivered,
		"Upgrades  %d" % upgrades.purchased,
		"Einheiten zugleich  %d" % max_units,
		"Veredelt  %d" % energy_dots.refined_delivered,
	])


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
		"energy_in_transit": energy_dots.pending(),
		"energy_generated": energy_dots.generated,
		"energy_delivered": energy_dots.delivered, "energy_expired": energy_dots.expired, "energy_ledger": energy_dots.ledger(),
		"energy_refined": energy_dots.refined_delivered,
		"workers_purchased": purchased_workers,
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
	energy_dots.ensure_tracks()
	if total_mass() != expected_mass():
		errors.append("Massenbilanz verletzt: %d != %d" % [total_mass(), expected_mass()])
	if energy_dots.generated != energy_dots.delivered + energy_dots.expired + energy_dots.pending():
		errors.append("Energiebilanz verletzt")
	if energy_dots.birth.size() != energy_dots.cells.size() or energy_dots.refined.size() != energy_dots.cells.size():
		errors.append("Energie-Dots ohne Herkunft")
	if energy_dots.owner.size() != energy_dots.cells.size():
		errors.append("Energie-Dots ohne Besitzer")
	if energy_dots.generated < 0 or energy_dots.delivered < 0 or energy_dots.expired < 0 or energy_dots.captured < 0 or energy_dots.neutralized < 0:
		errors.append("Negative Energiezähler")
	for i in energy_dots.cells.size():
		if energy_dots.owner[i] != EnergyStore.NEUTRAL and energy_dots.owner[i] >= (rules.faction_count if _match_live() else 1): errors.append("Energie ohne gültigen Besitzer")
		if energy_dots.cells[i] < 0 or energy_dots.cells[i] >= world.cell_count() or energy_dots.no_route[i] < 0 or energy_dots.no_route[i] >= 1200: errors.append("Ungültiger Energieort/Verfallstimer")
		var holder := energy_dots.held_by[i]
		if holder >= 0:
			if not construction.sites.valid(holder) or construction.sites.records[holder].kind != 2 or not construction.sites.records[holder].ready or construction.sites.records[holder].owner != int(energy_dots.owner[i]): errors.append("Energiepuffer ohne fertige eigene Station")
		elif holder < -1 or energy_dots.release_at[i] != 0: errors.append("Ungültige Energiepufferbindung")
	if energy_dots.refined_delivered > energy_dots.delivered:
		errors.append("Veredelte Energie übersteigt die Lieferung")
	errors.append_array(_building_errors())
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
		if not _match_live() and _footprint_hits_mask(id, core_mask):
			errors.append("Arbeiter %d steht im Energiekern" % id)
	for o in workers.occupant:
		if o != WorkerStore.NO_WORKER:
			occupied += 1
	if occupied != footprint_cells:
		errors.append("Belegte Zellen (%d) != Fußabdruck (%d)" % [occupied, footprint_cells])
	if recount != workers.group_counts:
		errors.append("Gruppenzähler inkonsistent")
	if army.purchased - army.lost != army.count + army.queue.size(): errors.append("Kriegerbilanz verletzt")
	var factions := rules.faction_count if config.mode == SimConfig.MODE_MATCH else 1
	for item in army.queue:
		if int(item.owner) >= factions: errors.append("Kriegerproduktion ohne Fraktion")
	for index in army.count:
		if army.owners[index] >= factions or army.hp[index] <= 0 or army.hp[index] > Army.HEALTH: errors.append("Ungültiger Kriegerzustand")
		var cell := army.cells[index]
		if cell < 0 or cell >= world.cell_count() or army.occupant[cell] != army.ids[index] or world.cells[cell] != Materials.EMPTY or workers.occupant[cell] >= 0:
			errors.append("Ungültige Kriegerbelegung")
	return errors


func state_hash() -> int:
	return hash([
		tick_count,
		world.state_hash(), army.state_hash(), worker_losses, construction.sites.state_hash(), hash(construction.demolitions), hash(spawner.site_queue()),
		workers.state_hash(),
		areas.state_hash(),
		spawner.pending(),
		energy_dots.state_hash(),
		purchased_workers,
		sacrificed_mass,
		upgrades.state_hash(), research.state_hash(), energy_network.state_hash(),
		config.mode,
		config.ai_count,
		config.victory_mask,
		config.difficulty,
		rules.state_hash(),
		buildings.state_hash(),
		hash(desired_size),
		hash(sacrifice_on),
		command_group,
		march_cell,
		won,
	])


func _setup(
	p_config: SimConfig, p_world: WorldState, start_cells: PackedInt32Array, place_workers: bool = true
) -> bool:
	config = p_config
	debug_mode = config.population_test_mode
	debug_modified = config.population_test_mode
	army.setup(p_world.cell_count())
	world = p_world
	quotas = config.group_quotas.duplicate()
	areas = DigAreas.new(world.width, world.height, quotas.size())
	workers = WorkerStore.new(world.cell_count(), quotas.size(), world.width)
	spawner = SpawnSystem.new(world.cell_count(), config.spawn_search_limit)
	construction.setup(world, 1 + config.ai_count if config.mode == SimConfig.MODE_MATCH else 1)
	energy_network.setup(world.width, world.height)
	research.setup(1 + config.ai_count if config.mode == SimConfig.MODE_MATCH else 1)
	for g in quotas.size():
		fields.append(FlowField.new(world, areas, g))
		_append_group_meta(g)
	if place_workers:
		if config.mode == SimConfig.MODE_MATCH:
			if not rules.install(self):
				return false
		else:
			var pit := pit_index()
			if start_cells.is_empty() and pit >= 0 and world.cells[pit] == Materials.INDESTRUCTIBLE:
				construction.initial(self, pit, 0)
			if not _place_initial_workers(start_cells): return false
	if config.mode == SimConfig.MODE_MATCH and place_workers:
		fog.setup(world, rules.faction_count)
		fog.update(self)
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
	var field := FlowField.new(world, areas, id)
	if config.mode != SimConfig.MODE_MATCH:
		field.blocked = core_mask
	fields.append(field)
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
	if not _group_is_open(group_id) or unit_size < 1 or unit_size != 1:
		return false
	desired_size[group_id] = unit_size
	return true


## Legacy-API für ältere Aufrufer; Arbeiteropfer sind nicht mehr möglich.
func set_sacrifice(group_id: int, enabled: bool) -> bool:
	if not _group_is_open(group_id) or enabled:
		return false
	sacrifice_on[group_id] = 0
	return true

## Debug-Werkzeuge umgehen ausschließlich Kosten, nicht Grenzen oder Kern-Kollisionen.
func debug_adjust_upgrade(kind: int, delta: int) -> bool:
	if not debug_mode or absi(delta) != 1:
		return false
	var u := upgrades
	match kind:
		Upgrades.KIND_SPEED:
			u.speed_level = clampi(u.speed_level + delta, 0, Upgrades.SPEED_MAX)
		Upgrades.KIND_ENERGY_SPEED:
			u.energy_speed_level = clampi(u.energy_speed_level + delta, 0, Upgrades.ENERGY_SPEED_MAX)
		Upgrades.KIND_DIG:
			u.dig_level = clampi(u.dig_level + delta, 0, 20)
		Upgrades.KIND_SWARM:
			u.swarm_level = clampi(u.swarm_level + delta, 0, Upgrades.SWARM_MAX)
		Upgrades.KIND_RESEARCH:
			u.research_level = clampi(u.research_level + delta, 0, Upgrades.RESEARCH_MAX)
		Upgrades.KIND_CORE:
			if not legacy_core_upgrades(): return false
			var next := clampi(u.core_level + delta, 0, Upgrades.CORE_MAX)
			if next == u.core_level:
				return false
			if not _bind_core(next, next > u.core_level):
				return false
			u.core_level = next
		_:
			return false
	debug_modified = true
	return true


func debug_adjust_building(kind: int, delta: int) -> bool:
	if not debug_mode or absi(delta) != 1 or not buildings.allowed(config.mode, kind):
		return false
	if kind == Buildings.KIND_SOURCE:
		buildings.source_level = clampi(buildings.source_level + delta, 0, Buildings.SOURCE_TIER_MAX)
	elif kind == Buildings.KIND_REFINERY:
		buildings.refinery_level = clampi(buildings.refinery_level + delta, 0, Buildings.REFINERY_TIER_MAX)
	else:
		return false
	debug_modified = true
	return true


## Setzt Dots in einem einzigen BFS-Lauf statt 500 einzelne teure Spawn-Suchen.
## Die Masse wird regulär bilanziert; fehlender Platz begrenzt die tatsächlich erzeugten Dots.
func debug_spawn_workers(want: int) -> int:
	if not debug_mode or want <= 0:
		return 0
	var site: int = construction.production_site(0)
	var origin: int = construction.origin(self, site)
	if origin < 0:
		return 0
	var available := spawner.find_free_cells(
		world, workers, origin, mini(want, 2000), world.cell_count(), army.blockers(core_mask)
	)
	for cell in available:
		workers.add(cell, GroupQuotas.pick_group(workers.group_mass, quotas))
	purchased_workers += available.size()
	if not available.is_empty():
		debug_modified = true
	peak_mass = maxi(peak_mass, total_mass())
	max_units = maxi(max_units, workers.count)
	return available.size()


func buy(kind: int) -> bool:
	# Ordinary upgrades must be researched in a completed research center.
	if not debug_mode: return false
	if kind in [Upgrades.KIND_FUSION2, Upgrades.KIND_FUSION3]:
		return false
	if kind == Upgrades.KIND_RESEARCH:
		if config.mode != SimConfig.MODE_MATCH or (config.victory_mask & MatchRules.VICTORY_RESEARCH) == 0:
			return false
	if kind == Upgrades.KIND_CORE:
		return _buy_core()
	var before := upgrades.max_size()
	if not upgrades.try_buy(kind):
		return false
	if upgrades.max_size() < before:
		return true
	for g in desired_size.size():
		if desired_size[g] > upgrades.max_size():
			desired_size[g] = upgrades.max_size()
	return true


## Arbeiter werden ausschließlich gegen bereits gelieferte Energie gekauft.
## Der Spawn beginnt am zentralen Tunnel; die bestehende Warteschlange erhält die Masse.
## Setzt eine Quelle oder einen Veredler auf eine leere Tunnelzelle. Der Kern bleibt frei.
func place_energy_conduit(cell: int, faction: int = 0) -> bool:
	return energy_network.place(self, faction, cell)

func place_building(kind: int, idx: int) -> bool:
	if not buildings.allowed(config.mode, kind):
		return false
	var cost := buildings.place_cost(kind)
	if cost < 0 or upgrades.energy < cost or energy_network.owner_at(idx) >= 0 or not _cell_accepts_building(idx):
		return false
	upgrades.energy -= cost
	upgrades.purchased += 1
	buildings.add(kind, idx)
	return true


## Hebt die gemeinsame Stufe aller Quellen oder aller Veredler an.
func upgrade_building(kind: int) -> bool:
	if not buildings.allowed(config.mode, kind):
		return false
	var cost := buildings.tier_cost(kind)
	if cost < 0 or upgrades.energy < cost:
		return false
	upgrades.energy -= cost
	upgrades.purchased += 1
	buildings.raise_tier(kind)
	return true


func buy_worker(site: int = -1) -> bool:
	if not can_buy_worker() or upgrades.energy < WORKER_COST:
		return false
	site = construction.production_site(0, site)
	var origin: int = construction.origin(self, site)
	if origin < 0:
		return false
	upgrades.energy -= WORKER_COST
	purchased_workers += 1
	spawner.enqueue(origin, site)
	return true


func open_group_count() -> int:
	var total := 0
	for flag in group_open:
		total += int(flag)
	return total


## Ablage der Energie. Ohne Kern-Upgrade sind das die leeren Nachbarn des Kerns.
## Danach ist die ganze freie Fläche um den Kern die Ablage.
func energy_exits() -> PackedInt32Array:
	if not construction.sites.records.is_empty() and (upgrades.core_level <= 0 or construction.sites.records[0].rect.size != Vector2i.ONE): return construction.receivers(self, 0)
	if upgrades.core_level <= 0 or core_mask.is_empty():
		return _delivery_cells()
	var exits := PackedInt32Array()
	for idx in core_mask.size():
		if core_mask[idx] == 1 and world.cells[idx] == Materials.EMPTY:
			exits.append(idx)
	return exits


func pit_index() -> int:
	if _match_live():
		return rules.cores[0]
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


func _match_live() -> bool:
	return config.mode == SimConfig.MODE_MATCH and rules.faction_count > 1


func _worker_origin() -> int:
	if _match_live():
		var core := rules.cores[0]
		return world.find_nearest_empty(core % world.width, core / world.width)
	return world.find_nearest_empty(world.width / 2, world.height / 2)


func _goals_met() -> bool:
	# Alte Solo-Siegziele sind auf Nutzerwunsch deaktiviert.
	return false


func _cell_accepts_building(idx: int) -> bool:
	if idx < 0 or idx >= world.cell_count() or world.cells[idx] != Materials.EMPTY:
		return false
	if _in_core(idx) or buildings.occupies(idx):
		return false
	return true


func _building_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	if buildings.kind.size() != buildings.cell.size() or buildings.buds.size() != buildings.cell.size():
		errors.append("Gebäudelisten ungleich lang")
		return errors
	for i in buildings.cell.size():
		var idx := buildings.cell[i]
		if seen.has(idx):
			errors.append("zwei Gebäude auf einer Zelle")
		seen[idx] = true
		if idx < 0 or idx >= world.cell_count() or world.cells[idx] != Materials.EMPTY or _in_core(idx):
			errors.append("Gebäude steht nicht auf einem freien Tunnel")
		if not buildings.allowed(config.mode, int(buildings.kind[i])):
			errors.append("Gebäude passt nicht zum Modus")
		if int(buildings.kind[i]) == Buildings.KIND_SOURCE:
			for bud in buildings.buds[i]:
				if bud < 0 or bud >= world.cell_count() or not Materials.is_mineable(world.cells[bud]):
					errors.append("Knospe ist kein Material")
	return errors


func _in_core(idx: int) -> bool:
	return idx >= 0 and idx < core_mask.size() and core_mask[idx] == 1


## Räumt die nächste Kernfläche, legt den Ring frei und sperrt sie für Arbeiter.
## Schlägt die Räumung fehl, bleibt Welt und Guthaben unverändert.
func _buy_core() -> bool:
	if not legacy_core_upgrades(): return false
	var cost := upgrades.core_cost()
	if cost < 0 or upgrades.energy < cost:
		return false
	if not _bind_core(upgrades.core_level + 1, true):
		return false
	return upgrades.try_buy(Upgrades.KIND_CORE)


## Setzt die Kernfläche für eine Stufe. `apply_carve` legt neue Zellen leer, ohne sie als Abbau zu zählen.
func _bind_core(radius: int, apply_carve: bool) -> bool:
	var around := rules.cores[0] if _match_live() else -1
	var plan := CoreZone.plan(world, radius, around)
	var carve: PackedInt32Array = plan.carve if apply_carve else PackedInt32Array()
	if not _evict_workers(plan.mask, carve):
		return false
	if apply_carve:
		for idx in plan.carve:
			world.open_without_mining(idx)
	core_mask = plan.mask
	for field in fields:
		if config.mode != SimConfig.MODE_MATCH:
			field.blocked = core_mask
		field.force_rebuild()
	return true


func _footprint_hits_mask(id: int, mask: PackedByteArray) -> bool:
	if mask.is_empty():
		return false
	var unit_size := int(workers.size[id])
	var anchor := workers.cell[id]
	var width := world.width
	var x0 := anchor % width
	var y0 := anchor / width
	if x0 + unit_size > width or y0 + unit_size > world.height:
		return true
	for dy in unit_size:
		for dx in unit_size:
			var idx := anchor + dy * width + dx
			if idx < mask.size() and mask[idx] == 1:
				return true
	return false


## Verschiebt jeden Arbeiter, dessen Fußabdruck in der Maske liegt, auf eine Zelle außerhalb.
## Die Ziele werden zuerst vollständig gesucht. Erst dann wird bewegt.
func _evict_workers(mask: PackedByteArray, carve: PackedInt32Array) -> bool:
	if mask.is_empty():
		return true
	var count := world.cell_count()
	var will_open := PackedByteArray()
	will_open.resize(count)
	for idx in count:
		if world.cells[idx] == Materials.EMPTY:
			will_open[idx] = 1
	for idx in carve:
		will_open[idx] = 1
	var reserved := PackedByteArray()
	reserved.resize(count)
	for cell in army.cells: reserved[cell] = 1
	var movers: Array[int] = []
	for id in workers.count:
		if _footprint_hits_mask(id, mask):
			movers.append(id)
		else:
			_reserve_footprint(id, reserved)
	var plans := PackedInt32Array()
	for id in movers:
		var dest := _evac_destination(id, mask, will_open, reserved)
		if dest < 0:
			return false
		plans.append(id)
		plans.append(dest)
		_reserve_anchor(dest, int(workers.size[id]), reserved)
	var cursor := 0
	while cursor < plans.size():
		var id := plans[cursor]
		var dest := plans[cursor + 1]
		cursor += 2
		if int(workers.size[id]) <= 1:
			workers.move_to(id, dest, tick_count)
		else:
			workers.move_footprint(id, dest, tick_count)
	return true


func _evac_destination(
	id: int, mask: PackedByteArray, will_open: PackedByteArray, reserved: PackedByteArray
) -> int:
	var unit_size := int(workers.size[id])
	var origin := workers.cell[id]
	var stamp := PackedByteArray()
	stamp.resize(world.cell_count())
	var frontier := PackedInt32Array()
	frontier.append(origin)
	stamp[origin] = 1
	var head := 0
	var width := world.width
	var size := world.cell_count()
	while head < frontier.size():
		var c := frontier[head]
		head += 1
		if _footprint_evac_ok(c, unit_size, mask, will_open, reserved):
			return c
		var x := c % width
		if c >= width:
			_evac_push(frontier, stamp, will_open, c - width)
		if x < width - 1:
			_evac_push(frontier, stamp, will_open, c + 1)
		if c < size - width:
			_evac_push(frontier, stamp, will_open, c + width)
		if x > 0:
			_evac_push(frontier, stamp, will_open, c - 1)
	return -1


func _evac_push(
	frontier: PackedInt32Array, stamp: PackedByteArray, will_open: PackedByteArray, idx: int
) -> void:
	if stamp[idx] != 0 or will_open[idx] == 0:
		return
	stamp[idx] = 1
	frontier.append(idx)


func _footprint_evac_ok(
	anchor: int,
	unit_size: int,
	mask: PackedByteArray,
	will_open: PackedByteArray,
	reserved: PackedByteArray,
) -> bool:
	var width := world.width
	var x0 := anchor % width
	var y0 := anchor / width
	if x0 + unit_size > width or y0 + unit_size > world.height:
		return false
	for dy in unit_size:
		for dx in unit_size:
			var idx := anchor + dy * width + dx
			if mask[idx] == 1 or will_open[idx] == 0 or reserved[idx] == 1:
				return false
			if workers.occupant[idx] != WorkerStore.NO_WORKER:
				return false
	return true


func _reserve_footprint(id: int, reserved: PackedByteArray) -> void:
	_reserve_anchor(workers.cell[id], int(workers.size[id]), reserved)


func _reserve_anchor(anchor: int, unit_size: int, reserved: PackedByteArray) -> void:
	var width := world.width
	for dy in unit_size:
		for dx in unit_size:
			reserved[anchor + dy * width + dx] = 1


func worker_population(faction: int = 0) -> int:
	var total := spawner.pending() if faction == 0 else 0
	for id in workers.count:
		if int(workers.faction[id]) == faction: total += workers.mass[id]
	return total


func can_buy_worker(faction: int = 0) -> bool:
	return worker_population(faction) < SimConfig.MAX_WORKERS_PER_PLAYER


func buy_warrior(faction: int = 0, site: int = -1) -> bool:
	if faction < 0 or faction >= (rules.faction_count if _match_live() else 1): return false
	if _match_live() and rules.alive[faction] == 0: return false
	var wallet := rules.wallet(self, faction)
	if wallet.energy < Army.COST: return false
	site = construction.production_site(faction, site)
	var origin: int = construction.origin(self, site)
	if origin < 0: return false
	wallet.energy -= Army.COST
	army.queue.append({"origin": origin, "owner": faction, "ready": tick_count + Army.PRODUCTION_TICKS, "site": site})
	army.purchased += 1
	return true


func unit_cell(id: int) -> int:
	if id >= Army.TAG:
		var uid := id - Army.TAG
		return army.cells[army.slots[uid]] if army.slots.has(uid) else -1
	return workers.cell[id] if id >= 0 and id < workers.count else -1


func unit_owner(id: int) -> int:
	if id >= Army.TAG:
		var uid := id - Army.TAG
		return army.owners[army.slots[uid]] if army.slots.has(uid) else -1
	return int(workers.faction[id]) if id >= 0 and id < workers.count else -1

func legacy_core_upgrades() -> bool:
	for row in construction.sites.records:
		if not row.destroyed and row.owner == 0 and row.kind == 0:
			return row.rect.size == Vector2i.ONE
	return construction.sites.records.is_empty()

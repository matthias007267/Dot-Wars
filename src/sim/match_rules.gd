class_name MatchRules
extends RefCounted
## Mehrspieler gegen KI. Menschliche Gegner sind ein freier Platz, noch ohne Netz.
## Der Takt bleibt ganzzahlig. Die Schwierigkeit wählt den Plan der KI.

const CONTROL_HUMAN := 0
const CONTROL_AI := 1
const CONTROL_REMOTE := 2

const VICTORY_ELIMINATION := 1
const VICTORY_RESEARCH := 2
const VICTORY_RELICS := 4
const VICTORY_HILL := 8
const VICTORY_ALL := 15

const CORE_HP_MAX := 160
const RELIC_NEED := 3
const RELIC_CHANNEL := 100
const HILL_TICKS := 600
const AI_MIN_WORKERS := 4
const AI_CAP := 8

## Spieler gelb, dann Koralle, Himmel, Minze. Rot bleibt frei.
const FACTION_COLORS: Array[Color] = [
	Color8(0xFF, 0xE4, 0x5E),
	Color8(0xFF, 0x7A, 0x59),
	Color8(0x7E, 0xB6, 0xFF),
	Color8(0x5D, 0xDE, 0x9A),
]

var faction_count: int = 1
var control := PackedByteArray()
var cores := PackedInt32Array()
var core_hp := PackedInt32Array()
var alive := PackedByteArray()
var group_of := PackedInt32Array()
var group_faction := PackedByteArray()
var relic_cell := PackedInt32Array()
var relic_owner := PackedInt32Array()
var relic_progress := PackedInt32Array()
var hill_cell: int = -1
var hill_score := PackedInt32Array()
var ai_upgrades: Array[Upgrades] = []
var match_bought: int = 0
var removed_mass: int = 0
var winner_faction: int = -1
var win_kind: int = 0
## Index 0 bleibt 0. Jede KI trägt Leicht, Mittel oder Schwer.
var difficulty := PackedByteArray()


func wallet(sim: Simulation, faction: int) -> Upgrades:
	if faction <= 0 or faction - 1 >= ai_upgrades.size():
		return sim.upgrades
	return ai_upgrades[faction - 1]


func install(sim: Simulation) -> bool:
	if sim.config.ai_count < 1 or sim.config.ai_count > 3:
		return false
	faction_count = 1 + sim.config.ai_count
	control.resize(faction_count)
	control[0] = CONTROL_HUMAN
	cores.resize(faction_count)
	core_hp.resize(faction_count)
	core_hp.fill(CORE_HP_MAX)
	alive.resize(faction_count)
	alive.fill(1)
	hill_score.resize(faction_count)
	ai_upgrades.clear()
	for faction in range(1, faction_count):
		control[faction] = CONTROL_AI
		ai_upgrades.append(Upgrades.new())
	_assign_difficulty(sim.config.difficulty)
	var arm := sim.config.tunnel_arm_length
	var origins := _base_origins(sim.world.width, arm, faction_count)
	if origins.size() != faction_count:
		return false
	for faction in faction_count:
		var core := _carve_base(sim.world, origins[faction], arm)
		if core < 0:
			return false
		cores[faction] = core
	hill_cell = _open_objective(sim.world, sim.world.width / 2, sim.world.height / 2)
	if hill_cell < 0 or not _place_relics(sim.world):
		return false
	group_faction.resize(sim.quotas.size())
	group_faction.fill(0)
	group_of.resize(faction_count)
	group_of[0] = 0
	for faction in range(1, faction_count):
		var group_id := sim.add_group("KI %d" % faction)
		if group_id < 0:
			return false
		group_of[faction] = group_id
		group_faction.append(faction)
		sim.set_group_color(group_id, FACTION_COLORS[faction])
	for faction in faction_count:
		if not _place_workers(sim, faction):
			return false
	return true


func pulse(sim: Simulation) -> void:
	if sim.won or faction_count <= 1:
		return
	_ai(sim)
	_combat(sim)
	_relics(sim)
	_hill(sim)
	_victory(sim)


func credit_energy(sim: Simulation, before: PackedInt32Array) -> void:
	var now := sim.energy_dots.delivered_to
	for faction in faction_count:
		var prev := before[faction] if faction < before.size() else 0
		var current := now[faction] if faction < now.size() else 0
		if current > prev:
			wallet(sim, faction).energy += current - prev


func gates(sim: Simulation) -> Dictionary:
	var cells := PackedInt32Array()
	var owners := PackedByteArray()
	for cell in sim.energy_exits():
		cells.append(cell)
		owners.append(0)
	for faction in range(1, faction_count):
		for cell in SacrificeSystem.delivery_cells(sim.world, cores[faction]):
			cells.append(cell)
			owners.append(faction)
	return {"cells": cells, "owners": owners}


func worker_periods(sim: Simulation) -> PackedByteArray:
	var periods := PackedByteArray()
	periods.resize(faction_count)
	for faction in faction_count:
		periods[faction] = wallet(sim, faction).worker_period(sim.config.move_period_ticks)
	return periods


func energy_periods(sim: Simulation) -> PackedByteArray:
	var periods := PackedByteArray()
	periods.resize(faction_count)
	for faction in faction_count:
		periods[faction] = wallet(sim, faction).energy_period()
	return periods


func export_state() -> Dictionary:
	var ai: Array = []
	for upgrades in ai_upgrades:
		ai.append({
			"energy": upgrades.energy,
			"speed_level": upgrades.speed_level,
			"energy_speed": upgrades.energy_speed_level,
			"dig_level": upgrades.dig_level,
			"fusion2": upgrades.fusion2,
			"fusion3": upgrades.fusion3,
			"core_level": upgrades.core_level,
			"purchased": upgrades.purchased,
			"research_level": upgrades.research_level,
		})
	return {
		"factions": faction_count,
		"control": control.duplicate(),
		"cores": cores.duplicate(),
		"hp": core_hp.duplicate(),
		"alive": alive.duplicate(),
		"group_of": group_of.duplicate(),
		"group_faction": group_faction.duplicate(),
		"relics": relic_cell.duplicate(),
		"relic_owner": relic_owner.duplicate(),
		"relic_progress": relic_progress.duplicate(),
		"hill": hill_cell,
		"hill_score": hill_score.duplicate(),
		"ai": ai,
		"bought": match_bought,
		"removed": removed_mass,
		"winner": winner_faction,
		"kind": win_kind,
		"difficulty": difficulty.duplicate(),
	}


func restore(blob: Dictionary) -> bool:
	if blob.is_empty():
		return false
	faction_count = int(blob.get("factions", 1))
	if faction_count < 2 or faction_count > 4:
		return false
	control = _bytes(blob.get("control", PackedByteArray()))
	cores = _ints(blob.get("cores", PackedInt32Array()))
	core_hp = _ints(blob.get("hp", PackedInt32Array()))
	alive = _bytes(blob.get("alive", PackedByteArray()))
	group_of = _ints(blob.get("group_of", PackedInt32Array()))
	group_faction = _bytes(blob.get("group_faction", PackedByteArray()))
	relic_cell = _ints(blob.get("relics", PackedInt32Array()))
	relic_owner = _ints(blob.get("relic_owner", PackedInt32Array()))
	relic_progress = _ints(blob.get("relic_progress", PackedInt32Array()))
	hill_cell = int(blob.get("hill", -1))
	hill_score = _ints(blob.get("hill_score", PackedInt32Array()))
	match_bought = int(blob.get("bought", 0))
	removed_mass = int(blob.get("removed", 0))
	winner_faction = int(blob.get("winner", -1))
	win_kind = int(blob.get("kind", 0))
	_fit_difficulty(_bytes(blob.get("difficulty", PackedByteArray())))
	ai_upgrades.clear()
	var rows: Array = blob.get("ai", [])
	for row in rows:
		var upgrades := Upgrades.new()
		upgrades.energy = int(row.get("energy", 0))
		upgrades.speed_level = int(row.get("speed_level", 0))
		upgrades.energy_speed_level = int(row.get("energy_speed", 0))
		upgrades.dig_level = int(row.get("dig_level", 0))
		upgrades.fusion2 = bool(row.get("fusion2", false))
		upgrades.fusion3 = bool(row.get("fusion3", false))
		upgrades.core_level = int(row.get("core_level", 0))
		upgrades.purchased = int(row.get("purchased", 0))
		upgrades.research_level = int(row.get("research_level", 0))
		ai_upgrades.append(upgrades)
	return (
		control.size() == faction_count
		and cores.size() == faction_count
		and core_hp.size() == faction_count
		and alive.size() == faction_count
		and ai_upgrades.size() == faction_count - 1
	)


func state_hash() -> int:
	var wallets: Array = []
	for upgrades in ai_upgrades:
		wallets.append(upgrades.state_hash())
	return hash([
		faction_count,
		hash(control),
		hash(cores),
		hash(core_hp),
		hash(alive),
		hash(group_of),
		hash(group_faction),
		hash(relic_cell),
		hash(relic_owner),
		hash(relic_progress),
		hill_cell,
		hash(hill_score),
		wallets,
		match_bought,
		removed_mass,
		winner_faction,
		win_kind,
		hash(difficulty),
	])


static func victory_name(kind: int) -> String:
	match kind:
		VICTORY_ELIMINATION:
			return "Auslöschen"
		VICTORY_RESEARCH:
			return "Forschungssieg"
		VICTORY_RELICS:
			return "Reliquien"
		VICTORY_HILL:
			return "König des Hügels"
	return "Ziel"


static func outcome_text(faction: int, kind: int) -> String:
	var who := "Sieg" if faction == 0 else "Niederlage"
	return "%s durch %s" % [who, victory_name(kind)]


## Leicht, Mittel, Schwer oder gemischt, je nach den gesetzten KI-Plänen.
func difficulty_label() -> String:
	var seen := -1
	for faction in range(1, faction_count):
		var level := _plan(faction)
		if seen < 0:
			seen = level
		elif level != seen:
			return "gemischt"
	if seen < 0:
		return SimConfig.difficulty_name(SimConfig.DIFFICULTY_NORMAL)
	return SimConfig.difficulty_name(seen)


func _ai(sim: Simulation) -> void:
	for faction in range(1, faction_count):
		if alive[faction] == 0 or control[faction] != CONTROL_AI:
			continue
		var level := _plan(faction)
		if level == SimConfig.DIFFICULTY_EASY:
			_ai_easy(sim, faction)
		elif level == SimConfig.DIFFICULTY_HARD:
			_ai_hard(sim, faction)
		else:
			_ai_normal(sim, faction)


func _ai_easy(sim: Simulation, faction: int) -> void:
	var group_id := group_of[faction]
	var rects: Array = sim.areas.rects[group_id]
	if rects.is_empty():
		var origin := _base_origin_of(sim, faction)
		sim.assign_area(group_id, Rect2i(origin.x - 4, origin.y - 4, 9, 9))
	var upgrades := wallet(sim, faction)
	if _workers_of(sim, faction) < 3 and upgrades.energy >= 30 and sim.tick_count % 40 == 0:
		_buy_worker(sim, faction)


func _ai_normal(sim: Simulation, faction: int) -> void:
	var group_id := group_of[faction]
	var rects: Array = sim.areas.rects[group_id]
	if rects.is_empty():
		sim.assign_area(group_id, Rect2i(0, 0, sim.world.width, sim.world.height))
	var upgrades := wallet(sim, faction)
	var have := _workers_of(sim, faction)
	if have < AI_MIN_WORKERS and upgrades.energy >= Simulation.WORKER_COST:
		if _buy_worker(sim, faction):
			return
	var research := upgrades.research_cost()
	if (
		(sim.config.victory_mask & VICTORY_RESEARCH) != 0
		and research >= 0
		and upgrades.energy >= research
	):
		if upgrades.try_buy(Upgrades.KIND_RESEARCH):
			return
	if have < AI_CAP and upgrades.energy >= Simulation.WORKER_COST:
		_buy_worker(sim, faction)


func _ai_hard(sim: Simulation, faction: int) -> void:
	var group_id := group_of[faction]
	var rects: Array = sim.areas.rects[group_id]
	var aim := _objective_cell(sim, faction)
	if rects.is_empty():
		if aim < 0:
			sim.assign_area(group_id, Rect2i(0, 0, sim.world.width, sim.world.height))
		else:
			var origin := _base_origin_of(sim, faction)
			var ax := aim % sim.world.width
			var ay := aim / sim.world.width
			var x0 := mini(origin.x, ax) - 2
			var y0 := mini(origin.y, ay) - 2
			var x1 := maxi(origin.x, ax) + 2
			var y1 := maxi(origin.y, ay) + 2
			sim.assign_area(group_id, Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
	_aim_move(sim, faction)
	var upgrades := wallet(sim, faction)
	var have := _workers_of(sim, faction)
	var research := upgrades.research_cost()
	if (
		(sim.config.victory_mask & VICTORY_RESEARCH) != 0
		and have >= 4
		and research >= 0
		and upgrades.energy >= research
	):
		if upgrades.try_buy(Upgrades.KIND_RESEARCH):
			return
	if have < 6 and upgrades.energy >= Simulation.WORKER_COST:
		if _buy_worker(sim, faction):
			return
	var dig := upgrades.dig_cost()
	if upgrades.dig_level < 2 and dig >= 0 and upgrades.energy >= dig:
		if upgrades.try_buy(Upgrades.KIND_DIG):
			return
	var speed := upgrades.speed_cost()
	if upgrades.speed_level < 1 and speed >= 0 and upgrades.energy >= speed:
		if upgrades.try_buy(Upgrades.KIND_SPEED):
			return
	if have < 10 and upgrades.energy >= Simulation.WORKER_COST:
		_buy_worker(sim, faction)


func _buy_worker(sim: Simulation, faction: int) -> bool:
	var upgrades := wallet(sim, faction)
	if upgrades.energy < Simulation.WORKER_COST:
		return false
	var origin := _tunnel_near(sim, cores[faction])
	if origin < 0:
		return false
	var spot := sim.spawner.find_free_cell(sim.world, sim.workers, origin)
	if spot < 0:
		return false
	upgrades.energy -= Simulation.WORKER_COST
	match_bought += 1
	sim.workers.add(spot, group_of[faction], faction)
	return true


func _combat(sim: Simulation) -> void:
	var damage := PackedInt32Array()
	damage.resize(faction_count)
	var width := sim.world.width
	for id in sim.workers.count:
		var faction := int(sim.workers.faction[id])
		if faction >= faction_count or alive[faction] == 0:
			continue
		for other in faction_count:
			if other == faction or alive[other] == 0:
				continue
			if _touches_core(sim, id, cores[other], width):
				damage[other] += 1
	for faction in faction_count:
		if damage[faction] <= 0 or alive[faction] == 0:
			continue
		core_hp[faction] = maxi(0, core_hp[faction] - damage[faction])
		if core_hp[faction] == 0:
			_eliminate(sim, faction)


func _eliminate(sim: Simulation, faction: int) -> void:
	alive[faction] = 0
	var guard := 0
	while guard < 100000:
		guard += 1
		var found := -1
		for id in sim.workers.count:
			if int(sim.workers.faction[id]) == faction:
				found = id
				break
		if found < 0:
			break
		removed_mass += sim.workers.mass[found]
		sim.workers.remove_swap(found)
	if faction == 0:
		removed_mass += sim.spawner.pending()
		sim.spawner.import_queue(PackedInt32Array())
	for index in relic_owner.size():
		if relic_owner[index] == faction:
			relic_owner[index] = -1
			relic_progress[index] = 0


func _relics(sim: Simulation) -> void:
	if (sim.config.victory_mask & VICTORY_RELICS) == 0:
		return
	for index in relic_cell.size():
		var seen := _factions_on(sim, relic_cell[index])
		if seen.size() != 1:
			relic_progress[index] = 0
			continue
		var faction := int(seen[0])
		if relic_owner[index] == faction:
			relic_progress[index] = 0
			continue
		relic_progress[index] += 1
		if relic_progress[index] >= RELIC_CHANNEL:
			relic_owner[index] = faction
			relic_progress[index] = 0


func _hill(sim: Simulation) -> void:
	if (sim.config.victory_mask & VICTORY_HILL) == 0 or hill_cell < 0:
		return
	var seen := _factions_on(sim, hill_cell)
	if seen.size() == 1:
		hill_score[int(seen[0])] += 1


func _victory(sim: Simulation) -> void:
	if sim.won:
		return
	var mask := sim.config.victory_mask
	if (mask & VICTORY_ELIMINATION) != 0:
		var last := -1
		var living := 0
		for faction in faction_count:
			if alive[faction] != 0:
				living += 1
				last = faction
		if living == 1:
			_win(sim, last, VICTORY_ELIMINATION)
			return
	if (mask & VICTORY_RESEARCH) != 0:
		for faction in faction_count:
			if alive[faction] != 0 and wallet(sim, faction).research_level >= Upgrades.RESEARCH_MAX:
				_win(sim, faction, VICTORY_RESEARCH)
				return
	if (mask & VICTORY_RELICS) != 0:
		var owned := PackedInt32Array()
		owned.resize(faction_count)
		for owner in relic_owner:
			if owner >= 0 and owner < faction_count and alive[owner] != 0:
				owned[owner] += 1
		for faction in faction_count:
			if owned[faction] >= RELIC_NEED:
				_win(sim, faction, VICTORY_RELICS)
				return
	if (mask & VICTORY_HILL) != 0:
		for faction in faction_count:
			if alive[faction] != 0 and hill_score[faction] >= HILL_TICKS:
				_win(sim, faction, VICTORY_HILL)
				return


func _win(sim: Simulation, faction: int, kind: int) -> void:
	sim.won = true
	sim.win_tick = sim.tick_count
	winner_faction = faction
	win_kind = kind


func _factions_on(sim: Simulation, cell: int) -> PackedInt32Array:
	var seen := PackedInt32Array()
	for id in sim.workers.count:
		if not _covers(sim, id, cell):
			continue
		var faction := int(sim.workers.faction[id])
		if faction >= faction_count or alive[faction] == 0:
			continue
		var known := false
		for entry in seen:
			if entry == faction:
				known = true
				break
		if not known:
			seen.append(faction)
	return seen


func _covers(sim: Simulation, id: int, cell: int) -> bool:
	var unit_size := int(sim.workers.size[id])
	var anchor := sim.workers.cell[id]
	if unit_size <= 1:
		return anchor == cell
	var width := sim.world.width
	var dx := (cell % width) - (anchor % width)
	var dy := (cell / width) - (anchor / width)
	return dx >= 0 and dy >= 0 and dx < unit_size and dy < unit_size


func _workers_of(sim: Simulation, faction: int) -> int:
	var total := 0
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) == faction:
			total += 1
	return total


func _place_workers(sim: Simulation, faction: int) -> bool:
	var origin := _tunnel_near(sim, cores[faction])
	if origin < 0:
		return false
	var spots := sim.spawner.find_free_cells(
		sim.world, sim.workers, origin, sim.config.initial_workers, sim.world.cell_count()
	)
	if spots.size() < sim.config.initial_workers:
		return false
	for cell in spots:
		if faction == 0:
			var group_id := GroupQuotas.pick_group(sim.workers.group_mass, sim.quotas)
			sim.workers.add(cell, group_id, 0)
		else:
			sim.workers.add(cell, group_of[faction], faction)
	return true


func _tunnel_near(sim: Simulation, core: int) -> int:
	var gates := SacrificeSystem.delivery_cells(sim.world, core)
	if not gates.is_empty():
		return gates[0]
	return sim.world.find_nearest_empty(core % sim.world.width, core / sim.world.width)


func _place_relics(world: WorldState) -> bool:
	var cx := world.width / 2
	var cy := world.height / 2
	var spots: Array[Vector2i] = [
		Vector2i(cx - 2, cy),
		Vector2i(cx + 2, cy),
		Vector2i(cx, cy - 2),
		Vector2i(cx, cy + 2),
		Vector2i(cx + 3, cy),
	]
	relic_cell.resize(spots.size())
	relic_owner.resize(spots.size())
	relic_owner.fill(-1)
	relic_progress.resize(spots.size())
	for index in spots.size():
		var spot := spots[index]
		if not world.in_bounds(spot.x, spot.y):
			return false
		var idx := _open_objective(world, spot.x, spot.y)
		if idx < 0 or idx == hill_cell:
			return false
		relic_cell[index] = idx
	return true


func _open_objective(world: WorldState, x: int, y: int) -> int:
	if not world.in_bounds(x, y):
		return -1
	var idx := world.index(x, y)
	if world.cells[idx] == Materials.INDESTRUCTIBLE:
		return -1
	if world.cells[idx] != Materials.EMPTY:
		world.open_without_mining(idx)
	if world.cells[idx] != Materials.EMPTY:
		return -1
	return idx


func _carve_base(world: WorldState, origin: Vector2i, arm: int) -> int:
	var core_x := origin.x + 1
	var core_y := origin.y + 1
	if not world.in_bounds(origin.x, origin.y) or not world.in_bounds(core_x, core_y):
		return -1
	world.carve_rect(Rect2i(origin.x - arm, origin.y, arm * 2 + 1, 1))
	world.carve_rect(Rect2i(origin.x, origin.y - arm, 1, arm * 2 + 1))
	var core := world.index(core_x, core_y)
	world.set_material(core, Materials.INDESTRUCTIBLE)
	return core


func _assign_difficulty(chosen: int) -> void:
	difficulty = PackedByteArray()
	difficulty.resize(faction_count)
	var ai := faction_count - 1
	var shared := chosen
	if chosen == SimConfig.DIFFICULTY_MIXED:
		shared = SimConfig.DIFFICULTY_NORMAL if ai <= 1 else -1
	if shared >= 0:
		for faction in range(1, faction_count):
			difficulty[faction] = shared
		return
	if ai == 2:
		difficulty[1] = SimConfig.DIFFICULTY_EASY
		difficulty[2] = SimConfig.DIFFICULTY_HARD
		return
	difficulty[1] = SimConfig.DIFFICULTY_EASY
	difficulty[2] = SimConfig.DIFFICULTY_NORMAL
	if faction_count > 3:
		difficulty[3] = SimConfig.DIFFICULTY_HARD


func _fit_difficulty(stored: PackedByteArray) -> void:
	difficulty = PackedByteArray()
	difficulty.resize(faction_count)
	difficulty.fill(SimConfig.DIFFICULTY_NORMAL)
	difficulty[0] = 0
	if stored.size() != faction_count:
		return
	for faction in range(1, faction_count):
		var level := int(stored[faction])
		if (
			level == SimConfig.DIFFICULTY_EASY
			or level == SimConfig.DIFFICULTY_NORMAL
			or level == SimConfig.DIFFICULTY_HARD
		):
			difficulty[faction] = level


func _plan(faction: int) -> int:
	if faction < 0 or faction >= difficulty.size():
		return SimConfig.DIFFICULTY_NORMAL
	return int(difficulty[faction])


func _base_origin_of(sim: Simulation, faction: int) -> Vector2i:
	var core := cores[faction]
	return Vector2i(core % sim.world.width - 1, core / sim.world.width - 1)


func _objective_cell(sim: Simulation, faction: int) -> int:
	var mask := sim.config.victory_mask
	if (mask & VICTORY_ELIMINATION) != 0:
		var enemy := _nearest_living_enemy_core(sim, faction)
		if enemy >= 0:
			return enemy
	if (mask & VICTORY_RELICS) != 0:
		var relic := _nearest_relic(sim, faction)
		if relic >= 0:
			return relic
	if (mask & VICTORY_HILL) != 0 and hill_cell >= 0:
		return hill_cell
	return -1


func _aim_move(sim: Simulation, faction: int) -> void:
	var mask := sim.config.victory_mask
	var cell := -1
	if (mask & VICTORY_ELIMINATION) != 0:
		var enemy := _nearest_living_enemy_core(sim, faction)
		if enemy >= 0:
			cell = _attack_cell(sim, enemy, faction)
	elif (mask & VICTORY_RELICS) != 0:
		cell = _nearest_relic(sim, faction)
	elif (mask & VICTORY_HILL) != 0:
		cell = hill_cell
	if cell >= 0:
		sim.set_move_goal(group_of[faction], cell)


func _nearest_living_enemy_core(sim: Simulation, faction: int) -> int:
	var origin := _base_origin_of(sim, faction)
	return _nearest_cell(sim, origin, _enemy_cores(faction))


func _nearest_relic(sim: Simulation, faction: int) -> int:
	var origin := _base_origin_of(sim, faction)
	var cells := PackedInt32Array()
	for index in relic_cell.size():
		if relic_owner[index] != faction:
			cells.append(relic_cell[index])
	return _nearest_cell(sim, origin, cells)


func _enemy_cores(faction: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for other in faction_count:
		if other != faction and alive[other] != 0:
			cells.append(cores[other])
	return cells


func _nearest_cell(sim: Simulation, origin: Vector2i, cells: PackedInt32Array) -> int:
	var best := -1
	var best_dist := 1 << 30
	var width := sim.world.width
	for cell in cells:
		var dist := absi((cell % width) - origin.x) + absi((cell / width) - origin.y)
		if dist < best_dist or (dist == best_dist and (best < 0 or cell < best)):
			best = cell
			best_dist = dist
	return best


func _attack_cell(sim: Simulation, core: int, faction: int) -> int:
	return _nearest_cell(sim, _base_origin_of(sim, faction), SacrificeSystem.delivery_cells(sim.world, core))


func _base_origins(size: int, arm: int, count: int) -> Array[Vector2i]:
	var inset := arm + 3
	var mid := size / 2
	var spots: Array[Vector2i] = [
		Vector2i(inset, mid),
		Vector2i(size - 1 - inset, mid),
		Vector2i(mid, inset),
		Vector2i(mid, size - 1 - inset),
	]
	var result: Array[Vector2i] = []
	if count > spots.size():
		return result
	for index in count:
		result.append(spots[index])
	return result


func _touches_core(sim: Simulation, id: int, core: int, width: int) -> bool:
	var unit_size := int(sim.workers.size[id])
	var anchor := sim.workers.cell[id]
	for dy in unit_size:
		for dx in unit_size:
			if _orthogonal(anchor + dy * width + dx, core, width):
				return true
	return false


func _orthogonal(a: int, b: int, width: int) -> bool:
	if a < 0 or b < 0:
		return false
	var delta := absi(a - b)
	return delta == width or (delta == 1 and a / width == b / width)


func _bytes(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		return (value as PackedByteArray).duplicate()
	return PackedByteArray()


func _ints(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		return (value as PackedInt32Array).duplicate()
	return PackedInt32Array()

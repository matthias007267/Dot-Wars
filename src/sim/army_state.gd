class_name ArmyState
extends RefCounted
## Vorläufiger spielbarer Nahkampf-Prototyp. Dichte Slots, dauerhafte Krieger-IDs.
const COST := 20
const HEALTH := 12
const DAMAGE := 1
const ATTACK_PERIOD := 10
const MOVE_PERIOD := 2
const PRODUCTION_TICKS := 20
const DEFENCE_RADIUS := 3
const TAG := 1000000000
const Native = preload("res://src/sim/native_search.gd")

## Transient presentation events; never saved or included in deterministic state.
signal combat_attack(uid: int)
signal combat_hit(cell: int, owner: int)
signal combat_death(cell: int, owner: int, warrior: bool)

var ids := PackedInt32Array()
var cells := PackedInt32Array()
var owners := PackedByteArray()
var hp := PackedInt32Array()
var goals := PackedInt32Array()
var next_move := PackedInt32Array()
var last_attack := PackedInt32Array()
var occupant := PackedInt32Array()
var slots := {}
var next_id := 0
var purchased := 0
var lost := 0
var queue: Array[Dictionary] = []
var teams := PackedInt32Array([0, 1, 2, 3])
var _paths := {}
var _revision := -1
## Diagnostic only: one shared field per goal/terrain, never one per warrior.
var field_builds := 0
var reference_only := false
var native_steps := 0
var profile_enabled := false
var profile_usec := PackedInt64Array([0, 0, 0, 0, 0])
var count: int:
	get: return ids.size()


func setup(cell_count: int) -> void:
	occupant.resize(cell_count)
	occupant.fill(-1)


func allied(a: int, b: int) -> bool:
	return a == b or (a >= 0 and b >= 0 and a < teams.size() and b < teams.size() and teams[a] == teams[b])


func add(cell: int, owner: int, account := true) -> int:
	if cell < 0 or cell >= occupant.size() or occupant[cell] != -1 or owner < 0 or owner > 255 or next_id >= TAG:
		return -1
	var uid := next_id
	next_id += 1
	slots[uid] = count
	ids.append(uid)
	cells.append(cell)
	owners.append(owner)
	hp.append(HEALTH)
	goals.append(-1)
	next_move.append(0)
	last_attack.append(-ATTACK_PERIOD)
	occupant[cell] = uid
	if account: purchased += 1
	return uid


func remove(uid: int) -> void:
	if not slots.has(uid): return
	var index: int = slots[uid]
	occupant[cells[index]] = -1
	var last := count - 1
	if index != last:
		ids[index] = ids[last]
		cells[index] = cells[last]
		owners[index] = owners[last]
		hp[index] = hp[last]
		goals[index] = goals[last]
		next_move[index] = next_move[last]
		last_attack[index] = last_attack[last]
		slots[ids[index]] = index
	for values in [ids, cells, owners, hp, goals, next_move, last_attack]: values.resize(last)
	slots.erase(uid)
	lost += 1


func population(owner: int) -> int:
	var total := 0
	for value in owners:
		if value == owner: total += 1
	for item in queue:
		if int(item.owner) == owner: total += 1
	return total


func eliminate(owner: int) -> void:
	for index in range(count - 1, -1, -1):
		if owners[index] == owner: remove(ids[index])
	for index in range(queue.size() - 1, -1, -1):
		if int(queue[index].owner) == owner:
			queue.remove_at(index)
			lost += 1


func command(selected: PackedInt32Array, goal: int, owner := 0) -> bool:
	if goal < 0 or goal >= occupant.size(): return false
	var changed := false
	for tagged in selected:
		var uid := tagged - TAG
		if slots.has(uid) and owners[slots[uid]] == owner:
			goals[slots[uid]] = goal
			changed = true
	return changed


func blockers(base: PackedByteArray) -> PackedByteArray:
	if count == 0: return base
	var result := base.duplicate()
	result.resize(occupant.size())
	for cell in cells: result[cell] = 1
	return result


func step(sim: Simulation) -> void:
	var stamp := Time.get_ticks_usec() if profile_enabled else 0
	_spawn(sim)
	if profile_enabled: profile_usec[0] += Time.get_ticks_usec() - stamp
	if count == 0: return
	if _revision != sim.world.revision:
		_paths.clear()
		_revision = sim.world.revision
	if not reference_only and not profile_enabled and _native_step(sim): return
	var worker_damage := {}
	var warrior_damage := {}
	# Stable IDs define order even after dense slot removal.
	var order := ids.duplicate()
	order.sort()
	for uid in order:
		var index: int = slots[uid]
		var cell := cells[index]
		if profile_enabled: stamp = Time.get_ticks_usec()
		var enemy := _enemy(sim, index, 1)
		if profile_enabled: profile_usec[1] += Time.get_ticks_usec() - stamp
		if not enemy.is_empty():
			if sim.tick_count - last_attack[index] >= ATTACK_PERIOD:
				last_attack[index] = sim.tick_count
				var damage: Dictionary = warrior_damage if bool(enemy.warrior) else worker_damage
				damage[int(enemy.id)] = int(damage.get(int(enemy.id), 0)) + DAMAGE
			continue
		if sim.tick_count < next_move[index]: continue
		if profile_enabled: stamp = Time.get_ticks_usec()
		var goal := goals[index]
		var local_pursuit := false
		if (sim.tick_count + uid) % 5 == 0:
			enemy = _enemy(sim, index, DEFENCE_RADIUS)
			if not enemy.is_empty():
				goal = int(enemy.cell)
				local_pursuit = true
		if goal < 0 and sim.config.mode == SimConfig.MODE_MATCH and owners[index] > 0 and sim.rules.control[owners[index]] == MatchRules.CONTROL_AI:
			goal = sim.rules._nearest_living_enemy_core(sim, owners[index])
			if goal >= 0: goal = sim.rules._attack_cell(sim, goal, owners[index])
		if profile_enabled: profile_usec[2] += Time.get_ticks_usec() - stamp
		if goal < 0 or goal == cell: continue
		if profile_enabled: stamp = Time.get_ticks_usec()
		var route: Variant = _local_field(cell, goal, sim.world) if local_pursuit else _field(goal, sim.world)
		if int(route.get(cell, -1) if local_pursuit else route[cell]) < 0: continue
		for direction in range(1, 5):
			var dest := MovementSystem.neighbor(cell, direction, sim.world.width, sim.world.cell_count())
			var distance := 1
			var previous := cell
			# Own workers can be crossed, never used as a standing destination.
			while dest >= 0 and occupant[dest] == -1 and sim.world.cells[dest] == Materials.EMPTY:
				var destination_distance: int = route.get(dest, -1) if local_pursuit else route[dest]
				var previous_distance: int = route.get(previous, -1) if local_pursuit else route[previous]
				if destination_distance < 0 or destination_distance >= previous_distance: break
				var worker := sim.workers.occupant[dest]
				if worker < 0:
					occupant[cell] = -1
					occupant[dest] = uid
					cells[index] = dest
					next_move[index] = sim.tick_count + MOVE_PERIOD * distance
					break
				if sim.workers.faction[worker] != owners[index]: break
				previous = dest
				dest = MovementSystem.neighbor(dest, direction, sim.world.width, sim.world.cell_count())
				distance += 1
			if cells[index] != cell: break
		if profile_enabled: profile_usec[3] += Time.get_ticks_usec() - stamp
	if profile_enabled: stamp = Time.get_ticks_usec()
	_apply_damage(sim, worker_damage, warrior_damage)
	if profile_enabled: profile_usec[4] += Time.get_ticks_usec() - stamp


func _enemy(sim: Simulation, index: int, radius: int) -> Dictionary:
	var origin := cells[index]
	var width := sim.world.width
	var ox := origin % width
	var oy := origin / width
	var best := {}
	var rank := 2147483647
	for y in range(maxi(0, oy - radius), mini(sim.world.height, oy + radius + 1)):
		for x in range(maxi(0, ox - radius), mini(width, ox + radius + 1)):
			var distance := absi(x - ox) + absi(y - oy)
			if distance == 0 or distance > radius: continue
			var cell := y * width + x
			var uid := occupant[cell]
			if uid >= 0 and not allied(owners[index], owners[slots[uid]]) and distance * 2 < rank:
				rank = distance * 2
				best = {"warrior": true, "id": uid, "cell": cell}
			var worker := sim.workers.occupant[cell]
			if worker >= 0 and not allied(owners[index], sim.workers.faction[worker]) and distance * 2 + 1 < rank:
				rank = distance * 2 + 1
				best = {"warrior": false, "id": worker, "cell": cell}
	return best


func _apply_damage(sim: Simulation, workers_hit: Dictionary, warriors_hit: Dictionary, announce_attacks := true) -> void:
	# Both arithmetic backends meet here before simultaneous damage/removal.
	# Adjacent enemies cannot move during the army step. A viewer can recover
	# a target with the same selector, after culling hidden/offscreen/full effects.
	if announce_attacks and (not workers_hit.is_empty() or not warriors_hit.is_empty()) and not combat_attack.get_connections().is_empty():
		for index in count:
			if last_attack[index] != sim.tick_count: continue
			combat_attack.emit(ids[index])
	for uid in warriors_hit:
		if slots.has(uid):
			combat_hit.emit(cells[slots[uid]], owners[slots[uid]])
			hp[slots[uid]] -= int(warriors_hit[uid])
	for id in workers_hit:
		combat_hit.emit(sim.workers.cell[id], sim.workers.faction[id])
		sim.workers.health[id] -= int(workers_hit[id])
	for index in range(count - 1, -1, -1):
		if hp[index] <= 0:
			combat_death.emit(cells[index], owners[index], true)
			remove(ids[index])
	for id in range(sim.workers.count - 1, -1, -1):
		if sim.workers.health[id] > 0: continue
		combat_death.emit(sim.workers.cell[id], sim.workers.faction[id], false)
		sim.worker_losses += sim.workers.mass[id]
		var last := sim.workers.count - 1
		var selection := PackedInt32Array()
		for selected in sim.picked:
			if selected != id: selection.append(id if selected == last else selected)
		sim.picked = selection
		sim.workers.remove_swap(id)


func _spawn(sim: Simulation) -> void:
	if queue.is_empty(): return
	# Built on the first due item only; waiting queues no longer copy the map each tick.
	var mask := PackedByteArray()
	var remaining: Array[Dictionary] = []
	for item in queue:
		var site := int(item.get("site", -1))
		if site >= 0:
			if not sim.construction.sites.valid(site):
				lost += 1
				continue
			item.origin = sim.construction.origin(sim, site)
		if sim.tick_count < int(item.ready):
			remaining.append(item)
			continue
		if mask.is_empty():
			mask = blockers(sim.core_mask if sim.config.mode != SimConfig.MODE_MATCH else PackedByteArray()).duplicate()
			mask.resize(sim.world.cell_count())
		var spot := sim.spawner.find_free_cell(sim.world, sim.workers, int(item.origin), mask)
		if spot < 0:
			remaining.append(item)
			continue
		add(spot, int(item.owner), false)
		mask[spot] = 1
	queue = remaining

func _field(goal: int, world: WorldState) -> PackedInt32Array:
	if _paths.has(goal): return _paths[goal]
	field_builds += 1
	var dist := PackedInt32Array()
	dist.resize(world.cell_count())
	dist.fill(-1)
	var frontier := PackedInt32Array()
	if goal >= 0 and goal < world.cell_count():
		if world.cells[goal] == Materials.EMPTY:
			dist[goal] = 0
			frontier.append(goal)
		else:
			for direction in range(1, 5):
				var cell := MovementSystem.neighbor(goal, direction, world.width, world.cell_count())
				if cell >= 0 and world.cells[cell] == Materials.EMPTY:
					dist[cell] = 0
					frontier.append(cell)
	var native := Native.backend()
	if native != null:
		var dirs := PackedByteArray()
		dirs.resize(world.cell_count())
		var result: Array = native.flow_spread(world.cells, PackedByteArray(), dist, dirs, frontier, 0, 1 << 40, false, world.width)
		dist = result[0]
	else:
		var head := 0
		while head < frontier.size():
			var cell := frontier[head]
			head += 1
			for direction in range(1, 5):
				var next := MovementSystem.neighbor(cell, direction, world.width, world.cell_count())
				if next >= 0 and dist[next] < 0 and world.cells[next] == Materials.EMPTY:
					dist[next] = dist[cell] + 1
					frontier.append(next)
	_fill_disconnected(dist, goal, world)
	if _paths.size() >= 16: _paths.erase(_paths.keys()[0])
	_paths[goal] = dist
	return dist


## Each isolated free component gets its nearest stands. Equal goal distance
## seeds all candidates, giving each warrior the shortest free walk to one of them.
func _fill_disconnected(dist: PackedInt32Array, goal: int, world: WorldState) -> void:
	if goal < 0 or goal >= world.cell_count(): return
	for origin in world.cell_count():
		if world.cells[origin] != Materials.EMPTY or dist[origin] != -1: continue
		var component := PackedInt32Array([origin])
		dist[origin] = -2
		var rank := _goal_distance(origin, goal, world.width)
		var head := 0
		while head < component.size():
			var cell := component[head]
			head += 1
			var candidate := _goal_distance(cell, goal, world.width)
			rank = mini(rank, candidate)
			for direction in range(1, 5):
				var next := MovementSystem.neighbor(cell, direction, world.width, world.cell_count())
				if next >= 0 and dist[next] == -1 and world.cells[next] == Materials.EMPTY:
					dist[next] = -2
					component.append(next)
		var frontier := PackedInt32Array()
		for cell in component:
			if _goal_distance(cell, goal, world.width) == rank:
				dist[cell] = 0
				frontier.append(cell)
		head = 0
		while head < frontier.size():
			var cell := frontier[head]
			head += 1
			for direction in range(1, 5):
				var next := MovementSystem.neighbor(cell, direction, world.width, world.cell_count())
				if next >= 0 and dist[next] == -2:
					dist[next] = dist[cell] + 1
					frontier.append(next)


func _goal_distance(cell: int, goal: int, width: int) -> int:
	return absi(cell % width - goal % width) + absi(cell / width - goal / width)


func snapshot() -> Dictionary:
	var units: Array[Dictionary] = []
	for index in count:
		units.append({"id": ids[index], "cell": cells[index], "owner": owners[index], "hp": hp[index], "goal": goals[index], "move": next_move[index], "attack": last_attack[index]})
	return {"units": units, "queue": queue.duplicate(true), "next": next_id, "purchased": purchased, "lost": lost, "teams": teams.duplicate()}


func restore(data: Dictionary, world: WorldState, workers: WorkerStore) -> bool:
	if not data.get("units", []) is Array or not data.get("queue", []) is Array or not data.get("teams", PackedInt32Array([0, 1, 2, 3])) is PackedInt32Array: return false
	for row in data.get("units", []):
		if not row is Dictionary: return false
		var uid := int(row.get("id", -1))
		var cell := int(row.get("cell", -1))
		var owner := int(row.get("owner", -1))
		if uid < 0 or uid >= TAG or slots.has(uid) or cell < 0 or cell >= world.cell_count() or world.cells[cell] != Materials.EMPTY or workers.occupant[cell] >= 0 or owner < 0 or owner > 3: return false
		var index := count
		next_id = uid
		if add(cell, owner, false) < 0: return false
		hp[index] = int(row.get("hp", HEALTH))
		goals[index] = int(row.get("goal", -1))
		next_move[index] = int(row.get("move", 0))
		last_attack[index] = int(row.get("attack", -ATTACK_PERIOD))
		if hp[index] <= 0 or hp[index] > HEALTH or goals[index] < -1 or goals[index] >= world.cell_count(): return false
	next_id = int(data.get("next", next_id))
	for uid in ids:
		if next_id <= uid: return false
	if next_id < 0 or next_id >= TAG: return false
	for row in data.get("queue", []):
		if not row is Dictionary or int(row.get("origin", -1)) < 0 or int(row.get("origin", -1)) >= world.cell_count() or int(row.get("owner", -1)) < 0 or int(row.get("owner", -1)) > 3 or int(row.get("ready", -1)) < 0: return false
		queue.append(row.duplicate())
	purchased = int(data.get("purchased", count + queue.size()))
	lost = int(data.get("lost", 0))
	teams = data.get("teams", PackedInt32Array([0, 1, 2, 3])).duplicate()
	return purchased >= 0 and lost >= 0 and purchased - lost == count + queue.size() and teams.size() == 4


func state_hash() -> int:
	return hash([hash(ids), hash(cells), hash(owners), hash(hp), hash(goals), hash(next_move), hash(last_attack), queue, next_id, purchased, lost, hash(teams)])


## Defence only needs a bounded neighbourhood, never a full-world BFS per enemy.
## Obstacles use the same cardinal terrain rules as march fields.
func _local_field(origin: int, goal: int, world: WorldState) -> Dictionary:
	var distances := {goal: 0}
	var frontier := PackedInt32Array([goal])
	var cursor := 0
	var ox := origin % world.width
	var oy := origin / world.width
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if cell == origin: break
		for direction in range(1, 5):
			var next := MovementSystem.neighbor(cell, direction, world.width, world.cell_count())
			if next < 0 or distances.has(next) or world.cells[next] != Materials.EMPTY: continue
			if absi(next % world.width - ox) + absi(next / world.width - oy) > DEFENCE_RADIUS: continue
			distances[next] = int(distances[cell]) + 1
			frontier.append(next)
	return distances

## Optional native arithmetic; old binaries use the current reference rules.
func _native_step(sim: Simulation) -> bool:
	if "--army-reference" in OS.get_cmdline_user_args(): return false
	var native := Native.backend()
	# Older DLLs stop at disconnected goals; use the current reference instead.
	if native == null or not native.has_method("army_step_reachable"): return false
	var ai_goals := PackedInt32Array([-1, -1, -1, -1])
	if sim.config.mode == SimConfig.MODE_MATCH:
		for owner in range(1, sim.rules.faction_count):
			if sim.rules.control[owner] == MatchRules.CONTROL_AI:
				ai_goals[owner] = sim.rules._nearest_living_enemy_core(sim, owner)
				if ai_goals[owner] >= 0: ai_goals[owner] = sim.rules._attack_cell(sim, ai_goals[owner], owner)
	var result: Variant = native.call("army_step_reachable", [
		ids, cells, owners, goals, next_move, last_attack, occupant,
		sim.workers.occupant, sim.workers.faction, teams, ai_goals, PackedInt32Array(),
		PackedInt32Array([DAMAGE, ATTACK_PERIOD, MOVE_PERIOD, DEFENCE_RADIUS, 5]),
	], [], sim.world.cells, sim.world.width, sim.tick_count)
	if not result is Array or result.size() != 6: return false
	cells = result[0]
	next_move = result[1]
	last_attack = result[2]
	occupant = result[3]
	var warrior_damage := {}
	var worker_damage := {}
	var hits: PackedInt32Array = result[4]
	for index in range(0, hits.size(), 2): warrior_damage[hits[index]] = hits[index + 1]
	hits = result[5]
	for index in range(0, hits.size(), 2): worker_damage[hits[index]] = hits[index + 1]
	_apply_damage(sim, worker_damage, warrior_damage)
	native_steps += 1
	return true

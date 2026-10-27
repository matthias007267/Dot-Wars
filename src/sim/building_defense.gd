class_name BuildingDefense
extends RefCounted
## Authoritative weapons with prepaid 60-second upkeep and individual tower upgrades.
const Store = preload("res://src/sim/settlement_store.gd")
const UPKEEP_TICKS := 1200
const UPGRADE_TICKS := 200
const UPGRADE_COST := [0, 150, 300]
var weapons: Dictionary = {}
var projectiles: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var upkeep_spent := 0

func armed(row: Dictionary) -> bool:
	return not row.destroyed and row.ready and int(row.kind) in [0, 1, 4]

func level(row: Dictionary) -> int:
	return int(row.get("weapon_level", 1)) if int(row.kind) == 4 else 0

func stats(row: Dictionary) -> Dictionary:
	var tier := level(row)
	return {"range": 5 if tier == 0 else 8 if tier == 3 else 7,
		"period": 30 if tier == 0 else 20 if tier == 1 else 10 if tier == 2 else 4,
		"damage": 2 if tier in [1, 2] else 1, "beam": tier == 3}

func upgrade_cost(row: Dictionary) -> int:
	var tier := level(row)
	return UPGRADE_COST[tier] if int(row.kind) == 4 and tier < 3 else -1

func can_upgrade(sim: Simulation, site: int, owner := 0) -> bool:
	if not sim.construction.sites.valid(site): return false
	var row: Dictionary = sim.construction.sites.records[site]
	return armed(row) and row.owner == owner and row.kind == 4 and level(row) < 3 and int(row.get("weapon_upgrade", -1)) < 0 and not sim.construction.demolitions.has(site) and sim.rules.wallet(sim, owner).energy >= upgrade_cost(row)

func upgrade(sim: Simulation, site: int, owner := 0) -> bool:
	if not can_upgrade(sim, site, owner): return false
	var row: Dictionary = sim.construction.sites.records[site]
	sim.rules.wallet(sim, owner).energy -= upgrade_cost(row)
	row.weapon_upgrade = sim.tick_count + UPGRADE_TICKS
	sim.construction.sites.revision += 1
	return true

func _valid(sim: Simulation, site: int) -> bool:
	return sim.construction.sites.valid(site) and armed(sim.construction.sites.records[site])

func upkeep_cost(row: Dictionary) -> int:
	return 100 if int(row.kind) == 4 else 25

func reserve(sim: Simulation, owner: int) -> int:
	var amount := 0
	for row in sim.construction.sites.records:
		if row.destroyed or int(row.owner) != owner or int(row.kind) != 4: continue
		if int(weapons.get(row.id, {}).get("paid_until", 0)) <= sim.tick_count: amount += upkeep_cost(row)
	return amount

func is_powered(sim: Simulation, site: int) -> bool:
	return _valid(sim, site) and int(weapons.get(site, {}).get("paid_until", 0)) > sim.tick_count and sim.energy_network.source_site(sim, site) >= 0

func remove_site(site: int) -> void:
	weapons.erase(site)
	for index in range(beams.size() - 1, -1, -1):
		if int(beams[index].site) == site: beams.remove_at(index)

func _distance(a: int, b: int, width: int) -> int:
	return absi(a % width - b % width) + absi(a / width - b / width)

func _open(sim: Simulation, row: Dictionary, cell: int) -> bool:
	return sim.world.cells[cell] == Materials.EMPTY or (not row.destroyed and sim.construction.at(cell) == int(row.id))

func ray(origin: int, target: int, width: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	var x := origin % width
	var y := origin / width
	var tx := target % width
	var ty := target / width
	var dx := absi(tx - x)
	var dy := -absi(ty - y)
	var sx := 1 if x < tx else -1
	var sy := 1 if y < ty else -1
	var error := dx + dy
	while x != tx or y != ty:
		var twice := error * 2
		if twice >= dy:
			error += dy
			x += sx
		if twice <= dx:
			error += dx
			y += sy
		result.append(y * width + x)
	return result

func clear_line(sim: Simulation, row: Dictionary, origin: int, target: int) -> bool:
	var previous := origin
	for cell in ray(origin, target, sim.world.width):
		if not _open(sim, row, cell): return false
		if cell % sim.world.width != previous % sim.world.width and cell / sim.world.width != previous / sim.world.width:
			# Solid corners cannot be threaded by a diagonal projectile/beam.
			if not _open(sim, row, previous / sim.world.width * sim.world.width + cell % sim.world.width): return false
			if not _open(sim, row, cell / sim.world.width * sim.world.width + previous % sim.world.width): return false
		previous = cell
	return true

func _target_valid(sim: Simulation, row: Dictionary, uid: int) -> bool:
	if not sim.army.slots.has(uid): return false
	var slot: int = sim.army.slots[uid]
	var cell := sim.army.cells[slot]
	if sim.army.allied(row.owner, sim.army.owners[slot]): return false
	if sim._match_live() and not sim.fog.is_visible(row.owner, cell): return false
	var origin: int = sim.construction.center(row.id)
	return _distance(origin, cell, sim.world.width) <= int(stats(row).range) and clear_line(sim, row, origin, cell)

func target(sim: Simulation, row: Dictionary, locked := -1) -> int:
	if _target_valid(sim, row, locked): return locked
	var origin: int = sim.construction.center(row.id)
	var radius: int = stats(row).range
	var best := -1
	var rank := 2147483647
	var ox := origin % sim.world.width
	var oy := origin / sim.world.width
	for y in range(maxi(0, oy - radius), mini(sim.world.height, oy + radius + 1)):
		for x in range(maxi(0, ox - radius), mini(sim.world.width, ox + radius + 1)):
			var uid := sim.army.occupant[y * sim.world.width + x]
			if uid < 0: continue
			var distance := absi(x - ox) + absi(y - oy)
			if distance > radius or distance > rank: continue
			if not _target_valid(sim, row, uid): continue
			if distance < rank or best < 0 or uid < best:
				rank = distance
				best = uid
	return best

func step(sim: Simulation) -> void:
	beams.clear()
	for site in weapons.keys():
		if not _valid(sim, site): remove_site(site)
	var hits := {}
	_advance_projectiles(sim, hits)
	for row in sim.construction.sites.records:
		if not armed(row): continue
		if sim._match_live() and sim.rules.alive[row.owner] == 0: continue
		var upgrading := int(row.get("weapon_upgrade", -1))
		if upgrading >= 0:
			if sim.tick_count >= upgrading:
				row.weapon_level = level(row) + 1
				row.weapon_upgrade = -1
				sim.construction.sites.revision += 1
		# Solo retains its existing economic sandbox; weapons belong to matches.
		if not sim._match_live(): continue
		var state: Dictionary = weapons.get(row.id, {"next": 0, "target": -1, "paid_until": 0})
		weapons[row.id] = state
		if sim.energy_network.source_site(sim, row.id) < 0: continue
		if int(state.paid_until) <= sim.tick_count:
			var wallet := sim.rules.wallet(sim, row.owner)
			var cost := upkeep_cost(row)
			if wallet.energy < cost: continue
			wallet.energy -= cost
			upkeep_spent += cost
			state.paid_until = sim.tick_count + UPKEEP_TICKS
		if int(row.get("weapon_upgrade", -1)) >= 0: continue
		if sim.construction.demolitions.has(row.id): continue
		var config := stats(row)
		if sim.tick_count < int(state.next) and not bool(config.beam): continue
		var uid := target(sim, row, int(state.target))
		state.target = uid
		weapons[row.id] = state
		if uid < 0: continue
		var cell: int = sim.army.cells[sim.army.slots[uid]]
		if bool(config.beam): beams.append({"site": int(row.id), "target": uid, "owner": int(row.owner), "cell": cell})
		if sim.tick_count < int(state.next): continue
		state.next = sim.tick_count + int(config.period)
		if bool(config.beam): hits[uid] = int(hits.get(uid, 0)) + int(config.damage)
		else:
			projectiles.append({"site": int(row.id), "target": uid, "owner": int(row.owner), "cell": sim.construction.center(row.id), "previous": sim.construction.center(row.id), "next": sim.tick_count + 2, "left": int(config.range) + 2, "damage": int(config.damage)})
	if not hits.is_empty(): sim.army._apply_damage(sim, {}, hits, false)

func _advance_projectiles(sim: Simulation, hits: Dictionary) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var shot := projectiles[index]
		if not sim.army.slots.has(int(shot.target)):
			projectiles.remove_at(index)
			continue
		var slot: int = sim.army.slots[int(shot.target)]
		if sim.army.allied(int(shot.owner), sim.army.owners[slot]) or (sim._match_live() and (sim.rules.alive[int(shot.owner)] == 0 or not sim.fog.is_visible(int(shot.owner), sim.army.cells[slot]))):
			projectiles.remove_at(index)
			continue
		if sim.tick_count < int(shot.next): continue
		var row: Dictionary = sim.construction.sites.records[int(shot.site)]
		var cell: int = sim.army.cells[slot]
		var path := ray(int(shot.cell), cell, sim.world.width)
		if int(shot.left) <= 0 or not _open(sim, row, int(shot.cell)) or (not path.is_empty() and not clear_line(sim, row, int(shot.cell), path[0])):
			projectiles.remove_at(index)
			continue
		shot.previous = int(shot.cell)
		if not path.is_empty(): shot.cell = path[0]
		shot.left = int(shot.left) - 1
		shot.next = sim.tick_count + 2
		if int(shot.cell) == cell:
			hits[int(shot.target)] = int(hits.get(int(shot.target), 0)) + int(shot.damage)
			projectiles.remove_at(index)

func errors(sim: Simulation) -> PackedStringArray:
	var result := PackedStringArray()
	var minimum_paid := 0
	for site in weapons:
		if not _valid(sim, site):
			result.append("Waffenstatus ohne fertiges Gebäude")
			continue
		var state: Dictionary = weapons[site]
		if int(state.paid_until) > 0: minimum_paid += upkeep_cost(sim.construction.sites.records[site])
		if int(state.paid_until) < 0 or int(state.paid_until) > sim.tick_count + UPKEEP_TICKS: result.append("Ungültiger Versorgungszeitraum")
	if upkeep_spent < minimum_paid or upkeep_spent % 25 != 0: result.append("Ungültige Unterhaltsbuchung")
	return result

func restore(sim: Simulation, data: Dictionary) -> bool:
	for row in sim.construction.sites.records:
		if int(row.kind) == 4 and int(row.get("weapon_upgrade", -1)) > sim.tick_count + UPGRADE_TICKS: return false
	if typeof(data.get("upkeep_spent", 0)) != TYPE_INT or int(data.get("upkeep_spent", 0)) < 0: return false
	if not data.get("weapons", {}) is Dictionary: return false
	for key in ["projectiles", "beams"]:
		if not data.get(key, []) is Array: return false
	for site in data.get("weapons", {}):
		if typeof(site) != TYPE_INT or not _valid(sim, site) or not data.weapons[site] is Dictionary: return false
		var state: Dictionary = data.weapons[site]
		if typeof(state.get("next")) != TYPE_INT or typeof(state.get("target")) != TYPE_INT or typeof(state.get("paid_until")) != TYPE_INT: return false
		if state.next < 0 or state.next > sim.tick_count + 30 or state.target < -1 or state.target >= sim.army.next_id: return false
		if state.paid_until < 0 or state.paid_until > sim.tick_count + UPKEEP_TICKS: return false
	for shot in data.get("projectiles", []):
		if not shot is Dictionary: return false
		for key in ["site", "target", "owner", "cell", "previous", "next", "left", "damage"]:
			if typeof(shot.get(key)) != TYPE_INT: return false
		if shot.site < 0 or shot.site >= sim.construction.sites.records.size(): return false
		var row: Dictionary = sim.construction.sites.records[shot.site]
		if row.kind not in [0, 1, 4] or shot.owner != row.owner or shot.target < 0 or shot.target >= sim.army.next_id: return false
		if shot.cell < 0 or shot.cell >= sim.world.cell_count() or shot.next < 0 or shot.next > sim.tick_count + 2: return false
		if shot.previous < 0 or shot.previous >= sim.world.cell_count(): return false
		if shot.left < 0 or shot.left > 10 or shot.damage not in [1, 2] or (row.kind != 4 and shot.damage != 1): return false
	for beam in data.get("beams", []):
		if not beam is Dictionary: return false
		for key in ["site", "target", "owner", "cell"]:
			if typeof(beam.get(key)) != TYPE_INT: return false
		if not _valid(sim, beam.site): return false
		var row: Dictionary = sim.construction.sites.records[beam.site]
		if row.kind != 4 or level(row) != 3 or beam.owner != row.owner or beam.target < 0 or beam.target >= sim.army.next_id: return false
		if beam.cell < 0 or beam.cell >= sim.world.cell_count(): return false
	weapons = data.get("weapons", {}).duplicate(true)
	projectiles.assign(data.get("projectiles", []).duplicate(true))
	beams.assign(data.get("beams", []).duplicate(true))
	upkeep_spent = int(data.get("upkeep_spent", 0))
	return errors(sim).is_empty()

func snapshot() -> Dictionary:
	return {"weapons": weapons.duplicate(true), "projectiles": projectiles.duplicate(true), "beams": beams.duplicate(true), "upkeep_spent": upkeep_spent}

func state_hash() -> int:
	return hash(snapshot())

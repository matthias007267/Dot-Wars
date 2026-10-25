extends RefCounted
## Explicit diagnostic fixtures, never normal game saves.
static func create(kind: String, population := 10000, seed_value := 58191) -> Simulation:
	var config := SimConfig.new()
	config.world_size = 256
	config.world_seed = seed_value
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 50 if kind.begins_with("mixed") else 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var world: WorldState
	if kind.begins_with("mixed"):
		world = WorldGenerator.generate(config)
		world.carve_rect(Rect2i(24, 40, 208, 176))
	elif kind == "choke":
		world = WorldState.new(256, 256, 8, Materials.INDESTRUCTIBLE)
		world.carve_rect(Rect2i(12, 32, 100, 192))
		world.carve_rect(Rect2i(144, 32, 100, 192))
		world.carve_rect(Rect2i(110, 128, 36, 1))
		world.carve_rect(Rect2i(124, 124, 9, 9))
	else:
		world = WorldState.new(256, 256, 8, Materials.EMPTY)
		if kind.begins_with("maze") or kind == "changing":
			for x in range(32, 232, 16):
				for y in range(16, 240):
					if absi(y - (48 if (x / 16) % 2 == 0 else 208)) <= 2: continue
					world.set_material(world.index(x, y), Materials.SOFT)
	var sim := Simulation.from_world(config, world)
	if sim == null: return null
	sim.debug_mode = true
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	if not kind.begins_with("mixed"): sim.army.teams[1] = 0
	if kind.begins_with("mixed"):
		sim.upgrades.swarm_level = 4
		sim.rules.wallet(sim, 1).swarm_level = 4
		for group in sim.quotas.size():
			var owner: int = sim.rules.group_faction[group]
			sim.assign_area(group, Rect2i(0 if owner == 0 else 128, 0, 128, 256))
	var placed := 0
	for y in range(44, 212):
		for x in range(16, 240):
			if placed >= population: break
			if kind.begins_with("mixed") and (x < 28 or x > 227): continue
			if kind == "mixed" and y > 100: continue
			if kind == "mixed_reserve" and not (y < 49 or (y >= 154 and (x < 112 or x >= 144))): continue
			var cell := world.index(x, y)
			if world.cells[cell] != Materials.EMPTY or sim.workers.occupant[cell] >= 0: continue
			# Keep both worker bases and energy entrance lanes free initially.
			var near_core := false
			for core in sim.rules.cores:
				if absi(x - core % 256) + absi(y - core / 256) < 12: near_core = true
			if near_core: continue
			var owner := 0 if x < 128 else 1
			var uid: int = sim.army.add(cell, owner)
			if uid < 0: continue
			var index: int = sim.army.slots[uid]
			if kind.begins_with("mixed"): sim.army.goals[index] = -1 if kind == "mixed_reserve" and uid >= 1000 else world.index(132 if owner == 0 else 123, 80)
			elif kind == "choke": sim.army.goals[index] = world.index(200 if owner == 0 else 52, 128)
			elif kind.contains("unique"): sim.army.goals[index] = world.index(20 + placed % 210, 180 + placed / 210)
			else: sim.army.goals[index] = world.index(240 - placed % 8, 180 + (placed / 8) % 8)
			placed += 1
		if placed >= population: break
	return sim

static func commands(sim: Simulation, kind: String, tick: int) -> void:
	if kind == "changing" and tick % 10 == 0:
		var x := 32 + ((tick / 10) % 13) * 16
		var cell := sim.world.index(x, 100 + (tick / 130) % 50)
		if sim.world.cells[cell] == Materials.SOFT: sim.world.open_without_mining(cell)
	if kind.begins_with("mixed") and tick % 100 == 0:
		for index in sim.army.count:
			if kind == "mixed_reserve" and sim.army.ids[index] >= 1000 and sim.army.ids[index] < 10000: continue
			sim.army.goals[index] = sim.world.index(132 if sim.army.owners[index] == 0 else 123, 80)
		for owner in 2:
			var attempts := 0
			while sim.army.population(owner) < 5000 and attempts < 50 and sim.buy_warrior(owner): attempts += 1
			while sim.worker_population(owner) < 50 and attempts < 100:
				var bought: bool = sim.buy_worker() if owner == 0 else sim.rules._buy_worker(sim, owner)
				if not bought: break
				attempts += 1

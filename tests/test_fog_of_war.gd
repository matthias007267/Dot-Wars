extends TestCase
const Fog = preload("res://src/sim/fog_of_war.gd")

func _sim() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	return sim

func test_blocker_is_visible_but_cell_behind_is_hidden() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	var blockers := PackedByteArray()
	blockers.resize(sim.world.cell_count())
	blockers[10 * 32 + 11] = 1
	var mask := PackedByteArray()
	mask.resize(blockers.size())
	fog._reveal(mask, blockers, 10 * 32 + 10, 5)
	check_eq(mask[10 * 32 + 11], 1, "blocker itself visible")
	check_eq(mask[10 * 32 + 12], 0, "no sight through blocker")
	check_eq(mask[10 * 32 + 9], 1, "unblocked side visible")

func test_remembers_terrain_only_when_seen_again() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	var cell := sim.workers.cell[0]
	fog.update(sim)
	check(fog.is_explored(0, cell), "own worker reveals terrain")
	var old := fog.known_material(0, cell)
	for site in sim.construction.sites.records:
		if site.owner == 0 and not site.destroyed:
			sim.construction.sites.damage(site.id, site.hp)
	for id in range(sim.workers.count - 1, -1, -1):
		if sim.workers.faction[id] == 0: sim.workers.remove_swap(id)
	sim.world.set_material(cell, Materials.SOFT)
	fog.update(sim)
	check_eq(fog.known_material(0, cell), old, "last known material does not change in fog")
	check(not fog.is_visible(0, cell), "lost sight")

func test_alliance_shares_sight_but_does_not_share_wallets() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	fog.alliance[1] = 0
	var energy_before := sim.rules.wallet(sim, 1).energy
	fog.update(sim)
	var own_cell := sim.workers.cell[0]
	check(fog.is_visible(1, own_cell), "allied faction sees worker area")
	check_eq(sim.rules.wallet(sim, 1).energy, energy_before, "alliance does not transfer energy")

func test_snapshot_roundtrip_preserves_exploration() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	fog.update(sim)
	var copy := Fog.new()
	check(copy.restore(fog.snapshot(), sim.world, 2), "valid fog save")
	check_eq(copy.explored[0], fog.explored[0], "exploration persisted")
	check_eq(copy.known_terrain[0], fog.known_terrain[0], "terrain memory persisted")
	var invalid := fog.snapshot()
	invalid["factions"] = 3
	check(not copy.restore(invalid, sim.world, 2), "mismatched faction count rejected")

func test_enemy_building_memory_is_frozen_outside_sight() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	var enemy_id := -1
	for row in sim.construction.sites.records:
		if int(row.owner) == 1:
			enemy_id = int(row.id)
			break
	check(enemy_id >= 0, "enemy has an initial core")
	if enemy_id < 0: return
	var site: Dictionary = sim.construction.sites.records[enemy_id]
	var footprint: Rect2i = site.rect
	var first_cell := footprint.position.y * sim.world.width + footprint.position.x
	check(fog.known_building(0, enemy_id).is_empty(), "unseen enemy core not known")
	# Directly set a sight mask to verify knowledge without needing a moving unit.
	fog.visible[0][first_cell] = 1
	fog.known_sites[0][enemy_id] = site.duplicate(true)
	var previous := fog.known_building(0, enemy_id)
	site.hp -= 10
	check_eq(fog.known_building(0, enemy_id).hp, previous.hp, "enemy HP stays frozen")
	fog.visible[0][first_cell] = 0
	check_eq(fog.remembered_sites(0).size(), 1, "previously seen site remains in memory")
	fog.known_sites[0][enemy_id].destroyed = true
	check_eq(fog.remembered_sites(0).size(), 0, "confirmed destroyed site not rendered")

func test_no_unexplored_material_or_site_leak() -> void:
	var sim := _sim()
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	var unseen := 0
	check_eq(fog.known_material(0, unseen), -1, "unknown terrain has no material")
	check(not fog.is_explored(0, unseen), "unknown terrain not explored")
	check(fog.remembered_sites(0).is_empty(), "no enemy site data before discovery")
	check(fog.known_building(-1, 0).is_empty(), "invalid viewer has no site knowledge")

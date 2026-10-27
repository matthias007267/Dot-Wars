extends TestCase
const Native = preload("res://src/sim/native_search.gd")

func _mining_sim(material: int) -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 16
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	world.set_material(world.index(7, 8), material)
	var sim := Simulation.from_world(config, world, PackedInt32Array([world.index(6, 8)]))
	sim.assign_area(0, Rect2i(7, 8, 1, 1))
	MiningSystem.claim_cell(sim.workers, world, sim.areas, 0, world.index(7, 8))
	return sim

func _work(sim: Simulation, power := 1) -> void:
	MiningSystem.step(sim.workers, sim.world, sim.areas, sim.energy_dots, sim.config.work_per_hardness, power)

func _reachable(world: WorldState, origin: int) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(world.cell_count())
	var queue := PackedInt32Array([origin])
	seen[origin] = 1
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for d in range(1, 5):
			var next := MovementSystem.neighbor(cell, d, world.width, world.cell_count())
			if next >= 0 and world.cells[next] == Materials.EMPTY and seen[next] == 0:
				seen[next] = 1
				queue.append(next)
	return seen

func test_resource_catalog_separates_hardness_time_and_energy() -> void:
	var energy := [3, 8, 25, 80, 250, 800, 4000, 20000]
	for index in 8:
		var ore: int = Materials.ORES[index]
		check_eq(Materials.hardness(ore), index + 1, "Erzhärte")
		check_eq(Materials.energy(ore), energy[index], "bestätigter Energieertrag")
		check_eq(Materials.durability(ore, 20), 20 * (1 << index), "bestätigte Abbaudauer")
	check_eq(Materials.energy(Materials.ROCK), 1, "gewöhnliches Gestein")
	check(not Materials.is_mineable(Materials.INDESTRUCTIBLE), "Obsidian ausgeschlossen")

func test_single_point_stone_emits_before_completion_on_free_worker_cell() -> void:
	var sim := _mining_sim(Materials.ROCK)
	for tick in 9: _work(sim)
	check_eq(sim.energy_dots.generated, 0, "noch kein ganzer Energieanteil")
	_work(sim)
	check_eq(sim.energy_dots.generated, 1, "einziger Punkt bereits während Abbau")
	check_eq(sim.world.cells[135], Materials.ROCK, "Block bleibt bis zum Abschluss fest")
	check_eq(sim.energy_dots.cells[0], sim.workers.cell[0], "Freisetzung auf freier Arbeitszelle")
	check_eq(sim.energy_dots.birth[0], 135, "Herkunft bleibt Ressourcenblock")
	for tick in 10: _work(sim)
	check_eq(sim.energy_dots.generated, 1, "kein zusätzlicher Abschlussbonus")
	check_eq(sim.world.cells[135], Materials.EMPTY, "Block nach voller Arbeit entfernt")

func test_diamond_stream_roundtrips_without_duplicate_or_lost_energy() -> void:
	var sim := _mining_sim(Materials.DIAMOND)
	_work(sim)
	check(sim.energy_dots.generated > 0 and sim.energy_dots.generated < 20000, "sofortiger anteiliger Fluss")
	for tick in 72: _work(sim)
	var data := SaveGame.snapshot(sim)
	var loaded := SaveGame.from_snapshot(data)
	check(loaded != null, "laufender Erzabbau gespeichert")
	if loaded == null: return
	check_eq(loaded.world.released, sim.world.released, "bereits freigesetzte Energie erhalten")
	check_eq(loaded.state_hash(), sim.state_hash(), "identischer vollständiger Zustand")
	for tick in range(73, 2560):
		_work(loaded)
	check_eq(loaded.world.cells[135], Materials.EMPTY, "Diamant nach 128 Sekunden abgebaut")
	check_eq(loaded.energy_dots.generated, 20000, "exakt bestätigter Gesamtertrag")
	check_eq(loaded.energy_dots.pending(), 20000, "weiterhin ein Punkt pro Dot")
	check_no_errors(loaded.check_invariants(), "Energiebilanz und freie Dotpositionen")
	data.mining_released[135] = 20001
	check(SaveGame.from_snapshot(data) == null, "ungültiger Auszahlungszähler verworfen")

func test_overkill_and_shared_mining_pay_each_point_once() -> void:
	var sim := _mining_sim(Materials.DIAMOND)
	for cell in [119, 136, 151]:
		var id := sim.workers.add(cell, 0, 0)
		MiningSystem.claim_cell(sim.workers, sim.world, sim.areas, id, 135)
	_work(sim, 10000)
	check_eq(sim.world.mined_count, 1, "ein Abschluss bei vier Arbeitern")
	check_eq(sim.energy_dots.generated, 20000, "Überarbeit erzeugt keinen Mehrertrag")
	_work(sim, 10000)
	check_eq(sim.energy_dots.generated, 20000, "verschwundener Block wird nicht erneut bezahlt")

func test_research_accelerates_every_resource_without_changing_yield() -> void:
	var resources := [Materials.ROCK] + Materials.ORES
	for material in resources:
		var sim := _mining_sim(material)
		MiningSystem.step_scaled(sim.workers, sim.world, sim.areas, sim.energy_dots, 20, 1, 1)
		var loaded := SaveGame.from_snapshot(SaveGame.snapshot(sim))
		check(loaded != null, "Forschungs-Bruchfortschritt ladbar")
		if loaded == null: continue
		check_eq(loaded.state_hash(), sim.state_hash(), "Bruchfortschritt und Auszahlung erhalten")
		var ticks := 1
		while loaded.world.cells[135] != Materials.EMPTY and ticks <= 2560:
			MiningSystem.step_scaled(loaded.workers, loaded.world, loaded.areas, loaded.energy_dots, 20, 1, 1)
			ticks += 1
		check_eq(ticks, ceili(Materials.durability(material, 20) * 4.0 / 5.0), "Abbau-Forschung beschleunigt um Faktor 5/4")
		check_eq(loaded.energy_dots.generated, Materials.energy(material), "Forschung ändert nicht den Ertrag")
		check_eq(loaded.energy_dots.pending(), Materials.energy(material), "ein Energiepunkt je Dot")

func test_generated_start_networks_stay_separate() -> void:
	for size in [32, 64]:
		for count in [2, 3, 4]:
			for seed_value in range(6):
				var config := TestHelpers.default_config()
				config.mode = SimConfig.MODE_MATCH
				config.world_size = size
				config.world_seed = seed_value
				config.ai_count = count - 1
				var sim := Simulation.create(config)
				check(sim != null, "Startgebiete für Größe/Spieler/Seed")
				if sim == null: continue
				for faction in count:
					var origin := -1
					for id in sim.workers.count:
						if sim.workers.faction[id] == faction:
							origin = sim.workers.cell[id]
							break
					check(origin >= 0, "eigene Startarbeiter")
					if origin < 0: continue
					var reachable := _reachable(sim.world, origin)
					for id in sim.workers.count:
						if sim.workers.faction[id] != faction: check_eq(reachable[sim.workers.cell[id]], 0, "keine freie Verbindung: Größe %s Spieler %s Seed %s Fraktion %s" % [size, count, seed_value, faction])

func test_every_region_remains_reachable_after_mining_all_resources() -> void:
	for seed_value in range(8):
		var config := TestHelpers.default_config()
		config.world_size = 64
		config.world_seed = seed_value
		config.mode = SimConfig.MODE_MATCH
		config.ai_count = 3
		var sim := Simulation.create(config)
		check(sim != null, "Welt erzeugt")
		if sim == null: continue
		for cell in sim.world.cell_count():
			if Materials.is_mineable(sim.world.cells[cell]): sim.world.mine_cell(cell)
		var reachable := _reachable(sim.world, sim.workers.cell[0])
		var empty := 0
		var reached := 0
		for cell in sim.world.cell_count():
			if sim.world.cells[cell] == Materials.EMPTY: empty += 1
			if reachable[cell] != 0: reached += 1
		check_eq(reached, empty, "Obsidian schließt keinen Teil der Karte ab")
		check(sim.world.indestructible_count > 100, "dauerhafte Kartenstruktur bleibt")

func test_obsidian_is_never_selected_but_new_ores_are_targets() -> void:
	var sim := _mining_sim(Materials.COPPER)
	sim.world.set_material(118, Materials.INDESTRUCTIBLE)
	sim.assign_area(0, Rect2i(6, 7, 2, 2))
	sim.run_ticks(3)
	check_eq(sim.world.progress[118], 0, "keine Arbeit an Obsidian")
	check(sim.world.progress[135] > 0, "neue Erze in aktueller Zielsuche erreichbar")

func test_large_energy_stream_matches_reference_each_tick() -> void:
	if Native.backend() == null:
		check(true, "nativer Vergleich im Referenzlauf nicht verfügbar")
		return
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.energy_dots.enqueue(32 * 4 + 16, 10000, 0)
	sim.energy_dots.enqueue(32 * 5 + 16, 10000, 1)
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(reference != null, "Referenzzustand ladbar")
	if reference == null: return
	var gates: Dictionary = sim.rules.gates(sim)
	var pace := PackedByteArray([2, 3])
	var previous := Native.enabled
	for tick in 30:
		Native.enabled = true
		sim.energy_dots.step(sim.world, sim.workers, gates.cells, tick, 8, gates.owners, pace, sim)
		Native.enabled = false
		reference.energy_dots.step(reference.world, reference.workers, gates.cells, tick, 8, gates.owners, pace, reference)
		check_eq(sim.energy_dots.state_hash(), reference.energy_dots.state_hash(), "20000 Dots, Besitzer und Takt %d" % tick)
	Native.enabled = previous

func test_all_ore_and_obsidian_sprites_are_distinct_square_assets() -> void:
	var image := WorldRenderer.ORE_TEXTURE.get_image()
	check_eq(image.get_size(), Vector2i(32, 320), "zehn quadratische Terrainbilder")
	var seen := {}
	for index in 10:
		var sprite := image.get_region(Rect2i(0, index * 32, 32, 32))
		var identity := hash(sprite.get_data())
		check(not seen.has(identity), "eigenes Muster für jedes Erz und Obsidian")
		seen[identity] = true

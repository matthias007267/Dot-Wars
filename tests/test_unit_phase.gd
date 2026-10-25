extends TestCase

func _match() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	return sim

func _worker(sim: Simulation, cell: int, owner: int) -> int:
	var id := sim.workers.add(cell, sim.rules.group_of[owner], owner)
	sim.initial_mass += 1
	return id

func test_limit_counts_pending_orders_and_does_not_charge_rejected_purchase() -> void:
	var sim := _match()
	sim.upgrades.energy = 1000
	for index in 50: check(sim.buy_worker(), "bezahlte Bestellung")
	check_eq(sim.worker_population(), 50, "Warteschlange zählt")
	var energy := sim.upgrades.energy
	check(not sim.buy_worker(), "51. Arbeiter abgelehnt")
	check_eq(sim.upgrades.energy, energy, "keine Zahlung bei Ablehnung")
	check_no_errors(sim.check_invariants(), "Massenbilanz mit Warteschlange")

func test_own_worker_can_be_crossed_but_not_used_as_destination() -> void:
	var sim := _match()
	var worker := _worker(sim, sim.world.index(4, 5), 0)
	var uid: int = sim.army.add(sim.world.index(3, 5), 0)
	check(sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), sim.world.index(5, 5)), "Befehl")
	sim.army.step(sim)
	check_eq(sim.army.cells[sim.army.slots[uid]], sim.world.index(5, 5), "eigener Arbeiter passiert")
	check_eq(sim.army.next_move[sim.army.slots[uid]], 2 * ArmyState.MOVE_PERIOD, "zwei Zellen kosten zwei Schritte")
	check_eq(sim.workers.cell[worker], sim.world.index(4, 5), "Arbeiter bleibt stehen")
	check_no_errors(sim.check_invariants(), "keine gemeinsame Endzelle")

func test_cannot_stop_on_own_worker_and_allied_warriors_block() -> void:
	var sim := _match()
	_worker(sim, sim.world.index(4, 5), 0)
	var uid: int = sim.army.add(sim.world.index(3, 5), 0)
	sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), sim.world.index(4, 5))
	sim.army.step(sim)
	check_eq(sim.army.cells[sim.army.slots[uid]], sim.world.index(3, 5), "besetztes Ziel bleibt gesperrt")
	var second := _match()
	second.army.teams[1] = 0
	uid = second.army.add(second.world.index(3, 5), 0)
	second.army.add(second.world.index(4, 5), 1)
	second.army.command(PackedInt32Array([ArmyState.TAG + uid]), second.world.index(5, 5))
	second.army.step(second)
	check_eq(second.army.cells[second.army.slots[uid]], second.world.index(3, 5), "verbündeter Krieger blockiert")
	check_eq(second.army.hp[0], ArmyState.HEALTH, "keine verbündeten Treffer")

func test_attacked_worker_keeps_working_and_death_keeps_mass_balance() -> void:
	var sim := _match()
	var cell := sim.world.index(6, 5)
	var worker := _worker(sim, cell, 1)
	var rock := sim.world.index(6, 4)
	sim.world.set_material(rock, Materials.HARD)
	sim.assign_cells(sim.rules.group_of[1], PackedInt32Array([rock]))
	sim.workers.state[worker] = WorkerStore.STATE_MINING
	sim.workers.target[worker] = rock
	sim.army.add(sim.world.index(5, 5), 0)
	sim.army.step(sim)
	check_eq(sim.workers.health[worker], WorkerStore.DEFAULT_HEALTH - ArmyState.DAMAGE, "Kontaktangriff")
	check_eq(sim.workers.state[worker], WorkerStore.STATE_MINING, "arbeitet bei Angriff weiter")
	check_eq(sim.workers.target[worker], rock, "Auftrag bleibt")
	for strike in range(1, WorkerStore.DEFAULT_HEALTH):
		sim.tick_count = strike * ArmyState.ATTACK_PERIOD
		sim.army.step(sim)
	check_eq(sim.workers.count, 0, "toter Arbeiter entfernt")
	check_eq(sim.worker_losses, 1, "Verlust bilanziert")
	check_no_errors(sim.check_invariants(), "Tod bilanziert")

func test_mutual_melee_is_simultaneous() -> void:
	var sim := _match()
	sim.army.add(sim.world.index(5, 5), 0)
	sim.army.add(sim.world.index(6, 5), 1)
	sim.army.hp.fill(1)
	sim.army.step(sim)
	check_eq(sim.army.count, 0, "beide Treffer wirken vor dem Entfernen")
	check_eq(sim.army.lost, 2, "beide Krieger bilanziert")
	check_no_errors(sim.check_invariants(), "keine verwaiste Belegung")

func test_production_and_save_roundtrip_keep_stable_warrior_ids() -> void:
	var sim := _match()
	sim.upgrades.energy = ArmyState.COST
	check(sim.buy_warrior(), "Ausbildung am Kern")
	check_eq(sim.upgrades.energy, 0, "Kosten bezahlt")
	check_eq(sim.army.count, 0, "nicht sofort fertig")
	sim.tick_count = ArmyState.PRODUCTION_TICKS
	sim.army.step(sim)
	check_eq(sim.army.count, 1, "Ausbildung abgeschlossen")
	var uid: int = sim.army.ids[0]
	sim.army.command(PackedInt32Array([ArmyState.TAG + uid]), sim.world.index(10, 10))
	var loaded := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(loaded != null, "Kriegerstand lesbar")
	if loaded == null: return
	check_eq(loaded.state_hash(), sim.state_hash(), "Zustand inklusive Krieger identisch")
	check_eq(loaded.army.ids[0], uid, "dauerhafte ID bleibt")
	for tick in range(20):
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "deterministisches Fortsetzen")

func test_fusion_is_removed_and_old_fused_save_becomes_individual_workers() -> void:
	var config := SimConfig.new()
	config.world_size = 32
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY), PackedInt32Array(), false)
	sim.workers.add_sized(sim.world.index(3, 4), 0, 0, 2)
	sim.initial_mass = 4
	sim.upgrades.energy = 1000
	check(not sim.buy(Upgrades.KIND_FUSION2), "kein Fusionskauf")
	check(not sim.set_desired_size(0, 2), "keine Fusionsanweisung")
	var loaded := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(loaded != null, "alter Großarbeiter bleibt lesbar")
	if loaded == null: return
	check_eq(loaded.workers.count, 4, "vier einzelne Arbeiter")
	check_eq(loaded.workers.max_size, 1, "nur noch 1×1")
	check_eq(loaded.total_mass(), 4, "keine Masse verloren")
	check_no_errors(loaded.check_invariants(), "Migration konsistent")

func test_mixed_selection_orders_workers_and_warriors() -> void:
	var sim := _match()
	_worker(sim, sim.world.index(3, 5), 0)
	var uid: int = sim.army.add(sim.world.index(4, 5), 0)
	var hud := GameHud.new()
	hud.sim = sim
	hud.select_in_rect(Rect2i(2, 4, 4, 3))
	check_eq(hud.selection.size(), 2, "beide Arten frei ausgewählt")
	check(ArmyState.TAG + uid in hud.selection, "Krieger ausgewählt")
	check(hud.issue_march(sim.world.index(8, 5)), "gemeinsamer Marsch")
	check_eq(sim.army.goals[sim.army.slots[uid]], sim.world.index(8, 5), "Kriegerauftrag")
	hud.free()


func test_malformed_army_save_is_rejected() -> void:
	var sim := _match()
	for key in ["units", "queue", "teams"]:
		var snapshot := SaveGame.snapshot(sim)
		snapshot.army[key] = 42
		check(SaveGame.from_snapshot(snapshot) == null, "ungültige Daten: " + key)
	var snapshot := SaveGame.snapshot(sim)
	snapshot.army.units = [{"id": 0, "cell": sim.world.index(5, 5), "owner": 3}]
	snapshot.army.next = 1
	snapshot.army.purchased = 1
	check(SaveGame.from_snapshot(snapshot) == null, "nicht existierende Fraktion abgelehnt")


func test_dense_removal_keeps_survivor_id_and_command() -> void:
	var sim := _match()
	var first: int = sim.army.add(sim.world.index(4, 5), 0)
	var second: int = sim.army.add(sim.world.index(5, 5), 0)
	sim.army.remove(first)
	check(sim.army.command(PackedInt32Array([ArmyState.TAG + second]), sim.world.index(7, 5)), "Überlebender behält Auswahl-ID")
	check_eq(sim.army.ids[0], second, "Swap behält ID")
	check_eq(sim.army.goals[0], sim.world.index(7, 5), "Befehl nach Swap")
	check_no_errors(sim.check_invariants(), "Belegung und Bilanz")

func test_core_evacuation_does_not_place_worker_on_warrior() -> void:
	var sim := _match()
	var worker := _worker(sim, sim.world.index(4, 5), 0)
	var cell := sim.world.index(5, 5)
	sim.army.add(cell, 0)
	var mask := PackedByteArray()
	mask.resize(sim.world.cell_count())
	mask.fill(1)
	mask[cell] = 0
	check(not sim._evict_workers(mask, PackedInt32Array()), "einziger Ausgang von Krieger besetzt")
	check_eq(sim.workers.cell[worker], sim.world.index(4, 5), "fehlgeschlagene Evakuierung verändert nichts")
	check_no_errors(sim.check_invariants(), "kein Überlappen")


func test_local_defence_path_goes_around_nearby_wall() -> void:
	var sim := _match()
	var origin := sim.world.index(4, 5)
	var goal := sim.world.index(6, 5)
	sim.world.set_material(sim.world.index(5, 5), Materials.HARD)
	var field: Dictionary = sim.army._local_field(origin, goal, sim.world)
	check_eq(field[origin], 4, "kurzer Umweg um Wand")
	check(field.size() <= 25, "Suche bleibt lokal")


func test_simultaneous_production_keeps_distinct_endpoints() -> void:
	var sim := _match()
	sim.upgrades.energy = ArmyState.COST * 10
	for index in 10: check(sim.buy_warrior(), "Ausbildungsauftrag")
	sim.tick_count = ArmyState.PRODUCTION_TICKS
	sim.army.step(sim)
	check_eq(sim.army.count, 10, "alle fälligen Aufträge platziert")
	check_eq(sim.army.queue.size(), 0, "Warteschlange geleert")
	check_no_errors(sim.check_invariants(), "keine doppelte Endposition")

func test_ai_worker_purchase_respects_army_occupancy() -> void:
	var sim := _match()
	var origin: int = sim.rules._tunnel_near(sim, sim.rules.cores[1])
	sim.army.add(origin, 1)
	sim.rules.wallet(sim, 1).energy = Simulation.WORKER_COST
	check(sim.rules._buy_worker(sim, 1), "KI kann anderen freien Platz nutzen")
	check(sim.workers.cell[0] != origin, "kein Arbeiter auf Krieger")
	check_no_errors(sim.check_invariants(), "Kauf hält Belegung und Bilanz")

func test_legacy_source_cannot_grow_rock_under_warriors() -> void:
	var config := SimConfig.new()
	config.world_size = 32
	config.mode = SimConfig.MODE_EXTRACTION
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY), PackedInt32Array(), false)
	var origin := sim.world.index(16, 16)
	sim.buildings.add(Buildings.KIND_SOURCE, origin)
	sim.buildings.elapsed[0] = Buildings.SOURCE_PERIOD[0] - 1
	for direction in range(1, 5):
		sim.army.add(MovementSystem.neighbor(origin, direction, 32, 1024), 0)
	sim.tick_once()
	check_eq(sim.buildings.buds[0].size(), 0, "volle Kriegerumgebung verhindert Nachwuchs")
	for cell in sim.army.cells: check_eq(sim.world.cells[cell], Materials.EMPTY, "kein Fels unter Krieger")
	check_no_errors(sim.check_invariants(), "alte Quellen mit neuer Armee konsistent")
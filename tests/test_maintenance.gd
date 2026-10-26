extends TestCase
const Planner = preload("res://src/sim/construction_ai.gd")

func _sim() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 5000
	sim.rules.wallet(sim, 1).energy = 5000
	return sim

func _worker(sim: Simulation, cell: int, owner := 0) -> int:
	sim.initial_mass += 1
	return sim.workers.add(cell, sim.rules.group_of[owner], owner)

func _site(sim: Simulation, ready := true, owner := 0) -> int:
	sim.construction.outposts_unlocked = true
	var id := sim.construction.place(sim, 1, 100, PackedInt32Array(), owner)
	if ready: sim.construction.sites.contribute(id, owner, 300)
	return id

func _ai_workers(sim: Simulation, count := 6) -> PackedInt32Array:
	var origin := sim.construction.origin(sim, 1)
	var cells := sim.spawner.find_free_cells(sim.world, sim.workers, origin, count, sim.world.cell_count())
	var ids := PackedInt32Array()
	for cell in cells: ids.append(_worker(sim, cell, 1))
	return ids

func test_repair_is_manual_costs_energy_and_uses_approved_test_cadence() -> void:
	var sim := _sim()
	var site := _site(sim)
	sim.construction.damage(sim, site, 50)
	var worker := _worker(sim, 68)
	var before := sim.upgrades.energy
	sim.run_ticks(8)
	check_eq(sim.construction.sites.records[site].hp, 150, "keine automatische Reparatur")
	check_eq(sim.upgrades.energy, before, "keine automatische Abbuchung")
	check_eq(sim.construction.assign_repair(sim, site, PackedInt32Array([worker])), 1, "manueller Auftrag")
	sim.run_ticks(4)
	check_eq(sim.construction.sites.records[site].hp, 152, "2 HP in 4 Takten")
	check_eq(sim.upgrades.energy, before - 1, "eine Energie")
	check_eq(sim.workers.build_mode[worker], 1, "Reparatur statt Neubau")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_multiple_repairers_share_costs_stop_at_max_and_do_not_charge_extra() -> void:
	var sim := _sim()
	var site := _site(sim)
	sim.construction.damage(sim, site, 5)
	var a := _worker(sim, 68)
	var b := _worker(sim, 69)
	sim.construction.assign_repair(sim, site, PackedInt32Array([a, b]))
	var before := sim.upgrades.energy
	sim.run_ticks(4)
	check_eq(sim.construction.sites.records[site].hp, 199, "zwei Arbeiter reparieren vier HP")
	sim.run_ticks(4)
	check_eq(sim.construction.sites.records[site].hp, 200, "letzter Beitrag gekappt")
	check_eq(sim.upgrades.energy, before - 3, "drei echte bezahlte Beiträge")
	check_eq(sim.workers.build_site[a], -1, "Auftrag beendet")
	check_eq(sim.workers.build_site[b], -1, "zweiter Auftrag beendet")
	sim.run_ticks(20)
	check_eq(sim.upgrades.energy, before - 3, "keine Zahlung bei voller Gesundheit")

func test_repair_waits_without_energy_and_new_command_stops_it() -> void:
	var sim := _sim()
	var site := _site(sim)
	sim.construction.damage(sim, site, 20)
	var worker := _worker(sim, 68)
	sim.upgrades.energy = 0
	sim.construction.assign_repair(sim, site, PackedInt32Array([worker]))
	sim.run_ticks(8)
	check_eq(sim.construction.sites.records[site].hp, 180, "ohne Energie kein Fortschritt")
	check_eq(sim.workers.build_site[worker], site, "Auftrag wartet")
	sim.upgrades.energy = 1
	sim.run_ticks(4)
	check_eq(sim.construction.sites.records[site].hp, 182, "nach Zahlung fortgesetzt")
	check_eq(sim.upgrades.energy, 0, "nur vorhandene Energie ausgegeben")
	check(sim.take_party(PackedInt32Array([worker])) >= 0, "neuer Befehl")
	sim.upgrades.energy = 10
	sim.run_ticks(8)
	check_eq(sim.construction.sites.records[site].hp, 182, "neuer Befehl beendet Reparatur")
	check_eq(sim.workers.build_mode[worker], 0, "Reparaturmodus gelöscht")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_repair_rejects_foreign_workers_unfinished_sites_and_healthy_buildings() -> void:
	var sim := _sim()
	var site := _site(sim, false)
	var own := _worker(sim, 68)
	var foreign := _worker(sim, 69, 1)
	check_eq(sim.construction.assign_repair(sim, site, PackedInt32Array([own])), 0, "Baustelle nicht reparierbar")
	sim.construction.sites.contribute(site, 0, 300)
	check_eq(sim.construction.assign_repair(sim, site, PackedInt32Array([own])), 0, "gesund")
	sim.construction.damage(sim, site, 10)
	check_eq(sim.construction.assign_repair(sim, site, PackedInt32Array([foreign])), 0, "fremder Arbeiter")
	check_eq(sim.construction.assign_repair(sim, site, PackedInt32Array([own]), 1), 0, "fremdes Gebäude")
	check_eq(sim.construction.assign_repair(sim, -1, PackedInt32Array([own])), 0, "ungültiges Ziel")

func test_repair_uses_owner_wallet_and_continues_under_attack_until_worker_death() -> void:
	var sim := _sim()
	var site := _site(sim, true, 1)
	sim.construction.damage(sim, site, 100)
	var worker := _worker(sim, 68, 1)
	sim.construction.assign_repair(sim, site, PackedInt32Array([worker]), 1)
	var enemy := sim.army.add(67, 0)
	sim.army.next_move[sim.army.slots[enemy]] = 100
	var player_before := sim.upgrades.energy
	var owner_before := sim.rules.wallet(sim, 1).energy
	sim.run_ticks(11)
	check(sim.construction.sites.records[site].hp > 100, "arbeitet trotz Angriff weiter")
	check_eq(sim.workers.build_mode[worker], 1, "Auftrag bleibt")
	check(sim.rules.wallet(sim, 1).energy < owner_before, "Besitzer zahlt")
	check_eq(sim.upgrades.energy, player_before, "anderes Konto bleibt")
	sim.run_ticks(30)
	check_eq(sim.workers.count, 0, "Arbeiter stirbt regulär")
	check_eq(sim.worker_losses, 1, "Verlust bilanziert")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_repair_save_load_and_swap_removal_keep_tasks_and_cadence() -> void:
	var sim := _sim()
	var site := _site(sim)
	sim.construction.damage(sim, site, 100)
	_worker(sim, 67)
	var worker := _worker(sim, 68)
	sim.construction.assign_repair(sim, site, PackedInt32Array([worker]))
	sim.workers.remove_swap(0)
	sim.worker_losses += 1
	check_eq(sim.workers.build_mode[0], 1, "Slottausch kopiert Modus")
	sim.run_ticks(3)
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "laufende Reparatur ladbar")
	if loaded == null: return
	check_eq(loaded.state_hash(), sim.state_hash(), "exakter Zustand")
	for tick in 80:
		sim.tick_once()
		loaded.tick_once()
		check_eq(loaded.state_hash(), sim.state_hash(), "Reparatur taktsynchron")
	var bad := SaveGame.snapshot(sim)
	bad.units[0].build_mode = 2
	check(SaveGame.from_snapshot(bad) == null, "unbekannter Modus abgewiesen")

func test_unstarted_undamaged_cancel_refunds_actual_price_once_and_releases_ground() -> void:
	var sim := _sim()
	var before := sim.upgrades.energy
	var site := _site(sim, false)
	var worker := _worker(sim, 68)
	sim.construction.assign(sim, site, PackedInt32Array([worker]))
	check_eq(sim.construction.cancel_refund(site), 200, "echter Kaufpreis")
	check(sim.construction.cancel(sim, site), "Abbruch")
	check_eq(sim.upgrades.energy, before, "volle Erstattung")
	check_eq(sim.world.cells[100], Materials.EMPTY, "Baugrund frei")
	check_eq(sim.workers.build_site[worker], -1, "Arbeiter freigegeben")
	check(not sim.construction.cancel(sim, site), "nicht doppelt abbrechen")
	check_eq(sim.upgrades.energy, before, "keine doppelte Erstattung")
	check_eq(sim.construction.price(1, 0), 200, "abgebrochene Fläche zählt nicht mehr")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_started_or_damaged_cancel_has_no_refund_and_foreign_or_ready_cancel_is_rejected() -> void:
	for started in [false, true]:
		var sim := _sim()
		var site := _site(sim, false)
		if started: sim.construction.sites.contribute(site, 0, 1)
		else: sim.construction.damage(sim, site, 1)
		var before := sim.upgrades.energy
		check_eq(sim.construction.cancel_refund(site), 0, "kein kostenloser Schadens-/Arbeitsreset")
		check(not sim.construction.cancel(sim, site, 1), "fremder Besitzer abgewiesen")
		check(sim.construction.cancel(sim, site), "eigener Abbruch")
		check_eq(sim.upgrades.energy, before, "keine Erstattung")
	var sim := _sim()
	check(not sim.construction.cancel(sim, 0), "fertigen Kern nicht abreißen")

func test_aborting_last_begun_core_loses_protection_on_next_tick() -> void:
	var sim := _sim()
	sim.construction.damage(sim, 0, 600)
	var worker := _worker(sim, 68)
	var site := sim.construction.place(sim, 0, 100, PackedInt32Array([worker]))
	sim.tick_once()
	check_eq(sim.rules.alive[0], 1, "erster Beitrag schützt")
	check(sim.construction.cancel(sim, site), "bewusster Abbruch")
	sim.tick_once()
	check_eq(sim.rules.alive[0], 0, "letzten Schutz verloren")
	check_no_errors(sim.check_invariants(), "Niederlagebilanz")

func test_cancel_price_survives_save_and_legacy_without_paid_field_cannot_mint_refund() -> void:
	var sim := _sim()
	var first := _site(sim, false)
	var second := sim.construction.place(sim, 1, 200, PackedInt32Array())
	check_eq(sim.construction.cancel_refund(second), 300, "Preissteigerung bezahlt")
	var loaded := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(loaded != null, "Kaufpreis gespeichert")
	if loaded == null: return
	check_eq(loaded.construction.cancel_refund(second), 300, "exakter bezahlter Preis")
	var old := SaveGame.snapshot(sim)
	for row in old.construction.sites.records: row.erase("paid")
	var legacy := SaveGame.from_snapshot(old)
	check(legacy != null, "ältere Baufassung lesbar")
	if legacy != null: check_eq(legacy.construction.cancel_refund(first), 0, "unbekannter alter Preis erzeugt keine Energie")

func test_ai_respects_research_lock_remote_control_and_manual_repair_rule() -> void:
	var sim := _sim()
	_ai_workers(sim)
	sim.rules.control[1] = MatchRules.CONTROL_AI
	sim.construction.damage(sim, 1, 10)
	sim.tick_once()
	check_eq(sim.construction.sites.count(1, 1), 0, "keine Forschungsumgehung")
	check_eq(sim.construction.sites.records[1].hp, 590, "keine automatische Reparatur")
	sim.construction.outposts_unlocked = true
	sim.rules.control[1] = MatchRules.CONTROL_REMOTE
	sim.run_ticks(101)
	check_eq(sim.construction.sites.count(1, 1), 0, "Fernspieler nicht von KI gesteuert")

func test_ai_expansion_selects_reachable_paid_site_and_does_not_change_player_selection() -> void:
	var sim := _sim()
	_ai_workers(sim)
	sim.construction.outposts_unlocked = true
	sim.construction.selected = 0
	sim.tick_count = 1
	var before := sim.rules.wallet(sim, 1).energy
	Planner.step(sim, 1)
	check_eq(sim.construction.sites.count(1, 1), 1, "KI plant Außenposten")
	check_eq(sim.rules.wallet(sim, 1).energy, before - 200, "gleicher Preis")
	check_eq(sim.construction.selected, 0, "Spielerauswahl bleibt")
	var site := sim.construction.sites.records.size() - 1
	var assigned := 0
	for id in sim.workers.count:
		if sim.workers.build_site[id] == site: assigned += 1
	check(assigned > 0 and assigned <= 3, "begrenzte Baugruppe")
	sim.run_ticks(700)
	check(sim.construction.sites.records[site].ready, "echte Arbeiter bauen fertig")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_ai_rebuilds_lost_main_from_outpost_and_saves_until_affordable() -> void:
	var sim := _sim()
	_ai_workers(sim)
	_site(sim, true, 1)
	sim.construction.damage(sim, 1, 600)
	var wallet := sim.rules.wallet(sim, 1)
	wallet.energy = 499
	sim.rules.control[1] = MatchRules.CONTROL_AI
	sim.tick_once()
	check_eq(wallet.energy, 499, "spart statt Krieger/Upgrades zu kaufen")
	check_eq(sim.construction.sites.count(1, 0), 0, "kein kostenloser Ersatzkern")
	wallet.energy = 500
	sim.tick_count = 100
	sim.tick_once()
	check_eq(sim.construction.sites.count(1, 0), 1, "Ersatzkern bezahlt geplant")
	check_eq(wallet.energy, 0, "fester Preis")
	sim.rules.control[1] = MatchRules.CONTROL_REMOTE
	sim.run_ticks(1200)
	check_eq(sim.construction.sites.ready_sites(1).size(), 2, "Außenposten und neuer Hauptkern fertig")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_ai_replaces_lost_builders_and_can_buy_worker_for_stalled_main() -> void:
	var sim := _sim()
	_ai_workers(sim)
	sim.construction.outposts_unlocked = true
	sim.tick_count = 1
	Planner.step(sim, 1)
	var site := sim.construction.sites.records.size() - 1
	var id := 0
	while id < sim.workers.count:
		if sim.workers.build_site[id] == site:
			sim.workers.remove_swap(id)
			sim.worker_losses += 1
		else: id += 1
	sim.tick_count = 101
	Planner.step(sim, 1)
	var assigned := 0
	for worker in sim.workers.count:
		if sim.workers.build_site[worker] == site: assigned += 1
	check(assigned > 0, "neue Bauarbeiter zugewiesen")
	check_no_errors(sim.check_invariants(), "Masse nach Ausfällen")

func test_hud_explicit_repair_and_cancel_actions_use_current_selection() -> void:
	var sim := _sim()
	var site := _site(sim)
	sim.construction.damage(sim, site, 10)
	var worker := _worker(sim, 68)
	var hud := GameHud.new()
	hud.sim = sim
	hud.select_at(68)
	hud.select_at(100)
	hud._repair_selected()
	check_eq(sim.workers.build_mode[worker], 1, "Reparaturbutton weist Arbeiter zu")
	sim.construction.release(sim, worker)
	var plan := sim.construction.place(sim, 1, 200, PackedInt32Array())
	hud.select_at(200)
	var before := sim.upgrades.energy
	hud._cancel_selected()
	check(not sim.construction.sites.valid(plan), "Abbruchbutton")
	check_eq(sim.upgrades.energy, before + 300, "Erstattung des zweiten Außenpostens")
	hud.free()

func test_ai_caps_and_builder_sizes_follow_difficulty_and_do_not_charge_at_cap() -> void:
	for level in [SimConfig.DIFFICULTY_EASY, SimConfig.DIFFICULTY_NORMAL, SimConfig.DIFFICULTY_HARD]:
		var sim := _sim()
		_ai_workers(sim, 8)
		sim.rules.difficulty[1] = level
		sim.construction.outposts_unlocked = true
		sim.tick_count = 1
		Planner.step(sim, 1)
		var site := sim.construction.sites.records.size() - 1
		var assigned := 0
		for id in sim.workers.count:
			if sim.workers.build_site[id] == site: assigned += 1
		check_eq(assigned, 2 if level == SimConfig.DIFFICULTY_EASY else 4 if level == SimConfig.DIFFICULTY_HARD else 3, "Baugruppengröße nach KI-Stufe")
		var cap := 1 if level == SimConfig.DIFFICULTY_EASY else 3 if level == SimConfig.DIFFICULTY_HARD else 2
		for n in cap:
			if n == 0:
				sim.construction.sites.contribute(site, 1, 300)
			else:
				var c := 100 + n * 4
				var extra := sim.construction.place(sim, 1, c, PackedInt32Array(), 1)
				check(extra >= 0, "weiterer fertiger Teststandort")
				sim.construction.sites.contribute(extra, 1, 300)
		for id in sim.workers.count: sim.construction.release(sim, id)
		var before := sim.rules.wallet(sim, 1).energy
		sim.tick_count = 101
		Planner.step(sim, 1)
		check_eq(sim.construction.sites.count(1, 1), cap, "kein unbegrenztes Gebäudespam")
		check_eq(sim.rules.wallet(sim, 1).energy, before, "am Limit kein weiterer Kauf")

func test_ai_buys_replacement_worker_for_begun_main_and_live_loop_finishes_outpost() -> void:
	var sim := _sim()
	_site(sim, true, 1)
	sim.construction.damage(sim, 1, 600)
	var plan := sim.construction.place(sim, 0, 200, PackedInt32Array(), 1)
	sim.construction.sites.contribute(plan, 1, 1)
	check_eq(sim.worker_population(1), 0, "keine Arbeiter")
	var before := sim.rules.wallet(sim, 1).energy
	sim.tick_count = 1
	Planner.step(sim, 1)
	check_eq(sim.worker_population(1), 1, "Nachwuchs am fertigen Außenposten")
	check_eq(sim.rules.wallet(sim, 1).energy, before - 10, "Kauf regulär bezahlt")
	var live := _sim()
	_ai_workers(live, 8)
	live.rules.wallet(live, 1).energy = 250
	live.construction.outposts_unlocked = true
	live.rules.control[1] = MatchRules.CONTROL_AI
	live.run_ticks(1000)
	check_eq(live.construction.sites.count(1, 1, 4), 1, "KI baut im vollständigen Simulationslauf fertig")
	check_no_errors(live.check_invariants(), "KI-Lauf bilanziert")

func test_ai_does_not_pay_for_unreachable_empty_pockets() -> void:
	var sim := _sim()
	_ai_workers(sim)
	sim.construction.outposts_unlocked = true
	# Preserve only the currently occupied worker cells and buildings; empty pockets have no route.
	for cell in sim.world.cell_count():
		if sim.construction.at(cell) < 0 and sim.workers.occupant[cell] < 0: sim.world.set_material(cell, Materials.INDESTRUCTIBLE)
	for y in range(2, 6):
		for x in range(2, 6): sim.world.set_material(sim.world.index(x, y), Materials.EMPTY)
	var before := sim.rules.wallet(sim, 1).energy
	sim.tick_count = 1
	Planner.step(sim, 1)
	check_eq(sim.construction.sites.count(1, 1), 0, "unerreichbares Loch nicht als Bauplatz bezahlt")
	check_eq(sim.rules.wallet(sim, 1).energy, before, "keine Ressourcen verloren")

func test_repair_approach_with_intelligence_four_resumes_exactly_after_loading() -> void:
	var sim := _sim()
	var site := _site(sim)
	sim.construction.damage(sim, site, 100)
	var worker := _worker(sim, 0)
	sim.upgrades.swarm_level = 4
	sim.construction.assign_repair(sim, site, PackedInt32Array([worker]))
	sim.run_ticks(9)
	var copy := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(copy != null, "Anreise gespeichert")
	if copy == null: return
	for tick in 160:
		sim.tick_once()
		copy.tick_once()
		check_eq(copy.state_hash(), sim.state_hash(), "Anreise und Reparatur bleiben taktsynchron")
	check(copy.construction.sites.records[site].hp > 100, "Reparaturziel erreicht")
	check_no_errors(copy.check_invariants(), "Bilanzen")


func test_legacy_core_repairs_without_obsolete_upgrade_purchase() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 5
	var sim := TestHelpers.legacy_core_sim(config)
	sim.upgrades.energy = 1000
	check(not sim.buy(Upgrades.KIND_CORE), "Kernausbau nicht mehr direkt kaufbar")
	sim.construction.damage(sim, 0, 20)
	var ids := PackedInt32Array()
	for id in sim.workers.count: ids.append(id)
	check(sim.construction.assign_repair(sim, 0, ids) > 0, "Kern bleibt reparierbar")
	for tick in 100:
		sim.tick_once()
		check_no_errors(sim.check_invariants(), "Reparatur wahrt Invarianten")
	check_eq(sim.construction.sites.records[0].hp, 600, "Kern vollständig repariert")


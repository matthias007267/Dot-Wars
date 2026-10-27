extends TestCase
const Store = preload("res://src/sim/settlement_store.gd")

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
	return sim

func _worker(sim: Simulation, cell: int, owner := 0) -> int:
	sim.initial_mass += 1
	return sim.workers.add(cell, sim.rules.group_of[owner], owner)

func _outpost(sim: Simulation, cell := 100) -> int:
	sim.construction.outposts_unlocked = true
	return sim.construction.place(sim, Store.Kind.OUTPOST, cell, PackedInt32Array())

func _ready(sim: Simulation, id: int) -> void:
	sim.construction.sites.contribute(id, 0, 10000)

func test_approved_values_footprints_research_gate_and_payment() -> void:
	var sim := _sim()
	var main: Dictionary = sim.construction.sites.records[0]
	check_eq(main.rect.size, Vector2i(5, 5), "Startkern 5×5")
	check_eq(main.hp, 600, "Startkern 600 HP")
	check_eq(sim.construction.place(sim, 1, 100, PackedInt32Array()), -1, "Forschungssperre")
	check_eq(sim.upgrades.energy, 5000, "Sperre bucht nichts ab")
	var site := _outpost(sim)
	check(site >= 0, "Testfreigabe")
	check_eq(sim.construction.sites.records[site].rect.size, Vector2i(3, 3), "Außenposten 3×3")
	check_eq(sim.construction.sites.records[site].hp, 200, "Außenposten 200 HP")
	check_eq(sim.upgrades.energy, 4800, "200 Energie bezahlt")
	check_eq(sim.construction.price(1, 0), 300, "reservierter Bau zählt bereits für nächsten Preis")
	check_eq(sim.construction.place(sim, 1, 100, PackedInt32Array()), -1, "keine Überschneidung")
	check_eq(sim.construction.place(sim, 0, 200, PackedInt32Array()), -1, "ein eigener Kern einschließlich Plänen")
	check_eq(sim.upgrades.energy, 4800, "ungültige Platzierung kostenlos")
	check(not sim.construction.sites.records[site].started, "Plan ist keine Arbeit")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_terrain_units_boundary_and_other_buildings_reject_before_payment() -> void:
	var sim := _sim()
	sim.construction.outposts_unlocked = true
	for cell in [31, 1023, -1]: check_eq(sim.construction.place(sim, 1, cell, PackedInt32Array()), -1, "Grenzen")
	sim.world.set_material(100, Materials.SOFT)
	check_eq(sim.construction.place(sim, 1, 100, PackedInt32Array()), -1, "Fels")
	sim.world.set_material(100, Materials.EMPTY)
	_worker(sim, 100)
	check_eq(sim.construction.place(sim, 1, 100, PackedInt32Array()), -1, "Arbeiter")
	sim.army.add(200, 1)
	check_eq(sim.construction.place(sim, 1, 200, PackedInt32Array()), -1, "Krieger")
	sim.buildings.add(Buildings.KIND_SOURCE, 300)
	check_eq(sim.construction.place(sim, 1, 300, PackedInt32Array()), -1, "bestehendes Legacy-Gebäude")
	sim.energy_dots.enqueue(400, 1)
	check_eq(sim.construction.place(sim, 1, 400, PackedInt32Array()), -1, "keine Energie unter Gebäude einschließen")
	check_eq(sim.upgrades.energy, 5000, "keine Abbuchung")

func test_one_worker_takes_300_ticks_and_two_workers_150_ticks() -> void:
	for count in [1, 2]:
		var sim := _sim()
		var site := _outpost(sim)
		var ids := PackedInt32Array()
		for offset in count: ids.append(_worker(sim, 68 + offset))
		check_eq(sim.construction.assign(sim, site, ids), count, "alle eigenen Arbeiter zugewiesen")
		sim.run_ticks(300 / count - 1)
		check(not sim.construction.sites.records[site].ready, "nicht vorzeitig fertig")
		check_eq(sim.construction.sites.records[site].work, 300 - count, "echte gemeinsame Beiträge")
		sim.tick_once()
		check(sim.construction.sites.records[site].ready, "genaue Bauzeit")
		check_eq(sim.workers.build_site[0], -1, "Auftrag bei Fertigstellung beendet")
		check_no_errors(sim.check_invariants(), "Bilanzen")

func test_builders_walk_around_obstacles_without_mining_and_can_receive_new_orders() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	var id := _worker(sim, 64)
	sim.world.set_material(66, Materials.INDESTRUCTIBLE)
	sim.upgrades.swarm_level = 4
	sim.assign_area(0, Rect2i(0, 0, 32, 32))
	sim.construction.assign(sim, site, PackedInt32Array([id]))
	sim.run_ticks(40)
	check(sim.construction.sites.records[site].work > 0, "Bauplatz über freien Umweg erreicht")
	check_eq(sim.workers.state[id], WorkerStore.STATE_BUILDING, "normaler Schwarm überschreibt Auftrag nicht")
	check_eq(sim.world.cells[66], Materials.INDESTRUCTIBLE, "Fels bleibt")
	check(sim.take_party(PackedInt32Array([id])) >= 0, "neuer Marschauftrag")
	check_eq(sim.workers.build_site[id], -1, "Bauzuweisung gelöscht")
	var before: int = sim.construction.sites.records[site].work
	sim.run_ticks(5)
	check_eq(sim.construction.sites.records[site].work, before, "kein weiterer Arbeitsbeitrag")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_dense_worker_removal_preserves_builder_assignment() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	_worker(sim, 67)
	var id := _worker(sim, 68)
	sim.construction.assign(sim, site, PackedInt32Array([id]))
	sim.workers.remove_swap(0)
	sim.worker_losses += 1
	check_eq(sim.workers.build_site[0], site, "nachgerückter Arbeiter behält Bauziel")
	sim.tick_once()
	check_eq(sim.construction.sites.records[site].work, 1, "lebender Nachrücker arbeitet")
	check_no_errors(sim.check_invariants(), "Masse")

func test_outpost_continues_after_main_loss_and_produces_both_unit_types() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	_ready(sim, site)
	sim.construction.damage(sim, 0, 600)
	sim.tick_once()
	check_eq(sim.rules.alive[0], 1, "fertiger Außenposten erhält Fraktion")
	check(not sim.won, "kein vorzeitiger Sieg")
	check(sim.buy_worker(site), "Arbeiter am Außenposten")
	check(sim.buy_warrior(0, site), "Krieger am Außenposten")
	sim.run_ticks(21)
	check_eq(sim.worker_population(), 1, "Arbeiter vorhanden")
	check_eq(sim.army.count, 1, "Krieger vorhanden")
	check_no_errors(sim.check_invariants(), "Produktionsbilanzen")

func test_finished_outposts_receive_physical_energy() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	_ready(sim, site)
	sim.construction.damage(sim, 0, 600)
	var cells := sim.construction.receivers(sim, 0)
	check(not cells.is_empty(), "Empfangsrand")
	var before := sim.upgrades.energy
	sim.energy_dots.enqueue(cells[0], 3)
	check_eq(sim.upgrades.energy, before, "keine vorzeitige Gutschrift")
	sim.run_ticks(10)
	check_eq(sim.upgrades.energy, before + 3 - 25, "Energieeingang abzüglich erster Außenpostenminute")
	check_no_errors(sim.check_invariants(), "Energiebilanz")

func test_begun_main_protects_without_workers_but_unstarted_plan_does_not() -> void:
	for begun in [false, true]:
		var sim := _sim()
		sim.construction.damage(sim, 0, 600)
		var plan: int = sim.construction.place(sim, 0, 100, PackedInt32Array())
		check(plan >= 0, "Ersatzkernplatz")
		check_eq(sim.upgrades.energy, 4500, "fester Kernpreis")
		check_eq(sim.construction.sites.records[plan].required, 600, "600 Arbeitertakte")
		if begun:
			var id := _worker(sim, 68)
			sim.construction.assign(sim, plan, PackedInt32Array([id]))
			sim.tick_once()
			sim.workers.remove_swap(0)
			sim.worker_losses += 1
		sim.tick_once()
		check_eq(sim.rules.alive[0], 1 if begun else 0, "nur erster echter Beitrag schützt")
		if begun:
			check(not sim.buy_worker(plan), "unfertiger Kern produziert nicht")
			sim.construction.damage(sim, plan, 600)
			sim.tick_once()
			check_eq(sim.rules.alive[0], 0, "letzter Schutz verloren")
		check_no_errors(sim.check_invariants(), "Niederlagebilanz")

func test_outpost_construction_does_not_protect_and_foreign_workers_do_not_build() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	var foreign := _worker(sim, 68, 1)
	check_eq(sim.construction.assign(sim, site, PackedInt32Array([foreign])), 0, "fremde Arbeiter abgewiesen")
	sim.construction.sites.contribute(site, 0, 1)
	sim.construction.damage(sim, 0, 600)
	sim.tick_once()
	check_eq(sim.rules.alive[0], 0, "begonnener Außenposten allein schützt nicht")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_global_50_limit_across_sites_and_destroyed_site_cancels_paid_queues() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	_ready(sim, site)
	for n in 50: check(sim.buy_worker(0 if n % 2 == 0 else site), "gemeinsame Käufe")
	check(not sim.buy_worker(site), "kein 51. Arbeiter über anderen Standort")
	check(sim.buy_warrior(0, site), "bezahlter Krieger")
	sim.construction.damage(sim, site, 200)
	sim.tick_once()
	check_eq(sim.worker_population(), 25, "verlorene Aufträge korrekt entfernt")
	check_eq(sim.army.lost, 1, "zerstörte Kriegerproduktion als Verlust")
	check_no_errors(sim.check_invariants(), "Bilanzen trotz verlorener Warteschlangen")

func test_construction_save_load_continues_exactly_and_bad_assignments_are_rejected() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	var id := _worker(sim, 64)
	sim.construction.assign(sim, site, PackedInt32Array([id]))
	sim.run_ticks(30)
	var copy := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(copy != null, "Bau gespeichert und geladen")
	if copy == null: return
	check_eq(copy.state_hash(), sim.state_hash(), "Ausgangszustand exakt")
	for n in 320:
		sim.tick_once()
		copy.tick_once()
		check_eq(copy.state_hash(), sim.state_hash(), "taktgleich nach Laden")
	check(copy.construction.sites.records[site].ready, "nach Laden fertig gebaut")
	var bad := SaveGame.snapshot(sim)
	bad.units[0].build_site = 9999
	check(SaveGame.from_snapshot(bad) == null, "unbekannte Zuweisung abgewiesen")
	check_no_errors(copy.check_invariants(), "Bilanzen")

func test_warrior_hits_full_building_perimeter_and_destruction_frees_ground() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	_ready(sim, site)
	sim.construction.sites.records[site].hp = 1
	var uid := sim.army.add(68, 1)
	sim.army.next_move[sim.army.slots[uid]] = 100
	sim.tick_once()
	check(not sim.construction.sites.valid(site), "Nahkampftreffer am Rand")
	check_eq(sim.world.cells[100], Materials.EMPTY, "Boden freigegeben")
	check_eq(sim.rules.alive[0], 1, "eigener Hauptkern bleibt Schutz")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_destroyed_production_saves_immediately_and_reservations_wait_when_blocked() -> void:
	var sim := _sim()
	var site := _outpost(sim)
	_ready(sim, site)
	check(sim.buy_worker(site), "Kauf wartet")
	check(sim.buy_warrior(0, site), "Krieger wartet")
	sim.construction.damage(sim, site, 200)
	check_eq(sim.spawner.pending(), 0, "Warteschlange sofort bereinigt")
	check_eq(sim.army.queue.size(), 0, "Krieger sofort bereinigt")
	check(SaveGame.from_bytes(SaveGame.to_bytes(sim)) != null, "direkt nach Treffer ladbar")
	check_no_errors(sim.check_invariants(), "sofortige Bilanz")
	var second := _outpost(sim, 100)
	_ready(sim, second)
	check(sim.buy_worker(second), "erneuter Kauf")
	for cell in sim.construction.receivers_for(sim, second): _worker(sim, cell)
	# A full ring of workers does not allow a unit to spawn in the solid building.
	sim.tick_once()
	check_no_errors(sim.check_invariants(), "kein Spawn auf Gebäude/Einheit")

func test_fixed_buildings_do_not_accept_legacy_core_area_upgrade() -> void:
	var sim := _sim()
	check(not sim.buy(Upgrades.KIND_CORE), "kein Alterweiterungskauf für neuen Gebäudekern")
	sim.debug_mode = true
	check(not sim.debug_adjust_upgrade(Upgrades.KIND_CORE, 1), "Testlabor verändert keine festen Gebäudeflächen")
	check_eq(sim.construction.sites.records[0].rect.size, Vector2i(5, 5), "Geometrie bleibt eindeutig")

func test_outpost_test_unlock_is_runtime_only_and_prevents_regular_saves() -> void:
	var sim := _sim()
	var hud := GameHud.new()
	hud.sim = sim
	hud._unlock_outposts()
	check(not sim.construction.outposts_unlocked, "außerhalb Labor gesperrt")
	sim.debug_mode = true
	hud._unlock_outposts()
	check(sim.construction.outposts_unlocked and sim.debug_modified, "Teständerung markiert")
	var copy := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(copy != null, "technischer Snapshot ladbar")
	if copy != null: check(not copy.construction.outposts_unlocked, "Freigabe nicht dauerhaft erforscht")
	hud.free()

func test_building_hud_selects_origin_and_issues_real_worker_build_order() -> void:
	var sim := _sim()
	var worker := _worker(sim, 68)
	var hud := GameHud.new()
	hud.sim = sim
	sim.fog.update(sim)
	hud.select_at(sim.workers.cell[worker])
	check_eq(hud.selection, PackedInt32Array([worker]), "sichtbarer Arbeiter gewählt")
	sim.construction.outposts_unlocked = true
	hud._begin_settlement(1)
	check(hud.issue_build(100), "Baustelle über echte HUD-Befehle")
	var site: int = sim.construction.at(100)
	check_eq(sim.workers.build_site[worker], site, "Auswahl zugewiesen")
	hud.select_at(100)
	check_eq(hud._production_site(), site, "Baustelle ist explizit gewählt")
	check(not sim.buy_worker(hud._production_site()), "kein heimlicher Kauf an anderem fertigem Kern")
	sim.run_ticks(300)
	check(sim.construction.sites.records[site].ready, "über HUD gebaut")
	check(sim.buy_worker(hud._production_site()), "gewählter Außenposten produziert")
	check_no_errors(sim.check_invariants(), "Bilanzen")
	hud.free()


func test_legacy_one_cell_cores_import_saved_hp_without_expanding_into_units() -> void:
	var sim := _sim()
	for row in sim.construction.sites.records:
		var center: int = sim.construction.center(row.id)
		var rect: Rect2i = row.rect
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if y * 32 + x != center: sim.world.set_material(y * 32 + x, Materials.EMPTY)
		# Original match cores had max HP 160; preserve damage rather than healing.
		sim.rules.core_hp[row.owner] = 120
	var beside := sim.rules.cores[0] - 1
	_worker(sim, beside)
	var old := SaveGame.snapshot(sim)
	old.erase("construction")
	for unit in old.units: unit.erase("build_site")
	var loaded := SaveGame.from_snapshot(old)
	check(loaded != null, "Version 2 ohne Bauabschnitt")
	if loaded == null: return
	check_eq(loaded.construction.sites.records[0].rect.size, Vector2i.ONE, "alte Fläche nicht erweitert")
	check_eq(loaded.construction.sites.records[0].hp, 120, "Schadensstand erhalten")
	check_eq(loaded.construction.sites.records[0].max_hp, 160, "altes HP-Maximum erhalten")
	check_eq(loaded.workers.cell[0], beside, "benachbarter Arbeiter nicht überbaut")
	check(loaded.buy_worker(), "alter Kern bleibt Produktionsort")
	loaded.run_ticks(5)
	check_no_errors(loaded.check_invariants(), "Altstand fortgesetzt")

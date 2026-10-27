extends TestCase
const Store = preload("res://src/sim/settlement_store.gd")
const ConstructionAI = preload("res://src/sim/construction_ai.gd")

func _sim() -> Simulation:
	var config := SimConfig.new()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 5000
	return sim

func _tower(sim: Simulation, ready := true) -> int:
	sim.research.levels[0]["energy_speed"] = 1
	sim.research.levels[0]["defense"] = 1
	var site: int = sim.construction.place(sim, 4, sim.world.index(27, 26), PackedInt32Array())
	if ready: sim.construction.sites.contribute(site, 0, 300)
	sim.fog.update(sim)
	return site

func _enemy(sim: Simulation, cell := -1) -> int:
	var uid := sim.army.add(sim.world.index(34, 27) if cell < 0 else cell, 1)
	sim.fog.update(sim)
	return uid

func _connect(sim: Simulation, site: int) -> PackedInt32Array:
	var route := sim.energy_network.plan_connection(sim, 0, 0, site)
	sim.energy_network.place_path(sim, 0, route)
	return route

func _activate(sim: Simulation, site: int) -> void:
	_connect(sim, site)
	sim.defense.step(sim)

func test_tower_requires_research_paid_construction_and_is_not_a_producer() -> void:
	var sim := _sim()
	check_eq(sim.construction.place(sim, 4, sim.world.index(27, 26), PackedInt32Array()), -1, "Forschung erforderlich")
	var site := _tower(sim, false)
	check_eq(sim.upgrades.energy, 4750, "250 Energie Baupreis")
	check_eq(sim.construction.sites.records[site].max_hp, 200, "200 HP")
	check_eq(sim.construction.sites.records[site].rect.size, Vector2i(3, 3), "3x3")
	_enemy(sim)
	_connect(sim, site)
	sim.defense.step(sim)
	check(not sim.defense.weapons.has(site), "Baustelle kauft keinen Unterhalt und feuert nicht")
	sim.construction.sites.contribute(site, 0, 300)
	check(not sim.buy_worker(site) and not sim.buy_warrior(0, site), "kein Produzent")
	sim.construction.damage(sim, 0, 600)
	check(not sim.construction.survives(0), "Turm allein schützt nicht vor Niederlage")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_shot_needs_connection_and_paid_upkeep_and_damage_waits_for_impact() -> void:
	var sim := _sim()
	var site := _tower(sim)
	var uid := _enemy(sim)
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "Guthaben ohne Anschluss reicht nicht")
	var before := sim.upgrades.energy
	_activate(sim, site)
	check_eq(sim.upgrades.energy, before - 100, "eine volle Minute vorausbezahlt")
	check_eq(sim.defense.projectiles.size(), 1, "ein Schuss")
	check_eq(sim.army.hp[sim.army.slots[uid]], ArmyState.HEALTH, "kein Sofortschaden")
	for tick in range(1, 12):
		sim.tick_count = tick
		sim.defense.step(sim)
	check_eq(sim.army.hp[sim.army.slots[uid]], ArmyState.HEALTH, "Flugzeit bleibt echt")
	sim.tick_count = 12
	sim.defense.step(sim)
	check_eq(sim.army.hp[sim.army.slots[uid]], ArmyState.HEALTH - 2, "Trefferschaden")
	check_eq(sim.upgrades.energy, before - 100, "Schüsse kosten nichts zusätzlich")

func test_upkeep_is_exactly_60_seconds_without_partial_debits_or_free_renewal() -> void:
	var sim := _sim()
	var site := _tower(sim)
	_connect(sim, site)
	sim.upgrades.energy = 100
	sim.defense.step(sim)
	check_eq(sim.upgrades.energy, 75, "Kern zuerst mit 25 bezahlt")
	check(not sim.defense.is_powered(sim, site), "75 reichen nicht für Turm")
	sim.upgrades.energy += 25
	sim.defense.step(sim)
	check_eq(sim.upgrades.energy, 0, "Turm für genau 100 aktiviert")
	sim.tick_count = 1199
	sim.defense.step(sim)
	check(sim.defense.is_powered(sim, site), "leeres Guthaben beendet bezahlte Minute nicht")
	check_eq(sim.defense.upkeep_spent, 125, "keine Zwischenzahlungen")
	sim.tick_count = 1200
	sim.defense.step(sim)
	check(not sim.defense.is_powered(sim, site), "nach 1200 Takten ohne Geld aus")
	check_eq(sim.upgrades.energy, 0, "kein negatives Guthaben")
	sim.upgrades.energy = 125
	sim.defense.step(sim)
	check(sim.defense.is_powered(sim, site), "Versorgung mit neuem Guthaben wieder an")
	check_eq(sim.defense.upkeep_spent, 250, "nächste Minute genau einmal bezahlt")

func test_cut_network_stops_paid_weapon_and_reconnects_without_rebilling() -> void:
	var sim := _sim()
	var site := _tower(sim)
	var path := _connect(sim, site)
	sim.defense.step(sim)
	var before := sim.upgrades.energy
	var deadline: int = sim.defense.weapons[site].paid_until
	var cut := path[path.size() / 2]
	sim.energy_network.remove(0, cut)
	_enemy(sim)
	sim.defense.step(sim)
	check(not sim.defense.is_powered(sim, site), "Netz fehlt trotz Zahlung")
	check_eq(sim.defense.projectiles.size(), 0, "kein Schuss ohne Verbindung")
	var loaded := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(loaded != null, "bezahlte Unterbrechung speicherbar")
	if loaded == null: return
	for copy in [sim, loaded]: copy.energy_network.place(copy, 0, cut)
	for tick in range(1, 16):
		for copy in [sim, loaded]:
			copy.tick_count = tick
			copy.defense.step(copy)
		check_eq(loaded.state_hash(), sim.state_hash(), "gleiche Fortsetzung")
	check_eq(sim.upgrades.energy, before, "kein zweiter Minutenpreis")
	check_eq(int(sim.defense.weapons[site].paid_until), deadline, "bezahlte Zeit läuft bei Abriss weiter")

func test_mined_energy_is_credited_to_wallet_without_local_buffers() -> void:
	var sim := _sim()
	var gate: int = sim.construction.receivers(sim, 0)[0]
	var before := sim.upgrades.energy
	sim.energy_dots.enqueue(gate, 11)
	sim.tick_once()
	check_eq(sim.energy_dots.delivered, 11, "alle elf Punkte physisch eingegangen")
	check_eq(sim.upgrades.energy, before + 11 - 25, "Guthaben plus Eingang minus erste Kernminute")
	check_eq(sim.energy_dots.delivered_to[0], 11, "vollständiger Energieeingang gutgeschrieben")
	check(not sim.defense.snapshot().has("supply") and not sim.defense.snapshot().has("shipments"), "keine lokalen Vorräte")
	check_no_errors(sim.check_invariants(), "Bilanz")

func test_resources_and_diagonal_corners_block_weapons_despite_fog_depth() -> void:
	for barrier in [Materials.ROCK, Materials.DIAMOND, Materials.INDESTRUCTIBLE]:
		var sim := _sim()
		var site := _tower(sim)
		_activate(sim, site)
		_enemy(sim)
		sim.world.set_material(sim.world.index(31, 27), barrier)
		sim.fog.update(sim)
		check(sim.fog.is_visible(0, sim.world.index(34, 27)), "Nebel blickt weiter")
		sim.defense.step(sim)
		check_eq(sim.defense.projectiles.size(), 0, "Waffe schießt nicht durch Material")
	var sim := _sim()
	var site := _tower(sim)
	_activate(sim, site)
	_enemy(sim, sim.world.index(31, 30))
	sim.world.set_material(sim.world.index(30, 28), Materials.ROCK)
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "keine Schüsse durch massive Ecken")

func test_workers_allies_and_hidden_warriors_are_not_targeted() -> void:
	var sim := _sim()
	var site := _tower(sim)
	_activate(sim, site)
	sim.workers.add(sim.world.index(34, 27), sim.rules.group_of[1], 1)
	sim.initial_mass += 1
	var uid := _enemy(sim, sim.world.index(34, 28))
	sim.army.teams[1] = 0
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "kein Beschuss von Verbündeten")
	sim.army.teams[1] = 1
	var cell: int = sim.army.cells[sim.army.slots[uid]]
	sim.fog.visible[0][cell] = 0
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "verdeckte Krieger und gegnerische Arbeiter ignoriert")
	sim.fog.visible[0][cell] = 1
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 1, "sichtbarer feindlicher Krieger")
	check_eq(sim.workers.health[0], WorkerStore.DEFAULT_HEALTH, "Arbeiter unbeschädigt")

func test_flying_shots_hit_new_walls_and_never_retarget_a_swapped_slot() -> void:
	var sim := _sim()
	var site := _tower(sim)
	_activate(sim, site)
	var uid := _enemy(sim)
	sim.defense.step(sim)
	sim.world.set_material(sim.world.index(30, 27), Materials.ROCK)
	for tick in range(1, 15):
		sim.tick_count = tick
		sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "neue Wand stoppt Flug")
	check_eq(sim.army.hp[sim.army.slots[uid]], ArmyState.HEALTH, "kein Treffer hinter neuer Wand")
	sim.world.set_material(sim.world.index(30, 27), Materials.EMPTY)
	sim.tick_count = 20
	sim.defense.step(sim)
	var survivor := _enemy(sim, sim.world.index(34, 28))
	sim.army.remove(uid)
	sim.tick_count = 22
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "verschwundene Ziel-ID verworfen")
	check_eq(sim.army.hp[sim.army.slots[survivor]], ArmyState.HEALTH, "kein Slot-Nachrücker getroffen")

func test_individual_upgrade_costs_time_and_updates_fog_art_without_unit_motion() -> void:
	var sim := _sim()
	var site := _tower(sim)
	_activate(sim, site)
	var before := sim.upgrades.energy
	check(sim.defense.upgrade(sim, site), "lokaler Ausbau")
	check(not sim.defense.upgrade(sim, site), "kein doppelter Ausbau")
	_enemy(sim)
	sim.tick_count = 199
	sim.defense.step(sim)
	check_eq(sim.defense.projectiles.size(), 0, "Ausbau pausiert Waffe")
	check(SaveGame.from_snapshot(SaveGame.snapshot(sim)) != null, "laufender Ausbau speicherbar")
	sim.tick_count = 200
	sim.defense.step(sim)
	sim.fog.update(sim)
	check_eq(int(sim.fog.known_sites[0][site].weapon_level), 2, "neue Stufe ohne Bewegung sichtbar")
	check(sim.defense.upgrade(sim, site), "Strahl-Ausbau")
	sim.tick_count = 400
	sim.defense.step(sim)
	check_eq(sim.defense.level(sim.construction.sites.records[site]), 3, "Strahlstufe")
	check_eq(sim.upgrades.energy, before - 450, "150 plus 300, kein neuer Unterhalt bei Stufenwechsel")
	check(not sim.defense.upgrade(sim, site), "keine Stufe IV")

func test_beam_has_five_damage_per_second_without_shot_costs_and_bases_are_weaker() -> void:
	var sim := _sim()
	var site := _tower(sim)
	var row: Dictionary = sim.construction.sites.records[site]
	row.weapon_level = 3
	_activate(sim, site)
	var uid := _enemy(sim)
	var before := sim.upgrades.energy
	for tick in 5:
		sim.tick_count = tick
		sim.defense.step(sim)
	check_eq(sim.army.hp[sim.army.slots[uid]], ArmyState.HEALTH - 2, "Strahlimpulse bei 0 und 4")
	check_eq(sim.upgrades.energy, before, "keine Schusskosten")
	check_eq(sim.defense.stats(sim.construction.sites.records[0]), {"range": 5, "period": 30, "damage": 1, "beam": false}, "schwächere Kernwaffe")
	check_eq(sim.defense.stats({"kind": 1}).period, 30, "Außenposten ebenfalls schwächer")

func test_save_keeps_paid_period_projectiles_cooldowns_and_rejects_corruption() -> void:
	var sim := _sim()
	var site := _tower(sim)
	_activate(sim, site)
	_enemy(sim)
	sim.defense.step(sim)
	var data := SaveGame.snapshot(sim)
	var reference := SaveGame.from_snapshot(data)
	check(reference != null, "fliegender Schuss ladbar")
	if reference == null: return
	reference.army.reference_only = true
	for tick in 45:
		sim.tick_once()
		reference.tick_once()
		check_eq(sim.state_hash(), reference.state_hash(), "Native/Referenz nach Laden")
	var bad := data.duplicate(true)
	bad.defense_state.weapons[site].paid_until = sim.tick_count + 99999
	check(SaveGame.from_snapshot(bad) == null, "erfundener Versorgungszeitraum abgewiesen")
	bad = data.duplicate(true)
	bad.defense_state.projectiles[0].target = -2
	check(SaveGame.from_snapshot(bad) == null, "ungültiges Ziel abgewiesen")
	var old := SaveGame.snapshot(_sim())
	old.erase("defense_state")
	var legacy := SaveGame.from_snapshot(old)
	check(legacy != null, "alter Version-2-Stand bleibt ladbar")
	if legacy != null: check_eq(legacy.defense.upkeep_spent, 0, "beim Laden keine Minute erfunden")

func test_defense_research_requires_network_pays_upfront_and_waits_full_duration() -> void:
	var sim := _sim()
	var site: int = sim.construction.place(sim, 3, sim.world.index(20, 35), PackedInt32Array())
	sim.construction.sites.contribute(site, 0, 300)
	check(not sim.research.start(sim, 0, site, "defense"), "Voraussetzung Energietransport")
	sim.research.levels[0]["energy_speed"] = 1
	check(not sim.research.start(sim, 0, site, "defense"), "Netz erforderlich")
	_connect(sim, site)
	var before := sim.upgrades.energy
	check(sim.research.start(sim, 0, site, "defense"), "regulärer Auftrag")
	check_eq(sim.upgrades.energy, before - 120, "sofort vollständig bezahlt")
	for tick in 359: sim.research.step(sim)
	check_eq(sim.research.level(0, "defense"), 0, "kein vorzeitiger Abschluss")
	sim.research.step(sim)
	check(sim.construction.unlocked(sim, 4), "nach 360 Takten freigeschaltet")

func test_ai_builds_owned_towers_and_connects_them_without_free_ammo() -> void:
	var sim := _sim()
	var ai := sim.rules.wallet(sim, 1)
	ai.energy = 2000
	sim.research.levels[1]["defense"] = 1
	var center: int = sim.construction.place(sim, 3, sim.world.index(46, 36), PackedInt32Array(), 1)
	sim.construction.sites.contribute(center, 1, 300)
	for y in range(32, 35):
		sim.workers.add(sim.world.index(46, y), sim.rules.group_of[1], 1)
		sim.initial_mass += 1
	sim.tick_count = 1
	check(ConstructionAI.step(sim, 1), "KI beauftragt bezahlten Turmbau")
	var site := sim.construction.sites.records.size() - 1
	check_eq(int(sim.construction.sites.records[site].kind), 4, "wirklicher Kriegsturm")
	check_eq(int(sim.construction.sites.records[site].owner), 1, "eigene KI-Fraktion")
	check_eq(ai.energy, 1450, "300 Forschungshaus und 250 Turm bezahlt")
	sim.construction.sites.contribute(site, 1, 300)
	sim.tick_count = 101
	ConstructionAI.step(sim, 1)
	check(sim.research.source_for(sim, 1, site) >= 0, "reale Leitungsverbindung zum KI-Kern")
	check(not sim.defense.weapons.has(site), "Planung erfindet keine bezahlte Minute")
	check_no_errors(sim.check_invariants(), "KI-Bau- und Waffenbilanzen")

func test_ai_keeps_tower_upkeep_budget_but_can_still_rebuild_minimal_workforce() -> void:
	var sim := _sim()
	sim.rules.wallet(sim, 1).energy = 500
	sim.research.levels[1]["defense"] = 1
	var site: int = sim.construction.place(sim, 4, sim.world.index(44, 26), PackedInt32Array(), 1)
	check(site >= 0, "KI-Turm geplant")
	sim.rules.wallet(sim, 1).energy = 100
	check(sim.rules._buy_worker(sim, 1), "fehlende Grundbelegschaft hat Vorrang")
	for y in range(29, 33):
		sim.workers.add(sim.world.index(46, y), sim.rules.group_of[1], 1)
		sim.initial_mass += 1
	sim.rules.wallet(sim, 1).energy = 100
	check_eq(sim.defense.reserve(sim, 1), 100, "bezahlbaren Turmunterhalt zurückhalten")
	check(not sim.rules._buy_worker(sim, 1), "zusätzlicher Arbeiter verbraucht Unterhaltsreserve nicht")

extends TestCase
const Transport = preload("res://src/sim/energy_transport.gd")

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

func _station(sim: Simulation, owner := 0, cell := 100, ready := true) -> int:
	sim.construction.interceptors_unlocked = true
	var site := sim.construction.place(sim, 2, cell, PackedInt32Array(), owner)
	if ready: sim.construction.sites.contribute(site, owner, 300)
	return site

func _raw(world: WorldState, energy: EnergyStore, gates: PackedInt32Array, start: int, count: int) -> void:
	var workers := WorkerStore.new(world.cell_count(), 1, world.width)
	for tick in range(start, start + count): energy.step(world, workers, gates, tick)

func _ledger(sim: Simulation) -> void:
	var ledger := sim.energy_dots.ledger()
	check_eq(ledger.generated, ledger.delivered + ledger.expired + ledger.pending, "globale Erhaltung")
	check_eq(ledger.pending, ledger.free_owned + ledger.buffered + ledger.neutral, "Puffer nicht doppelt zählen")
	check_no_errors(sim.check_invariants(), "Simulationsinvarianten")

func test_no_route_expires_exactly_after_1200_simulation_ticks_even_between_movement_ticks() -> void:
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var energy := EnergyStore.new()
	energy.enqueue(10, 3)
	_raw(world, energy, PackedInt32Array(), 0, 1199)
	check_eq(energy.pending(), 3, "59,95 Sekunden noch vorhanden")
	check_eq(energy.no_route[0], 1199, "Timer unabhängig vom Bewegungstakt")
	_raw(world, energy, PackedInt32Array(), 1199, 1)
	check_eq(energy.pending(), 0, "60 Sekunden verfallen")
	check_eq(energy.expired, 3, "Verfall bilanziert")
	check_eq(energy.generated, energy.expired, "keine Gutschrift")

func test_worker_congestion_is_not_missing_terrain_route() -> void:
	var world := WorldState.new(16, 16, 8, Materials.INDESTRUCTIBLE)
	for x in range(2, 13): world.set_material(world.index(x, 8), Materials.EMPTY)
	var workers := WorkerStore.new(world.cell_count(), 1, world.width)
	workers.add(world.index(3, 8), 0)
	var energy := EnergyStore.new()
	energy.enqueue(world.index(2, 8), 1)
	for tick in 1300: energy.step(world, workers, PackedInt32Array([world.index(12, 8)]), tick)
	check_eq(energy.pending(), 1, "wartet hinter Arbeiter")
	check_eq(energy.expired, 0, "kein Verfall durch Stau")
	check_eq(energy.no_route[0], 0, "Terrainroute gilt weiterhin")

func test_route_restoration_resets_timer_and_changed_terrain_is_checked_immediately() -> void:
	var world := WorldState.new(16, 16, 8, Materials.INDESTRUCTIBLE)
	for x in range(2, 13): world.set_material(world.index(x, 8), Materials.EMPTY)
	var origin := world.index(2, 8)
	var barrier := world.index(6, 8)
	world.set_material(barrier, Materials.INDESTRUCTIBLE)
	var workers := WorkerStore.new(world.cell_count(), 1, world.width)
	workers.add(world.index(3, 8), 0)
	var energy := EnergyStore.new()
	energy.enqueue(origin, 1)
	var gate := PackedInt32Array([world.index(12, 8)])
	for tick in 1199: energy.step(world, workers, gate, tick)
	world.set_material(barrier, Materials.EMPTY)
	energy.step(world, workers, gate, 1199)
	check_eq(energy.no_route[0], 0, "Route im letzten Moment setzt zurück")
	world.set_material(barrier, Materials.INDESTRUCTIBLE)
	energy.step(world, workers, gate, 1200)
	check_eq(energy.no_route[0], 1, "neue Sperre sofort erkannt")
	for tick in range(1201, 2399): energy.step(world, workers, gate, tick)
	check_eq(energy.pending(), 1, "neue volle Frist")
	energy.step(world, workers, gate, 2399)
	check_eq(energy.expired, 1, "erneute 60 Sekunden abgelaufen")

func test_research_gate_values_real_worker_build_and_station_is_not_production_or_survival() -> void:
	var sim := _sim()
	check_eq(sim.construction.place(sim, 2, 100, PackedInt32Array()), -1, "normal gesperrt")
	var before := sim.upgrades.energy
	var site := _station(sim, 0, 100, false)
	check(site >= 0, "Testlabor-Freigabe")
	check_eq(sim.upgrades.energy, before - 250, "250 Energie")
	check_eq(sim.construction.sites.records[site].hp, 150, "150 HP")
	check_eq(sim.construction.sites.records[site].rect.size, Vector2i(3, 3), "3×3")
	var worker := sim.workers.add(68, 0)
	sim.initial_mass += 1
	sim.construction.assign(sim, site, PackedInt32Array([worker]))
	sim.run_ticks(300)
	check(sim.construction.sites.records[site].ready, "300 echte Arbeitertakte")
	check(not sim.buy_worker(site), "keine Fabrik")
	check(not sim.buy_warrior(0, site), "kein Kriegerproduzent")
	check(not sim.construction.receivers(sim, 0).has(68), "kein Energieempfänger")
	sim.construction.damage(sim, 0, 600)
	check(not sim.construction.survives(0), "Station allein schützt nicht")
	_ledger(sim)

func test_capture_changes_owner_but_credits_only_after_physical_arrival() -> void:
	var sim := _sim()
	var site := _station(sim)
	var before := sim.upgrades.energy
	var enemy_before := sim.rules.wallet(sim, 1).energy
	sim.energy_dots.enqueue(68, 1, 1)
	sim.tick_once()
	check_eq(sim.energy_dots.owner[0], 0, "Besitzer geändert")
	check_eq(sim.energy_dots.held_by[0], site, "gepuffert")
	check_eq(sim.energy_dots.cells[0], 68, "kein Teleport")
	check_eq(sim.upgrades.energy, before - 25, "keine sofortige Gutschrift, nur eigener Kernunterhalt")
	check_eq(sim.rules.wallet(sim, 1).energy, enemy_before - 25, "nur eigener Kernunterhalt, kein Geldraub")
	sim.run_ticks(19)
	check_eq(sim.energy_dots.held_by[0], site, "volle Pufferfrist")
	sim.tick_once()
	check_eq(sim.energy_dots.held_by[0], -1, "nach 20 Takten weitergegeben")
	check_eq(sim.energy_dots.owner[0], 0, "Besitz bleibt nach Weitergabe")
	sim.run_ticks(300)
	check_eq(sim.upgrades.energy, before + 1 - 25, "Gutschrift erst nach Ankunft, Kernunterhalt separat")
	check_eq(sim.energy_dots.delivered_to[0], 1, "richtige Fraktion")
	check_eq(sim.energy_dots.generated, 1, "Diebstahl erzeugt nichts")
	_ledger(sim)

func test_repeated_recapture_has_no_lifetime_limit_and_is_deterministic() -> void:
	var sim := _sim()
	var a := _station(sim, 0, 100)
	var b := _station(sim, 1, 104)
	sim.energy_dots.enqueue(103, 1, 1) # Shared free edge between both buildings.
	for tick in 161: sim.tick_once()
	check(sim.energy_dots.captured >= 9, "beliebig oft erneut abgefangen")
	check_eq(sim.energy_dots.pending(), 1, "immer derselbe Energiepunkt")
	check_eq(sim.energy_dots.generated, 1, "keine Duplizierung")
	check(sim.energy_dots.held_by[0] == a or sim.energy_dots.held_by[0] == b, "weiterhin physisch gepuffert")
	_ledger(sim)

func test_destruction_neutralizes_only_held_energy_at_its_actual_position() -> void:
	var sim := _sim()
	var site := _station(sim)
	sim.energy_dots.enqueue(68, 1, 1)
	sim.tick_once()
	sim.energy_dots.enqueue(70, 1, 0) # Already free transport is not the building's buffer.
	var before := sim.upgrades.energy
	sim.construction.damage(sim, site, 150)
	check_eq(sim.energy_dots.owner[0], EnergyStore.NEUTRAL, "Puffer neutral")
	check_eq(sim.energy_dots.cells[0], 68, "bleibt am Ort")
	check_eq(sim.energy_dots.held_by[0], -1, "nicht mehr an zerstörte Station gebunden")
	check_eq(sim.energy_dots.owner[1], 0, "freie Energie behält Besitz")
	check_eq(sim.upgrades.energy, before, "keine Neutralisierungsprämie")
	check_eq(sim.energy_dots.neutralized, 1, "Neutralisierung gezählt")
	_ledger(sim)

func test_neutral_energy_requires_station_and_can_be_recaptured_after_destruction() -> void:
	var sim := _sim()
	var a := _station(sim, 0, 100)
	_station(sim, 1, 104)
	sim.energy_dots.enqueue(103, 1, 1)
	sim.tick_once()
	sim.construction.damage(sim, a, 150)
	check_eq(sim.energy_dots.owner[0], EnergyStore.NEUTRAL, "erst neutral")
	sim.tick_once()
	check_eq(sim.energy_dots.owner[0], 1, "Gegnerstation fängt neutralen Punkt erneut")
	var raw := _sim()
	var gate := raw.construction.receivers(raw, 0)[0]
	raw.energy_dots.enqueue(gate, 1, EnergyStore.NEUTRAL)
	var before := raw.upgrades.energy
	raw.run_ticks(1200)
	check_eq(raw.upgrades.energy, before - 25, "kein neutraler Energieeingang, nur 25 Kernunterhalt")
	check_eq(raw.energy_dots.expired, 1, "neutral ohne Abfangen nach 60 Sekunden verfallen")
	_ledger(sim)
	_ledger(raw)

func test_own_and_allied_energy_and_unfinished_stations_do_not_capture() -> void:
	var sim := _sim()
	_station(sim)
	sim.army.teams[1] = 0
	sim.energy_dots.enqueue(68, 1, 1)
	sim.energy_dots.enqueue(69, 1, 0)
	sim.tick_once()
	check_eq(sim.energy_dots.captured, 0, "verbündet und eigen nicht stehlen")
	var other := _sim()
	_station(other, 0, 100, false)
	other.energy_dots.enqueue(68, 1, 1)
	other.tick_once()
	check_eq(other.energy_dots.captured, 0, "Baustelle ist noch keine Abfangstation")
	_ledger(sim)
	_ledger(other)

func test_contact_radius_respects_solid_footprint_and_priority_uses_stable_site_ids() -> void:
	var sim := _sim()
	var first := _station(sim, 0, 100)
	_station(sim, 0, 104)
	sim.energy_dots.enqueue(103, 1, 1)
	sim.energy_dots.enqueue(35, 1, 1) # Not directly adjacent.
	sim.tick_once()
	check_eq(sim.energy_dots.held_by[0], first, "kleinste stabile ID gewinnt gleichen Kontakt")
	check_eq(sim.energy_dots.held_by[1], -1, "kein Fernabfangen durch Hindernisse")
	_ledger(sim)

func test_throughput_and_capacity_limit_do_not_destroy_or_duplicate_energy() -> void:
	var sim := _sim()
	var site := _station(sim)
	sim.energy_dots.enqueue(68, 40, 1)
	sim.tick_once()
	check_eq(sim.energy_dots.ledger().buffered, 8, "acht Punkte pro Takt")
	check_eq(sim.energy_dots.pending(), 40, "Rest bleibt physisch unterwegs")
	_ledger(sim)
	var full := _sim()
	var holder := _station(full)
	full.energy_dots.enqueue(68, 256, 0)
	for i in 256:
		full.energy_dots.held_by[i] = holder
		full.energy_dots.release_at[i] = 20
	full.energy_dots.enqueue(68, 1, 1)
	full.tick_count = 1
	full.tick_once()
	check_eq(full.energy_dots.ledger().buffered, 256, "Pufferkapazität eingehalten")
	check_eq(full.energy_dots.owner[256], 1, "voller Puffer nimmt nicht an")
	_ledger(full)

func test_capture_does_not_reset_missing_route_timer_without_actual_route() -> void:
	var sim := _sim()
	_station(sim)
	# No own receiver remains, but a begun core preserves the faction.
	sim.construction.damage(sim, 0, 600)
	var main := sim.construction.place(sim, 0, 200, PackedInt32Array())
	sim.construction.sites.contribute(main, 0, 1)
	sim.energy_dots.enqueue(68, 1, 1)
	sim.energy_dots.no_route[0] = 1199
	sim.tick_once()
	check_eq(sim.energy_dots.captured, 1, "Abfangen findet statt")
	check_eq(sim.energy_dots.expired, 1, "Eigentumswechsel erfindet keine neue Frist ohne Route")
	check_eq(sim.energy_dots.pending(), 0, "Puffer korrekt bereinigt")
	_ledger(sim)

func test_save_load_keeps_buffer_timers_ownership_and_recapture_exactly() -> void:
	var sim := _sim()
	_station(sim, 0, 100)
	_station(sim, 1, 104)
	sim.energy_dots.enqueue(103, 7, 1)
	sim.run_ticks(13)
	var copy := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(copy != null, "Puffer und Restzeit gespeichert")
	if copy == null: return
	check_eq(copy.state_hash(), sim.state_hash(), "exakter Ausgangszustand")
	check(not copy.construction.interceptors_unlocked, "Testfreischaltung nicht erforscht gespeichert")
	for tick in 160:
		sim.tick_once()
		copy.tick_once()
		check_eq(copy.state_hash(), sim.state_hash(), "Abfangen nach Laden taktsynchron")
	_ledger(copy)

func test_save_load_missing_route_timer_and_invalid_buffer_payloads() -> void:
	var sim := _sim()
	sim.energy_dots.enqueue(1, 1, EnergyStore.NEUTRAL)
	sim.run_ticks(1199)
	var copy := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(copy != null, "59,95 Sekunden gespeichert")
	if copy != null:
		copy.tick_once()
		check_eq(copy.energy_dots.expired, 1, "Frist nach Laden nicht zurückgesetzt")
	var held := _sim()
	_station(held)
	held.energy_dots.enqueue(68, 1, 1)
	held.tick_once()
	for kind in 5:
		var bad := SaveGame.snapshot(held)
		if kind == 0: bad.energy_transport.no_route = PackedInt32Array()
		if kind == 1: bad.energy_transport.held_by[0] = 9999
		if kind == 2: bad.energy_transport.no_route[0] = 1200
		if kind == 3: bad.energy_transport.release_at[0] = 99999
		if kind == 4: bad.energy_transport.expired = -1
		check(SaveGame.from_snapshot(bad) == null, "ungültiger Puffer/Timer %d" % kind)

func test_legacy_save_without_transport_data_starts_new_timers_without_losing_energy() -> void:
	var sim := _sim()
	sim.energy_dots.enqueue(1, 3, 0)
	var old := SaveGame.snapshot(sim)
	old.erase("energy_transport")
	var loaded := SaveGame.from_snapshot(old)
	check(loaded != null, "alte Version 2 lesbar")
	if loaded == null: return
	check_eq(loaded.energy_dots.pending(), 3, "keine Energie verloren")
	check_eq(loaded.energy_dots.expired, 0, "kein erfundener historischer Verfall")
	check_eq(loaded.energy_dots.no_route[0], 0, "neue Frist beginnt bei null")
	_ledger(loaded)

func test_station_hud_build_unlock_and_normal_save_lock() -> void:
	var sim := _sim()
	var hud := GameHud.new()
	hud.sim = sim
	hud._unlock_interceptors()
	check(not sim.construction.interceptors_unlocked, "ohne Labor gesperrt")
	sim.debug_mode = true
	hud._unlock_interceptors()
	check(sim.construction.interceptors_unlocked and sim.debug_modified, "Testfreigabe markiert")
	# A build click must use currently observed terrain, even in the testlab.
	sim.initial_mass += 1
	sim.workers.add(68, 0, 0)
	sim.fog.update(sim)
	hud._begin_settlement(2)
	check(hud.issue_build(100), "Bauplatz über Oberfläche")
	check_eq(sim.construction.sites.records[sim.construction.at(100)].kind, 2, "echte Abfangstation")
	hud.free()

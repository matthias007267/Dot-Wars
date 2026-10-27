extends TestCase

func _fixture() -> Simulation:
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
	for y in [28, 32]:
		sim.army.add(sim.world.index(28, y), 0)
		sim.army.add(sim.world.index(29, y), 1)
	sim.army.hp[sim.army.slots[3]] = 1
	var worker := sim.workers.add(sim.world.index(28, 36), sim.rules.group_of[1], 1)
	sim.initial_mass += 1
	sim.workers.health[worker] = 1
	sim.army.add(sim.world.index(29, 36), 0)
	sim.fog.update(sim)
	return sim

func _record(sim: Simulation, events: Array) -> void:
	sim.army.combat_attack.connect(func(uid: int) -> void:
		var index: int = sim.army.slots[uid]
		var enemy := sim.army._enemy(sim, index, 1)
		events.append(["strike", uid, sim.army.cells[index], enemy]))
	sim.army.combat_hit.connect(func(cell: int, owner: int) -> void: events.append(["hit", cell, owner]))
	sim.army.combat_death.connect(func(cell: int, owner: int, warrior: bool) -> void: events.append(["death", cell, owner, warrior]))

func _strike(view: CombatEffects, origin: int, target: int, owner: int, target_owner: int) -> void:
	view._strike(origin, target, owner)
	view._on_hit(target, target_owner)

func _normalized(events: Array) -> Array:
	# Damage maps have different iteration orders; compare the complete multiset.
	var result: Array = events.map(func(e: Array) -> String: return JSON.stringify(e))
	result.sort()
	return result

func test_real_strikes_and_deaths_match_reference_without_changing_state() -> void:
	var sim := _fixture()
	var reference := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	var silent := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(reference != null and silent != null, "identische gespeicherte Fixtures")
	if reference == null or silent == null: return
	reference.army.reference_only = true
	var events: Array = []
	var expected: Array = []
	_record(sim, events)
	_record(reference, expected)
	for tick in 25:
		sim.tick_once()
		reference.tick_once()
		silent.tick_once()
		check_eq(_normalized(events), _normalized(expected), "Native-/Referenz-Ereignisse einschließlich Slottausch und Toden")
		check_eq(sim.state_hash(), silent.state_hash(), "Ereignisbeobachtung beeinflusst keine Spielregel")
		check_eq(sim.state_hash(), reference.state_hash(), "taktgleicher Referenzzustand")
	var warrior_death := false
	var worker_death := false
	for event in events:
		if event[0] == "death":
			if event[3]: warrior_death = true
			else: worker_death = true
	check(warrior_death and worker_death, "echte Krieger- und Arbeitertode gemeldet")
	if "--require-native" in OS.get_cmdline_user_args(): check_eq(sim.army.native_steps, 25, "Ereignisvergleich läuft tatsächlich nativ")
	check_no_errors(sim.check_invariants(), "Massen- und Energiebilanzen")
	# The recording callback captures its simulation; release that test-only cycle.
	for observed in [sim, reference]:
		for connection in observed.army.combat_attack.get_connections(): observed.army.combat_attack.disconnect(connection.callable)

func test_hidden_events_and_particle_edges_never_reveal_fog() -> void:
	var sim := _fixture()
	var view := CombatEffects.new()
	view.sim = sim
	view._ready()
	var visible := sim.world.index(28, 28)
	var hidden := sim.world.index(29, 28)
	sim.fog.visible[0].fill(0)
	sim.fog.visible[0][visible] = 1
	_strike(view, hidden, hidden, 1, 1)
	view._on_death(hidden, 1, true)
	check_eq(view.effects.size(), 0, "verborgener Kampf erzeugt keine Effekte")
	_strike(view, hidden, visible, 1, 0)
	check_eq(view.effects.size(), 1, "nur sichtbarer Treffer bei unbekanntem Angreifer")
	check_eq(int(view.effects[0].kind), CombatEffects.HIT, "kein verräterischer Angriffsvektor")
	view._on_death(visible, 0, true)
	view.advance(0.18)
	view.compose()
	check(view.quad_count > 0, "sichtbarer Partikelzerfall gezeichnet")
	for index in view.quad_count:
		var at := index * 12
		var half := Vector2(view._buffer[at], view._buffer[at + 5]) * 0.5
		var center := Vector2(view._buffer[at + 3], view._buffer[at + 7])
		check(center.x - half.x >= 28 - 0.0001 and center.x + half.x <= 29 + 0.0001 and center.y - half.y >= 28 - 0.0001 and center.y + half.y <= 29 + 0.0001, "auch Halo an sichtbarer Zellgrenze abgeschnitten")
	sim.fog.visible[0][visible] = 0
	view.advance(0)
	view.compose()
	check_eq(view.quad_count, 0, "Sichtverlust entfernt sofort alle Effekte")
	check_eq(view.effects.size(), 0, "keine spätere Wiederanzeige nach Aufklärung")
	view.free()

func test_effect_budget_pause_speed_and_noncombat_removal() -> void:
	var sim := _fixture()
	var view := CombatEffects.new()
	view.sim = sim
	view.clock = TickClock.new()
	view._ready()
	var cell := sim.world.index(28, 28)
	var before := sim.state_hash()
	for index in 2000: _strike(view, cell, cell + 1, 0, 1)
	check_eq(view.effects.size(), CombatEffects.MAX_EFFECTS, "Ereignisbudget begrenzt")
	view._on_death(cell, 0, true)
	check_eq(int(view.effects.back().kind), CombatEffects.DEATH, "Tod verdrängt einen weniger wichtigen Effekt")
	view.clock.paused = true
	view._process(1.0)
	check_eq(float(view.effects.back().age), 0.0, "Pause friert Effekte ein")
	check(view.quad_count <= CombatEffects.MAX_QUADS, "feste obere Grenze für Render-Quads")
	check_eq(view.get_child_count(), 0, "keine Node je Partikel")
	check_eq(sim.state_hash(), before, "Partikel erzeugen weder Energie noch Schaden")
	view.clock.paused = false
	view.clock.speed = 4
	view._process(0.13)
	check_eq(view.effects.size(), 0, "4x-Tempo beschleunigt Ausblenden")
	sim.army.remove(sim.army.ids[0])
	check_eq(view.effects.size(), 0, "Entfernen außerhalb des Kampfes ist keine Explosion")
	view.free()

func test_worker_burst_is_smaller_and_visual_levels_keep_same_gameplay() -> void:
	var sim := _fixture()
	var view := CombatEffects.new()
	view.sim = sim
	view._ready()
	var cell := sim.world.index(28, 28)
	view._on_death(cell, 0, false)
	view._on_death(cell, 1, true)
	check_eq(int(view.effects[0].pieces), 8, "acht Arbeitersplitter")
	check_eq(int(view.effects[1].pieces), 12, "zwölf Kriegersplitter")
	check(float(view.effects[0].life) < float(view.effects[1].life), "Arbeiterzerfall kürzer")
	view.effects.clear()
	var before := sim.state_hash()
	for level in range(1, 4):
		view.visual_level = level
		_strike(view, cell, cell + 1, 0, 1)
		view.compose()
		check_eq(int(view.effects[-2].level), level, "verwandtes Angriffsmuster für Katalogstufe")
	check_eq(sim.state_hash(), before, "Grafikstufen führen keine neuen Kriegerregeln ein")
	view.free()

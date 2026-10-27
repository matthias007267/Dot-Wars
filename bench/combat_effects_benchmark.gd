extends SceneTree
## Isolated observer/composition cost. Not a full-game frame-rate measurement.
const Native = preload("res://src/sim/native_search.gd")
func _init() -> void: call_deferred("_run")
func _run() -> void:
	if Native.backend() == null:
		printerr("Combat benchmark requires native backend")
		quit(1)
		return
	var config := SimConfig.new()
	config.world_size = 256
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.from_world(config, WorldState.new(256, 256, 8, Materials.EMPTY))
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.initial_mass = 0
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	for y in range(70, 170):
		for x in range(70, 170): sim.army.add(sim.world.index(x, y), (x + y) % 2)
	var silent := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	if silent == null:
		quit(1)
		return
	# Diagnostic visibility only: stress all simultaneous visible strikes.
	sim.fog.visible[0].fill(1)
	var view := CombatEffects.new()
	view.sim = sim
	view._ready()
	var observed_usec := 0
	var silent_usec := 0
	for sample in 5:
		sim.tick_count = sample * ArmyState.ATTACK_PERIOD
		silent.tick_count = sim.tick_count
		view.effects.clear()
		# Hold population constant across isolated contact samples, outside timing.
		sim.army.hp.fill(ArmyState.HEALTH)
		silent.army.hp.fill(ArmyState.HEALTH)
		var start := Time.get_ticks_usec()
		silent.army.step(silent)
		silent_usec += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		sim.army.step(sim)
		observed_usec += Time.get_ticks_usec() - start
		if sim.state_hash() != silent.state_hash() or view.effects.size() > CombatEffects.MAX_EFFECTS:
			printerr("Combat observer changed state or exceeded budget")
			view.free()
			quit(1)
			return
	view.effects.clear()
	for index in CombatEffects.MAX_EFFECTS: view._on_death(sim.world.index(120, 120), index % 4, true)
	view.advance(0.16)
	for warmup in 5: view.compose()
	var started := Time.get_ticks_usec()
	for sample in 30: view.compose()
	var compose_ms := (Time.get_ticks_usec() - started) / 30000.0
	print("COMBAT BENCH warriors=", sim.army.count, " silent_army_ms=", silent_usec / 5000.0, " observed_army_ms=", observed_usec / 5000.0, " effects=", view.effects.size(), " quads=", view.quad_count, " compose_ms=", compose_ms)
	var valid := sim.army.native_steps == 5 and silent.army.native_steps == 5 and sim.army.count == 10000 and view.quad_count <= CombatEffects.MAX_QUADS
	view.free()
	quit(0 if valid else 1)

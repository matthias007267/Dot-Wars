extends SceneTree
## Isolated transport probe; no game-clock, rendering or AI performance claim.
func _init() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.debug_modified = true
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	while sim.workers.count > 0: sim.workers.remove_swap(0)
	sim.energy_dots.enqueue(5 * 64 + 32, 20000)
	var gates: Dictionary = sim.rules.gates(sim)
	var total := 0
	var peak := 0
	for tick in 80:
		var started := Time.get_ticks_usec()
		sim.energy_dots.step(sim.world, sim.workers, gates.cells, tick, 8, gates.owners, PackedByteArray(), sim)
		var elapsed := Time.get_ticks_usec() - started
		if tick > 0: # omit initial topology build
			total += elapsed
			peak = maxi(peak, elapsed)
	print("ENERGY 20000 dots average_ms=", total / 79000.0, " peak_ms=", peak / 1000.0)
	quit()

extends SceneTree
## Alle Intelligenzstufen über 60 Takte am selben gespeicherten Ausgangszustand.
## Die Ausgabe enthält Zustandsprüfsummen zum Vergleich vor/nach einer Optimierung.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Erwartet: -- eingabe.dw")
		quit(2)
		return
	var path := args[0]
	var bytes := FileAccess.get_file_as_bytes(path)
	for level in 5:
		var sim := SaveGame.from_bytes(bytes)
		if sim == null:
			quit(2)
			return
		sim.upgrades.swarm_level = level
		var total := 0
		var maximum := 0
		var samples := PackedInt64Array()
		for tick in 60:
			sim.tick_once()
			total += sim.last_tick_usec
			maximum = maxi(maximum, sim.last_tick_usec)
			samples.append(sim.last_tick_usec)
		samples.sort()
		var stages := {}
		for stage in Simulation.Stage.keys():
			stages[stage] = sim.stage_usec[Simulation.Stage[stage]] / 60000.0
		var search := {}
		for stage in Simulation.SearchStage.keys():
			search[stage] = sim.search_usec[Simulation.SearchStage[stage]] / 60000.0
		print("SNAPSHOT_LEVEL ", JSON.stringify({"level":level,"workers":sim.workers.count,"avg_ms":total/60000.0,"max_ms":maximum/1000.0,"p95_ms":samples[56]/1000.0,"stages":stages,"search_stages":search,"energy_dots":sim.energy_dots.cells.size(),"tick":sim.tick_count,"goals":Array(sim.fields.map(func(f):return f.goal_cell)),"hash":sim.state_hash(),"invariants":Array(sim.check_invariants())}))
	quit()

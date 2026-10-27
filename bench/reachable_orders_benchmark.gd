extends SceneTree
## Army-only timing: shared orders, real walls and 10,000 independent health records.
func _init() -> void:
	var ok := true
	for separated in [false, true]:
		var config := SimConfig.new()
		config.world_size = 256
		config.initial_workers = 0
		var world := WorldState.new(256, 256, 1337, Materials.EMPTY)
		if separated:
			for y in 256: world.set_material(world.index(200, y), Materials.INDESTRUCTIBLE)
		var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
		var selected := PackedInt32Array()
		for y in range(20, 120):
			for x in range(20, 120):
				selected.append(ArmyState.TAG + sim.army.add(world.index(x, y), 0))
		sim.army.command(selected, world.index(230, 220))
		var initial := sim.army.cells.duplicate()
		var backend := preload("res://src/sim/native_search.gd").backend()
		var before: PackedInt64Array = backend.army_route_stats() if backend != null else PackedInt64Array([0, 0, 0, 0])
		var samples: Array[int] = []
		for tick in 120:
			sim.tick_count = tick
			var start := Time.get_ticks_usec()
			sim.army.step(sim)
			samples.append(Time.get_ticks_usec() - start)
		var after: PackedInt64Array = backend.army_route_stats() if backend != null else before
		var total := 0
		for value in samples.slice(20): total += value
		var moved := 0
		for index in sim.army.count:
			if sim.army.cells[index] != initial[index]: moved += 1
		print(JSON.stringify({"separated": separated, "warriors": sim.army.count, "moved": moved,
			"cold_ms": samples[0] / 1000.0, "mean_ms": total / 100000.0,
			"max_ms": samples.max() / 1000.0, "field_builds": after[2] - before[2],
			"native_steps": sim.army.native_steps}))
		ok = ok and moved == 10000 and sim.check_invariants().is_empty()
		if separated and backend != null: ok = ok and after[2] - before[2] == 1
		if "--require-native" in OS.get_cmdline_user_args(): ok = ok and sim.army.native_steps == 120
	# Costly order creation is measured separately from per-tick movement.
	var world := WorldState.new(256, 256, 8, Materials.ROCK)
	world.carve_rect(Rect2i(1, 1, 60, 60))
	world.carve_rect(Rect2i(180, 180, 60, 60))
	var targets := PackedByteArray()
	targets.resize(world.cell_count())
	targets[world.index(220, 220)] = 1
	for reference in [false, true]:
		var start := Time.get_ticks_usec()
		var path := ExcavationPath.find(world, PackedByteArray(), PackedInt32Array([world.index(20, 20)]), targets, reference)
		print(JSON.stringify({"worker_order": true, "reference": reference,
			"elapsed_ms": (Time.get_ticks_usec() - start) / 1000.0, "path_cells": path.size()}))
		ok = ok and not path.is_empty()
	print("REACHABLE ORDERS SUMMARY: ", 0 if ok else 1, " failures")
	quit(0 if ok else 1)

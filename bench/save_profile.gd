extends SceneTree
## Misst eine Kopie eines Spielstands headless und protokolliert Gleichheitsdaten.
##
##   godot --headless --path . -s bench/save_profile.gd -- --save=pfad.dw [--ticks=400] [--out=pfad.json]
##
## Nie den Originalstand angeben, der noch von einer laufenden Partie beschrieben wird:
## das Skript schreibt nur, wenn `--write-test=pfad` ausdrücklich gesetzt ist.

func _init() -> void:
	var save := ""
	var ticks := 400
	var output := ""
	var write_test := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="): save = arg.substr(7)
		elif arg.begins_with("--ticks="): ticks = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--out="): output = arg.substr(6)
		elif arg.begins_with("--write-test="): write_test = arg.substr(13)
	var started := Time.get_ticks_usec()
	var sim := SaveGame.read_file(save)
	if sim == null:
		printerr("Spielstand nicht lesbar: ", save)
		quit(2)
		return
	var load_ms := (Time.get_ticks_usec() - started) / 1000.0
	sim.profile_detail = true
	var samples := PackedInt64Array()
	var hashes := PackedInt64Array()
	var world_changes := 0
	for i in ticks:
		var revision := sim.world.revision
		var t := Time.get_ticks_usec()
		sim.tick_once()
		samples.append(Time.get_ticks_usec() - t)
		if sim.world.revision != revision: world_changes += 1
		hashes.append(sim.state_hash())
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0
	for v in sorted: total += v
	var detail := {}
	for key in sim.detail_usec: detail[key] = snappedf(float(sim.detail_usec[key]) / ticks / 1000.0, 0.001)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(SaveGame.snapshot(sim)))
	var result := {
		"size": "%dx%d" % [sim.world.width, sim.world.height],
		"start_tick": sim.tick_count - ticks, "ticks": ticks, "load_ms": load_ms,
		"mean_ms": snappedf(total / float(ticks) / 1000.0, 0.001),
		"p95_ms": sorted[int(ticks * 0.95) - 1] / 1000.0, "max_ms": sorted[-1] / 1000.0,
		"ticks_with_world_change": world_changes,
		"detail_ms_per_tick": detail,
		"workers": sim.workers.count, "warriors": sim.army.count, "energy_dots": sim.energy_dots.cells.size(),
		"invariant_errors": Array(sim.check_invariants()),
		"state_hash_end": sim.state_hash(),
		"snapshot_sha256": digest.finish().hex_encode(),
		"tick_hashes": Array(hashes),
	}
	if write_test != "":
		var times := []
		for i in 3:
			var t := Time.get_ticks_usec()
			SaveGame.write_file(write_test, sim)
			times.append((Time.get_ticks_usec() - t) / 1000.0)
		result["write_ms"] = times
		result["write_bytes"] = FileAccess.get_file_as_bytes(write_test).size()
		var t2 := Time.get_ticks_usec()
		var reloaded := SaveGame.read_file(write_test)
		result["reload_ms"] = (Time.get_ticks_usec() - t2) / 1000.0
		result["reload_same_state"] = reloaded != null and reloaded.state_hash() == sim.state_hash()
		# Autosave path: main-thread share only; the disk write finishes in a worker.
		var main_ms := []
		for i in 3:
			var t := Time.get_ticks_usec()
			SaveGame.write_file_background(write_test, sim)
			main_ms.append((Time.get_ticks_usec() - t) / 1000.0)
			SaveGame.finish_background_write()
		result["background_main_thread_ms"] = main_ms
		result["background_write_ok"] = SaveGame.last_write_ok
		var again := SaveGame.read_file(write_test)
		result["background_reload_same_state"] = again != null and again.state_hash() == sim.state_hash()
	var brief := result.duplicate()
	brief.erase("tick_hashes")
	print("SAVE_PROFILE ", JSON.stringify(brief))
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(result, "  "))
	quit(0)

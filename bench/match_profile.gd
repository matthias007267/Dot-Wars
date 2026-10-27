extends SceneTree
## Reine KI-Partie mit Teilzeiten je Systemschritt.
##
##   godot --headless --path . -s bench/match_profile.gd -- [--size=256] [--ai=3] [--minutes=10] [--seed=1337] [--out=pfad.json]
##
## Alle Fraktionen werden von der KI gesteuert. Das ist ein Messlauf, keine Spielregel.


func _init() -> void:
	var size := 256
	var ai := 3
	var minutes := 10
	var seed := 1337
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="): size = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--ai="): ai = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--minutes="): minutes = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--seed="): seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--out="): output = arg.substr(6)
	var config := SimConfig.new()
	config.world_size = size
	config.world_seed = seed
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = ai
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	config.group_quotas = PackedInt32Array([40, 30, 30])
	var sim := Simulation.create(config)
	if sim == null:
		quit(1)
		return
	sim.rules.control.fill(MatchRules.CONTROL_AI)
	sim.profile_detail = true
	var ticks := minutes * 60 * SimConfig.TICKS_PER_SECOND
	var samples := PackedInt64Array()
	var per_minute := []
	var minute_detail := {}
	var started := Time.get_ticks_usec()
	while sim.tick_count < ticks and not sim.won:
		var t := Time.get_ticks_usec()
		sim.tick_once()
		samples.append(Time.get_ticks_usec() - t)
		if sim.tick_count % (60 * SimConfig.TICKS_PER_SECOND) == 0:
			var row := _summary(samples.slice(samples.size() - 60 * SimConfig.TICKS_PER_SECOND))
			row["minute"] = sim.tick_count / (60 * SimConfig.TICKS_PER_SECOND)
			row["warriors"] = sim.army.count
			row["workers"] = sim.workers.count
			row["energy_dots"] = sim.energy_dots.cells.size()
			var delta := {}
			for key in sim.detail_usec:
				delta[key] = int(sim.detail_usec[key]) - int(minute_detail.get(key, 0))
			minute_detail = sim.detail_usec.duplicate()
			row["detail_ms_per_tick"] = _per_tick(delta, 60 * SimConfig.TICKS_PER_SECOND)
			per_minute.append(row)
			print(JSON.stringify(row))
	var errors := sim.check_invariants()
	var result := _summary(samples)
	result["wall_s"] = (Time.get_ticks_usec() - started) / 1000000.0
	result["ticks"] = sim.tick_count
	result["native"] = load("res://src/sim/native_search.gd").backend() != null
	result["detail_ms_per_tick"] = _per_tick(sim.detail_usec, samples.size())
	result["invariant_errors"] = errors
	result["state_hash"] = sim.state_hash()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(SaveGame.snapshot(sim)))
	result["snapshot_sha256"] = digest.finish().hex_encode()
	result["minutes"] = per_minute
	print(JSON.stringify(result))
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(result, "  "))
	quit(0 if errors.is_empty() else 1)


func _per_tick(source: Dictionary, count: int) -> Dictionary:
	var out := {}
	for key in source:
		out[key] = snappedf(float(source[key]) / maxi(1, count) / 1000.0, 0.001)
	return out


func _summary(values: PackedInt64Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0
	for v in sorted: total += v
	var n := maxi(1, sorted.size())
	var over := 0
	for v in sorted:
		if v > 50000: over += 1
	return {
		"mean_ms": snappedf(total / float(n) / 1000.0, 0.001),
		"p95_ms": snappedf(sorted[int(n * 0.95) - 1] / 1000.0 if sorted.size() > 0 else 0.0, 0.001),
		"p99_ms": snappedf(sorted[int(n * 0.99) - 1] / 1000.0 if sorted.size() > 0 else 0.0, 0.001),
		"max_ms": snappedf(sorted[sorted.size() - 1] / 1000.0 if sorted.size() > 0 else 0.0, 0.001),
		"over_50ms": over,
	}

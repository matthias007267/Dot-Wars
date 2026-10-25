extends SceneTree
## Headless-Benchmark der Simulation.
##
##   godot --headless --path . -s bench/benchmark.gd -- [--workers=1000,10000] [--ticks=200]
##       [--warmup=0] [--size=256] [--seed=1337] [--move-period=2] [--out=pfad.json]
##
## Gemessen wird ausschließlich die Simulation (kein Rendering). Rendering-FPS müssen im
## grafischen Betrieb gemessen werden (siehe docs/benchmarks.md).

var _worker_counts := PackedInt32Array([1000, 10000])
var _ticks: int = 200
var _warmup: int = 0
var _size: int = 256
var _seed: int = 1337
var _move_period: int = 2
var _swarm_level: int = 0
var _out_path: String = ""


func _init() -> void:
	_parse_args(OS.get_cmdline_user_args())
	var results: Array[Dictionary] = []
	for count in _worker_counts:
		var result := _run_scenario(count)
		if result.is_empty():
			quit(2)
			return
		results.append(result)
	_print_report(results)
	if not _out_path.is_empty():
		_write_json(results)
	var failed := false
	for result in results:
		failed = failed or not result["invariants_ok"]
	quit(1 if failed else 0)


func _parse_args(args: PackedStringArray) -> void:
	for arg in args:
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--workers="):
			_worker_counts = PackedInt32Array()
			for part in value.split(","):
				_worker_counts.append(part.to_int())
		elif arg.begins_with("--ticks="):
			_ticks = value.to_int()
		elif arg.begins_with("--warmup="):
			_warmup = value.to_int()
		elif arg.begins_with("--size="):
			_size = value.to_int()
		elif arg.begins_with("--seed="):
			_seed = value.to_int()
		elif arg.begins_with("--move-period="):
			_move_period = value.to_int()
		elif arg.begins_with("--swarm="):
			_swarm_level = clampi(value.to_int(), 0, Upgrades.SWARM_MAX)
		elif arg.begins_with("--out="):
			_out_path = value


func _run_scenario(worker_count: int) -> Dictionary:
	var config := SimConfig.new()
	config.population_test_mode = true
	config.world_size = _size
	config.world_seed = _seed
	config.initial_workers = worker_count
	config.move_period_ticks = _move_period
	var errors := config.validate()
	if not errors.is_empty():
		printerr("Ungültige Konfiguration: ", ", ".join(errors))
		return {}

	var memory_before := OS.get_static_memory_usage()
	var t_world := Time.get_ticks_usec()
	var world := WorldGenerator.generate(config)
	var world_ms := (Time.get_ticks_usec() - t_world) / 1000.0

	# Großzügige Höhle, damit alle Arbeiter Platz haben: etwa doppelt so viele Zellen wie Arbeiter.
	var side := mini(ceili(sqrt(worker_count * 2.0)), _size - 8)
	var origin := (_size - side) / 2
	world.carve_rect(Rect2i(origin, origin, side, side))
	if side * side < worker_count:
		printerr("Welt zu klein für %d Arbeiter" % worker_count)
		return {}

	var t_sim := Time.get_ticks_usec()
	var sim := Simulation.from_world(config, world)
	if sim == null:
		return {}
	var sim_create_ms := (Time.get_ticks_usec() - t_sim) / 1000.0
	sim.upgrades.swarm_level = _swarm_level
	sim.assign_area(0, Rect2i(0, 0, _size / 2, _size))
	sim.assign_area(1, Rect2i(_size / 2, 0, _size - _size / 2, _size))
	var memory_after := OS.get_static_memory_usage()

	var field_samples := PackedFloat64Array()
	for i in 3:
		var t := Time.get_ticks_usec()
		sim.fields[i % 2].rebuild_blocking()
		field_samples.append((Time.get_ticks_usec() - t) / 1000.0)
	field_samples.sort()

	sim.run_ticks(_warmup)
	var stage_before := sim.stage_usec.duplicate()
	var cpu_before := _process_cpu_seconds()
	var wall_start := Time.get_ticks_usec()
	var tick_usec := PackedInt64Array()
	for i in _ticks:
		sim.tick_once()
		tick_usec.append(sim.last_tick_usec)
	var wall_ms := (Time.get_ticks_usec() - wall_start) / 1000.0
	var cpu_after := _process_cpu_seconds()

	var sorted := tick_usec.duplicate()
	sorted.sort()
	var total_usec := 0
	var over_budget := 0
	for usec in tick_usec:
		total_usec += usec
		if usec > 1_000_000 / SimConfig.TICKS_PER_SECOND:
			over_budget += 1
	var avg_ms := total_usec / 1000.0 / _ticks
	var stage_ms := {}
	for stage in Simulation.Stage.keys():
		var idx: int = Simulation.Stage[stage]
		stage_ms[stage.to_lower()] = (sim.stage_usec[idx] - stage_before[idx]) / 1000.0 / _ticks

	var errors_after := sim.check_invariants()
	var state_counts := PackedInt32Array([0, 0, 0, 0])
	for id in sim.workers.count:
		state_counts[sim.workers.state[id]] += 1
	return {
		"workers_start": worker_count,
		"workers_end": sim.workers.count,
		"pending_spawns": sim.spawner.pending(),
		"mined_cells": sim.world.mined_count,
		"ticks": _ticks,
		"warmup_ticks": _warmup,
		"avg_tick_ms": avg_ms,
		"p95_tick_ms": sorted[int(_ticks * 0.95)] / 1000.0,
		"p99_tick_ms": sorted[int(_ticks * 0.99)] / 1000.0,
		"max_tick_ms": sorted[_ticks - 1] / 1000.0,
		"ticks_over_50ms": over_budget,
		"max_sustainable_ticks_per_s": 1000.0 / avg_ms if avg_ms > 0.0 else 0.0,
		"stage_avg_ms": stage_ms,
		"field_full_rebuild_ms_median": field_samples[1],
		"wall_ms": wall_ms,
		"cpu_seconds": cpu_after - cpu_before if cpu_after >= 0.0 else -1.0,
		"world_generation_ms": world_ms,
		"simulation_create_ms": sim_create_ms,
		"static_memory_mb_before": memory_before / 1048576.0,
		"static_memory_mb_after_setup": memory_after / 1048576.0,
		"static_memory_mb_end": OS.get_static_memory_usage() / 1048576.0,
		"rss_mb_end": _rss_mb(),
		"worker_states_end": {
			"waiting": state_counts[WorkerStore.STATE_WAITING],
			"moving": state_counts[WorkerStore.STATE_MOVING],
			"mining": state_counts[WorkerStore.STATE_MINING],
			"blocked": state_counts[WorkerStore.STATE_BLOCKED],
		},
		"invariants_ok": errors_after.is_empty(),
		"invariant_errors": Array(errors_after).slice(0, 5),
		"world_size": _size,
		"move_period_ticks": _move_period,
		"world_seed": _seed,
		"swarm_level": _swarm_level,
	}


func _print_report(results: Array[Dictionary]) -> void:
	print("== DOT WARS Benchmark (Godot %s; Intelligenzstufe %d) ==" % [Engine.get_version_info()["string"], _swarm_level])
	print("CPU: %s (%d Threads) | Welt %d² | Seed %d | Bewegungsperiode %d Takte | %d Takte (Warmup %d)" % [
		_cpu_model(), OS.get_processor_count(), _size, _seed, _move_period, _ticks, _warmup,
	])
	for r in results:
		var stage: Dictionary = r["stage_avg_ms"]
		print("")
		print("-- %d Arbeiter (Ende: %d, abgebaut: %d) --" % [r["workers_start"], r["workers_end"], r["mined_cells"]])
		print("Takt Ø %.3f ms | p95 %.3f | p99 %.3f | max %.3f | >50 ms: %d | max. nachhaltig %.0f Takte/s" % [
			r["avg_tick_ms"], r["p95_tick_ms"], r["p99_tick_ms"], r["max_tick_ms"], r["ticks_over_50ms"], r["max_sustainable_ticks_per_s"],
		])
		print("Stufen Ø ms: Zielsuche %.3f | Bewegung %.3f | Abbau %.3f | Entstehung %.3f" % [
			stage["target_search"], stage["movement"], stage["mining"], stage["spawn"],
		])
		print("Zielsuche komplett (Median einer vollständigen Feldberechnung): %.2f ms" % r["field_full_rebuild_ms_median"])
		print("Wandzeit %.0f ms | CPU %s | Welt-Generierung %.0f ms | Simulation anlegen %.0f ms" % [
			r["wall_ms"], "%.2f s" % r["cpu_seconds"] if r["cpu_seconds"] >= 0.0 else "n/a", r["world_generation_ms"], r["simulation_create_ms"],
		])
		print("Speicher (Godot statisch): %.1f MB vor, %.1f MB nach Aufbau, %.1f MB am Ende | RSS %s" % [
			r["static_memory_mb_before"], r["static_memory_mb_after_setup"], r["static_memory_mb_end"],
			"%.0f MB" % r["rss_mb_end"] if r["rss_mb_end"] >= 0.0 else "n/a",
		])
		print("Zustände am Ende: %s | Invarianten: %s" % [str(r["worker_states_end"]), "ok" if r["invariants_ok"] else "VERLETZT " + str(r["invariant_errors"])])


func _write_json(results: Array[Dictionary]) -> void:
	var dir := _out_path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file == null:
		printerr("Kann %s nicht schreiben" % _out_path)
		return
	file.store_string(JSON.stringify({
		"godot": Engine.get_version_info()["string"],
		"cpu": _cpu_model(),
		"threads": OS.get_processor_count(),
		"os": OS.get_name(),
		"results": results,
	}, "  "))


## Prozess-CPU-Zeit (user + system) in Sekunden, nur unter Linux; sonst -1.
func _process_cpu_seconds() -> float:
	var text := _read_proc("/proc/self/stat")
	if text.is_empty():
		return -1.0
	# Nach dem Prozessnamen "(...)" folgen state (Index 0), ... utime (Index 11), stime (Index 12) in 1/100 s.
	var fields := text.rsplit(")", true, 1)[1].strip_edges().split(" ")
	return (fields[11].to_int() + fields[12].to_int()) / 100.0


## /proc-Dateien melden Länge 0, daher zeilenweise lesen.
func _read_proc(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := ""
	while not file.eof_reached():
		text += file.get_line() + "\n"
	return text


func _rss_mb() -> float:
	for line in _read_proc("/proc/self/status").split("\n"):
		if line.begins_with("VmRSS:"):
			return line.get_slice(":", 1).strip_edges().get_slice(" ", 0).to_float() / 1024.0
	return -1.0


func _cpu_model() -> String:
	var name := OS.get_processor_name()
	return name if not name.is_empty() else "unbekannt"

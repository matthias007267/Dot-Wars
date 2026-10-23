extends SceneTree
## Skriptierte Partie bis zu den drei Siegzielen oder bis zum Zeitlimit.
##
##   godot --headless --path . -s bench/match_probe.gd -- [--size=64] [--seed=1337] [--cap-minutes=90]
##
## Der Lauf kauft Kern, Abbau, einmal Tempo und Arbeiter. Er markiert die ganze Welt.
## Das ist kein menschliches Spiel und ändert keine Siegbedingungen.


func _init() -> void:
	var size := 64
	var seed := 1337
	var cap_minutes := 90
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			size = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--seed="):
			seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--cap-minutes="):
			cap_minutes = arg.get_slice("=", 1).to_int()
	var config := SimConfig.new()
	config.world_size = size
	config.world_seed = seed
	config.group_quotas = PackedInt32Array([100])
	var sim := Simulation.create(config)
	if sim == null:
		push_error("Simulation ließ sich nicht erzeugen")
		quit(1)
		return
	sim.assign_area(0, Rect2i(0, 0, size, size))
	var cap_ticks := cap_minutes * 60 * SimConfig.TICKS_PER_SECOND
	var started := Time.get_ticks_usec()
	var last_report := -1
	while sim.tick_count < cap_ticks and not sim.won:
		_spend(sim)
		sim.tick_once()
		var minute := sim.tick_count / (60 * SimConfig.TICKS_PER_SECOND)
		if minute != last_report and sim.tick_count % (60 * SimConfig.TICKS_PER_SECOND) == 0:
			last_report = minute
			_report(sim, started, "Minute %d" % minute)
			var errors := sim.check_invariants()
			if not errors.is_empty():
				push_error("Invariante: %s" % ", ".join(errors))
				quit(1)
				return
	_report(sim, started, "Ende")
	var final_errors := sim.check_invariants()
	if not final_errors.is_empty():
		push_error("Invariante: %s" % ", ".join(final_errors))
		quit(1)
		return
	quit(0)


func _spend(sim: Simulation) -> void:
	for _attempt in 8:
		if not _buy_one(sim):
			return


func _buy_one(sim: Simulation) -> bool:
	var energy := sim.upgrades.energy
	var mass := sim.total_mass()
	if sim.upgrades.core_level == 0 and energy >= sim.upgrades.core_cost() and sim.buy(Upgrades.KIND_CORE):
		return true
	if mass < 40 and energy >= Simulation.WORKER_COST and sim.buy_worker():
		return true
	if sim.upgrades.dig_level < 4 and energy >= sim.upgrades.dig_cost() and sim.buy(Upgrades.KIND_DIG):
		return true
	if sim.upgrades.speed_level < 1 and energy >= sim.upgrades.speed_cost() and sim.buy(Upgrades.KIND_SPEED):
		return true
	if mass < 100 and energy >= Simulation.WORKER_COST and sim.buy_worker():
		return true
	if sim.upgrades.purchased < 2 and energy >= sim.upgrades.dig_cost() and sim.buy(Upgrades.KIND_DIG):
		return true
	return false


func _report(sim: Simulation, started_usec: int, label: String) -> void:
	var elapsed_ms := (Time.get_ticks_usec() - started_usec) / 1000
	var seconds := sim.tick_count / SimConfig.TICKS_PER_SECOND
	var clock := "%d:%02d" % [seconds / 60, seconds % 60]
	var mined := int(round(sim.world.mined_fraction() * 100.0))
	print(
		"%s  Spiel %s  Wand %d ms  Masse %d  Abbau %d Prozent  Energie %d (+%d)  Fähigkeiten %d  Kern %d  Arbeiter %d"
		% [
			label,
			clock,
			elapsed_ms,
			sim.total_mass(),
			mined,
			sim.upgrades.energy,
			sim.energy_dots.pending(),
			sim.upgrades.purchased,
			sim.upgrades.core_level,
			sim.workers.count,
		]
	)

extends TestCase
## Regressionen für sichere Diagnostik, ohne reguläre Speicherstände zu berühren.

class TimedGoalSimulation:
	extends Simulation

	func _goals_met() -> bool:
		OS.delay_usec(10000)
		return false


func test_debug_save_is_rejected_before_overwriting_existing_file() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := Simulation.create(config)
	var path := "user://diagnostic-save-guard-%d.dw" % OS.get_process_id()
	check(SaveGame.write_file(path, sim), "regulärer Stand wird gespeichert")
	var original := FileAccess.get_file_as_bytes(path)
	sim.debug_mode = true
	check(not SaveGame.write_file(path, sim), "aktives Testlabor sperrt Schreiben")
	check_eq(FileAccess.get_file_as_bytes(path), original, "bestehender Stand bleibt unverändert")
	check(sim.debug_adjust_upgrade(Upgrades.KIND_SPEED, 1), "Teständerung")
	sim.debug_mode = false
	check(not SaveGame.write_file(path, sim), "Teständerung sperrt Schreiben auch nach Deaktivierung")
	check_eq(FileAccess.get_file_as_bytes(path), original, "Teststand überschreibt keine regulären Daten")
	check_eq(DirAccess.remove_absolute(path), OK, "nur eigene Testdatei entfernen")


func test_last_tick_includes_final_goal_processing() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := TimedGoalSimulation.new()
	check(sim._setup(config, WorldGenerator.generate(config), PackedInt32Array(), true), "Testsimulation")
	sim.tick_once()
	check(sim.last_tick_usec >= 10000, "vollständige Taktzeit enthält auch die Abschlusslogik")


func test_loaded_game_uses_only_new_ticks_for_profile_averages() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	var sim := Simulation.create(config)
	sim.run_ticks(4)
	var restored := SaveGame.from_bytes(SaveGame.to_bytes(sim))
	check(restored != null, "Stand geladen")
	if restored == null:
		return
	check_eq(restored.profiled_ticks, 0, "Profiling startet beim Laden neu")
	check_eq(restored.tick_count, 4, "Spielzeit bleibt erhalten")
	restored.tick_once()
	check_eq(restored.profiled_ticks, 1, "genau ein gemessener Takt")
	check_eq(restored.tick_count, 5, "Spielzeit läuft weiter")
	var hud := GameHud.new()
	hud.sim = restored
	hud.clock = TickClock.new()
	var layer := Control.new()
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	hud._build_upgrade_panel(layer)
	hud._build_perf_overlay(layer)
	restored.debug_mode = true
	restored.stage_usec[Simulation.Stage.MOVEMENT] = 10000
	hud.refresh()
	check(hud._perf_overlay.text.contains("Bewegung Ø: 10.00 ms"), "Mittelwert verwendet neue Messtakte statt gespeicherte Spielzeit")
	layer.free()
	hud.free()


func test_clock_reports_discarded_time_without_changing_catch_up() -> void:
	var clock := TickClock.new()
	check_eq(clock.advance(10.0), 5, "bestehendes Aufhollimit")
	check_eq(clock.catch_up_limit_hits, 1, "Limitereignis erfasst")
	check_eq(clock.discarded_usec, 9750000, "9,75 Sekunden verworfen")
	check_eq(clock.advance(0.0), 0, "weiterhin kein nachträgliches Aufholen")
	clock.reset()
	check_eq(clock.catch_up_limit_hits, 0, "Ereignisse zurückgesetzt")
	check_eq(clock.discarded_usec, 0, "Verlust zurückgesetzt")


func test_wall_clock_accounts_for_a_stall_before_applying_own_limit() -> void:
	var clock := TickClock.new()
	check_eq(clock.advance_wall_time(1000000), 0, "erster Zeitstempel startet Messung")
	check_eq(clock.advance_wall_time(1050000), 1, "50 ms ergeben einen Takt")
	check_eq(clock.advance_wall_time(1530000), 5, "480 ms werden erst am eigenen Limit begrenzt")
	check_eq(clock.discarded_usec, 230000, "nur der eigene Überhang wird verworfen")
	clock.paused = true
	check_eq(clock.advance_wall_time(5000000), 0, "Pause ohne Takte")
	clock.paused = false
	check_eq(clock.advance_wall_time(5050000), 1, "Pausenzeit wird nicht nachgeholt")
	clock.reset()
	check_eq(clock.advance_wall_time(9000000), 0, "Laden oder Neustart setzt die Zeitbasis zurück")
	check_eq(clock.advance_wall_time(9050000), 1, "danach normaler Takt")


func test_wall_clock_speed_scales_ticks_without_changing_real_time() -> void:
	var clock := TickClock.new()
	clock.speed = 4
	clock.advance_wall_time(0)
	var ticks := 0
	for frame in 100:
		ticks += clock.advance_wall_time((frame + 1) * 10000)
	check_eq(ticks, 80, "4× führt 80 Takte je Echtzeitsekunde aus")
	check_eq(clock.discarded_usec, 0, "ohne Lastspitzen keine verworfene Zeit")

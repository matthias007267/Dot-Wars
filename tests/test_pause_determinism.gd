extends TestCase


func _prepared_sim(world_seed: int) -> Simulation:
	var config := SimConfig.new()
	config.world_size = 96
	config.world_seed = world_seed
	var sim := Simulation.create(config)
	sim.assign_area(0, Rect2i(30, 30, 20, 14))
	sim.assign_area(1, Rect2i(46, 40, 20, 20))
	return sim


## Simuliert `frames` Frames mit fester Frame-Zeit über die Taktuhr.
func _drive(sim: Simulation, clock: TickClock, frames: int, delta: float) -> int:
	var executed := 0
	for i in frames:
		var ticks := clock.advance(delta)
		sim.run_ticks(ticks)
		executed += ticks
	return executed


func test_clock_produces_20_ticks_per_second_independent_of_frame_rate() -> void:
	check_eq(SimConfig.TICKS_PER_SECOND, 20, "Konstante")
	for fps in [30, 60, 144, 240]:
		var clock := TickClock.new()
		var ticks := 0
		for i in fps * 10:
			ticks += clock.advance(1.0 / fps)
		check(absi(ticks - 200) <= 1, "10 s bei %d FPS → %d Takte" % [fps, ticks])


func test_clock_pause_executes_nothing_and_does_not_accumulate() -> void:
	var clock := TickClock.new()
	clock.paused = true
	var ticks := 0
	for i in 1000:
		ticks += clock.advance(0.1)
	check_eq(ticks, 0, "keine Takte während der Pause")
	clock.paused = false
	check_eq(clock.advance(0.02), 0, "kein Nachholen nach der Pause")
	check_eq(clock.advance(0.03), 1, "danach normaler Takt")


func test_clock_caps_catch_up_after_long_frame() -> void:
	var clock := TickClock.new()
	check_eq(clock.advance(10.0), 5, "höchstens 5 Takte pro Frame")
	check_eq(clock.advance(0.0), 0, "Überschuss wird verworfen")


func test_pause_and_resume_gives_identical_state_as_uninterrupted_run() -> void:
	var continuous := _prepared_sim(11)
	continuous.run_ticks(400)

	var interrupted := _prepared_sim(11)
	var clock := TickClock.new()
	var executed := _drive(interrupted, clock, 100, 0.05)
	check_eq(executed, 100, "100 Takte vor der Pause")
	var hash_before_pause := interrupted.state_hash()
	clock.paused = true
	check_eq(_drive(interrupted, clock, 600, 1.0 / 60.0), 0, "Pause führt keine Takte aus")
	check_eq(interrupted.state_hash(), hash_before_pause, "Zustand während der Pause unverändert")
	clock.paused = false
	_drive(interrupted, clock, 300, 0.05)
	check_eq(interrupted.tick_count, 400, "gleiche Taktzahl")
	check_eq(interrupted.state_hash(), continuous.state_hash(), "identischer Zustand nach Fortsetzung")
	check_eq(interrupted.workers.cell, continuous.workers.cell, "identische Positionen")


func test_commands_between_ticks_are_deterministic() -> void:
	var a := _prepared_sim(5)
	var b := _prepared_sim(5)
	for sim in [a, b]:
		sim.run_ticks(60)
		sim.assign_area(0, Rect2i(10, 10, 30, 30))
		sim.set_quotas(PackedInt32Array([20, 80]))
		sim.run_ticks(200)
		sim.clear_area(1)
		sim.run_ticks(100)
	check_eq(a.state_hash(), b.state_hash(), "gleiche Befehle → gleicher Zustand")


func test_restart_with_same_seed_reproduces_the_run() -> void:
	var first := _prepared_sim(21)
	var initial_hash := first.state_hash()
	first.run_ticks(300)
	var restarted := _prepared_sim(21)
	check_eq(restarted.state_hash(), initial_hash, "Neustart-Zustand = Ausgangszustand")
	restarted.run_ticks(300)
	check_eq(restarted.state_hash(), first.state_hash(), "gleicher Verlauf nach Neustart")


func test_different_seed_changes_the_run() -> void:
	var a := _prepared_sim(1)
	var b := _prepared_sim(2)
	a.run_ticks(100)
	b.run_ticks(100)
	check(a.state_hash() != b.state_hash(), "anderer Seed → anderer Zustand")

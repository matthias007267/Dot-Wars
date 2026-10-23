extends TestCase
## Die automatische Front sucht zuerst nur in der Nähe und weitet die Suche erst danach.


func test_a_distant_rock_waits_for_the_next_radius() -> void:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 100
	var sim := TestHelpers.sim_from_ascii(["w...................#"], config)
	var far := sim.world.index(20, 0)
	sim.run_ticks(2)
	check(not sim.areas.is_marked(0, far), "16 Zellen reichen nicht bis zum fernen Fels")
	check_eq(sim.areas.rects[0].size(), 0, "ohne Fels in Reichweite bleibt das Gebiet leer")
	sim.run_ticks(1)
	check(sim.areas.is_marked(0, far), "die nächste Reichweite markiert den Fels")
	check_no_errors(sim.check_invariants(), "Bilanz")


func test_a_nearby_rock_is_marked_without_waiting() -> void:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 100
	var sim := TestHelpers.sim_from_ascii(["w.#"], config)
	var rock := sim.world.index(2, 0)
	sim.run_ticks(2)
	check(sim.areas.is_marked(0, rock), "angrenzender Fels wird sofort markiert")
	check_no_errors(sim.check_invariants(), "Bilanz")

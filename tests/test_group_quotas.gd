extends TestCase


func _simulate_picks(quotas: PackedInt32Array, count: int) -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(quotas.size())
	for i in count:
		counts[GroupQuotas.pick_group(counts, quotas)] += 1
	return counts


func test_validation_accepts_only_sums_of_100() -> void:
	check(GroupQuotas.validate(PackedInt32Array([50, 50])).is_empty(), "50/50")
	check(GroupQuotas.validate(PackedInt32Array([100, 0])).is_empty(), "100/0")
	check(GroupQuotas.validate(PackedInt32Array([0, 100])).is_empty(), "0/100")
	check(GroupQuotas.validate(PackedInt32Array([33, 33, 34])).is_empty(), "drei Gruppen")
	check(not GroupQuotas.validate(PackedInt32Array([50, 49])).is_empty(), "Summe 99")
	check(not GroupQuotas.validate(PackedInt32Array([60, 50])).is_empty(), "Summe 110")
	check(not GroupQuotas.validate(PackedInt32Array([0, 0])).is_empty(), "Summe 0")
	check(not GroupQuotas.validate(PackedInt32Array([120, -20])).is_empty(), "negative Quote")
	check(not GroupQuotas.validate(PackedInt32Array()).is_empty(), "keine Gruppen")


func test_zero_quota_group_never_receives_workers() -> void:
	check_eq(_simulate_picks(PackedInt32Array([100, 0]), 500), PackedInt32Array([500, 0]), "100/0")
	check_eq(_simulate_picks(PackedInt32Array([0, 100]), 500), PackedInt32Array([0, 500]), "0/100")
	var three := _simulate_picks(PackedInt32Array([0, 40, 60]), 500)
	check_eq(three[0], 0, "mittlere Gruppe mit 0 % bleibt leer")


func test_zero_quota_group_with_existing_workers_is_still_skipped() -> void:
	var counts := PackedInt32Array([0, 10])
	check_eq(GroupQuotas.pick_group(counts, PackedInt32Array([0, 100])), 1, "Gruppe 0 bleibt trotz Defizit ausgeschlossen")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([0, 0]), PackedInt32Array([0, 0])), -1, "ohne gültige Quote keine Gruppe")


func test_largest_relative_deficit_wins() -> void:
	var quotas := PackedInt32Array([50, 50])
	check_eq(GroupQuotas.pick_group(PackedInt32Array([3, 2]), quotas), 1, "Gruppe 1 hat das Defizit")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([2, 3]), quotas), 0, "Gruppe 0 hat das Defizit")
	# Relativ gesehen fehlt der kleinen Gruppe mehr: 1/10 = 10 % der Quote vs. 10/90 = 11 %.
	check_eq(GroupQuotas.pick_group(PackedInt32Array([1, 10]), PackedInt32Array([10, 90])), 0, "relativ, nicht absolut")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([0, 5]), PackedInt32Array([10, 90])), 0, "leere Gruppe zuerst")


func test_tie_break_prefers_larger_quota_then_lower_index() -> void:
	check_eq(GroupQuotas.pick_group(PackedInt32Array([0, 0]), PackedInt32Array([50, 50])), 0, "gleiche Quote → kleiner Index")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([0, 0]), PackedInt32Array([30, 70])), 1, "größere Quote gewinnt")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([3, 7]), PackedInt32Array([30, 70])), 1, "Gleichstand im Verhältnis → größere Quote")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([2, 2, 2]), PackedInt32Array([30, 30, 40])), 2, "Dreiergleichstand der Verhältnisse")
	check_eq(GroupQuotas.pick_group(PackedInt32Array([0, 0, 0]), PackedInt32Array([34, 33, 33])), 0, "größte Quote bei Gleichstand")


func test_distribution_converges_to_target_shares() -> void:
	for quotas in [[70, 30], [50, 50], [20, 30, 50], [1, 99], [33, 33, 34]]:
		var q := PackedInt32Array(quotas)
		var counts := _simulate_picks(q, 1000)
		for g in q.size():
			check(absi(counts[g] - q[g] * 10) <= 1, "Quote %s Gruppe %d: %d" % [str(quotas), g, counts[g]])


func test_pick_sequence_is_deterministic() -> void:
	var a := PackedInt32Array()
	var b := PackedInt32Array()
	for run in 2:
		var counts := PackedInt32Array([0, 0, 0])
		for i in 200:
			var g := GroupQuotas.pick_group(counts, PackedInt32Array([25, 25, 50]))
			counts[g] += 1
			(a if run == 0 else b).append(g)
	check_eq(a, b, "gleiche Eingabe → gleiche Folge")


func test_set_quotas_rejects_invalid_and_applies_valid() -> void:
	var sim := TestHelpers.sim_from_ascii(["#####", "#w..#", "#####"], TestHelpers.default_config())
	check(not sim.set_quotas(PackedInt32Array([60, 60])), "ungültige Summe abgelehnt")
	check(not sim.set_quotas(PackedInt32Array([100])), "falsche Gruppenzahl abgelehnt")
	check_eq(sim.quotas, PackedInt32Array([100, 0]), "unverändert")
	check(sim.set_quotas(PackedInt32Array([0, 100])), "gültig")
	sim.upgrades.energy = 2 * Simulation.WORKER_COST
	check(sim.buy_worker(), "erster Kauf")
	check(sim.buy_worker(), "zweiter Kauf")
	sim.run_ticks(5)
	check_eq(sim.spawner.pending(), 0, "beide platziert")
	check_eq(sim.workers.group_counts[0], 1, "nur der Startarbeiter in Gruppe 0")
	check_eq(sim.workers.group_counts[1], 2, "gekaufte Arbeiter in Gruppe 1")


func test_new_workers_follow_quotas_in_simulation() -> void:
	var config := SimConfig.new()
	config.world_size = 32
	config.initial_workers = 1
	config.group_quotas = PackedInt32Array([70, 30])
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var sim := Simulation.from_world(config, world, PackedInt32Array([world.index(16, 16)]))
	sim.upgrades.energy = 100 * Simulation.WORKER_COST
	for i in 100:
		check(sim.buy_worker(), "Kauf %d" % i)
	sim.run_ticks(5)
	check_eq(sim.spawner.pending(), 0, "alle platziert")
	var total := sim.workers.count
	check_eq(total, 101, "Startarbeiter plus Käufe")
	check(absi(sim.workers.group_counts[0] * 100 - 70 * total) <= 100, "Gruppe 0 ≈ 70 %% (%d)" % sim.workers.group_counts[0])
	check_eq(sim.workers.group_counts[0] + sim.workers.group_counts[1], total, "Zähler passen")
	check_no_errors(sim.check_invariants(), "Bilanzen")

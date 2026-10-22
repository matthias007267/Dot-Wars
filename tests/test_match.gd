extends TestCase
## Mehrspieler gegen KI. Solo-Ziele bleiben in ihrem Modus.


func test_two_factions_get_two_cores_and_ignore_solo_goals() -> void:
	var sim := _match(MatchRules.VICTORY_ELIMINATION)
	check_eq(sim.rules.faction_count, 2, "Mensch und eine KI")
	check_eq(sim.rules.cores.size(), 2, "zwei Kerne")
	check(sim.rules.cores[0] != sim.rules.cores[1], "die Kerne liegen auseinander")
	check_eq(sim.world.cells[sim.rules.cores[0]], Materials.INDESTRUCTIBLE, "Spieler-Kern")
	check_eq(sim.world.cells[sim.rules.cores[1]], Materials.INDESTRUCTIBLE, "KI-Kern")
	check_eq(sim.pit_index(), sim.rules.cores[0], "der Ausbau trifft den eigenen Kern")
	check_eq(sim.rules.hill_cell, sim.world.index(16, 16), "der Hügel ist die Kreuzmitte")
	check_eq(sim.world.cells[sim.rules.hill_cell], Materials.EMPTY, "der Hügel bleibt begehbar")
	check_eq(sim.rules.relic_cell.size(), 5, "fünf Reliquien")
	sim.energy_dots.delivered = SimConfig.EXTRACTION_GOAL
	sim.energy_dots.generated = SimConfig.EXTRACTION_GOAL
	sim.energy_dots.refined_delivered = SimConfig.REFINING_GOAL
	sim.upgrades.purchased = 5
	sim.tick_once()
	check(not sim.won, "Räumung, Förderung und Veredelung gewinnen das Match nicht")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_elimination_removes_the_faction_and_keeps_mass() -> void:
	var sim := _match(MatchRules.VICTORY_ELIMINATION)
	sim.rules.core_hp[1] = 1
	var spot := _free_gate(sim, sim.rules.cores[1])
	check(spot >= 0, "eine Angriffszelle ist frei")
	sim.workers.move_to(_worker(sim, 0), spot, 0)
	sim.tick_once()
	check(sim.won, "der letzte lebende Kern gewinnt")
	check_eq(sim.rules.winner_faction, 0, "der Spieler gewinnt")
	check_eq(sim.rules.win_kind, MatchRules.VICTORY_ELIMINATION, "Auslöschen")
	check_eq(sim.rules.alive[1], 0, "die KI ist aus")
	check_eq(_count(sim, 1), 0, "ihre Arbeiter sind weg")
	check_eq(sim.world.cells[sim.rules.cores[1]], Materials.INDESTRUCTIBLE, "der Kern bleibt unzerstörbar")
	check_no_errors(sim.check_invariants(), "Masse nach dem Entfernen")


func test_research_bought_by_the_ai_wins_the_same_tick() -> void:
	var sim := _match(MatchRules.VICTORY_RESEARCH, 4)
	var ai := sim.rules.ai_upgrades[0]
	ai.research_level = 4
	ai.energy = ai.research_cost()
	sim.tick_once()
	check_eq(ai.research_level, 5, "die fünfte Stufe ist gekauft")
	check(sim.won, "Forschungssieg im selben Takt")
	check_eq(sim.rules.winner_faction, 1, "die KI hat geforscht")
	check_eq(sim.rules.win_kind, MatchRules.VICTORY_RESEARCH, "Forschung")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_relics_need_three_and_a_channel() -> void:
	var sim := _match(MatchRules.VICTORY_RELICS)
	_park(sim)
	sim.rules.relic_owner[0] = 0
	sim.rules.relic_owner[1] = 0
	sim.workers.move_to(_worker(sim, 0), sim.rules.relic_cell[2], 0)
	sim.run_ticks(99)
	check(not sim.won, "99 Takte reichen nicht")
	check(sim.rules.relic_owner[2] < 0, "die dritte Reliquie ist noch neutral")
	sim.tick_once()
	check_eq(sim.rules.relic_owner[2], 0, "der Kanal gehört dem Spieler")
	check(sim.won, "drei Reliquien gewinnen")
	check_eq(sim.rules.win_kind, MatchRules.VICTORY_RELICS, "Reliquien")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_hill_needs_thirty_seconds_uncontested() -> void:
	var sim := _match(MatchRules.VICTORY_HILL)
	_park(sim)
	sim.workers.move_to(_worker(sim, 0), sim.rules.hill_cell, 0)
	sim.run_ticks(599)
	check(not sim.won, "unter 30 Sekunden kein Sieg")
	sim.tick_once()
	check(sim.won, "600 Takte auf dem Hügel gewinnen")
	check_eq(sim.rules.winner_faction, 0, "der Spieler hält den Hügel")
	check_eq(sim.rules.win_kind, MatchRules.VICTORY_HILL, "König des Hügels")
	check_eq(sim.rules.hill_score[0], MatchRules.HILL_TICKS, "der Zähler bleibt stehen")
	check_no_errors(sim.check_invariants(), "Bilanzen")


func test_ai_buys_a_worker_and_remote_does_not() -> void:
	var sim := _match(MatchRules.VICTORY_ELIMINATION)
	var before := _count(sim, 1)
	sim.rules.ai_upgrades[0].energy = Simulation.WORKER_COST
	sim.tick_once()
	check_eq(_count(sim, 1), before + 1, "unter vier Arbeitern kauft die KI")
	check_eq(sim.rules.ai_upgrades[0].energy, 0, "10 Energie sind weg")
	check_eq(sim.rules.match_bought, 1, "der Kauf zählt in der Masse")
	check_eq(sim.purchased_workers, 0, "der Spieler hat nicht gekauft")
	check_no_errors(sim.check_invariants(), "Masse nach KI-Kauf")
	var remote := _match(MatchRules.VICTORY_ELIMINATION)
	remote.rules.control[1] = MatchRules.CONTROL_REMOTE
	remote.rules.ai_upgrades[0].energy = 100
	var held := remote.workers.count
	remote.tick_once()
	check_eq(remote.workers.count, held, "ein ferner Slot kauft nicht")
	check_eq(remote.rules.ai_upgrades[0].energy, 100, "das Guthaben bleibt")


func test_energy_reaches_only_the_owning_core() -> void:
	var sim := _match(MatchRules.VICTORY_ELIMINATION)
	var gate := SacrificeSystem.delivery_cells(sim.world, sim.rules.cores[1])[0]
	sim.rules.ai_upgrades[0].energy = 0
	sim.upgrades.energy = 0
	sim.energy_dots.enqueue(gate, 1, 1)
	sim.tick_once()
	check_eq(sim.rules.ai_upgrades[0].energy, 1, "die KI bekommt den eigenen Dot")
	check_eq(sim.upgrades.energy, 0, "der Spieler bekommt ihn nicht")
	var other := _match(MatchRules.VICTORY_ELIMINATION)
	var foreign := SacrificeSystem.delivery_cells(other.world, other.rules.cores[1])[0]
	other.energy_dots.enqueue(foreign, 1, 0)
	other.tick_once()
	check_eq(other.upgrades.energy, 0, "ein fremder Kern schreibt nichts gut")
	check_eq(other.energy_dots.pending(), 1, "der Dot bleibt unterwegs")
	check_no_errors(other.check_invariants(), "Energiebilanz")


func test_hud_dig_does_not_overwrite_the_ai_rect() -> void:
	var sim := _match(MatchRules.VICTORY_ALL)
	var group_id := sim.rules.group_of[1]
	var rect := Rect2i(1, 1, 2, 2)
	check(sim.assign_area(group_id, rect), "KI-Gebiet")
	var hud := GameHud.new()
	hud.sim = sim
	check(hud.issue_dig_area(Rect2i(8, 8, 4, 4)), "der Spieler markiert")
	var kept: Array = sim.areas.rects[group_id]
	check_eq(kept.size(), 1, "das KI-Gebiet bleibt eines")
	check_eq(kept[0], rect, "die KI-Fläche ist unverändert")
	check(sim.areas.rects[0].size() > 0, "die eigene Gruppe hat das neue Gebiet")
	var layer := Control.new()
	hud.clock = TickClock.new()
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	hud._build_upgrade_panel(layer)
	hud.refresh()
	check_eq(hud._goal_heading.text, "MEHRSPIELER", "Zielkarte")
	check(_goal_visible(hud, "Forschung Stufe 5"), "Forschung ist an")
	check(hud._research_button.visible, "der Forschungsknopf ist da")
	check(not hud._build_caption.visible, "Bauen bleibt im Match aus")
	sim.config.victory_mask = MatchRules.VICTORY_ELIMINATION
	hud.refresh()
	check(not hud._research_button.visible, "ohne Forschungssieg kein Knopf")
	layer.free()
	hud.free()


func test_match_save_roundtrip_keeps_owner_and_research() -> void:
	var sim := _match(MatchRules.VICTORY_ALL)
	sim.upgrades.research_level = 2
	sim.energy_dots.enqueue(sim.rules.hill_cell, 1, 0)
	sim.tick_once()
	var expected := sim.state_hash()
	var loaded := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check(loaded != null, "Stand lesbar")
	if loaded == null:
		return
	check_eq(loaded.state_hash(), expected, "identischer Zustand")
	check_eq(loaded.config.mode, SimConfig.MODE_MATCH, "Modus")
	check_eq(loaded.config.ai_count, 1, "eine KI")
	check_eq(loaded.upgrades.research_level, 2, "Forschung")
	check_eq(loaded.rules.faction_count, 2, "Fraktionen")
	check_eq(loaded.energy_dots.owner.size(), loaded.energy_dots.cells.size(), "Besitzer")
	check_no_errors(loaded.check_invariants(), "geladene Bilanzen")


func test_single_player_stays_one_faction() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 1
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	var center := world.index(16, 16)
	world.carve_rect(Rect2i(11, 16, 11, 1))
	world.carve_rect(Rect2i(16, 11, 1, 11))
	var sim := Simulation.from_world(config, world, PackedInt32Array([center]))
	check_eq(sim.rules.faction_count, 1, "ohne Match keine zweite Fraktion")
	check(sim.rules.cores.is_empty(), "kein zweiter Kern")
	check_no_errors(sim.check_invariants(), "Einzelspieler")


func _match(mask: int, workers := 1) -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = workers
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.victory_mask = mask
	var world := WorldState.new(32, 32, 8, Materials.EMPTY)
	return Simulation.from_world(config, world)


func _worker(sim: Simulation, faction: int) -> int:
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) == faction:
			return id
	return -1


func _count(sim: Simulation, faction: int) -> int:
	var total := 0
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) == faction:
			total += 1
	return total


func _free_gate(sim: Simulation, core: int) -> int:
	for cell in SacrificeSystem.delivery_cells(sim.world, core):
		if sim.workers.is_free(cell):
			return cell
	return -1


func _park(sim: Simulation) -> void:
	var group_id := sim.rules.group_of[1]
	sim.clear_area(group_id)
	sim.assign_area(group_id, Rect2i(0, 0, 3, 3))
	sim.world.set_material(sim.world.index(0, 0), Materials.SOFT)
	var id := _worker(sim, 1)
	var dest := sim.world.index(1, 0)
	if id >= 0 and sim.workers.cell[id] != dest and sim.workers.is_free(dest):
		sim.workers.move_to(id, dest, 0)


func _goal_visible(hud: GameHud, title: String) -> bool:
	for index in hud._goal_names.size():
		if hud._goal_names[index].text == title and hud._goal_sections[index].visible:
			return true
	return false

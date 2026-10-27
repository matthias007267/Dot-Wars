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
	sim.construction.sites.records[1].hp = 1
	sim.rules.core_hp[1] = 1
	var spot := _free_gate(sim, sim.rules.cores[1])
	check(spot >= 0, "eine Angriffszelle ist frei")
	var attacker := sim.army.add(spot, 0)
	sim.army.next_move[sim.army.slots[attacker]] = 100
	sim.tick_once()
	check(sim.won, "der letzte lebende Kern gewinnt")
	check_eq(sim.rules.winner_faction, 0, "der Spieler gewinnt")
	check_eq(sim.rules.win_kind, MatchRules.VICTORY_ELIMINATION, "Auslöschen")
	check_eq(sim.rules.alive[1], 0, "die KI ist aus")
	check_eq(_count(sim, 1), 0, "ihre Arbeiter sind weg")
	check_eq(sim.world.cells[sim.rules.cores[1]], Materials.EMPTY, "zerstörter Kern gibt Baugrund frei")
	check_no_errors(sim.check_invariants(), "Masse nach dem Entfernen")


func test_research_requires_center_and_cannot_win_instantly() -> void:
	var sim := _match(MatchRules.VICTORY_RESEARCH, 4)
	var ai := sim.rules.ai_upgrades[0]
	ai.research_level = 4
	ai.energy = 5000
	sim.tick_once()
	check_eq(ai.research_level, 4, "ohne Forschungszentrum kein Sofortkauf")
	check(not sim.won, "Siegforschung benötigt Energieübertragung und Forschungszeit")
	check_no_errors(sim.check_invariants(), "Bilanzen")

func test_relics_need_three_and_a_channel() -> void:
	var sim := _match(MatchRules.VICTORY_RELICS)
	_park(sim)
	sim.rules.relic_owner[0] = 0
	sim.rules.relic_owner[1] = 0
	var relic := sim.rules.relic_cell[2]
	sim.workers.move_to(_worker(sim, 0), relic, 0)
	check(sim.set_move_goal(sim.rules.group_of[0], relic), "Laufziel hält die Reliquie")
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
	check(sim.set_move_goal(sim.rules.group_of[0], sim.rules.hill_cell), "Laufziel hält den Hügel")
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
	check_eq(remote.rules.ai_upgrades[0].energy, 75, "kein KI-Kauf, nur eigener Kernunterhalt")


func test_energy_reaches_only_the_owning_core() -> void:
	var sim := _match(MatchRules.VICTORY_ELIMINATION)
	var gate := sim.construction.receivers(sim, 1)[0]
	sim.rules.ai_upgrades[0].energy = 0
	sim.upgrades.energy = 0
	sim.energy_dots.enqueue(gate, 1, 1)
	sim.tick_once()
	check_eq(sim.rules.ai_upgrades[0].energy, 1, "die KI bekommt den eigenen Dot")
	check_eq(sim.upgrades.energy, 0, "der Spieler bekommt ihn nicht")
	var other := _match(MatchRules.VICTORY_ELIMINATION)
	var foreign := other.construction.receivers(other, 1)[0]
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
	var player := _worker(sim, 0)
	check(player >= 0, "Spielerarbeiter")
	hud.select_at(sim.workers.cell[player])
	check(hud.issue_conquer(Rect2i(8, 8, 4, 4)), "der Spieler erobert")
	var kept: Array = sim.areas.rects[group_id]
	check_eq(kept.size(), 1, "das KI-Gebiet bleibt eines")
	check_eq(kept[0], rect, "die KI-Fläche ist unverändert")
	check(sim.command_group > group_id, "der Befehl liegt nicht in der KI-Gruppe")
	check(sim.areas.rects[sim.command_group].size() > 0, "das Aufgebot hat das Gebiet")
	var layer := Control.new()
	hud.clock = TickClock.new()
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	hud._build_upgrade_panel(layer)
	hud.refresh()
	check_eq(hud._goal_heading.text, "MEHRSPIELER", "Zielkarte")
	check(_goal_visible(hud, "Forschung Stufe 5"), "Forschung ist an")
	var victory_index := hud._research_tech_ids.find("victory")
	check(victory_index >= 0, "Siegtechnologie im P6-Katalog")
	check(hud._research_tech_buttons[victory_index].visible, "Siegforschung im Baum sichtbar")
	check(not hud._research_tree_view.available("victory"), "ohne Forschungszentrum kein Start")
	check(not hud._build_caption.visible, "Bauen bleibt im Match aus")
	sim.config.victory_mask = MatchRules.VICTORY_ELIMINATION
	hud.refresh()
	check(not hud._research_tech_buttons[victory_index].visible, "ohne Forschungssieg keine Siegtechnologie")
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


func test_match_world_drops_the_old_center_and_splits_mass() -> void:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 1
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.victory_mask = MatchRules.VICTORY_ELIMINATION
	var sim := Simulation.create(config)
	check(sim != null, "Mehrspielerwelt")
	if sim == null:
		return
	var pit := WorldGenerator.sacrifice_cell(sim.world)
	check(sim.world.cells[sim.world.index(pit.x, pit.y)] != Materials.INDESTRUCTIBLE, "kein zentrales Opferloch")
	check(sim.world.cells[sim.world.index(15, 16)] != Materials.EMPTY, "der alte Starttunnel ist zu")
	check_eq(sim.world.cells[sim.rules.hill_cell], Materials.EMPTY, "der Hügel ist offen")
	check_eq(sim.rules.relic_cell.size(), 5, "fünf Reliquien")
	for cell in sim.rules.relic_cell:
		check_eq(sim.world.cells[cell], Materials.EMPTY, "Reliquie %d ist frei" % cell)
	check_eq(sim.world.indestructible_count, WorldGenerator.generate(sim.config).indestructible_count + 50, "zwei Kerne mit je 25 Zellen zusätzlich zum Obsidian")
	check_eq(sim.faction_mass(0), 1, "eigene Masse")
	check_eq(sim.opponent_mass(), 1, "Masse der KI")
	check_no_errors(sim.check_invariants(), "Bilanzen")


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


func test_easy_camps_and_hard_digs_toward_the_core() -> void:
	var easy := _match(MatchRules.VICTORY_ELIMINATION, 1, 1, SimConfig.DIFFICULTY_EASY)
	var before := _count(easy, 1)
	easy.rules.ai_upgrades[0].energy = Simulation.WORKER_COST
	easy.tick_once()
	check_eq(_count(easy, 1), before, "Leicht kauft für 10 Energie keinen Arbeiter")
	check_eq(easy.rules.ai_upgrades[0].energy, Simulation.WORKER_COST, "das Guthaben bleibt")
	check_eq(easy.move_goal(easy.rules.group_of[1]), -1, "Leicht setzt kein Laufziel")
	var camp: Array = easy.areas.rects[easy.rules.group_of[1]]
	check_eq(camp.size(), 1, "ein lokales Feld")
	check_eq(camp[0], Rect2i(17, 11, 9, 9), "9×9 um die eigene Basis")
	check(not camp[0].has_point(Vector2i(16, 16)), "der Hügel liegt außerhalb")
	check_no_errors(easy.check_invariants(), "Bilanzen Leicht")
	var hard := _match(MatchRules.VICTORY_ELIMINATION, 6, 1, SimConfig.DIFFICULTY_HARD)
	var wallet := hard.rules.ai_upgrades[0]
	wallet.energy = Upgrades.DIG_BASE + 25 # Same purchase budget after core upkeep.
	var workers_before := _count(hard, 1)
	hard.tick_once()
	check_eq(_count(hard, 1), workers_before + 1, "ohne verfügbaren Forschungsauftrag kauft Schwer Nachwuchs")
	check_eq(wallet.dig_level, 0, "ohne Forschungszentrum kein Abbauupgrade")
	check_eq(wallet.energy, Upgrades.DIG_BASE - Simulation.WORKER_COST - ArmyState.COST, "nur Arbeiter und Krieger bezahlt, kein Sofortupgrade")
	check_eq(hard.rules.match_bought, 1, "ein regulärer Arbeiterkauf")
	var lane: Array = hard.areas.rects[hard.rules.group_of[1]]
	check_eq(lane.size(), 1, "ein Korridor")
	check_eq(lane[0], Rect2i(7, 13, 17, 6), "Band von der Basis zum gegnerischen Kern")
	check(lane[0].get_area() < hard.world.width * hard.world.height, "nicht die ganze Karte")
	check(hard.move_goal(hard.rules.group_of[1]) >= 0, "Schwer läuft auf eine Angriffszelle")
	var plain := _match(MatchRules.VICTORY_ELIMINATION, 6)
	plain.rules.ai_upgrades[0].energy = Upgrades.DIG_BASE
	plain.tick_once()
	check_eq(_count(plain, 1), workers_before + 1, "Mittel kauft den nächsten Arbeiter")
	check_eq(plain.rules.ai_upgrades[0].dig_level, 0, "Mittel kauft keinen Abbau")
	var whole: Array = plain.areas.rects[plain.rules.group_of[1]]
	check_eq(whole[0], Rect2i(0, 0, 32, 32), "Mittel gräbt die ganze Karte")
	check_eq(plain.move_goal(plain.rules.group_of[1]), -1, "Mittel setzt kein Laufziel")
	check_no_errors(hard.check_invariants(), "Bilanzen Schwer")


func test_mixed_gives_each_ai_its_own_plan() -> void:
	var sim := _match(MatchRules.VICTORY_ELIMINATION, 1, 2, SimConfig.DIFFICULTY_MIXED)
	check_eq(sim.rules.faction_count, 3, "Spieler und zwei KI")
	check_eq(int(sim.rules.difficulty[0]), 0, "der Spieler hat keinen Plan")
	check_eq(int(sim.rules.difficulty[1]), SimConfig.DIFFICULTY_EASY, "die erste KI ist leicht")
	check_eq(int(sim.rules.difficulty[2]), SimConfig.DIFFICULTY_HARD, "die zweite KI ist schwer")
	check_eq(sim.rules.difficulty_label(), "gemischt", "der Hinweis sagt gemischt")
	var solo := _match(MatchRules.VICTORY_ELIMINATION, 1, 1, SimConfig.DIFFICULTY_MIXED)
	check_eq(int(solo.rules.difficulty[1]), SimConfig.DIFFICULTY_NORMAL, "eine KI auf Gemischt ist Mittel")
	check_eq(solo.rules.difficulty_label(), "Mittel", "der Hinweis sagt Mittel")
	var hud := GameHud.new()
	hud.sim = sim
	check(hud._opening_hint().contains("gemischt"), "Status nennt gemischt")
	hud.sim = solo
	check(hud._opening_hint().contains("Mittel"), "Status nennt Mittel")
	hud.free()
	var three := _match(MatchRules.VICTORY_ELIMINATION, 1, 3, SimConfig.DIFFICULTY_MIXED)
	check_eq(int(three.rules.difficulty[1]), SimConfig.DIFFICULTY_EASY, "drei KI: leicht")
	check_eq(int(three.rules.difficulty[2]), SimConfig.DIFFICULTY_NORMAL, "drei KI: mittel")
	check_eq(int(three.rules.difficulty[3]), SimConfig.DIFFICULTY_HARD, "drei KI: schwer")
	var data := SaveGame.snapshot(sim)
	data.erase("difficulty")
	var blob: Dictionary = data["match"]
	blob.erase("difficulty")
	data["match"] = blob
	var loaded := SaveGame.from_snapshot(data)
	check(loaded != null, "Stand ohne Schwierigkeit")
	if loaded == null:
		return
	check_eq(loaded.config.difficulty, SimConfig.DIFFICULTY_NORMAL, "fehlende Stufe ist Mittel")
	check_eq(int(loaded.rules.difficulty[1]), SimConfig.DIFFICULTY_NORMAL, "jede KI fällt auf Mittel")
	check_eq(int(loaded.rules.difficulty[2]), SimConfig.DIFFICULTY_NORMAL, "auch die zweite KI")
	var kept := SaveGame.from_snapshot(SaveGame.snapshot(sim))
	check_eq(kept.state_hash(), sim.state_hash(), "gemischte Pläne bleiben im Stand")
	var config := SimConfig.from_cmdline(PackedStringArray([
		"--mode=mehrspieler", "--schwierigkeit=schwer", "--ai=2",
	]))
	check_eq(config.difficulty, SimConfig.DIFFICULTY_HARD, "Schwer von der Kommandozeile")
	check_eq(config.ai_count, 2, "zwei KI")
	var easy_config := SimConfig.from_cmdline(PackedStringArray(["--schwierigkeit=leicht"]))
	check_eq(easy_config.mode, SimConfig.MODE_CLEARING, "Einzelspieler bleibt Räumung")
	check_eq(easy_config.difficulty, SimConfig.DIFFICULTY_EASY, "Leicht bleibt gesetzt")
	check(easy_config.validate().is_empty(), "Einzelspieler mit Schwierigkeit ist gültig")
	var bad := SimConfig.new()
	bad.difficulty = 9
	check(not bad.validate().is_empty(), "eine unbekannte Stufe fällt auf")
	check_no_errors(sim.check_invariants(), "Bilanzen Gemischt")


func _match(mask: int, workers := 1, ai := 1, difficulty := SimConfig.DIFFICULTY_NORMAL) -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = workers
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = ai
	config.victory_mask = mask
	config.difficulty = difficulty
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
	for cell in sim.construction.receivers_for(sim, sim.construction.at(core)):
		if not sim.workers.is_free(cell): continue
		var contested := false
		for direction in range(1, 5):
			var next := MovementSystem.neighbor(cell, direction, sim.world.width, sim.world.cell_count())
			if next >= 0 and sim.workers.occupant[next] >= 0: contested = true
		if not contested: return cell
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

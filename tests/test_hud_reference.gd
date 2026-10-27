extends TestCase

func _sim() -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 64
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 2
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(64, 64, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.upgrades.energy = 10000
	return sim

func _hud(sim: Simulation) -> GameHud:
	var hud := GameHud.new()
	hud.sim = sim
	hud.clock = TickClock.new()
	var layer := Control.new()
	hud.add_child(layer)
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	hud._build_upgrade_panel(layer)
	hud._build_pause_menu(layer)
	hud._build_minimap(layer)
	hud.refresh()
	return hud

func _research(sim: Simulation, owner: int, cell: int, tech: String) -> int:
	sim.rules.wallet(sim, owner).energy = 10000
	var site: int = sim.construction.place(sim, 3, cell, PackedInt32Array(), owner)
	if site >= 0:
		sim.construction.sites.contribute(site, owner, 300)
		sim.research.start(sim, owner, site, tech)
		sim.fog.update(sim)
	return site

func test_overview_groups_own_queues_without_revealing_enemy_orders() -> void:
	var sim := _sim()
	check(_research(sim, 0, sim.world.index(22, 22), "dig") >= 0, "eigene Forschung")
	check(_research(sim, 1, sim.world.index(42, 42), "speed") >= 0, "gegnerische Forschung")
	check(sim.buy_worker(0), "Arbeiter bestellt")
	check(sim.buy_warrior(0, 0) and sim.buy_warrior(0, 0), "zwei Krieger bestellt")
	var before := sim.state_hash()
	var jobs := HudOverview.jobs(sim)
	check_eq(jobs.size(), 3, "eigene Forschung und zwei Produktionsgruppen")
	var warriors := 0
	for job in jobs:
		check(not str(job.detail).contains("Arbeiterbewegung"), "keine gegnerische Forschung im HUD")
		if job.icon == "warrior": warriors = int(job.count)
	check_eq(warriors, 2, "Warteschlange wird gezählt, nicht in Simulationspakete verwandelt")
	check_eq(sim.state_hash(), before, "Übersicht liest nur")
	var snapshot := hash(jobs)
	sim.research.jobs[1].elapsed = 75
	check_eq(hash(HudOverview.jobs(sim)), snapshot, "gegnerischer Fortschritt verändert eigene Übersicht nicht")
	sim.research.jobs[0].spent = sim.research.jobs[0].energy
	check(not HudOverview.jobs(sim)[0].waiting, "vollständig versorgte Forschung wartet nicht auf weitere Energie")

func test_team_rows_only_use_existing_allied_objective_scores() -> void:
	var sim := _sim()
	sim.army.teams[2] = 0
	sim.rules.hill_score[2] = 60
	var before := sim.state_hash()
	var rows := HudOverview.team_rows(sim)
	check_eq(rows.size(), 2, "nur eigene und verbündete Fraktion")
	check_eq(rows[1].owner, 2, "richtiger Verbündeter")
	check(str(rows[1].score).contains("H 60"), "bestehender Hügelstand, keine neue Punkteformel")
	check_eq(sim.state_hash(), before, "Teamübersicht verändert keine Regeln")

func test_selection_changes_actions_and_hover_explains_actual_action() -> void:
	var sim := _sim()
	var hud := _hud(sim)
	check(not hud._buy_worker_button.visible, "keine globale Produktion ohne Gebäudewahl")
	hud.select_at(sim.workers.cell[0])
	check(hud._research_center_button.visible, "Arbeiter können bauen")
	check(not hud._buy_worker_button.visible, "Arbeiter haben keine Standortproduktion")
	hud._research_center_button.mouse_entered.emit()
	check(hud._info_description.text.contains("300"), "Erklärung übernimmt tatsächliche Baukosten")
	hud.select_at(sim.construction.center(0))
	check(hud._buy_worker_button.visible and hud._buy_warrior_button.visible, "Kern zeigt Produktion")
	check(not hud._research_center_button.visible, "Kern zeigt keine Arbeiter-Bauaktionen")
	check(not hud._info_title.text.contains("Zentrum"), "alter Hovertext bleibt nach Kontextwechsel nicht stehen")
	var site := _research(sim, 0, sim.world.index(22, 22), "dig")
	hud.select_at(sim.construction.center(site))
	check(hud._context_buttons.technology.visible, "Zentrum zeigt Forschung")
	check(not hud._buy_warrior_button.visible, "Zentrum produziert keine Krieger")
	var plan: int = sim.construction.place(sim, 3, sim.world.index(30, 30), PackedInt32Array(), 0)
	check(plan >= 0, "eigene neue Baustelle")
	sim.fog.visible[0].fill(0)
	hud.select_at(sim.construction.center(plan))
	check(sim.construction.selected == plan and hud._cancel_build_button.visible, "eigener bekannter Plan bleibt vor dem nächsten Sichttakt auswählbar")
	hud.select_at(sim.construction.center(1))
	check_eq(sim.construction.selected, -1, "unbekanntes gegnerisches Gebäude bleibt unselektierbar")
	hud.free()

func test_hud_refresh_preserves_simulation_and_uses_available_energy_only() -> void:
	var sim := _sim()
	sim.energy_dots.enqueue(sim.workers.cell[0], 17, 0)
	var hud := _hud(sim)
	var before := sim.state_hash()
	hud.refresh()
	check_eq(hud._energy_value.text, "10.000", "nur ausgebbares Guthaben im Hauptzähler")
	check(hud._energy_value.tooltip_text.contains("17 eigene"), "Transport getrennt erklärt")
	check_eq(hud._warrior_value.text, "0", "Krieger im Feld")
	check_eq(sim.state_hash(), before, "neues HUD bleibt rein darstellend")
	hud.free()

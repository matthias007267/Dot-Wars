class_name GameHud
extends CanvasLayer
## Minimalistische Spieloberfläche. Farbgruppen/Quoten sind interne Simulationsdetails.
## Der Spieler steuert den Schwarm über gemeinsame Befehle und eine Aktionsleiste.

signal load_requested(path: String)
signal restart_requested
signal leave_requested

enum Command { MINE, MOVE, BUILD }
enum Pointer { SELECT_ONE, SELECT_RECT, MARCH, WAR, CONQUER, PAN }

var sim: Simulation
var clock: TickClock
var camera: CameraController
var renderer: WorldRenderer
var fog_view: FogOverlay
var command_mode: int = Command.MINE

var _mass_value: Label
var _energy_value: Label
var _mined_value: Label
var _kern_value: Label
var _mass_bar: ProgressBar
var _energy_bar: ProgressBar
var _mined_bar: ProgressBar
var _kern_bar: ProgressBar

var _goal_heading: Label
var _goal_sections: Array[Control] = []
var _goal_names: Array[Label] = []
var _goal_mass: ProgressBar
var _goal_upgrade: ProgressBar
var _goal_mining: ProgressBar
var _goal_mass_value: Label
var _goal_upgrade_value: Label
var _goal_mining_value: Label
var _goal_fourth_value: Label
var _goal_fourth: ProgressBar
var _research_caption: Label
var _research_button: Button
var _victory: Label
var _report: PanelContainer
var _report_labels: Array[Label] = []

var _message: Label
var _approach: Label
var _opponent_value: Label
var _pause_layer: Control
var _test_lab: VBoxContainer
var _test_scroll: ScrollContainer
var _test_toggle: Button
var _test_labels: Array[Label] = []
var _test_keys: Array[int] = []
var _test_stats: Label
var _perf_overlay: Label
var _volume: HSlider
var _dock_row: Container
var selection := PackedInt32Array()
var _buy_warrior_button: Button
var _buy_worker_button: Button
var _repair_button: Button
var _cancel_build_button: Button
var _interceptor_button: Button
var _research_center_button: Button
var _research_tech_buttons: Array[Button] = []
var _research_tech_ids: Array[String] = []
var _research_status: Label
var _research_tree: VBoxContainer
var _research_tree_view: ResearchTreeView
var _pause_button: Button
var _speed_button: Button
var _swarm_ids: Array[int] = []
var _swarm_labels: Array[Label] = []
var _upgrade_panel: PanelContainer
var _upgrade_buttons: Array[Button] = []
var _upgrade_kinds: Array[int] = []
var _source_place_button: Button
var _source_tier_button: Button
var _refinery_place_button: Button
var _refinery_tier_button: Button
var _build_caption: Label
var _build_kind := Buildings.KIND_SOURCE
var _settlement_kind := -1
var _placing_conduit := false
var _demolition_mode := false
var _size_buttons: Array[Button] = []
var _map: WorldMinimap

var _hud_root: Control
var _bottom_strip: PanelContainer
var _bottom_row: HBoxContainer
var _map_slot: PanelContainer
var _selection_slot: PanelContainer
var _actions_slot: PanelContainer
var _stats_slot: PanelContainer
var _goals_slot: PanelContainer
var _selection_caption: Label
var _selection_detail: Label
var _selection_cards: Array[TextureRect] = []
var _unit_icons: Array[Texture2D] = []
var _warrior_value: Label
var _top_menu: PanelContainer
var _tasks_row: HBoxContainer
var _context_jobs: HBoxContainer
var _task_icons: Array[HudTaskIcon] = []
var _context_icons: Array[HudTaskIcon] = []
var _team_rows: VBoxContainer
var _team_labels: Array[Label] = []
var _orders_panel: PanelContainer
var _orders_rows: VBoxContainer
var _action_caption: Label
var _action_hint: Label
var _info_title: Label
var _info_description: Label
var _hovered_action: Control
var _context_buttons: Dictionary = {}
var _own_jobs: Array[Dictionary] = []
var _orders_signature := 0
var _order_buttons: Array[Button] = []

var _last_size_style := -1
var _last_mine_area := Rect2i()


func _ready() -> void:
	var layer := Control.new()
	layer.name = "HUD"
	layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_root = layer
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	_build_stats(layer)
	_build_perf_overlay(layer)
	_build_goals(layer)
	_build_dock(layer)
	_build_upgrade_panel(layer)
	_build_pause_menu(layer)
	_build_minimap(layer)
	get_viewport().size_changed.connect(_resize_hud)
	_resize_hud()
	refresh()


func _resize_hud() -> void:
	if _hud_root == null: return
	var screen := get_viewport().get_visible_rect().size
	var factor := clampf(minf(screen.x / 1920.0, screen.y / 1080.0), 0.5, 1.5)
	_hud_root.scale = Vector2.ONE * factor
	_hud_root.size = screen / factor
	if _bottom_strip != null:
		_bottom_strip.offset_right = minf(1120, _hud_root.size.x - 354)

func select_in_rect(rect: Rect2i) -> void:
	if sim == null:
		return
	var clipped := rect.abs().intersection(Rect2i(0, 0, sim.world.width, sim.world.height))
	var ids := PackedInt32Array()
	var kinds := PackedByteArray()
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) != 0 or not _unit_hits(id, clipped):
			continue
		ids.append(id)
		kinds.append(DotOrder.kind_of(sim, id))
	for index in sim.army.count:
		var cell := sim.army.cells[index]
		if sim.army.owners[index] == 0 and clipped.has_point(Vector2i(cell % sim.world.width, cell / sim.world.width)):
			ids.append(ArmyState.TAG + sim.army.ids[index])
	_set_selection(ids)


func select_at(cell: int) -> void:
	if sim == null:
		return
	if cell < 0 or cell >= sim.world.cell_count():
		_set_selection(PackedInt32Array())
		return
	# Own placed sites are already known, including plans awaiting the next fog tick.
	# Foreign sites still pass through the visibility guard below.
	var site: int = sim.construction.at(cell)
	if site >= 0 and sim.construction.sites.records[site].owner == 0:
		sim.construction.selected = site
		_notice("Standort gewählt. Rechtsklick mit Arbeitern: bauen bzw. reparieren. Abbruch nur bei Baustellen.")
		if _buy_worker_button != null: refresh()
		return
	if _match_live() and not sim.fog.is_visible(0, cell):
		_set_selection(PackedInt32Array())
		return
	var warrior := sim.army.occupant[cell]
	if warrior >= 0 and sim.army.owners[sim.army.slots[warrior]] == 0:
		_set_selection(PackedInt32Array([ArmyState.TAG + warrior]))
		return
	var occ := sim.workers.occupant[cell]
	if occ == WorkerStore.NO_WORKER or int(sim.workers.faction[occ]) != 0:
		_set_selection(PackedInt32Array())
		return
	var ids := PackedInt32Array([occ])
	var kinds := PackedByteArray([DotOrder.kind_of(sim, occ)])
	_set_selection(ids)


## Rechte Taste allein verschiebt die Karte. Mit Strg setzt ein Zug das Gebiet, ein Klick schickt Krieger.
static func pointer_gesture(button: int, ctrl: bool, dragged: bool) -> int:
	if button == MOUSE_BUTTON_LEFT:
		if dragged:
			return Pointer.SELECT_RECT
		return Pointer.SELECT_ONE
	if ctrl and dragged:
		return Pointer.CONQUER
	if ctrl:
		return Pointer.WAR
	if dragged:
		return Pointer.PAN
	return Pointer.MARCH


## Rechtsklick schickt nur die aktuelle Auswahl. Sie gräbt den Weg frei und sucht sich danach wieder selbst Arbeit.
func issue_march(cell: int) -> bool:
	if sim == null or cell < 0 or cell >= sim.world.cell_count():
		return false
	var site: int = sim.construction.at(cell) if not _match_live() or sim.fog.is_visible(0, cell) else -1
	if site >= 0 and sim.construction.assign_repair(sim, site, selection) > 0:
		_notice("Arbeiter reparieren: bis zu 2 HP für 1 Energie je 4 Takte (Testwerte).")
		return true
	if site >= 0 and sim.construction.assign(sim, site, selection) > 0:
		_notice("Arbeiter zum Bau zugewiesen.")
		return true
	var armies := PackedInt32Array()
	for id in selection:
		if id >= ArmyState.TAG: armies.append(id)
	var army_goal := cell
	if site >= 0:
		var perimeter := sim.construction.receivers_for(sim, site)
		if not perimeter.is_empty(): army_goal = perimeter[0]
	var army_order := sim.army.command(armies, army_goal)
	var party := _party_for(cell, Rect2i())
	if party.is_empty() and army_order:
		_notice("Krieger marschieren.")
		return true
	if party.is_empty():
		_notice("Wähle zuerst Arbeiter.")
		return false
	var group_id := sim.take_party(party)
	if group_id < 0:
		_notice("Der Befehl hat keinen Platz.")
		return false
	var route := DigGuidance.mark_route(sim, group_id, cell)
	var exact := sim.world.cells[cell] == Materials.EMPTY and not sim._in_core(cell) and sim.set_move_goal(group_id, cell)
	if not exact and not sim.set_approach(group_id, cell):
		_notice("Dorthin führt kein Weg.")
		return false
	sim.march_cell = cell
	_notice(_march_notice(route, exact and sim.reaches_move_goal(group_id)))
	return true


## Strg und Rechtszug: die Auswahl erobert das Rechteck und baut alles darin ab.
func issue_conquer(rect: Rect2i) -> bool:
	if sim == null:
		return false
	var clipped := rect.abs().intersection(Rect2i(0, 0, sim.world.width, sim.world.height))
	if not clipped.has_area():
		return false
	var party := _party_for(-1, clipped)
	if party.is_empty():
		_notice("Wähle zuerst Arbeiter.")
		return false
	var group_id := sim.take_party(party)
	if group_id < 0 or not sim.assign_area(group_id, clipped):
		_notice("Der Befehl hat keinen Platz.")
		return false
	_last_mine_area = clipped
	_notice(_dig_notice(clipped))
	return true


## Strg und Rechtsklick schickt später alle Krieger. Solange es keine gibt, bleibt der Schwarm stehen.
func issue_war(cell: int) -> bool:
	if sim == null or cell < 0 or cell >= sim.world.cell_count():
		return false
	var warriors := PackedInt32Array()
	for id in selection:
		if id >= ArmyState.TAG and sim.unit_owner(id) == 0: warriors.append(id)
	if warriors.is_empty():
		_notice("Wähle zuerst Krieger.")
		return false
	_set_selection(warriors)
	return issue_march(cell)


func issue_build(cell: int) -> bool:
	if sim == null:
		return false
	if _placing_conduit:
		if not place_energy_network_cell(cell):
			_notice("Energieleitung: nur auf freiem Boden platzierbar.")
			return false
		_notice("Energieleitung gesetzt. Weitere Zellen ziehen oder E zum Beenden.")
		refresh()
		return true
	if _settlement_kind >= 0:
		if _match_live():
			var side := 5 if _settlement_kind == 0 else 3
			for dy in side:
				for dx in side:
					if not sim.fog.is_visible(0, cell + dy * sim.world.width + dx):
						_notice("Baugrund zuerst vollständig aufklären.")
						return false
		var id: int = sim.construction.place(sim, _settlement_kind, cell, selection)
		if id < 0:
			_notice("Bau gesperrt: freier Baugrund, Energie, Forschung und Kernlimit prüfen.")
			return false
		_settlement_kind = -1
		command_mode = Command.MINE
		_notice("Baustelle bezahlt. Bau beginnt erst beim ersten Arbeiterbeitrag.")
		return true
	if sim.place_building(_build_kind, cell):
		var placed := "Quelle gesetzt." if _build_kind == Buildings.KIND_SOURCE else "Veredler gesetzt."
		_notice(placed)
		command_mode = Command.MINE
		if renderer != null:
			renderer.set_buildings(sim.buildings.mask(sim.world.cell_count()))
	else:
		_notice("Diese Zelle nimmt das Gebäude nicht an.")
	refresh()
	return command_mode == Command.MINE


func _buy_worker() -> void:
	if sim.buy_worker(_production_site()):
		_notice("Arbeiter gekauft. Er startet am gewählten fertigen Standort.")
	else:
		_notice("Zu wenig Energie oder kein freier Starttunnel.")
	refresh()


func set_size_all(unit_size: int) -> bool:
	if sim == null or unit_size < 1 or unit_size > sim.upgrades.max_size():
		_notice("Dot-Größe ist noch gesperrt.")
		return false
	var changed := false
	for group_id in sim.group_open.size():
		if not _has_presence(group_id):
			continue
		changed = sim.set_desired_size(group_id, unit_size) or changed
	_notice("Dot-Größe: %d×%d" % [unit_size, unit_size] if changed else "Keine aktive Einheitengruppe.")
	refresh()
	return changed


func refresh() -> void:
	if renderer != null and sim != null and renderer.energy_network != sim.energy_network:
		renderer.energy_network = sim.energy_network
		renderer.energy_sim = sim
		renderer.queue_redraw()
	if sim == null or _mass_value == null:
		return
	var mass := sim.faction_mass(0) if _match_live() else sim.total_mass()
	var energy := sim.upgrades.energy
	var mined := sim.world.mined_fraction()
	var percent := clampi(int(round(mined * 100.0)), 0, 100)
	var transit := sim.energy_dots.pending_owned(0)
	var living_workers := sim.worker_population() - sim.spawner.pending()
	var living_warriors := sim.army.owners.count(0)
	var warrior_population := sim.army.population(0)

	_mass_value.text = str(living_workers)
	_mass_value.tooltip_text = "%d Arbeiter im Feld · %d bezahlt und wartend · Limit 50 einschließlich Warteschlange." % [living_workers, sim.spawner.pending()]
	_energy_value.text = _grouped(energy)
	_energy_value.tooltip_text = "%d verfügbare Energie · %d eigene Energiepunkte unterwegs. Nur gelieferte Energie ist ausgebbar." % [energy, transit]
	if _warrior_value != null:
		_warrior_value.text = _grouped(living_warriors)
		_warrior_value.tooltip_text = "%d Krieger im Feld · %d bezahlt in Produktion." % [living_warriors, warrior_population - living_warriors]
	if _opponent_value != null:
		_opponent_value.visible = _match_live()
		_opponent_value.text = "Gegner: unbekannt" if _match_live() else "Gegner  %d" % sim.opponent_mass()
	if _approach != null:
		_approach.text = "" if _match_live() else sim.approach_text
		_approach.visible = not _approach.text.is_empty()
	_mined_value.text = "%d %%" % percent
	_kern_value.text = "Stufe %d" % sim.upgrades.core_level
	_mass_bar.value = minf(100.0, float(mass))
	_energy_bar.value = minf(250.0, float(energy))
	_mined_bar.value = float(percent)
	_kern_bar.value = sim.upgrades.core_level
	var site: int = _production_site()
	if site < 0: site = sim.construction.production_site(0)
	if sim.construction.sites.valid(site):
		var row: Dictionary = sim.construction.sites.records[site]
		var title := "Kern" if row.kind == 0 else "Abfangstation" if row.kind == 2 else "Forschungszentrum" if row.kind == 3 else "Außenposten"
		_kern_bar.max_value = 100
		_kern_bar.value = 100.0 * float(row.hp) / row.max_hp if row.ready else 100.0 * float(row.work) / row.required
		_kern_value.text = "%s %d/%d HP" % [title, row.hp, row.max_hp] if row.ready else "%s Bau %d %%" % [title, 100 * row.work / row.required]
	elif not sim.construction.sites.records.is_empty():
		_kern_value.text = "Kein fertiger Standort"
		_kern_bar.value = 0

	_refresh_goals(mass, mined)
	_victory.visible = sim.won
	if _report != null:
		_report.visible = sim.won
		if sim.won:
			var lines := sim.victory_lines()
			for index in mini(lines.size(), _report_labels.size()):
				_report_labels[index].text = lines[index]
	if _pause_button != null:
		_pause_button.text = "WEITER" if clock.paused else "PAUSE"
	_speed_button.text = "%d×" % clock.speed
	_buy_worker_button.disabled = not sim.can_buy_worker() or sim.upgrades.energy < Simulation.WORKER_COST or sim.construction.production_site(0, _production_site()) < 0
	_buy_worker_button.text = "ARBEITER
%d/50 · 10 E" % sim.worker_population()
	if _buy_warrior_button != null:
		_buy_warrior_button.disabled = sim.upgrades.energy < ArmyState.COST or sim.construction.production_site(0, _production_site()) < 0
		_buy_warrior_button.text = "KRIEGER
%d · %d E" % [warrior_population, ArmyState.COST]

	_refresh_build_actions()
	_refresh_selection()
	_refresh_upgrades()
	for i in _upgrade_kinds.size():
		if _upgrade_kinds[i] == Upgrades.KIND_CORE and not sim.legacy_core_upgrades():
			_upgrade_buttons[i].disabled = true
			_upgrade_buttons[i].tooltip_text = "Historischer Kernflächenausbau gilt nur für alte Ein-Zellen-Kerne."
	_refresh_test_lab()
	_refresh_reference_hud()
	if _perf_overlay != null:
		_perf_overlay.visible = sim.debug_mode
		if sim.debug_mode:
			_perf_overlay.text = "TESTLABOR  |  %d Arbeiter · %d Krieger  |  %.1f FPS\nLetzter Tick: %.2f ms  |  Ziel Ø: %.2f ms\nBewegung Ø: %.2f ms  |  Abbau Ø: %.2f ms\nSuchaufträge: %d  |  Pfadaufträge: %d" % [
				sim.workers.count, sim.army.count, Engine.get_frames_per_second(),
				float(sim.last_tick_usec) / 1000.0,
				float(sim.stage_usec[Simulation.Stage.TARGET_SEARCH]) / maxi(1, sim.profiled_ticks) / 1000.0,
				float(sim.stage_usec[Simulation.Stage.MOVEMENT]) / maxi(1, sim.profiled_ticks) / 1000.0,
				float(sim.stage_usec[Simulation.Stage.MINING]) / maxi(1, sim.profiled_ticks) / 1000.0,
				SwarmMind.seeks_last_tick, SwarmMind.paths_last_tick,
			]


func _build_perf_overlay(layer: Control) -> void:
	_perf_overlay = _label(layer, "", 12, UiTheme.ACCENT)
	_perf_overlay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_perf_overlay.offset_left = -310
	_perf_overlay.offset_right = 310
	_perf_overlay.offset_top = 16
	_perf_overlay.offset_bottom = 100
	_perf_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perf_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_overlay.visible = false


func _ensure_bottom(layer: Control) -> void:
	if _bottom_strip != null: return
	_bottom_strip = _panel(layer)
	_bottom_strip.name = "ContextDock"
	_bottom_strip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bottom_strip.offset_left = 10
	_bottom_strip.offset_right = 1120
	_bottom_strip.offset_top = -260
	_bottom_strip.offset_bottom = -10
	_bottom_row = HBoxContainer.new()
	_bottom_row.add_theme_constant_override("separation", 8)
	_bottom_strip.add_child(_bottom_row)
	_actions_slot = _panel(_bottom_row)
	_actions_slot.custom_minimum_size.x = 322
	_selection_slot = _panel(_bottom_row)
	_selection_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_slot = _panel(layer)
	_stats_slot.name = "ResourceBar"
	_stats_slot.position = Vector2(10, 10)
	_stats_slot.custom_minimum_size = Vector2(640, 52)
	_tasks_row = HBoxContainer.new()
	_tasks_row.position = Vector2(10, 70)
	_tasks_row.add_theme_constant_override("separation", 5)
	_tasks_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_tasks_row)
	_map_slot = _panel(layer)
	_map_slot.name = "TeamMinimap"
	_map_slot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_map_slot.offset_left = -336
	_map_slot.offset_right = -10
	_map_slot.offset_top = -340
	_map_slot.offset_bottom = -10
	_goals_slot = _panel(layer)
	_goals_slot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_goals_slot.offset_left = -380
	_goals_slot.offset_right = -10
	_goals_slot.offset_top = 76
	_goals_slot.offset_bottom = 350
	_goals_slot.visible = false
	_build_top_menu(layer)
	_build_orders_panel(layer)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	_selection_slot.add_child(info)
	var selected := _column(info, 7)
	selected.custom_minimum_size.x = 230
	_selection_caption = _label(selected, "KEINE AUSWAHL", 13, UiTheme.ACCENT)
	var portraits := HBoxContainer.new()
	portraits.add_theme_constant_override("separation", 4)
	selected.add_child(portraits)
	_unit_icons = [TacticalArt.icon("worker"), TacticalArt.icon("warrior")]
	for i in 7:
		var card := TextureRect.new()
		card.custom_minimum_size = Vector2(28, 34)
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portraits.add_child(card)
		_selection_cards.append(card)
	_selection_detail = _label(selected, "Einheit oder Gebäude auswählen.", 12, UiTheme.MUTED)
	_selection_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_jobs = HBoxContainer.new()
	_context_jobs.add_theme_constant_override("separation", 4)
	selected.add_child(_context_jobs)
	var details := _column(info, 7)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_title = _label(details, "AUSWAHL & INFORMATION", 15, UiTheme.ACCENT)
	_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_description = _label(details, "Fahre über ein Aktionssymbol, um seine Funktion zu sehen.", 13, UiTheme.TEXT)
	_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message = _label(details, _opening_hint(), 11, UiTheme.MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_approach = _label(details, "", 11, UiTheme.ACCENT)
	_approach.visible = false
	_opponent_value = _label(details, "", 11, UiTheme.MUTED)
	_opponent_value.visible = false


func _build_stats(layer: Control) -> void:
	_ensure_bottom(layer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_stats_slot.add_child(row)
	_energy_value = _resource_counter(row, "ENERGIE", "energy", Color("70deee"))
	_mass_value = _resource_counter(row, "ARBEITER", "worker", UiTheme.ACCENT)
	_warrior_value = _resource_counter(row, "KRIEGER", "warrior", Color("b2c5dc"))
	# Existing status bindings remain available in the contextual info, not a global bar.
	_mined_value = _label(_selection_slot, "", 11, UiTheme.MUTED)
	_mined_value.visible = false
	_kern_value = Label.new()
	_kern_value.visible = false
	_selection_slot.add_child(_kern_value)
	_mass_bar = ProgressBar.new()
	_energy_bar = ProgressBar.new()
	_mined_bar = ProgressBar.new()
	_kern_bar = ProgressBar.new()
	for bar in [_mass_bar, _energy_bar, _mined_bar, _kern_bar]:
		bar.visible = false
		_selection_slot.add_child(bar)


func _build_goals(layer: Control) -> void:
	_ensure_bottom(layer)
	var card := _goals_slot
	var content := _column(card, 4)
	_goal_heading = _label(content, "RÄUMUNG", 16, UiTheme.TEXT)

	var mass := _objective(content, "100 Masse", UiTheme.ACCENT, 100)
	_goal_mass_value = mass[0]
	_goal_mass = mass[1]
	var upgrades := _objective(content, "2 Fähigkeiten", Color8(0x53, 0xC7, 0xFF), 2)
	_goal_upgrade_value = upgrades[0]
	_goal_upgrade = upgrades[1]
	var mining := _objective(content, "90 % Welt abbauen", Materials.COLORS[Materials.SOFT], 90)
	_goal_mining_value = mining[0]
	_goal_mining = mining[1]
	var fourth := _objective(content, "Weiteres Ziel", Color8(0xE6, 0xC3, 0x5C), 1)
	_goal_fourth_value = fourth[0]
	_goal_fourth = fourth[1]
	_goal_sections[_goal_sections.size() - 1].visible = false
	_victory = _label(content, "WELT EROBERT – WEITERSPIELEN MÖGLICH", 12, UiTheme.ACCENT)
	_victory.visible = false
	_build_report(layer)


func _build_report(layer: Control) -> void:
	_report = _panel(layer)
	_report.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_report.offset_left = -332
	_report.offset_right = -16
	_report.offset_top = 308
	_report.offset_bottom = 544
	_report.visible = false
	var content := _column(_report, 4)
	_label(content, "AUSWERTUNG", 16, UiTheme.ACCENT)
	for _index in 8:
		_report_labels.append(_label(content, "", 13, UiTheme.TEXT))


func _command_button(parent: Node, title: String, kind: String, action: Callable) -> Button:
	var button := _button(parent, title, action)
	button.icon = TacticalArt.icon(kind)
	button.add_theme_font_size_override("font_size", 11)
	button.custom_minimum_size = Vector2(134, 46)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _build_dock(layer: Control) -> void:
	_ensure_bottom(layer)
	var content := _column(_actions_slot, 6)
	_action_caption = _label(content, "AKTIONEN", 13, UiTheme.ACCENT)
	var grid := GridContainer.new()
	grid.columns = 3
	_dock_row = grid
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	content.add_child(grid)
	_buy_worker_button = _context_button(grid, "worker", "ARBEITER\n10 Energie", "worker", _buy_worker)
	_buy_worker_button.tooltip_text = "10 Energie · Arbeiter am ausgewählten fertigen Kern/Außenposten bestellen. Maximal 50 einschließlich Warteschlange."
	_buy_warrior_button = _context_button(grid, "warrior", "KRIEGER\n20 Energie", "warrior", func() -> void: sim.buy_warrior(0, _production_site()); refresh())
	_buy_warrior_button.tooltip_text = "20 Energie · Nahkämpfer am ausgewählten fertigen Kern/Außenposten produzieren."
	_context_button(grid, "core", "HAUPTKERN\n500 Energie", "core", _begin_settlement.bind(0)).tooltip_text = "Hauptkern bauen: 5×5 Felder, 500 Energie. Ausgewählte Arbeiter errichten den Kern."
	_context_button(grid, "outpost", "AUSSENPOSTEN", "outpost", _begin_settlement.bind(1)).tooltip_text = "Außenposten bauen. Produziert Einheiten und empfängt Energie; benötigt die entsprechende Forschung."
	_research_center_button = _context_button(grid, "research", "FORSCHUNG\nZentrum · 300", "research", _begin_settlement.bind(3))
	_interceptor_button = _context_button(grid, "interceptor", "ABFANGEN\nStation · 250", "interceptor", _begin_settlement.bind(2))
	_context_button(grid, "tower", "KRIEGSTURM\n250 Energie", "tower", _begin_settlement.bind(4)).tooltip_text = "3×3 Felder · 200 HP · 250 Energie. Benötigt Verteidigungstechnik. 100 Energie pro Minute Unterhalt, kostenlose Schüsse; benötigt Netzanschluss."
	_context_button(grid, "network", "LEITUNGEN\nE", "network", toggle_energy_network).tooltip_text = "Energieleitungen ziehen: verbindet eigene Gebäude mit einem Kern oder Außenposten. E beendet das Werkzeug."
	_repair_button = _context_button(grid, "repair", "REPARIEREN", "repair", _repair_selected)
	_context_button(grid, "demolish", "ABRISS\nQ", "demolish", toggle_demolition).tooltip_text = "Q: Leitungen sofort entfernen oder Arbeiterabriss eines eigenen Gebäudes beauftragen."
	_cancel_build_button = _context_button(grid, "cancel", "BAU ABBRECHEN", "demolish", _cancel_selected)
	_context_button(grid, "technology", "TECHNOLOGIE\nForschungsbaum", "research_tree", _toggle_upgrades).tooltip_text = "Technologien am gewählten Forschungszentrum ansehen und bei erfüllten Voraussetzungen starten."
	_context_button(grid, "tower_upgrade", "TURM AUSBAUEN", "tower", _upgrade_tower)
	_action_hint = _label(content, "Einheit oder eigenes Gebäude auswählen.", 12, UiTheme.MUTED)
	_action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_upgrade_panel(layer: Control) -> void:
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 1.0
	center.anchor_top = 1.0
	center.anchor_bottom = 1.0
	center.anchor_top = 0.08
	center.anchor_bottom = 0.92
	center.offset_top = 0
	center.offset_bottom = 0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	_upgrade_panel = _panel(center)
	_upgrade_panel.custom_minimum_size = Vector2(880, 0)
	var content := _column(_upgrade_panel, 7)
	var head := HBoxContainer.new()
	content.add_child(head)
	var caption := _label(head, "FORSCHUNG", 16, UiTheme.ACCENT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(head, "SCHLIESSEN", _toggle_upgrades)
	_label(content, "FORSCHUNGSBAUM · Zentrum auf der Karte auswählen", 13, UiTheme.ACCENT)
	_research_status = _label(content, "Kein Forschungszentrum ausgewählt.", 12, UiTheme.MUTED)
	var tools := HBoxContainer.new()
	content.add_child(tools)
	_research_tree_view = ResearchTreeView.new()
	_button(tools, "−", func() -> void: _research_tree_view.set_zoom(_research_tree_view.zoom / 1.2))
	_button(tools, "+", func() -> void: _research_tree_view.set_zoom(_research_tree_view.zoom * 1.2))
	_button(tools, "ANSICHT", func() -> void: _research_tree_view.reset_view())
	_label(tools, "Mausrad: Zoom · Mittlere Maustaste: Verschieben", 12, UiTheme.MUTED)
	content.add_child(_research_tree_view)
	_research_tree_view.detail = _label(content, "Technologie auswählen.", 12, UiTheme.TEXT)
	_research_tree_view.detail.custom_minimum_size.y = 92
	_research_tree_view.start_button = _button(content, "FORSCHUNG STARTEN", func() -> void: _start_research(_research_tree_view.selected))
	for tech in _research_tree_view.buttons:
		_research_tech_ids.append(tech)
		_research_tech_buttons.append(_research_tree_view.buttons[tech])
	if _research_center_button == null: _research_center_button = _button(content, "FORSCHUNGSZENTRUM BAUEN · 300", _begin_settlement.bind(3))
	if _interceptor_button == null: _interceptor_button = _button(content, "ABFANGSTATION BAUEN · 250", _begin_settlement.bind(2))
	_build_caption = _label(content, "BAUEN", 12, UiTheme.MUTED)
	_source_place_button = _build_button(content, _arm_source)
	_source_tier_button = _build_button(content, _raise_source)
	_refinery_place_button = _build_button(content, _arm_refinery)
	_refinery_tier_button = _build_button(content, _raise_refinery)
	_upgrade_panel.visible = false


func _build_minimap(layer: Control) -> void:
	_ensure_bottom(layer)
	var content := _column(_map_slot, 4)
	_label(content, "TEAM & KARTE", 12, UiTheme.MUTED)
	_team_rows = _column(content, 2)
	for index in 4:
		var label := _label(_team_rows, "", 12, UiTheme.TEXT)
		label.tooltip_text = "F = Siegforschungsstufe · R = gehaltene Relikte · H = Hügelfortschritt. Angezeigt werden die aktivierten Siegziele."
		label.visible = false
		_team_labels.append(label)
	if renderer == null or camera == null: return
	_map = WorldMinimap.new()
	_map.custom_minimum_size = Vector2(280, 210)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.world = sim.world
	_map.renderer = renderer
	_map.fog_view = fog_view
	_map.camera = camera
	content.add_child(_map)


func _stat_row(parent: Node, title: String, color: Color, maximum: float) -> Array:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 7)
	parent.add_child(line)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(11, 11)
	chip.color = color
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(chip)
	var name := _label(line, title, 14, UiTheme.TEXT)
	name.custom_minimum_size.x = 72
	var bar := _progress(line, maximum, color, 70)
	var value := _label(line, "0", 14, UiTheme.TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 53
	return [value, bar]

func _resource_counter(parent: Node, title: String, kind: String, color: Color) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = 175
	row.add_theme_constant_override("separation", 9)
	parent.add_child(row)
	var icon := TextureRect.new()
	if kind == "energy":
		var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		pixel.fill(MatchRules.FACTION_COLORS[0])
		icon.texture = ImageTexture.create_from_image(pixel)
		var effect := ShaderMaterial.new()
		effect.shader = EnergyRenderer.DOT_GLOW_SHADER
		icon.material = effect
	else: icon.texture = TacticalArt.icon(kind)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	var column := _column(row, 0)
	_label(column, title, 10, UiTheme.MUTED)
	return _label(column, "0", 22, color)

func _build_top_menu(layer: Control) -> void:
	_top_menu = _panel(layer)
	_top_menu.name = "TopMenu"
	_top_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_top_menu.offset_left = -570
	_top_menu.offset_right = -10
	_top_menu.offset_top = 10
	_top_menu.offset_bottom = 64
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_top_menu.add_child(row)
	_button(row, "MENÜ", toggle_pause_menu).tooltip_text = "Escape · Einstellungen, Lautstärke, Speichern, Laden und Spiel verlassen."
	_button(row, "AUFTRÄGE", _toggle_orders).tooltip_text = "Alle eigenen Forschungs-, Bau- und Produktionsaufträge ansehen."
	_button(row, "ZIELE", _toggle_goals).tooltip_text = "Aktivierte Siegziele und eigenen Fortschritt ansehen."
	_button(row, "TECHNIK", _toggle_upgrades).tooltip_text = "Forschungsbaum ansehen. Zum Starten einer Technologie ein eigenes Zentrum wählen."
	_pause_button = _button(row, "PAUSE", func() -> void: clock.paused = not clock.paused; refresh())
	_speed_button = _button(row, "1×", _cycle_speed)

func _build_orders_panel(layer: Control) -> void:
	_orders_panel = _panel(layer)
	_orders_panel.name = "OwnOrders"
	_orders_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_orders_panel.offset_left = -490
	_orders_panel.offset_right = -10
	_orders_panel.offset_top = 76
	_orders_panel.offset_bottom = 468
	_orders_panel.visible = false
	var content := _column(_orders_panel, 8)
	_label(content, "EIGENE AUFTRÄGE", 16, UiTheme.ACCENT)
	_label(content, "Anklicken: Standort auswählen und Kamera zentrieren.", 11, UiTheme.MUTED)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 290)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_orders_rows = _column(scroll, 5)
	_orders_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _toggle_orders() -> void:
	_orders_panel.visible = not _orders_panel.visible
	_goals_slot.visible = false
	_refresh_reference_hud()

func _toggle_goals() -> void:
	_goals_slot.visible = not _goals_slot.visible
	_orders_panel.visible = false

func _context_button(parent: Node, key: String, title: String, kind: String, action: Callable) -> Button:
	var button := _command_button(parent, title, kind, action)
	button.custom_minimum_size = Vector2(96, 48)
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_constant_override("icon_max_width", 24)
	button.focus_mode = Control.FOCUS_ALL
	_context_buttons[key] = button
	button.mouse_entered.connect(_show_action_info.bind(button))
	button.focus_entered.connect(_show_action_info.bind(button))
	button.mouse_exited.connect(_clear_action_info.bind(button))
	button.focus_exited.connect(_clear_action_info.bind(button))
	return button

func _show_action_info(control: Control) -> void:
	_hovered_action = control
	_update_action_info()

func _clear_action_info(control: Control) -> void:
	if _hovered_action == control: _hovered_action = null
	_update_action_info()

func _update_action_info() -> void:
	if _info_title == null: return
	if is_instance_valid(_hovered_action) and _hovered_action.visible:
		_info_title.text = str(_hovered_action.job.title) if _hovered_action is HudTaskIcon else (_hovered_action as Button).text.replace("\n", " · ")
		_info_description.text = _hovered_action.tooltip_text
		if _hovered_action is Button and _hovered_action.disabled: _info_description.text += "\nDerzeit nicht verfügbar."
		return
	_hovered_action = null
	_info_title.text = "AKTION ERKLÄREN"
	_info_description.text = "Fahre über ein Aktions- oder Auftragssymbol. Hier erscheinen Funktion, Kosten und Voraussetzungen."
	if _placing_conduit:
		_info_title.text = "ENERGIENETZ"
		_info_description.text = "Linke Maustaste halten und Leitungen ziehen. Beim Loslassen wird gebaut. E beendet das Werkzeug."
	elif _demolition_mode:
		_info_title.text = "ABRISS"
		_info_description.text = "Eigene Leitung oder eigenes Gebäude anklicken. Gebäude werden von Arbeitern abgerissen. Q beendet das Werkzeug."

func _focus_hud_job(job: Dictionary) -> void:
	var site := int(job.site)
	if site < 0:
		_toggle_orders()
		return
	if not sim.construction.sites.valid(site) or sim.construction.sites.records[site].owner != 0: return
	sim.construction.selected = site
	if camera != null:
		var cell := sim.construction.center(site)
		camera.focus_world(Vector2(cell % sim.world.width, cell / sim.world.width) + Vector2.ONE * 0.5)
	refresh()

func _refresh_job_icons(parent: HBoxContainer, icons: Array[HudTaskIcon], items: Array[Dictionary], limit: int) -> void:
	var shown: Array[Dictionary] = []
	for index in mini(items.size(), limit):
		if index == limit - 1 and items.size() > limit:
			shown.append({"key": "overflow", "site": -1, "icon": "research_tree", "title": "Weitere Aufträge", "count": items.size() - index, "progress": 0.0, "waiting": false, "detail": "%d weitere Aufträge · anklicken für die Gesamtübersicht." % (items.size() - index)})
		else: shown.append(items[index])
	var changed := icons.size() != shown.size()
	if not changed:
		for index in shown.size():
			if icons[index].job.key != shown[index].key: changed = true
	if changed:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
		icons.clear()
		for value in shown:
			var icon := HudTaskIcon.new()
			parent.add_child(icon)
			icon.pressed.connect(func() -> void: _focus_hud_job(icon.job))
			icon.mouse_entered.connect(_show_action_info.bind(icon))
			icon.focus_entered.connect(_show_action_info.bind(icon))
			icon.mouse_exited.connect(_clear_action_info.bind(icon))
			icon.focus_exited.connect(_clear_action_info.bind(icon))
			icons.append(icon)
	for index in shown.size(): icons[index].update_job(shown[index])

func _refresh_reference_hud() -> void:
	if sim == null or _tasks_row == null: return
	_own_jobs = HudOverview.jobs(sim)
	_refresh_job_icons(_tasks_row, _task_icons, _own_jobs, 10)
	var site := _production_site()
	var local_jobs: Array[Dictionary] = []
	for job in _own_jobs:
		if site < 0 or int(job.site) == site: local_jobs.append(job)
	_refresh_job_icons(_context_jobs, _context_icons, local_jobs, 4)
	if _action_hint != null: _refresh_context_actions(site)
	if not _team_labels.is_empty():
		var rows := HudOverview.team_rows(sim)
		for index in _team_labels.size():
			_team_labels[index].visible = index < rows.size()
			if index >= rows.size(): continue
			var row: Dictionary = rows[index]
			_team_labels[index].text = "%s  ·  %s" % [row.name, row.score]
			_team_labels[index].add_theme_color_override("font_color", MatchRules.FACTION_COLORS[int(row.owner)])
	if _orders_panel.visible:
		var order_keys: Array = []
		for job in _own_jobs: order_keys.append(job.key)
		var signature := hash(order_keys)
		if signature != _orders_signature or _orders_rows.get_child_count() == 0:
			_orders_signature = signature
			for child in _orders_rows.get_children():
				_orders_rows.remove_child(child)
				child.queue_free()
			_order_buttons.clear()
			if _own_jobs.is_empty(): _label(_orders_rows, "Keine laufenden eigenen Aufträge.", 13, UiTheme.MUTED)
			for job in _own_jobs:
				var button := _button(_orders_rows, "", _focus_hud_job.bind(job))
				button.icon = TacticalArt.icon(str(job.icon))
				_order_buttons.append(button)
		for index in _order_buttons.size():
			var job: Dictionary = _own_jobs[index]
			_order_buttons[index].text = "%s ×%d · %d %%" % [job.title, job.count, roundi(float(job.progress) * 100.0)]
			_order_buttons[index].tooltip_text = str(job.detail)
	_update_action_info()

func _refresh_context_actions(site: int) -> void:
	var keys: Array = []
	var workers_selected := 0
	for id in sim.picked:
		if id >= 0 and id < sim.workers.count and sim.workers.faction[id] == 0: workers_selected += 1
	if sim.construction.sites.valid(site):
		var row: Dictionary = sim.construction.sites.records[site]
		_action_caption.text = HudOverview.site_name(int(row.kind)).to_upper()
		_selection_caption.text = "%s #%d" % [HudOverview.site_name(int(row.kind)).to_upper(), site]
		_selection_detail.text = "%d / %d HP%s" % [row.hp, row.max_hp, " · Bau %d %%" % roundi(100.0 * row.work / maxi(1, int(row.required))) if not row.ready else ""]
		if sim.defense.armed(row):
			_selection_detail.text += "\nWaffe: %s · %d Energie/Minute" % ["versorgt" if sim.defense.is_powered(sim, site) else "Unterhalt / Netz fehlt", sim.defense.upkeep_cost(row)]
			if int(row.kind) == 4:
				_selection_detail.text += " · Stufe %d/3" % sim.defense.level(row)
				if int(row.weapon_upgrade) >= 0: _selection_detail.text += "\nAusbau: %.1f s · Waffe pausiert" % (maxi(0, int(row.weapon_upgrade) - sim.tick_count) / 20.0)
		if not sim.picked.is_empty(): _selection_detail.text += "\n%d Einheiten mitgewählt" % sim.picked.size()
		_selection_cards[0].texture = TacticalArt.icon(HudOverview.site_icon(int(row.kind)))
		_selection_cards[0].visible = true
		_selection_cards[0].modulate = Color.WHITE
		if row.ready:
			if int(row.kind) in [0, 1]: keys.append_array(["worker", "warrior"])
			if int(row.kind) == 3: keys.append("technology")
			if int(row.kind) == 4: keys.append("tower_upgrade")
			keys.append_array(["network", "demolish"])
			if workers_selected > 0 and row.hp < row.max_hp: keys.append("repair")
		else: keys.append("cancel")
		_action_hint.text = "Standortproduktion und Baufortschritt rechts."
	elif workers_selected > 0:
		keys = ["core", "outpost", "research", "interceptor", "tower", "network", "demolish"]
		_action_caption.text = "ARBEITER · BAUEN"
		_action_hint.text = "Rechtsklick: Marsch\nStrg + Rechtsziehen: Abbaugebiet"
	else:
		_action_caption.text = "KRIEGER · BEFEHLE" if not sim.picked.is_empty() else "AKTIONEN"
		_action_hint.text = "Rechtsklick: Marsch\nStrg + Rechtsklick: Kampfauftrag" if not sim.picked.is_empty() else "Einheit oder eigenes Gebäude auswählen."
	for key in _context_buttons:
		var button: Button = _context_buttons[key]
		button.visible = keys.has(key)
		if key == "outpost": button.disabled = not sim.construction.unlocked(sim, 1) or sim.upgrades.energy < sim.construction.price(1, 0)
		if key == "core": button.disabled = sim.upgrades.energy < sim.construction.price(0, 0) or sim.construction.sites.count(0, 0) > 0
		if key == "tower": button.disabled = not sim.construction.unlocked(sim, 4) or sim.upgrades.energy < sim.construction.price(4, 0)
		if key == "tower_upgrade":
			button.disabled = not sim.defense.can_upgrade(sim, site)
			if sim.construction.sites.valid(site) and int(sim.construction.sites.records[site].kind) == 4:
				var row: Dictionary = sim.construction.sites.records[site]
				var cost := sim.defense.upgrade_cost(row)
				button.text = "AUSGEBAUT · III" if cost < 0 else "%s\n%d Energie" % ["SCHNELLFEUER" if sim.defense.level(row) == 1 else "STRAHL", cost]
				button.tooltip_text = "Ausbau am einzelnen Turm: 10 Sekunden ohne Feuern. Netzanschluss und bezahlter Unterhalt bleiben nötig."

func _upgrade_tower() -> void:
	if sim.defense.upgrade(sim, sim.construction.selected):
		_notice("Turmausbau gestartet. Die Waffe pausiert für 10 Sekunden.")
	refresh()


func _objective(parent: Node, title: String, color: Color, maximum: float) -> Array:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 3)
	parent.add_child(section)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	section.add_child(row)
	var label := _label(row, title, 13, UiTheme.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_sections.append(section)
	_goal_names.append(label)
	var value := _label(row, "0", 12, UiTheme.MUTED)
	var bar := _progress(section, maximum, color, 270)
	return [value, bar]


func _progress(parent: Node, maximum: float, color: Color, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maximum
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(width, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.style_progress(bar, color)
	parent.add_child(bar)
	return bar


func _column(parent: Node, separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _panel(parent: Node) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", UiTheme.panel())
	parent.add_child(card)
	return card


func _label(parent: Node, label_text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	button.custom_minimum_size.y = 39
	UiTheme.style_button(button)
	parent.add_child(button)
	return button


func _divider(parent: Node) -> void:
	var separator := VSeparator.new()
	separator.custom_minimum_size.x = 9
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(separator)


func _has_presence(group_id: int) -> bool:
	return _human_group(group_id) and sim.group_open[group_id] == 1 and (
		sim.quotas[group_id] > 0 or sim.workers.group_mass[group_id] > 0
	)


func _human_group(group_id: int) -> bool:
	return sim.rules.group_faction.size() <= group_id or sim.rules.group_faction[group_id] == 0


func _available_for_work(group_id: int) -> bool:
	return _has_presence(group_id)




func _cycle_speed() -> void:
	if clock.speed == 1:
		clock.speed = 2
	elif clock.speed == 2:
		clock.speed = 4
	else:
		clock.speed = 1
	_notice("Tempo %d×." % clock.speed)
	refresh()


func _load_game() -> void:
	load_requested.emit("user://slot.dw")


func report(text: String) -> void:
	_notice(text)


func _pause_game() -> void:
	clock.paused = not clock.paused
	_notice("Pausiert." if clock.paused else "Fortgesetzt.")
	refresh()


func _save_game() -> void:
	if sim.debug_modified or sim.debug_mode:
		_notice("Testlabor: Speichern bis zum Neustart deaktiviert.")
		return
	_notice("Spiel gespeichert." if SaveGame.write_file("user://slot.dw", sim) else "Speichern fehlgeschlagen.")


func _toggle_upgrades() -> void:
	_upgrade_panel.visible = not _upgrade_panel.visible
	if _upgrade_panel.visible:
		_placing_conduit = false
		_demolition_mode = false
		_settlement_kind = -1
		command_mode = Command.MINE
		if renderer != null: renderer.set_energy_preview(PackedInt32Array())
		if _research_tree_view != null: _research_tree_view.reset_view()


func _add_upgrade_button(parent: Node, kind: int, indent: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	if indent > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(indent, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)
	var button := _button(row, "", _buy.bind(kind))
	button.custom_minimum_size = Vector2(310 - indent, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_buttons.append(button)
	_upgrade_kinds.append(kind)


func _buy(kind: int) -> void:
	if sim.buy(kind):
		if kind == Upgrades.KIND_CORE:
			if renderer != null:
				renderer.set_core_mask(sim.core_mask)
			_notice("Energiekern erweitert. Arbeiter betreten die Fläche nicht.")
		elif kind == Upgrades.KIND_SPEED:
			_notice("Arbeiter bewegen sich schneller.")
		elif kind == Upgrades.KIND_ENERGY_SPEED:
			_notice("Energie bewegt sich schneller.")
		elif kind == Upgrades.KIND_RESEARCH:
			_notice("Forschung steigt.")
		elif kind == Upgrades.KIND_SWARM:
			_notice("Der Schwarm sucht sich freie Ziele.")
		else:
			_notice("Fähigkeit gekauft.")
	else:
		_notice("Nicht verfügbar oder zu wenig Energie.")
	refresh()


func _refresh_upgrades() -> void:
	var u := sim.upgrades
	for i in _upgrade_buttons.size():
		var button := _upgrade_buttons[i]
		var kind := _upgrade_kinds[i]
		var cost := -1
		var locked := false
		match kind:
			Upgrades.KIND_CORE:
				cost = u.core_cost()
				locked = cost < 0
				if locked:
					button.text = "KERN   Stufe %d    VOLL" % u.core_level
				else:
					button.text = "KERN   Stufe %d    •    %d Energie" % [u.core_level + 1, cost]
			Upgrades.KIND_SPEED:
				cost = u.speed_cost()
				if cost < 0:
					button.text = "ARBEITER  jeder Takt  VOLL"
					locked = true
				else:
					button.text = "ARBEITER  %s    •    %d Energie" % [u.pace_text(u.next_worker_period(sim.config.move_period_ticks)), cost]
			Upgrades.KIND_ENERGY_SPEED:
				cost = u.energy_speed_cost()
				if cost < 0:
					button.text = "ENERGIE  jeder Takt  VOLL"
					locked = true
				else:
					button.text = "ENERGIE  %s    •    %d Energie" % [u.pace_text(u.next_energy_period()), cost]
			Upgrades.KIND_DIG:
				cost = u.dig_cost()
				button.text = "ABBAU   Stufe %d    •    %d Energie" % [u.dig_level + 1, cost]
			Upgrades.KIND_SWARM:
				cost = u.swarm_cost()
				locked = cost < 0
				if locked:
					button.text = "INTELLIGENZ   Stufe %d    VOLL" % u.swarm_level
				else:
					button.text = "INTELLIGENZ   Stufe %d    •    %d Energie" % [u.swarm_level + 1, cost]
			Upgrades.KIND_FUSION2:
				cost = u.fusion2_cost()
				locked = u.fusion2
				button.text = "VERSCHMELZUNG 2×2   FREIGESCHALTET" if locked else "VERSCHMELZUNG 2×2    •    %d Energie" % cost
			Upgrades.KIND_FUSION3:
				cost = u.fusion3_cost()
				locked = u.fusion3 or not u.fusion2
				if u.fusion3:
					button.text = "VERSCHMELZUNG 3×3   FREIGESCHALTET"
				else:
					button.text = "VERSCHMELZUNG 3×3    •    %d Energie" % cost
		button.disabled = true
		button.tooltip_text = "Alte Sofortkäufe deaktiviert: Forschung im Forschungszentrum starten."
	_refresh_buildings()
	_refresh_research()


func _refresh_goals(_mass: int, _mined: float) -> void:
	if _goal_names.size() < 3 or _goal_sections.size() < 3: return
	if sim.config.mode == SimConfig.MODE_MATCH:
		_refresh_match_goals()
		return
	_goal_heading.text = "FREIES SPIEL"
	_show_single_goal("Arbeiterlimit", sim.worker_population(), SimConfig.MAX_WORKERS_PER_PLAYER)
	_victory.visible = false

func _refresh_match_goals() -> void:
	_goal_heading.text = "MEHRSPIELER"
	var rows: Array = []
	var mask := sim.config.victory_mask
	if (mask & MatchRules.VICTORY_ELIMINATION) != 0:
		var gone := 0
		for faction in range(1, sim.rules.faction_count):
			if faction < sim.rules.alive.size() and sim.rules.alive[faction] == 0:
				gone += 1
		rows.append(["Gegner auslöschen", gone, maxi(1, sim.rules.faction_count - 1)])
	if (mask & MatchRules.VICTORY_RESEARCH) != 0:
		rows.append(["Forschung Stufe 5", sim.upgrades.research_level, Upgrades.RESEARCH_MAX])
	if (mask & MatchRules.VICTORY_RELICS) != 0:
		var owned := 0
		for owner in sim.rules.relic_owner:
			if owner == 0:
				owned += 1
		rows.append(["Reliquien", owned, MatchRules.RELIC_NEED])
	if (mask & MatchRules.VICTORY_HILL) != 0:
		var score := sim.rules.hill_score[0] if sim.rules.hill_score.size() > 0 else 0
		rows.append(["König des Hügels", score, MatchRules.HILL_TICKS])
	var bars: Array[ProgressBar] = [_goal_mass, _goal_upgrade, _goal_mining, _goal_fourth]
	var values: Array[Label] = [_goal_mass_value, _goal_upgrade_value, _goal_mining_value, _goal_fourth_value]
	for index in _goal_sections.size():
		var show := index < rows.size()
		_goal_sections[index].visible = show
		if not show:
			continue
		var row: Array = rows[index]
		_goal_names[index].text = str(row[0])
		var goal := maxi(1, int(row[2]))
		var current := int(row[1])
		bars[index].max_value = float(goal)
		bars[index].value = minf(float(goal), float(current))
		values[index].text = "%d / %d" % [current, goal]
	if sim.won:
		_victory.text = MatchRules.outcome_text(sim.rules.winner_faction, sim.rules.win_kind) + " – weiterspielen möglich"


func _start_research(tech: String) -> void:
	var site := _production_site()
	if sim.research.start(sim, 0, site, tech):
		_notice("Forschung gestartet: %s" % ResearchSystem.CATALOG[tech]["label"])
	else:
		_notice("Forschungszentrum wählen und Voraussetzungen prüfen.")
	refresh()

func _refresh_research() -> void:
	var site := _production_site()
	if _research_status != null:
		_research_status.text = "Forschungszentrum #%d · %s" % [site, "Netz verbunden" if sim.research.source_for(sim, 0, site) >= 0 else "Netzanschluss fehlt"] if site >= 0 and sim.construction.sites.valid(site) and sim.construction.sites.records[site].kind == 3 else "Forschungszentrum auf der Karte auswählen."
	if _research_tree_view != null: _research_tree_view.refresh(sim, site)


func _show_single_goal(title: String, current: int, goal: int) -> void:
	_goal_sections[0].visible = true
	_goal_sections[1].visible = false
	_goal_sections[2].visible = false
	if _goal_sections.size() > 3:
		_goal_sections[3].visible = false
	_goal_names[0].text = title
	_goal_mass.max_value = float(goal)
	_goal_mass.value = minf(float(goal), float(current))
	_goal_mass_value.text = "%s / %s" % [_grouped(current), _grouped(goal)]


func _refresh_buildings() -> void:
	if _source_place_button == null or _build_caption == null:
		return
	var sources := buildings_allowed(Buildings.KIND_SOURCE)
	var refineries := buildings_allowed(Buildings.KIND_REFINERY)
	_build_caption.visible = sources or refineries
	_source_place_button.visible = sources
	_source_tier_button.visible = sources
	_refinery_place_button.visible = refineries
	_refinery_tier_button.visible = refineries
	_fill_place_button(_source_place_button, Buildings.KIND_SOURCE, "QUELLE")
	_fill_tier_button(_source_tier_button, Buildings.KIND_SOURCE, "QUELLE", sim.buildings.source_level, Buildings.SOURCE_TIER_MAX)
	_fill_place_button(_refinery_place_button, Buildings.KIND_REFINERY, "VEREDLER")
	_fill_tier_button(_refinery_tier_button, Buildings.KIND_REFINERY, "VEREDLER", sim.buildings.refinery_level, Buildings.REFINERY_TIER_MAX)


func buildings_allowed(kind: int) -> bool:
	return sim.buildings.allowed(mode_of_sim(), kind)


func mode_of_sim() -> int:
	return sim.config.mode


func _fill_place_button(button: Button, kind: int, title: String) -> void:
	var cost := sim.buildings.place_cost(kind)
	var have := sim.buildings.count_of(kind)
	var limit := Buildings.SOURCE_MAX if kind == Buildings.KIND_SOURCE else Buildings.REFINERY_MAX
	if cost < 0:
		button.text = "%s   %d/%d    VOLL" % [title, have, limit]
		button.disabled = true
	else:
		button.text = "%s setzen    •    %d Energie" % [title, cost]
		button.disabled = sim.upgrades.energy < cost


func _fill_tier_button(button: Button, kind: int, title: String, level: int, max_level: int) -> void:
	var cost := sim.buildings.tier_cost(kind)
	if cost < 0:
		button.text = "%s   Stufe %d    VOLL" % [title, level]
		button.disabled = true
	else:
		button.text = "%s   Stufe %d    •    %d Energie" % [title, level + 1, cost]
		button.disabled = sim.upgrades.energy < cost
	if level > max_level:
		button.disabled = true


func _arm_source() -> void:
	_arm_build(Buildings.KIND_SOURCE)


func _arm_refinery() -> void:
	_arm_build(Buildings.KIND_REFINERY)


func _raise_source() -> void:
	_raise_building(Buildings.KIND_SOURCE)


func _raise_refinery() -> void:
	_raise_building(Buildings.KIND_REFINERY)


func _arm_build(kind: int) -> void:
	_placing_conduit = false
	_demolition_mode = false
	if not sim.buildings.allowed(sim.config.mode, kind):
		_notice("In diesem Modus nicht baubar.")
		return
	var cost := sim.buildings.place_cost(kind)
	if cost < 0:
		_notice("Mehr Gebäude dieser Art gibt es nicht.")
		return
	if sim.upgrades.energy < cost:
		_notice("Zu wenig Energie.")
		return
	_build_kind = kind
	_settlement_kind = -1
	command_mode = Command.BUILD
	_notice("Freien Tunnel anklicken.")
	refresh()


func _raise_building(kind: int) -> void:
	if sim.upgrade_building(kind):
		_notice("Gebäude verbessert.")
	else:
		_notice("Nicht verfügbar oder zu wenig Energie.")
	refresh()


func _build_button(parent: Node, action: Callable) -> Button:
	var button := _button(parent, "", action)
	button.custom_minimum_size = Vector2(310, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _opening_hint() -> String:
	if sim == null:
		return "Linke Taste wählt. Rechtsklick schickt die Auswahl. Rechte Taste verschiebt, mit Strg ein Gebiet."
	if sim.config.mode == SimConfig.MODE_MATCH:
		return "Gegen KI (%s). Rechtsklick schickt die Auswahl. Rechte Taste verschiebt, mit Strg ein Gebiet." % sim.rules.difficulty_label()
	if sim.config.mode == SimConfig.MODE_EXTRACTION:
		return "Quellen lassen Material nachwachsen. Rechtsklick schickt die Auswahl, mit Strg ein Gebiet."
	if sim.config.mode == SimConfig.MODE_REFINING:
		return "Setze den Veredler in eine Ader. Rechtsklick schickt die Auswahl, mit Strg ein Gebiet."
	return "Linke Taste wählt. Rechtsklick schickt die Auswahl. Rechte Taste verschiebt, mit Strg ein Gebiet."


func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var text := ""
	while digits.length() > 3:
		text = "." + digits.substr(digits.length() - 3, 3) + text
		digits = digits.substr(0, digits.length() - 3)
	text = digits + text
	return "-" + text if value < 0 else text


func _refresh_selection() -> void:
	selection = sim.picked
	if _selection_caption != null:
		var workers_selected := 0
		var warriors_selected := 0
		for id in selection:
			if id >= ArmyState.TAG: warriors_selected += 1
			else: workers_selected += 1
		_selection_caption.text = "AUSWAHL · %d EINHEIT%s" % [selection.size(), "" if selection.size() == 1 else "EN"]
		_selection_detail.text = "%d Arbeiter  /  %d Krieger\nRechtsklick: Marsch · E: Netz · Q: Abriss" % [workers_selected, warriors_selected]
		for i in _selection_cards.size():
			_selection_cards[i].texture = _unit_icons[1 if i >= workers_selected else 0]
			_selection_cards[i].visible = i < selection.size()
			_selection_cards[i].modulate = Color.WHITE if i < selection.size() else Color(0.20, 0.32, 0.40)
	var unit_size := 1
	for group_id in sim.group_open.size():
		if _available_for_work(group_id):
			unit_size = int(sim.desired_size[group_id])
			break
	if unit_size != _last_size_style:
		for i in _size_buttons.size():
			UiTheme.style_button(_size_buttons[i], i + 1 == unit_size)
		_last_size_style = unit_size
	for i in _size_buttons.size():
		_size_buttons[i].disabled = i + 1 > sim.upgrades.max_size()


func _build_swarm(parent: Node) -> void:
	if sim == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	for group_id in sim.group_open.size():
		if not _has_presence(group_id):
			continue
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(12, 12)
		chip.color = sim.group_colors[group_id]
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
		var label := _label(row, "0", 12, UiTheme.TEXT)
		_swarm_ids.append(group_id)
		_swarm_labels.append(label)


func _refresh_swarm() -> void:
	for index in _swarm_ids.size():
		var group_id := _swarm_ids[index]
		var mass := sim.workers.group_mass[group_id]
		_swarm_labels[index].text = str(mass)


func menu_open() -> bool:
	return _pause_layer != null and _pause_layer.visible


func toggle_pause_menu() -> void:
	if menu_open():
		_close_pause_menu()
	else:
		_open_pause_menu()


func _match_live() -> bool:
	return sim != null and sim.config.mode == SimConfig.MODE_MATCH and sim.rules.faction_count > 1


func _set_selection(ids: PackedInt32Array) -> void:
	selection = ids
	sim.picked = ids
	sim.construction.selected = -1
	if _buy_worker_button != null: refresh()


func _party_for(_cell: int, _rect: Rect2i) -> PackedInt32Array:
	var chosen := PackedInt32Array()
	for id in selection:
		if id < 0 or id >= sim.workers.count:
			continue
		if int(sim.workers.faction[id]) != 0:
			continue
		chosen.append(id)
	return chosen


func _unit_hits(id: int, rect: Rect2i) -> bool:
	if not rect.has_area():
		return false
	var width := sim.world.width
	var anchor := sim.workers.cell[id]
	var unit_size := int(sim.workers.size[id])
	var origin_x := anchor % width
	var origin_y := anchor / width
	for dy in unit_size:
		for dx in unit_size:
			if rect.has_point(Vector2i(origin_x + dx, origin_y + dy)):
				return true
	return false


func _march_notice(route: int, reaches: bool) -> String:
	if route == DigGuidance.ROUTE_MINING:
		return "Die Auswahl gräbt sich den Weg frei."
	if reaches:
		return "Die Auswahl ist unterwegs."
	return "Die Auswahl geht zum nächstmöglichen Punkt."


func _dig_notice(rect: Rect2i) -> String:
	var group_id := sim.command_group
	if group_id < 0:
		return "Das Gebiet wird erobert."
	var kind := DigGuidance.preview(sim, group_id, rect)
	if kind == DigGuidance.TOWARD:
		return "Das Gebiet ist nicht erreichbar. Der Schwarm gräbt sich dorthin."
	if kind == DigGuidance.EMPTY:
		return "Dort ist nichts abzubauen. Der Schwarm nimmt die nächste Ressource."
	return "Das Gebiet wird erobert."


func _build_pause_menu(layer: Control) -> void:
	_pause_layer = Control.new()
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.visible = false
	layer.add_child(_pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(center)
	var card := _panel(center)
	card.custom_minimum_size = Vector2(320, 0)
	var column := _column(card, 8)
	_label(column, "PAUSE", 22, UiTheme.ACCENT)
	_menu_button(column, "WEITER", _close_pause_menu)
	_menu_button(column, "SPEICHERN", _save_game)
	_menu_button(column, "LADEN", _load_game)
	_test_toggle = _menu_button(column, "TESTLABOR AKTIVIEREN", _toggle_test_lab)
	_build_test_lab(column)
	_menu_button(column, "NEU STARTEN", func() -> void: restart_requested.emit())
	_label(column, "LAUTSTÄRKE", 12, UiTheme.MUTED)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.value = 80
	_volume.custom_minimum_size = Vector2(280, 22)
	_volume.value_changed.connect(_set_volume)
	column.add_child(_volume)
	_set_volume(80)
	_menu_button(column, "BEENDEN", func() -> void: leave_requested.emit())


func _menu_button(parent: Node, title: String, action: Callable) -> Button:
	var button := _button(parent, title, action)
	button.custom_minimum_size = Vector2(280, 36)
	return button


## Nur im Testlabor: Stufen beliebig hoch/runter, Dots für reproduzierbare Lasttests.
func _build_test_lab(parent: Node) -> void:
	_test_scroll = ScrollContainer.new()
	_test_scroll.custom_minimum_size = Vector2(340, 235)
	_test_scroll.visible = false
	parent.add_child(_test_scroll)
	_test_lab = VBoxContainer.new()
	_test_lab.add_theme_constant_override("separation", 4)
	_test_scroll.add_child(_test_lab)
	_label(_test_lab, "TESTLABOR – OHNE KOSTEN", 12, UiTheme.ACCENT)
	_button(_test_lab, "Außenposten freischalten (Test)", _unlock_outposts)
	_button(_test_lab, "Abfangstationen freischalten (Test)", _unlock_interceptors)
	_button(_test_lab, "+1000 Bauenergie (Test)", _test_construction_energy)
	for item in [
		["Arbeiter-Tempo", Upgrades.KIND_SPEED],
		["Energie-Tempo", Upgrades.KIND_ENERGY_SPEED],
		["Abbau", Upgrades.KIND_DIG],
		["Intelligenz", Upgrades.KIND_SWARM],
		["Kern", Upgrades.KIND_CORE],
		["Forschung", Upgrades.KIND_RESEARCH],
		["Quellenstufe", -1],
		["Veredlerstufe", -2],
	]:
		var row := HBoxContainer.new()
		_test_lab.add_child(row)
		var name := _label(row, str(item[0]), 12, UiTheme.TEXT)
		name.custom_minimum_size.x = 128
		_button(row, "−", _test_change.bind(int(item[1]), -1))
		var value := _label(row, "0", 12, UiTheme.ACCENT)
		value.custom_minimum_size.x = 24
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(row, "+", _test_change.bind(int(item[1]), 1))
		_test_labels.append(value)
		_test_keys.append(int(item[1]))
	var spawns := HBoxContainer.new()
	_test_lab.add_child(spawns)
	_button(spawns, "+100 Dots", _test_spawn.bind(100))
	_button(spawns, "+500 Dots", _test_spawn.bind(500))
	_test_stats = _label(_test_lab, "", 11, UiTheme.MUTED)
	_test_lab.visible = true


func _toggle_test_lab() -> void:
	sim.debug_mode = not sim.debug_mode
	_test_scroll.visible = sim.debug_mode
	_notice("Testlabor aktiv. Teststände werden nicht gespeichert." if sim.debug_mode else "Testlabor beendet. Änderungen bleiben bis zum Neustart und werden nicht gespeichert.")
	_refresh_test_lab()


func _test_change(kind: int, delta: int) -> void:
	var ok := false
	if kind == -1:
		ok = sim.debug_adjust_building(Buildings.KIND_SOURCE, delta)
	elif kind == -2:
		ok = sim.debug_adjust_building(Buildings.KIND_REFINERY, delta)
	else:
		ok = sim.debug_adjust_upgrade(kind, delta)
	if ok and kind == Upgrades.KIND_CORE and renderer != null:
		renderer.set_core_mask(sim.core_mask)
	if not ok:
		_notice("Stufengrenze erreicht oder Änderung nicht möglich.")
	_refresh_test_lab()
	refresh()


func _test_spawn(count: int) -> void:
	var spawned := sim.debug_spawn_workers(count)
	_notice("%d von %d Test-Dots erzeugt." % [spawned, count])
	_refresh_test_lab()
	refresh()


func _refresh_test_lab() -> void:
	if _test_lab == null or sim == null:
		return
	_test_scroll.visible = sim.debug_mode
	if _test_toggle != null:
		_test_toggle.text = "TESTLABOR DEAKTIVIEREN" if sim.debug_mode else "TESTLABOR AKTIVIEREN"
	var u := sim.upgrades
	for i in _test_keys.size():
		var kind := _test_keys[i]
		var level := 0
		match kind:
			Upgrades.KIND_SPEED:
				level = u.speed_level
			Upgrades.KIND_ENERGY_SPEED:
				level = u.energy_speed_level
			Upgrades.KIND_DIG:
				level = u.dig_level
			Upgrades.KIND_SWARM:
				level = u.swarm_level
			Upgrades.KIND_CORE:
				level = u.core_level
			Upgrades.KIND_FUSION2:
				level = 2 if u.fusion3 else 1 if u.fusion2 else 0
			Upgrades.KIND_RESEARCH:
				level = u.research_level
			-1:
				level = sim.buildings.source_level
			-2:
				level = sim.buildings.refinery_level
		_test_labels[i].text = str(level)
	if _test_stats != null:
		_test_stats.text = "Arbeiter: %d | Letzter Tick: %.2f ms | Ziel Ø: %.2f | Bewegung Ø: %.2f | Abbau Ø: %.2f | Such-/Pfadaufträge: %d/%d" % [
			sim.workers.count,
			float(sim.last_tick_usec) / 1000.0,
			float(sim.stage_usec[Simulation.Stage.TARGET_SEARCH]) / maxi(1, sim.profiled_ticks) / 1000.0,
			float(sim.stage_usec[Simulation.Stage.MOVEMENT]) / maxi(1, sim.profiled_ticks) / 1000.0,
			float(sim.stage_usec[Simulation.Stage.MINING]) / maxi(1, sim.profiled_ticks) / 1000.0,
			SwarmMind.seeks_last_tick, SwarmMind.paths_last_tick,
		]

	if _test_stats != null:
		var ledger := sim.energy_dots.ledger()
		_test_stats.text += "\nEnergie: geliefert %d | verfallen %d | Puffer %d | neutral %d | Abfangen %d" % [ledger.delivered, ledger.expired, ledger.buffered, ledger.neutral, ledger.captures]


func _open_pause_menu() -> void:
	if _pause_layer == null:
		return
	if _upgrade_panel != null:
		_upgrade_panel.visible = false
	_pause_layer.visible = true
	_refresh_test_lab()
	if clock != null:
		clock.paused = true


func _close_pause_menu() -> void:
	if _pause_layer != null:
		_pause_layer.visible = false
	if clock != null:
		clock.paused = false


func _set_volume(value: float) -> void:
	var linear := clampf(value / 100.0, 0.0, 1.0)
	var db := -80.0 if linear <= 0.001 else linear_to_db(linear)
	AudioServer.set_bus_volume_db(0, db)


func _notice(message: String) -> void:
	if _message != null:
		_message.text = message


func _production_site() -> int:
	var site: int = sim.construction.selected
	return site if sim.construction.sites.valid(site) and sim.construction.sites.records[site].owner == 0 else -1

func toggle_energy_network() -> void:
	var was_active := _placing_conduit
	_placing_conduit = not was_active
	_demolition_mode = false
	_settlement_kind = -1
	command_mode = Command.BUILD if _placing_conduit else Command.MINE
	_notice("ENERGIENETZ AKTIV · Linke Maustaste halten und Leitungen ziehen · E zum Beenden" if _placing_conduit else "Energienetz beendet · normale Steuerung aktiv")

func toggle_demolition() -> void:
	var was_active := _demolition_mode
	_demolition_mode = not was_active
	_placing_conduit = false
	_settlement_kind = -1
	command_mode = Command.BUILD if _demolition_mode else Command.MINE
	_notice("ABRISS AKTIV · Leitung sofort, Gebäude mit Arbeitern · Q zum Beenden" if _demolition_mode else "Abrissmodus beendet")

func demolition_active() -> bool:
	return _demolition_mode

func energy_network_active() -> bool:
	return _placing_conduit

func demolish_at(cell: int) -> bool:
	if sim == null: return false
	if sim.energy_network.remove(0, cell):
		_notice("Energieleitung sofort entfernt.")
		return true
	var site := sim.construction.at(cell)
	if _match_live() and not sim.fog.is_visible(0, cell) and (site < 0 or sim.construction.sites.records[site].owner != 0): return false
	if site >= 0 and sim.construction.start_demolition(sim, site, 0):
		_notice("Abriss beauftragt: Arbeiter entfernen das Gebäude mit 20 % des Bauaufwands.")
		return true
	_notice("Hier gibt es kein eigenes abreißbares Gebäude oder Netz.")
	return false

func place_energy_network_cell(cell: int) -> bool:
	if not _placing_conduit or sim == null: return false
	if _match_live() and not sim.fog.is_visible(0, cell): return false
	if sim.energy_network.owner_at(cell) == 0: return true
	var placed := sim.place_energy_conduit(cell)
	if placed and renderer != null: renderer.queue_redraw()
	return placed

func _begin_settlement(kind: int) -> void:
	_placing_conduit = false
	_demolition_mode = false
	if kind == 2 and not sim.construction.unlocked(sim, 2):
		_notice("Abfangstationen benötigen Forschung. Im Forschungsbaum freischalten.")
		return
	if kind == 1 and not sim.construction.unlocked(sim, 1):
		_notice("Außenposten benötigen Forschung. Im Forschungsbaum freischalten.")
		return
	if kind == 4 and not sim.construction.unlocked(sim, 4):
		_notice("Kriegstürme benötigen Verteidigungstechnik im Forschungsbaum.")
		return
	if _upgrade_panel != null: _upgrade_panel.visible = false
	_settlement_kind = kind
	command_mode = Command.BUILD
	_notice("Bauplatz anklicken (linke obere Ecke): %d×%d. Freier Boden erforderlich; gewählte Arbeiter bauen." % [5 if kind == 0 else 3, 5 if kind == 0 else 3])

func _unlock_outposts() -> void:
	if not sim.debug_mode: return
	sim.debug_modified = true
	sim.construction.outposts_unlocked = true
	_notice("Außenposten zum Testen freigeschaltet. Dieser Teststand wird nicht regulär gespeichert.")

func _test_construction_energy() -> void:
	if not sim.debug_mode: return
	sim.debug_modified = true
	sim.upgrades.energy += 1000
	refresh()


func _repair_selected() -> void:
	var site: int = _production_site()
	var assigned := sim.construction.assign_repair(sim, site, selection)
	_notice("%d Arbeiter zum Reparieren zugewiesen." % assigned if assigned > 0 else "Eigene Arbeiter und ein beschädigtes fertiges Gebäude auswählen.")
	refresh()

func _cancel_selected() -> void:
	var site: int = _production_site()
	var refund := sim.construction.cancel_refund(site)
	if sim.construction.cancel(sim, site):
		_notice("Baustelle abgebrochen. %d Energie erstattet. Ohne verbleibenden Schutz folgt die Niederlage." % refund)
	else:
		_notice("Nur eigene unfertige Baustellen können abgebrochen werden.")
	refresh()

func _refresh_build_actions() -> void:
	if _research_center_button != null:
		_research_center_button.disabled = sim.upgrades.energy < sim.construction.price(3, 0)
		_research_center_button.tooltip_text = "Forschungszentrum: 3×3, 200 HP, 300 Energie, 300 Arbeitertakte. Von Anfang an baubar; Ein Auftrag pro fertigem Zentrum; Energiezufuhr über Leitungen."
	if _interceptor_button != null:
		_interceptor_button.disabled = not sim.construction.unlocked(sim, 2) or sim.upgrades.energy < 250
		_interceptor_button.tooltip_text = "3×3, 150 HP, 250 Energie, 300 Arbeitertakte. Abfangen am freien Rand; Freischaltung über Energietransport → Abfangstation."
	if _repair_button == null or _cancel_build_button == null: return
	var site: int = _production_site()
	_repair_button.disabled = true
	_cancel_build_button.disabled = true
	_cancel_build_button.text = "BAU ABBRECHEN"
	if not sim.construction.sites.valid(site): return
	var row: Dictionary = sim.construction.sites.records[site]
	_repair_button.disabled = not row.ready or row.hp >= row.max_hp or selection.is_empty()
	_repair_button.tooltip_text = "Ausgewählte eigene Arbeiter reparieren am Gebäuderand: bis zu 2 HP für 1 Energie alle 4 Takte je Arbeiter. Ohne Energie wartet der Auftrag."
	_cancel_build_button.disabled = row.ready
	if not row.ready:
		var refund := sim.construction.cancel_refund(site)
		_cancel_build_button.text = "ABBRUCH +%d" % refund
		_cancel_build_button.tooltip_text = "Unbegonnen und unbeschädigt: Baupreis zurück; sonst keine Erstattung. Abbruch des letzten begonnenen Kerns kann die Niederlage auslösen."


func _unlock_interceptors() -> void:
	if not sim.debug_mode: return
	sim.debug_modified = true
	sim.construction.interceptors_unlocked = true
	_notice("Abfangstationen im Testlabor freigeschaltet. Bau unter Fähigkeiten → Energietransport.")

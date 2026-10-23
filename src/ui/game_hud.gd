class_name GameHud
extends CanvasLayer
## Minimalistische Spieloberfläche. Farbgruppen/Quoten sind interne Simulationsdetails.
## Der Spieler steuert den Schwarm über gemeinsame Befehle und eine Aktionsleiste.

signal load_requested(path: String)
signal restart_requested
signal leave_requested

enum Command { MINE, MOVE, BUILD }

var sim: Simulation
var clock: TickClock
var camera: CameraController
var renderer: WorldRenderer
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
var _volume: HSlider
var _dock_row: HBoxContainer
var selection := PackedInt32Array()
var _buy_worker_button: Button
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
var _size_buttons: Array[Button] = []
var _map: WorldMinimap

var _last_size_style := -1
var _last_mine_area := Rect2i()


func _ready() -> void:
	var layer := Control.new()
	layer.name = "HUD"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)

	_build_stats(layer)
	_build_goals(layer)
	_build_dock(layer)
	_build_upgrade_panel(layer)
	_build_pause_menu(layer)
	_build_minimap(layer)
	refresh()


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
	_set_selection(DotOrder.filter_highest(ids, kinds))


func select_at(cell: int) -> void:
	if sim == null:
		return
	if cell < 0 or cell >= sim.world.cell_count():
		_set_selection(PackedInt32Array())
		return
	var occ := sim.workers.occupant[cell]
	if occ == WorkerStore.NO_WORKER or int(sim.workers.faction[occ]) != 0:
		_set_selection(PackedInt32Array())
		return
	var ids := PackedInt32Array([occ])
	var kinds := PackedByteArray([DotOrder.kind_of(sim, occ)])
	_set_selection(DotOrder.filter_highest(ids, kinds))


## Rechtsklick: die Auswahl, sonst etwa ein Zehntel der nächsten Arbeiter, geht dorthin und gräbt den Weg frei.
func issue_march(cell: int) -> bool:
	if sim == null or cell < 0 or cell >= sim.world.cell_count():
		return false
	var party := _party_for(cell, Rect2i())
	if party.is_empty():
		_notice("Keine Arbeiter in der Nähe.")
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


## Rechtszug: dasselbe Aufgebot erobert das Rechteck und baut alles darin ab.
func issue_conquer(rect: Rect2i) -> bool:
	if sim == null:
		return false
	var clipped := rect.abs().intersection(Rect2i(0, 0, sim.world.width, sim.world.height))
	if not clipped.has_area():
		return false
	var party := _party_for(-1, clipped)
	if party.is_empty():
		_notice("Keine Arbeiter in der Nähe.")
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
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) == 0 and DotOrder.kind_of(sim, id) == DotOrder.KIND_WARRIOR:
			warriors.append(id)
	if warriors.is_empty():
		_notice("Krieger folgen später.")
		return false
	_set_selection(warriors)
	return issue_march(cell)


func issue_build(cell: int) -> bool:
	if sim == null:
		return false
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
	if sim.buy_worker():
		_notice("Arbeiter gekauft. Er startet am Energiekern.")
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
	if sim == null or _mass_value == null:
		return
	var mass := sim.faction_mass(0) if _match_live() else sim.total_mass()
	var energy := sim.upgrades.energy
	var mined := sim.world.mined_fraction()
	var percent := clampi(int(round(mined * 100.0)), 0, 100)
	var transit := sim.energy_dots.pending_owned(0) if _match_live() else sim.energy_dots.pending()

	_mass_value.text = str(mass)
	_energy_value.text = "%d (+%d)" % [energy, transit]
	if _opponent_value != null:
		_opponent_value.visible = _match_live()
		_opponent_value.text = "Gegner  %d" % sim.opponent_mass()
	if _approach != null:
		_approach.text = sim.approach_text
		_approach.visible = not sim.approach_text.is_empty()
	_mined_value.text = "%d %%" % percent
	_kern_value.text = "Stufe %d" % sim.upgrades.core_level
	_mass_bar.value = minf(100.0, float(mass))
	_energy_bar.value = minf(250.0, float(energy))
	_mined_bar.value = float(percent)
	_kern_bar.value = sim.upgrades.core_level

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
	_buy_worker_button.disabled = sim.upgrades.energy < Simulation.WORKER_COST

	_refresh_selection()
	_refresh_upgrades()


func _build_stats(layer: Control) -> void:
	var card := _panel(layer)
	card.position = Vector2(16, 16)
	card.custom_minimum_size = Vector2(270, 0)
	var content := _column(card, 8)
	var title := _label(content, "DOT WARS", 25, UiTheme.ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	var sub := _label(content, "SCHWARMSTATUS", 11, UiTheme.MUTED)
	sub.add_theme_font_size_override("font_size", 11)

	var mass := _stat_row(content, "Masse", UiTheme.ACCENT, 100)
	_mass_value = mass[0]
	_mass_bar = mass[1]
	var energy := _stat_row(content, "Energie", Color8(0x53, 0xC7, 0xFF), 250)
	_energy_value = energy[0]
	_energy_bar = energy[1]
	var mined := _stat_row(content, "Abgebaut", Materials.COLORS[Materials.SOFT], 100)
	_mined_value = mined[0]
	_mined_bar = mined[1]
	var kern := _stat_row(content, "Kern", Materials.PIT_COLOR, Upgrades.CORE_MAX)
	_kern_value = kern[0]
	_kern_bar = kern[1]
	_kern_value.custom_minimum_size.x = 78

	_message = _label(content, _opening_hint(), 12, UiTheme.MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_approach = _label(content, "", 12, UiTheme.ACCENT)
	_approach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_approach.visible = false
	_opponent_value = _label(content, "", 12, Color8(0xFF, 0x7A, 0x59))
	_opponent_value.visible = false


func _build_goals(layer: Control) -> void:
	var card := _panel(layer)
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -332
	card.offset_right = -16
	card.offset_top = 16
	card.offset_bottom = 300
	var content := _column(card, 9)
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


func _build_dock(layer: Control) -> void:
	var bottom := CenterContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -92
	bottom.offset_bottom = -12
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bottom)
	var dock := _panel(bottom)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 7)
	dock.add_child(buttons)
	_dock_row = buttons

	_buy_worker_button = _button(buttons, "ARBEITER +10", _buy_worker)
	_buy_worker_button.tooltip_text = "Kauft einen Arbeiter für 10 Energie. Start am Energiekern."

	_divider(buttons)
	for size in [1, 2, 3]:
		var button := _button(buttons, "%d×%d" % [size, size], set_size_all.bind(size))
		_size_buttons.append(button)

	_divider(buttons)
	var upgrades := _button(buttons, "FÄHIGKEITEN", _toggle_upgrades)
	upgrades.tooltip_text = "Fähigkeiten kaufen. Weitere Zweige bleiben in diesem Fenster."
	_speed_button = _button(buttons, "1×", _cycle_speed)
	_speed_button.tooltip_text = "Wechselt zwischen 1×, 2× und 4×. Escape öffnet das Menü."


func _build_upgrade_panel(layer: Control) -> void:
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 1.0
	center.anchor_top = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = -680
	center.offset_bottom = -94
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	_upgrade_panel = _panel(center)
	_upgrade_panel.custom_minimum_size = Vector2(360, 0)
	var content := _column(_upgrade_panel, 7)
	var head := HBoxContainer.new()
	content.add_child(head)
	var caption := _label(head, "FÄHIGKEITEN", 16, UiTheme.ACCENT)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(head, "SCHLIESSEN", _toggle_upgrades)
	_label(content, "KERN", 12, UiTheme.MUTED)
	_add_upgrade_button(content, Upgrades.KIND_CORE, 0)
	_label(content, "BEWEGUNG", 12, UiTheme.MUTED)
	_add_upgrade_button(content, Upgrades.KIND_SPEED, 0)
	_add_upgrade_button(content, Upgrades.KIND_ENERGY_SPEED, 0)
	_label(content, "SCHWARM", 12, UiTheme.MUTED)
	_add_upgrade_button(content, Upgrades.KIND_DIG, 0)
	_add_upgrade_button(content, Upgrades.KIND_FUSION2, 0)
	_add_upgrade_button(content, Upgrades.KIND_FUSION3, 22)
	_research_caption = _label(content, "FORSCHUNG", 12, UiTheme.MUTED)
	_research_button = _button(content, "FORSCHUNG", func() -> void: _buy(Upgrades.KIND_RESEARCH))
	_research_button.custom_minimum_size = Vector2(310, 34)
	_research_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_caption = _label(content, "BAUEN", 12, UiTheme.MUTED)
	_source_place_button = _build_button(content, _arm_source)
	_source_tier_button = _build_button(content, _raise_source)
	_refinery_place_button = _build_button(content, _arm_refinery)
	_refinery_tier_button = _build_button(content, _raise_refinery)
	_upgrade_panel.visible = false


func _build_minimap(layer: Control) -> void:
	if renderer == null or camera == null:
		return
	var frame := _panel(layer)
	frame.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	frame.offset_left = -201
	frame.offset_right = -16
	frame.offset_top = -318
	frame.offset_bottom = -112
	var content := _column(frame, 5)
	_label(content, "ÜBERSICHT", 12, UiTheme.MUTED)
	_map = WorldMinimap.new()
	_map.custom_minimum_size = Vector2(164, 164)
	_map.world = sim.world
	_map.renderer = renderer
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
	_notice("Spiel gespeichert." if SaveGame.write_file("user://slot.dw", sim) else "Speichern fehlgeschlagen.")


func _toggle_upgrades() -> void:
	_upgrade_panel.visible = not _upgrade_panel.visible


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
		button.disabled = locked or cost < 0 or u.energy < cost
	_refresh_buildings()
	_refresh_research()


func _refresh_goals(mass: int, mined: float) -> void:
	if _goal_names.size() < 3 or _goal_sections.size() < 3:
		return
	if sim.config.mode == SimConfig.MODE_MATCH:
		_refresh_match_goals()
		return
	if _goal_sections.size() > 3:
		_goal_sections[3].visible = false
	var percent := clampi(int(round(mined * 100.0)), 0, 100)
	if sim.config.mode == SimConfig.MODE_EXTRACTION:
		_goal_heading.text = "FÖRDERUNG"
		_show_single_goal("1.000 Energie liefern", sim.energy_dots.delivered, SimConfig.EXTRACTION_GOAL)
		_victory.text = "FÖRDERZIEL ERREICHT – WEITERSPIELEN MÖGLICH"
	elif sim.config.mode == SimConfig.MODE_REFINING:
		_goal_heading.text = "VEREDELUNG"
		_show_single_goal("400 veredelte Energie", sim.energy_dots.refined_delivered, SimConfig.REFINING_GOAL)
		_victory.text = "VEREDLUNG ERREICHT – WEITERSPIELEN MÖGLICH"
	else:
		_goal_heading.text = "RÄUMUNG"
		for section in _goal_sections:
			section.visible = true
		_goal_names[0].text = "100 Masse"
		_goal_names[1].text = "2 Fähigkeiten"
		_goal_names[2].text = "90 % Welt abbauen"
		_goal_mass.max_value = 100.0
		_goal_upgrade.max_value = 2.0
		_goal_mining.max_value = 90.0
		_goal_mass.value = minf(100.0, float(mass))
		_goal_upgrade.value = mini(sim.upgrades.purchased, 2)
		_goal_mining.value = minf(90.0, mined * 100.0)
		_goal_mass_value.text = "%d / 100" % mass
		_goal_upgrade_value.text = "%d / 2" % sim.upgrades.purchased
		_goal_mining_value.text = "%d / 90 %%" % percent
		_victory.text = "WELT EROBERT – WEITERSPIELEN MÖGLICH"


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


func _refresh_research() -> void:
	if _research_button == null or _research_caption == null:
		return
	var show := (
		sim.config.mode == SimConfig.MODE_MATCH
		and (sim.config.victory_mask & MatchRules.VICTORY_RESEARCH) != 0
	)
	_research_caption.visible = show
	_research_button.visible = show
	if not show:
		return
	var cost := sim.upgrades.research_cost()
	if cost < 0:
		_research_button.text = "FORSCHUNG   Stufe %d    VOLL" % sim.upgrades.research_level
		_research_button.disabled = true
	else:
		_research_button.text = "FORSCHUNG   Stufe %d    •    %d Energie" % [sim.upgrades.research_level + 1, cost]
		_research_button.disabled = sim.upgrades.energy < cost


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
		return "Linke Taste wählt. Rechtsklick schickt, ein Rechtszug erobert."
	if sim.config.mode == SimConfig.MODE_MATCH:
		return "Gegen KI (%s). Linke Taste wählt, Rechtsklick schickt, ein Rechtszug erobert." % sim.rules.difficulty_label()
	if sim.config.mode == SimConfig.MODE_EXTRACTION:
		return "Quellen lassen Material nachwachsen. Rechtszug erobert ein Gebiet."
	if sim.config.mode == SimConfig.MODE_REFINING:
		return "Setze den Veredler in eine Ader. Rechtszug erobert ein Gebiet."
	return "Linke Taste wählt. Rechtsklick schickt, ein Rechtszug erobert."


func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var text := ""
	while digits.length() > 3:
		text = "." + digits.substr(digits.length() - 3, 3) + text
		digits = digits.substr(0, digits.length() - 3)
	text = digits + text
	return "-" + text if value < 0 else text


func _refresh_selection() -> void:
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


func _party_for(cell: int, rect: Rect2i) -> PackedInt32Array:
	var chosen := PackedInt32Array()
	for id in selection:
		if id < 0 or id >= sim.workers.count:
			continue
		if int(sim.workers.faction[id]) != 0:
			continue
		chosen.append(id)
	if not chosen.is_empty():
		return chosen
	return DotOrder.nearest_share(sim, 0, cell, rect)


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
	var share := selection.is_empty()
	if route == DigGuidance.ROUTE_MINING:
		return "Die nächsten Arbeiter graben sich den Weg frei." if share else "Die Auswahl gräbt sich den Weg frei."
	if reaches:
		return "Etwa ein Zehntel der nächsten Arbeiter ist unterwegs." if share else "Die Auswahl ist unterwegs."
	return "Der Schwarm geht zum nächstmöglichen Punkt."


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


func _menu_button(parent: Node, title: String, action: Callable) -> void:
	var button := _button(parent, title, action)
	button.custom_minimum_size = Vector2(280, 36)


func _open_pause_menu() -> void:
	if _pause_layer == null:
		return
	if _upgrade_panel != null:
		_upgrade_panel.visible = false
	_pause_layer.visible = true
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

class_name GameHud
extends CanvasLayer
## Minimalistische Spieloberfläche. Farbgruppen/Quoten sind interne Simulationsdetails.
## Der Spieler steuert den Schwarm über gemeinsame Befehle und eine Aktionsleiste.

signal load_requested(path: String)

enum Command { MINE, MOVE }

var sim: Simulation
var clock: TickClock
var camera: CameraController
var renderer: WorldRenderer
var command_mode: int = Command.MINE

var _mass_value: Label
var _energy_value: Label
var _mined_value: Label
var _mass_bar: ProgressBar
var _energy_bar: ProgressBar
var _mined_bar: ProgressBar

var _goal_mass: ProgressBar
var _goal_upgrade: ProgressBar
var _goal_mining: ProgressBar
var _goal_mass_value: Label
var _goal_upgrade_value: Label
var _goal_mining_value: Label
var _victory: Label
var _report: PanelContainer
var _report_labels: Array[Label] = []

var _message: Label
var _mine_button: Button
var _move_button: Button
var _buy_worker_button: Button
var _pause_button: Button
var _speed_button: Button
var _swarm_ids: Array[int] = []
var _swarm_labels: Array[Label] = []
var _upgrade_panel: PanelContainer
var _upgrade_buttons: Array[Button] = []
var _upgrade_kinds: Array[int] = []
var _size_buttons: Array[Button] = []
var _map: WorldMinimap

var _last_mode_style := -1
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
	_build_minimap(layer)
	refresh()


## Für einen Abbauauftrag werden alle nicht opfernden internen Gruppen zusammen eingesetzt.
## Neue Befehle ersetzen ältere Gebiete, um nicht beliebig viele unsichtbare Aufträge anzuhäufen.
func issue_dig_area(rect: Rect2i) -> bool:
	if sim == null:
		return false
	var clipped := rect.abs().intersection(Rect2i(0, 0, sim.world.width, sim.world.height))
	if not clipped.has_area():
		return false
	var issued := false
	for group_id in sim.group_open.size():
		if not _available_for_work(group_id):
			continue
		sim.clear_move_goal(group_id)
		sim.clear_area(group_id)
		issued = sim.assign_area(group_id, clipped) or issued
	if issued:
		_last_mine_area = clipped
		_notice("Abbaugebiet gesetzt.")
	else:
		_notice("Kein aktiver Schwarm für den Abbau.")
	return issued


## Der gemeinsame Laufbefehl ersetzt Abbauziele, Opfergruppen bleiben unberührt.
func issue_move_goal(cell: int) -> bool:
	if sim == null or cell < 0 or cell >= sim.world.cell_count():
		return false
	if sim.world.cells[cell] != Materials.EMPTY:
		_notice("Bewegungsziel muss im Tunnel liegen.")
		return false
	var issued := false
	for group_id in sim.group_open.size():
		if not _available_for_work(group_id):
			continue
		sim.clear_area(group_id)
		issued = sim.set_move_goal(group_id, cell) or issued
	_notice("Sammelpunkt gesetzt." if issued else "Kein aktiver Schwarm verfügbar.")
	return issued


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
	var mass := sim.total_mass()
	var energy := sim.upgrades.energy
	var mined := sim.world.mined_fraction()
	var percent := clampi(int(round(mined * 100.0)), 0, 100)

	_mass_value.text = str(mass)
	_energy_value.text = "%d (+%d)" % [energy, sim.energy_dots.pending()]
	_mined_value.text = "%d %%" % percent
	_mass_bar.value = minf(100.0, float(mass))
	_energy_bar.value = minf(250.0, float(energy))
	_mined_bar.value = float(percent)

	_goal_mass.value = minf(100.0, float(mass))
	_goal_upgrade.value = mini(sim.upgrades.purchased, 2)
	_goal_mining.value = minf(90.0, mined * 100.0)
	_goal_mass_value.text = "%d / 100" % mass
	_goal_upgrade_value.text = "%d / 2" % sim.upgrades.purchased
	_goal_mining_value.text = "%d / 90 %%" % percent
	_victory.visible = sim.won
	if _report != null:
		_report.visible = sim.won
		if sim.won:
			var lines := sim.victory_lines()
			for index in mini(lines.size(), _report_labels.size()):
				_report_labels[index].text = lines[index]
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

	_message = _label(content, "Ziehen markiert den Abbau. Bewegen setzt einen Punkt im Tunnel.", 12, UiTheme.MUTED)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_goals(layer: Control) -> void:
	var card := _panel(layer)
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -332
	card.offset_right = -16
	card.offset_top = 16
	card.offset_bottom = 224
	var content := _column(card, 9)
	_label(content, "MISSIONSZIELE", 16, UiTheme.TEXT)

	var mass := _objective(content, "100 Masse", UiTheme.ACCENT, 100)
	_goal_mass_value = mass[0]
	_goal_mass = mass[1]
	var upgrades := _objective(content, "2 Fähigkeiten", Color8(0x53, 0xC7, 0xFF), 2)
	_goal_upgrade_value = upgrades[0]
	_goal_upgrade = upgrades[1]
	var mining := _objective(content, "90 % Welt abbauen", Materials.COLORS[Materials.SOFT], 90)
	_goal_mining_value = mining[0]
	_goal_mining = mining[1]
	_victory = _label(content, "WELT EROBERT – WEITERSPIELEN MÖGLICH", 12, UiTheme.ACCENT)
	_victory.visible = false
	_build_report(layer)


func _build_report(layer: Control) -> void:
	_report = _panel(layer)
	_report.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_report.offset_left = -332
	_report.offset_right = -16
	_report.offset_top = 232
	_report.offset_bottom = 444
	_report.visible = false
	var content := _column(_report, 4)
	_label(content, "AUSWERTUNG", 16, UiTheme.ACCENT)
	for _index in 7:
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

	_mine_button = _button(buttons, "ABBAU", func() -> void: _set_mode(Command.MINE))
	_mine_button.tooltip_text = "Rechteck auf die Welt ziehen, um Material abzubauen."
	_move_button = _button(buttons, "BEWEGEN", func() -> void: _set_mode(Command.MOVE))
	_move_button.tooltip_text = "Auf einen freien Tunnel klicken, um den Schwarm zu bewegen."
	_buy_worker_button = _button(buttons, "ARBEITER +10", _buy_worker)
	_buy_worker_button.tooltip_text = "Kauft einen Arbeiter für 10 Energie. Start am Energiekern."

	_divider(buttons)
	for size in [1, 2, 3]:
		var button := _button(buttons, "%d×%d" % [size, size], set_size_all.bind(size))
		_size_buttons.append(button)

	_divider(buttons)
	var upgrades := _button(buttons, "FÄHIGKEITEN", _toggle_upgrades)
	upgrades.tooltip_text = "Fähigkeiten kaufen. Weitere Zweige bleiben in diesem Fenster."
	_pause_button = _button(buttons, "PAUSE", _pause_game)
	_pause_button.tooltip_text = "Leertaste pausiert ebenfalls."
	_speed_button = _button(buttons, "1×", _cycle_speed)
	_speed_button.tooltip_text = "Wechselt zwischen 1×, 2× und 4×."
	var save := _button(buttons, "SPEICHERN", _save_game)
	save.tooltip_text = "Alternativ F5."
	var load := _button(buttons, "LADEN", _load_game)
	load.tooltip_text = "Lädt user://slot.dw. Alternativ F9."


func _build_upgrade_panel(layer: Control) -> void:
	var center := CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_right = 1.0
	center.anchor_top = 1.0
	center.anchor_bottom = 1.0
	center.offset_top = -470
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
	_label(content, "SCHWARM", 12, UiTheme.MUTED)
	_add_upgrade_button(content, Upgrades.KIND_SPEED, 0)
	_add_upgrade_button(content, Upgrades.KIND_DIG, 0)
	_add_upgrade_button(content, Upgrades.KIND_FUSION2, 0)
	_add_upgrade_button(content, Upgrades.KIND_FUSION3, 22)
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
	return sim.group_open[group_id] == 1 and (
		sim.quotas[group_id] > 0 or sim.workers.group_mass[group_id] > 0
	)


func _available_for_work(group_id: int) -> bool:
	return _has_presence(group_id)




func _set_mode(next: int) -> void:
	command_mode = next
	_notice("Abbaufläche aufziehen." if next == Command.MINE else "Ziel im Tunnel anklicken.")
	refresh()


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
			_notice("Energiekern erweitert. Arbeiter betreten die Fläche nicht.")
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
				button.text = "TEMPO   Stufe %d    •    %d Energie" % [u.speed_level + 1, cost]
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


func _refresh_selection() -> void:
	if _last_mode_style != command_mode:
		UiTheme.style_button(_mine_button, command_mode == Command.MINE)
		UiTheme.style_button(_move_button, command_mode == Command.MOVE)
		_last_mode_style = command_mode

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


func _notice(message: String) -> void:
	if _message != null:
		_message.text = message

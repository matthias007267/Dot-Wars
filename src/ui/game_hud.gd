class_name GameHud
extends CanvasLayer
## Bedienleiste für Gruppen, Aufträge, Upgrades und den Spielstand.

var sim: Simulation
var clock: TickClock

var _status: Label
var _win: Label
var _groups: VBoxContainer
var _spins: Array[SpinBox] = []
var _message: Label
var _built_groups := -1


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", UiTheme.panel())
	margin.add_child(panel)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 4)
	panel.add_child(root)

	var heading := _label(root, "DOT WARS   /   COMMAND CENTER", 19)
	heading.add_theme_color_override("font_color", UiTheme.ACCENT)
	_label(root, "Linksklick: Ziel   ·   Ziehen: Abbau   ·   1–8: Gruppe   ·   Leertaste: Pause   ·   F11: Vollbild", 13)
	_status = _label(root, "", 16)
	_win = _label(root, "", 18)
	_message = _label(root, "", 14)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	_chip(row, Materials.COLORS[Materials.SOFT], "Weich")
	_chip(row, Materials.COLORS[Materials.MEDIUM], "Mittel")
	_chip(row, Materials.COLORS[Materials.HARD], "Hart")
	_chip(row, Materials.COLORS[Materials.INDESTRUCTIBLE], "Unzerstörbar")
	_chip(row, Materials.PIT_COLOR, "Opferloch")

	_label(root, "BEFEHLE   /   TECHNOLOGIE", 12)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)
	_button(actions, "Quoten setzen", _apply_quotas)
	_button(actions, "Gruppe neu", _add_group)
	_button(actions, "Gruppe löschen", _remove_group)
	_button(actions, "Abbau löschen", _clear_dig)
	_button(actions, "Ziel löschen", _clear_goal)
	_button(actions, "1×", func() -> void: clock.speed = 1)
	_button(actions, "2×", func() -> void: clock.speed = 2)
	_button(actions, "4×", func() -> void: clock.speed = 4)
	_button(actions, "Speichern", func() -> void: _save("user://slot.dw"))
	_button(actions, "Tempo", _buy_speed)
	_button(actions, "Abbau", _buy_dig)
	_button(actions, "2×2", _buy_fusion2)
	_button(actions, "3×3", _buy_fusion3)

	_label(root, "FARBGRUPPEN   /   EINHEITEN", 12)
	_groups = VBoxContainer.new()
	_groups.add_theme_constant_override("separation", 2)
	root.add_child(_groups)
	refresh()


func refresh() -> void:
	if sim == null or _status == null:
		return
	if sim.quotas.size() != _built_groups:
		_rebuild_groups()
	var pause := "Pause" if clock.paused else "%d×" % clock.speed
	var fraction := int(round(sim.world.mined_fraction() * 100.0))
	_status.text = "Masse %d  ·  Einheiten %d  ·  Abbau %d %%  ·  Energie %d  ·  Tick %d  ·  %s" % [
		sim.total_mass(), sim.workers.count, fraction, sim.upgrades.energy, sim.tick_count, pause,
	]
	if sim.won:
		_win.text = "Sieg bei Tick %d  ·  weiter spielen ist möglich  ·  höchste Masse %d  ·  geopfert %d  ·  Upgrades %d" % [
			sim.win_tick, sim.peak_mass, sim.sacrificed_mass, sim.upgrades.purchased,
		]
	else:
		_win.text = "Ziele: Masse 100 (%d), zwei Upgrades (%d), 90 %% Abbau (%d %%)" % [
			sim.total_mass(), sim.upgrades.purchased, fraction,
		]
	for g in _spins.size():
		var row := _groups.get_child(g) as HBoxContainer
		if row == null:
			continue
		var button := row.get_child(0) as Button
		var mass_label := row.get_child(2) as Label
		if sim.group_open[g] == 0:
			row.visible = false
			continue
		row.visible = true
		var mark := "▸ " if g == sim.selected_group else ""
		button.text = "%s%d %s" % [mark, g + 1, sim.group_names[g]]
		button.add_theme_color_override("font_color", sim.group_colors[g])
		mass_label.text = "Masse %d  Größe %d  %s" % [
			sim.workers.group_mass[g],
			int(sim.desired_size[g]),
			"opfert" if sim.sacrifice_on[g] == 1 else "",
		]


func _rebuild_groups() -> void:
	for child in _groups.get_children():
		_groups.remove_child(child)
		child.free()
	_spins.clear()
	for g in sim.quotas.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_groups.add_child(row)
		var select := Button.new()
		select.custom_minimum_size = Vector2(160, 0)
		select.pressed.connect(_select.bind(g))
		UiTheme.style_button(select)
		row.add_child(select)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 100
		spin.value = sim.quotas[g]
		spin.custom_minimum_size = Vector2(90, 0)
		row.add_child(spin)
		UiTheme.style_line(spin.get_line_edit())
		_spins.append(spin)
		_label(row, "", 14)
		_button(row, "1", _set_size.bind(g, 1))
		_button(row, "2", _set_size.bind(g, 2))
		_button(row, "3", _set_size.bind(g, 3))
		_button(row, "Opfer", _toggle_sacrifice.bind(g))
	_built_groups = sim.quotas.size()


func _apply_quotas() -> void:
	var next := PackedInt32Array()
	var sum := 0
	for g in _spins.size():
		var value := int(_spins[g].value) if sim.group_open[g] == 1 else 0
		next.append(value)
		sum += value
	if not sim.set_quotas(next):
		_message.text = "Quoten müssen zusammen 100 ergeben, derzeit %d. Nichts geändert." % sum
		return
	_message.text = "Quoten gesetzt."


func _add_group() -> void:
	var id := sim.add_group("")
	if id < 0:
		_message.text = "Höchstens %d Gruppen." % SimConfig.MAX_GROUPS
		return
	sim.selected_group = id
	_built_groups = -1
	_message.text = "Gruppe %d angelegt, Quote 0." % [id + 1]
	refresh()


func _remove_group() -> void:
	if sim.remove_group(sim.selected_group):
		_built_groups = -1
		_message.text = "Gruppe geschlossen. Arbeiter und Quote bleiben erhalten."
		refresh()
	else:
		_message.text = "Die letzte Gruppe bleibt."


func _clear_dig() -> void:
	sim.clear_area(sim.selected_group)
	_message.text = "Abbaugebiet gelöscht."


func _clear_goal() -> void:
	sim.clear_move_goal(sim.selected_group)
	_message.text = "Laufziel gelöscht."


func _select(group_id: int) -> void:
	if sim.group_open[group_id] == 1:
		sim.selected_group = group_id


func _set_size(group_id: int, unit_size: int) -> void:
	if sim.set_desired_size(group_id, unit_size):
		_message.text = "Wunschgröße %d." % unit_size
	else:
		_message.text = "Diese Größe ist noch nicht freigeschaltet."


func _toggle_sacrifice(group_id: int) -> void:
	var enable := sim.sacrifice_on[group_id] == 0
	if sim.set_sacrifice(group_id, enable):
		_message.text = "Opferauftrag %s." % ("an" if enable else "aus")
	else:
		_message.text = "Kein erreichbares Opferloch."


func _buy_speed() -> void:
	_buy(Upgrades.KIND_SPEED, "Tempo %d, nächste Kosten %d" % [sim.upgrades.speed_level, sim.upgrades.speed_cost()])


func _buy_dig() -> void:
	_buy(Upgrades.KIND_DIG, "Abbau verbessert, nächste Kosten %d" % sim.upgrades.dig_cost())


func _buy_fusion2() -> void:
	_buy(Upgrades.KIND_FUSION2, "2×2 freigeschaltet.")


func _buy_fusion3() -> void:
	_buy(Upgrades.KIND_FUSION3, "3×3 freigeschaltet.")


func _buy(kind: int, success: String) -> void:
	if sim.buy(kind):
		_message.text = success
	else:
		_message.text = "Kauf abgelehnt. Energie %d." % sim.upgrades.energy


func _save(path: String) -> void:
	if SaveGame.write_file(path, sim):
		_message.text = "Gespeichert."
	else:
		_message.text = "Speichern fehlgeschlagen."


func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	UiTheme.style_button(button)
	parent.add_child(button)
	return button


func _chip(parent: Node, color: Color, title: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(12, 12)
	chip.color = color
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	_label(row, title, 14)

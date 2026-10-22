class_name MainMenu
extends CanvasLayer
## Startmenü. Zuerst Einzelspieler oder Mehrspieler, danach nur die passenden Einstellungen.

signal start_requested(config: SimConfig)
signal load_requested(path: String)

var _seed := LineEdit.new()
var _size := 256
var _multi := false
var _mode := SimConfig.MODE_CLEARING
var _ai := 1
var _mask := MatchRules.VICTORY_ALL
var _difficulty := SimConfig.DIFFICULTY_NORMAL
var _solo_box: VBoxContainer
var _match_box: VBoxContainer
var _mode_hint: Label
var _match_hint: Label


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Materials.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title := Label.new()
	title.text = "DOT WARS"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Baue die Welt ab. Vergrößere deinen Schwarm. Investiere Energie."
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var sides := HBoxContainer.new()
	sides.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(sides)
	var side_buttons: Array[Button] = []
	for index in 2:
		var button := Button.new()
		button.text = "Einzelspieler" if index == 0 else "Mehrspieler"
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(180, 40)
		button.pressed.connect(_select_side.bind(index == 1, button))
		sides.add_child(button)
		side_buttons.append(button)
	_select_side(false, side_buttons[0])

	_solo_box = VBoxContainer.new()
	_solo_box.add_theme_constant_override("separation", 8)
	box.add_child(_solo_box)
	_solo_box.add_child(_caption("Modus"))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	_solo_box.add_child(modes)
	var mode_buttons: Array[Button] = []
	var mode_values := [SimConfig.MODE_CLEARING, SimConfig.MODE_EXTRACTION, SimConfig.MODE_REFINING]
	var mode_names := ["Räumung", "Förderung", "Veredelung"]
	for index in mode_values.size():
		var button := Button.new()
		button.text = mode_names[index]
		button.toggle_mode = true
		button.pressed.connect(_select_mode.bind(mode_values[index], button))
		modes.add_child(button)
		mode_buttons.append(button)
	_mode_hint = Label.new()
	_mode_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	_mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_solo_box.add_child(_mode_hint)
	_select_mode(SimConfig.MODE_CLEARING, mode_buttons[0])

	_match_box = VBoxContainer.new()
	_match_box.add_theme_constant_override("separation", 8)
	box.add_child(_match_box)
	_match_box.add_child(_caption("Ziele"))
	var victory_row := HBoxContainer.new()
	victory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_box.add_child(victory_row)
	var victory_bits := [
		MatchRules.VICTORY_ELIMINATION, MatchRules.VICTORY_RESEARCH, MatchRules.VICTORY_RELICS, MatchRules.VICTORY_HILL,
	]
	var victory_names := ["Auslöschen", "Forschung", "Reliquien", "Hügel"]
	for index in victory_bits.size():
		var victory := Button.new()
		victory.text = victory_names[index]
		victory.toggle_mode = true
		victory.button_pressed = true
		victory.pressed.connect(_toggle_victory.bind(victory_bits[index], victory))
		UiTheme.style_button(victory, true)
		victory_row.add_child(victory)
	_match_box.add_child(_caption("Schwierigkeit"))
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_box.add_child(diff_row)
	var diff_buttons: Array[Button] = []
	var diff_values := [
		SimConfig.DIFFICULTY_EASY, SimConfig.DIFFICULTY_NORMAL, SimConfig.DIFFICULTY_HARD, SimConfig.DIFFICULTY_MIXED,
	]
	var diff_names := ["Leicht", "Mittel", "Schwer", "Gemischt"]
	for index in diff_values.size():
		var diff := Button.new()
		diff.text = diff_names[index]
		diff.toggle_mode = true
		diff.pressed.connect(_select_difficulty.bind(diff_values[index], diff))
		diff_row.add_child(diff)
		diff_buttons.append(diff)
	_select_difficulty(SimConfig.DIFFICULTY_NORMAL, diff_buttons[1])
	_match_box.add_child(_caption("Teilnehmer"))
	var people := Label.new()
	people.text = "Du · 1 Spieler"
	people.add_theme_color_override("font_color", UiTheme.TEXT)
	people.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_box.add_child(people)
	var ai_row := HBoxContainer.new()
	ai_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_box.add_child(ai_row)
	var ai_buttons: Array[Button] = []
	for count in [1, 2, 3]:
		var ai_button := Button.new()
		ai_button.text = "%d KI" % count
		ai_button.toggle_mode = true
		ai_button.pressed.connect(_select_ai.bind(count, ai_button))
		ai_row.add_child(ai_button)
		ai_buttons.append(ai_button)
	_select_ai(1, ai_buttons[0])
	_match_hint = Label.new()
	_match_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	_match_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_box.add_child(_match_hint)
	_apply_match_hint()
	_match_box.visible = false

	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(size_row)
	var size_label := Label.new()
	size_label.text = "Weltgröße"
	size_label.add_theme_color_override("font_color", UiTheme.MUTED)
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_row.add_child(size_label)
	var selected: Button
	for value in [256, 500, 1000]:
		var button := Button.new()
		button.text = str(value)
		button.toggle_mode = true
		button.pressed.connect(_select_size.bind(value, button))
		size_row.add_child(button)
		if value == 256:
			selected = button
	_select_size(256, selected)

	_seed.placeholder_text = "Seed"
	_seed.text = "1337"
	_seed.custom_minimum_size = Vector2(220, 0)
	_seed.alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.style_line(_seed)
	box.add_child(_seed)

	var play := Button.new()
	play.text = "Neues Spiel"
	play.pressed.connect(_play)
	UiTheme.style_button(play, true)
	box.add_child(play)

	var load := Button.new()
	load.text = "Spielstand laden"
	load.pressed.connect(_load)
	UiTheme.style_button(load)
	box.add_child(load)


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _select_side(multi: bool, button: Button) -> void:
	_multi = multi
	for child in button.get_parent().get_children():
		if child is Button:
			var selected := child == button
			child.button_pressed = selected
			UiTheme.style_button(child, selected)
	if _solo_box != null:
		_solo_box.visible = not multi
	if _match_box != null:
		_match_box.visible = multi


func _select_size(value: int, button: Button) -> void:
	_size = value
	for child in button.get_parent().get_children():
		if child is Button:
			var selected := child == button
			child.button_pressed = selected
			UiTheme.style_button(child, selected)


func _select_mode(value: int, button: Button) -> void:
	_mode = value
	for child in button.get_parent().get_children():
		if child is Button:
			var selected := child == button
			child.button_pressed = selected
			UiTheme.style_button(child, selected)
	_apply_mode_hint()


func _apply_mode_hint() -> void:
	if _mode_hint == null:
		return
	if _mode == SimConfig.MODE_EXTRACTION:
		_mode_hint.text = "Liefere 1.000 Energie. Quellen lassen Material nachwachsen."
	elif _mode == SimConfig.MODE_REFINING:
		_mode_hint.text = "Liefere 400 veredelte Energie durch einen Veredler."
	else:
		_mode_hint.text = "Masse 100, zwei Fähigkeiten und 90 % der Welt."


func _select_ai(count: int, button: Button) -> void:
	_ai = count
	for child in button.get_parent().get_children():
		if child is Button:
			var selected := child == button
			child.button_pressed = selected
			UiTheme.style_button(child, selected)
	_apply_match_hint()


func _select_difficulty(level: int, button: Button) -> void:
	_difficulty = level
	for child in button.get_parent().get_children():
		if child is Button:
			var selected := child == button
			child.button_pressed = selected
			UiTheme.style_button(child, selected)
	_apply_match_hint()


func _apply_match_hint() -> void:
	if _match_hint == null:
		return
	if _difficulty == SimConfig.DIFFICULTY_MIXED and _ai <= 1:
		_match_hint.text = "Eine KI gilt als Mittel. Andere Spieler folgen später."
	elif _difficulty == SimConfig.DIFFICULTY_MIXED:
		_match_hint.text = "Jede KI bekommt eine andere Schwierigkeit. Andere Spieler folgen später."
	elif _difficulty == SimConfig.DIFFICULTY_EASY:
		_match_hint.text = "Die KI bleibt an der Basis. Andere Spieler folgen später."
	elif _difficulty == SimConfig.DIFFICULTY_HARD:
		_match_hint.text = "Die KI gräbt auf das Ziel zu. Andere Spieler folgen später."
	else:
		_match_hint.text = "Die KI gräbt die Karte. Andere Spieler folgen später."


func _toggle_victory(bit: int, button: Button) -> void:
	var next := _mask ^ bit
	if (next & MatchRules.VICTORY_ALL) == 0:
		button.button_pressed = true
		UiTheme.style_button(button, true)
		return
	_mask = next
	var selected := (_mask & bit) != 0
	button.button_pressed = selected
	UiTheme.style_button(button, selected)


func _play() -> void:
	var config := SimConfig.new()
	config.world_size = _size
	config.world_seed = int(_seed.text) if _seed.text.is_valid_int() else 1337
	config.mode = SimConfig.MODE_MATCH if _multi else _mode
	config.ai_count = _ai if _multi else 0
	config.victory_mask = _mask if _multi else MatchRules.VICTORY_ALL
	config.difficulty = _difficulty if _multi else SimConfig.DIFFICULTY_NORMAL
	config.group_quotas = PackedInt32Array([40, 30, 30])
	var errors := config.validate()
	if not errors.is_empty():
		_seed.placeholder_text = errors[0]
		return
	start_requested.emit(config)


func _load() -> void:
	var path := "user://slot.dw"
	if not FileAccess.file_exists(path):
		path = "user://autosave.dw"
	if FileAccess.file_exists(path):
		load_requested.emit(path)

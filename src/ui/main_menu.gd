class_name MainMenu
extends CanvasLayer
## Startmenü. Größe und Seed bleiben in der Konfiguration nachprüfbar.

signal start_requested(config: SimConfig)
signal load_requested(path: String)

var _seed := LineEdit.new()
var _size := 256
var _mode := SimConfig.MODE_CLEARING
var _ai := 1
var _mask := MatchRules.VICTORY_ALL
var _mode_hint: Label
var _match_box: VBoxContainer


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

	var sizes := HBoxContainer.new()
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(sizes)
	var selected: Button
	for value in [256, 500, 1000]:
		var button := Button.new()
		button.text = str(value)
		button.toggle_mode = true
		button.pressed.connect(_select_size.bind(value, button))
		sizes.add_child(button)
		if value == 256:
			selected = button
	_select_size(256, selected)

	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(modes)
	var mode_buttons: Array[Button] = []
	var mode_values := [SimConfig.MODE_CLEARING, SimConfig.MODE_EXTRACTION, SimConfig.MODE_REFINING, SimConfig.MODE_MATCH]
	var mode_names := ["Räumung", "Förderung", "Veredelung", "Mehrspieler"]
	for index in mode_values.size():
		var button := Button.new()
		button.text = mode_names[index]
		button.toggle_mode = true
		button.pressed.connect(_select_mode.bind(mode_values[index], button))
		modes.add_child(button)
		mode_buttons.append(button)
	_select_mode(SimConfig.MODE_CLEARING, mode_buttons[0])

	_mode_hint = Label.new()
	_mode_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	_mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_mode_hint)
	_apply_mode_hint()

	_match_box = VBoxContainer.new()
	_match_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_box.add_theme_constant_override("separation", 8)
	box.add_child(_match_box)
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
	var later := Label.new()
	later.text = "Vorläufig nur gegen KI. Andere Spieler folgen später."
	later.add_theme_color_override("font_color", UiTheme.MUTED)
	later.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_box.add_child(later)
	_match_box.visible = false

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

	var note := Label.new()
	note.text = "Der Modus bestimmt das Ziel. Fähigkeiten und Gebäude bleiben im Fenster."
	note.add_theme_color_override("font_color", UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)


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
	if _match_box != null:
		_match_box.visible = _mode == SimConfig.MODE_MATCH
	if _mode == SimConfig.MODE_EXTRACTION:
		_mode_hint.text = "Liefere 1.000 Energie. Quellen lassen Material nachwachsen."
	elif _mode == SimConfig.MODE_REFINING:
		_mode_hint.text = "Liefere 400 veredelte Energie durch einen Veredler."
	elif _mode == SimConfig.MODE_MATCH:
		_mode_hint.text = "Gegen KI. Mindestens ein Ziel: Auslöschen, Forschung, Reliquien oder Hügel."
	else:
		_mode_hint.text = "Masse 100, zwei Fähigkeiten und 90 % der Welt."


func _select_ai(count: int, button: Button) -> void:
	_ai = count
	for child in button.get_parent().get_children():
		if child is Button:
			var selected := child == button
			child.button_pressed = selected
			UiTheme.style_button(child, selected)


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
	config.mode = _mode
	config.ai_count = _ai if _mode == SimConfig.MODE_MATCH else 0
	config.victory_mask = _mask if _mode == SimConfig.MODE_MATCH else MatchRules.VICTORY_ALL
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

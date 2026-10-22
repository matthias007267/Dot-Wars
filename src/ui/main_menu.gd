class_name MainMenu
extends CanvasLayer
## Startmenü. Größe und Seed bleiben in der Konfiguration nachprüfbar.

signal start_requested(config: SimConfig)
signal load_requested(path: String)

var _seed := LineEdit.new()
var _size := 256
var _mode := SimConfig.MODE_CLEARING
var _mode_hint: Label


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
	var mode_values := [SimConfig.MODE_CLEARING, SimConfig.MODE_EXTRACTION, SimConfig.MODE_REFINING]
	var mode_names := ["Räumung", "Förderung", "Veredelung"]
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
	if _mode == SimConfig.MODE_EXTRACTION:
		_mode_hint.text = "Liefere 1.000 Energie. Quellen lassen Material nachwachsen."
	elif _mode == SimConfig.MODE_REFINING:
		_mode_hint.text = "Liefere 400 veredelte Energie durch einen Veredler."
	else:
		_mode_hint.text = "Masse 100, zwei Fähigkeiten und 90 % der Welt."


func _play() -> void:
	var config := SimConfig.new()
	config.world_size = _size
	config.world_seed = int(_seed.text) if _seed.text.is_valid_int() else 1337
	config.mode = _mode
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

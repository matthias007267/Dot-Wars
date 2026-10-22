class_name UiTheme
extends RefCounted
## Dunkle Fläche, helle Schrift, kaum Farbe. Die Akzente bleiben den Dots vorbehalten.

const TEXT := Color8(0xE7, 0xEE, 0xF5)
const MUTED := Color8(0x9A, 0xA7, 0xB5)
const PANEL := Color8(0x13, 0x19, 0x21)
const PANEL_HOVER := Color8(0x24, 0x30, 0x3B)
const PANEL_PRESSED := Color8(0x2C, 0x38, 0x48)
const LINE := Color8(0x2A, 0x34, 0x42)
const ACCENT := Color8(0xFF, 0xE4, 0x5E)


static func style_button(button: Button, accent: bool = false) -> void:
	var normal := _box(PANEL, ACCENT if accent else LINE)
	var hover := _box(PANEL_HOVER, ACCENT if accent else LINE)
	var pressed := _box(PANEL_PRESSED, ACCENT)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", ACCENT if accent else TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", ACCENT)
	button.add_theme_color_override("font_focus_color", TEXT)


static func style_line(edit: LineEdit) -> void:
	var box := _box(PANEL, LINE)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", _box(PANEL, ACCENT))
	edit.add_theme_color_override("font_color", TEXT)
	edit.add_theme_color_override("font_placeholder_color", MUTED)
	edit.add_theme_color_override("caret_color", TEXT)


static func panel() -> StyleBoxFlat:
	var box := _box(Color(Materials.BACKDROP, 0.94), LINE)
	box.set_corner_radius_all(9)
	box.shadow_color = Color(0, 0, 0, 0.30)
	box.shadow_size = 7
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	return box


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_top = 3
	box.content_margin_right = 8
	box.content_margin_bottom = 3
	box.set_corner_radius_all(5)
	return box


## Einheitliche, dezente Fortschrittsbalken für Status und Missionsziele.
static func style_progress(bar: ProgressBar, fill: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = PANEL_HOVER
	track.set_corner_radius_all(4)
	var progress := StyleBoxFlat.new()
	progress.bg_color = fill
	progress.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", progress)

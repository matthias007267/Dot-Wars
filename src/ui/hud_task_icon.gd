class_name HudTaskIcon
extends Button
## One icon per own task/group, with a progress line and optional count badge.
var job: Dictionary = {}
var _progress: ProgressBar
var _badge: Label

func _init() -> void:
	custom_minimum_size = Vector2(44, 44)
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", 26)
	UiTheme.style_button(self)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_progress.offset_left = 4
	_progress.offset_right = -4
	_progress.offset_top = -5
	_progress.offset_bottom = -2
	UiTheme.style_progress(_progress, UiTheme.ACCENT)
	add_child(_progress)
	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_font_size_override("font_size", 11)
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -27
	_badge.offset_right = -3
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_badge)

func update_job(value: Dictionary) -> void:
	var changed := job.is_empty() or bool(job.get("waiting", false)) != bool(value.waiting)
	job = value
	icon = TacticalArt.icon(str(job.icon))
	tooltip_text = str(job.detail)
	_progress.value = clampf(float(job.progress), 0.0, 1.0)
	if changed: UiTheme.style_progress(_progress, Color("e6ad56") if job.waiting else UiTheme.ACCENT)
	_badge.text = str(job.count) if int(job.count) > 1 else ""

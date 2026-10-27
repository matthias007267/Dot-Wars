class_name ResearchTreeView
extends Control
## A small retained graph, no simulation ownership. Locked nodes remain inspectable.
signal start_requested(tech: String)
const BRANCHES := ["Wirtschaft", "Infrastruktur", "Energietechnik", "Militär"]
const COLORS := [Color("78dca3"), Color("ffe45e"), Color("68d8ee"), Color("f3909e")]
var sim: Simulation
var site := -1
var selected := "dig"
var board: Control
var buttons: Dictionary = {}
var positions: Dictionary = {}
var detail: Label
var start_button: Button
var zoom := 1.0
var pan := Vector2(12, 12)
var _dragging := false

func _init() -> void:
	custom_minimum_size = Vector2(840, 430)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	var counts := [0, 0, 0, 0]
	for branch in BRANCHES.size():
		var title := Label.new()
		title.text = BRANCHES[branch].to_upper()
		title.position = Vector2(branch * 230, 0)
		title.add_theme_color_override("font_color", COLORS[branch])
		board.add_child(title)
	for tech in ResearchSystem.CATALOG:
		var entry: Dictionary = ResearchSystem.CATALOG[tech]
		var branch := BRANCHES.find(entry.branch)
		var button := Button.new()
		button.position = Vector2(branch * 230, 40 + counts[branch] * 112)
		button.size = Vector2(208, 86)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		UiTheme.style_button(button)
		button.add_theme_color_override("font_color", COLORS[branch])
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(select_tech.bind(str(tech)))
		board.add_child(button)
		buttons[tech] = button
		positions[tech] = button.position
		counts[branch] += 1
	board.position = pan
	gui_input.connect(_on_input)

func select_tech(tech: String) -> void:
	selected = tech
	refresh(sim, site)

func available(tech: String) -> bool:
	return sim != null and sim.research.can_start(sim, 0, site, tech)

func refresh(p_sim: Simulation, p_site: int) -> void:
	sim = p_sim
	site = p_site
	if sim == null: return
	for tech in buttons:
		var entry: Dictionary = ResearchSystem.CATALOG[tech]
		var level := sim.research.level(0, tech)
		var cost := sim.research.details(tech, level + 1, 0)
		var status := "ABGESCHLOSSEN" if cost.is_empty() else "%.1f s · %d Energie einmalig" % [int(cost.ticks) / 20.0, int(cost.energy)]
		var missing: Array[String] = []
		for dep in entry.requires:
			if sim.research.level(0, dep) == 0: missing.append(ResearchSystem.CATALOG[dep].label)
		if not missing.is_empty(): status = "Benötigt: " + ", ".join(missing)
		for job in sim.research.jobs:
			if job.faction == 0 and job.tech == tech:
				status = "FORSCHUNG %d %% · %.1f s · %d bezahlt" % [roundi(100.0 * job.elapsed / job.ticks), (job.ticks - job.elapsed) / 20.0, job.paid]
				if not sim.research.running(sim, job): status += " · PAUSIERT"
		var button: Button = buttons[tech]
		button.text = "%s [%d/%d]\n%s" % [entry.label, level, entry.max, status]
		button.tooltip_text = status + " · Klicken für Details"
		button.visible = tech != "victory" or (sim.config.victory_mask & MatchRules.VICTORY_RESEARCH) != 0
		button.modulate = Color.WHITE if available(tech) or level > 0 else Color(0.65, 0.7, 0.75)
		UiTheme.style_button(button, tech == selected)
	if detail != null:
		var text: String = buttons[selected].text if buttons.has(selected) else "Technologie wählen"
		text += "\nZentrum #%d · Kosten werden beim Start vollständig bezahlt." % site if site >= 0 else "\nEigenes fertiges Forschungszentrum auf der Karte wählen."
		for job in sim.research.jobs:
			if job.faction == 0:
				text += "\n#%d %s: %.1f s verbleibend" % [job.site, ResearchSystem.CATALOG[job.tech].label, (job.ticks - job.elapsed) / 20.0]
		detail.text = text
	if start_button != null:
		start_button.disabled = not available(selected)
		start_button.text = "FORSCHUNG STARTEN" if available(selected) else "GESPERRT / ZENTRUM BELEGT"
	queue_redraw()

func set_zoom(value: float, anchor := Vector2(400, 180)) -> void:
	var next := clampf(value, 0.55, 1.6)
	pan = anchor - (anchor - pan) * (next / zoom)
	zoom = next
	board.scale = Vector2.ONE * zoom
	board.position = pan
	queue_redraw()

func reset_view() -> void:
	zoom = minf(1.0, maxf(0.55, (size.x - 24.0) / 920.0))
	pan = Vector2(12, 12)
	board.position = pan
	board.scale = Vector2.ONE * zoom
	queue_redraw()

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: _dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: set_zoom(zoom * 1.1, event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: set_zoom(zoom / 1.1, event.position)
		accept_event()
	if event is InputEventMouseMotion and _dragging:
		pan += event.relative
		board.position = pan
		queue_redraw()
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1019"))
	for tech in positions:
		if not buttons[tech].visible: continue
		var entry: Dictionary = ResearchSystem.CATALOG[tech]
		for dep in entry.requires:
			if not positions.has(dep): continue
			var a: Vector2 = pan + (positions[dep] + Vector2(104, 86)) * zoom
			var b: Vector2 = pan + (positions[tech] + Vector2(104, 0)) * zoom
			var color: Color = COLORS[BRANCHES.find(entry.branch)]
			if sim == null or sim.research.level(0, dep) < 1: color = Color("3c4655")
			var points := PackedVector2Array([a, b])
			if b.y - a.y > 60.0 * zoom:
				var side := a.x + 114.0 * zoom
				points = PackedVector2Array([a, a + Vector2(0, 10) * zoom, Vector2(side, a.y + 10 * zoom), Vector2(side, b.y - 10 * zoom), b - Vector2(0, 10) * zoom, b])
			draw_polyline(points, color, 2.0)
			draw_colored_polygon(PackedVector2Array([b, b + Vector2(-4, -6), b + Vector2(4, -6)]), color)

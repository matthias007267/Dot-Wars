extends Control
## Minimale Hauptszene der Projektgrundlage.
## Sie prüft Konfiguration und Simulation beim Start und zeigt den Stand.
## Weltgrafik, Kamera und Steuerung gehören zu späteren Phasen.

func _ready() -> void:
	var config := SimConfig.from_cmdline(OS.get_cmdline_user_args())
	var errors := config.validate()
	if not errors.is_empty():
		push_error("Konfiguration ungültig: " + ", ".join(errors))
		get_tree().quit(1)
		return
	var sim := Simulation.create(config)
	var invariant_errors := PackedStringArray() if sim == null else sim.check_invariants()
	if sim == null or not invariant_errors.is_empty():
		push_error("Startprüfung fehlgeschlagen: " + ", ".join(invariant_errors))
		get_tree().quit(1)
		return
	print(
		"DOT WARS bereit: %dx%d Seed %d Arbeiter %d"
		% [sim.world.width, sim.world.height, sim.config.world_seed, sim.workers.count]
	)
	_build_screen(sim)


func _build_screen(sim: Simulation) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 48)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_label(box, "DOT WARS", 46, Color(0.93, 0.95, 0.9))
	_label(box, "Phase 1 — Projektgrundlage", 22, Color(0.62, 0.78, 0.55))
	_label(
		box,
		"Die Simulation ist headless geprüft. Darstellung der Welt, Kamera und Aufträge folgen in späteren Phasen.",
		18,
		Color(0.78, 0.8, 0.76),
	)
	_label(box, _status_text(sim), 18, Color(0.9, 0.91, 0.88))


func _status_text(sim: Simulation) -> String:
	var config := sim.config
	return "\n".join([
		"Welt %d × %d, Seed %d" % [sim.world.width, sim.world.height, config.world_seed],
		"Startarbeiter %d, alle auf freien Zellen" % sim.workers.count,
		"Simulationstakt %d Hz" % SimConfig.TICKS_PER_SECOND,
		"Abbau: Härte 1 = %.0f s, Härte 3 = %.0f s, Härte 8 = %.0f s" % [
			config.seconds_for_hardness(1),
			config.seconds_for_hardness(3),
			config.seconds_for_hardness(8),
		],
		"Masse %d, Invarianten erfüllt" % sim.total_mass(),
		"",
		"Start mit anderer Welt: godot --path . -- --size=64 --seed=7",
		"Tests: godot --headless --path . -s tests/run_tests.gd",
	])


func _label(parent: Node, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

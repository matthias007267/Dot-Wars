class_name OrderOverlay
extends Node2D
## Zeichnet Abbaugebiete und Sammelpunkte. Keine Node pro Zelle.

var sim: Simulation


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var areas := {}
	var goals := {}
	for group_id in sim.group_open.size():
		if sim.group_open[group_id] == 0:
			continue
		var sacrificing := sim.sacrifice_on[group_id] == 1
		if not sacrificing:
			var rects: Array[Rect2i] = sim.areas.rects[group_id]
			for rect in rects:
				areas[rect] = true
		var goal := sim.move_goal(group_id)
		if goal >= 0:
			goals[goal] = sim.group_colors[group_id] if sacrificing else UiTheme.ACCENT
	var outline := Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.95)
	for rect in areas:
		draw_rect(Rect2(rect.position, rect.size), outline, false, 2.0)
	var width := sim.world.width
	for cell in goals:
		var tint: Color = goals[cell]
		tint.a = 0.72
		draw_rect(Rect2(cell % width, cell / width, 1, 1), tint, true)

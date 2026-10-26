class_name OrderOverlay
extends Node2D
## Zeichnet Abbaugebiete und Sammelpunkte. Keine Node pro Zelle.

var sim: Simulation
var drag_rect := Rect2i()
var drag_active := false
var drag_conquer := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var width := sim.world.width
	var height := sim.world.height
	for group_id in sim.group_open.size():
		if sim.group_open[group_id] == 0:
			continue
		var faction := _faction_of(group_id)
		if sim._match_live() and faction != 0: continue
		var color := _faction_color(faction)
		if sim.sacrifice_on[group_id] == 0:
			var rects: Array[Rect2i] = sim.areas.rects[group_id]
			for rect in rects:
				if rect.size.x >= width and rect.size.y >= height:
					continue
				var outline := color
				outline.a = 0.95 if faction == 0 else 0.8
				draw_rect(Rect2(rect.position, rect.size), outline, false, 0.16 if faction == 0 else 0.1)
		var goal := sim.move_goal(group_id)
		if goal >= 0:
			var tint := color
			tint.a = 0.72
			draw_rect(Rect2(goal % width, goal / width, 1, 1), tint, true)
	_draw_selection(width)
	if drag_active and drag_rect.has_area():
		var tone := Color(1, 0.89, 0.37, 0.9) if drag_conquer else Color(1, 1, 1, 0.85)
		draw_rect(Rect2(drag_rect.position, drag_rect.size), tone, false, 0.12)
	_draw_sites()
	if sim.construction.sites.records.is_empty(): _draw_bases(width)


func _draw_selection(width: int) -> void:
	for id in sim.picked:
		var cell := sim.unit_cell(id)
		if cell < 0 or (sim._match_live() and not sim.fog.is_visible(0, cell)): continue
		var unit := 1
		draw_rect(Rect2(cell % width, cell / width, unit, unit), Color(1, 1, 1, 0.95), false, 0.14)


func _faction_of(group_id: int) -> int:
	if sim.rules.group_faction.size() <= group_id:
		return 0
	return int(sim.rules.group_faction[group_id])


func _faction_color(faction: int) -> Color:
	if faction > 0 and faction < MatchRules.FACTION_COLORS.size():
		return MatchRules.FACTION_COLORS[faction]
	return UiTheme.ACCENT


func _draw_bases(width: int) -> void:
	if sim.config.mode != SimConfig.MODE_MATCH or sim.rules.cores.is_empty():
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var zoom := get_canvas_transform().get_scale().x
	if zoom < 0.05:
		zoom = 1.0
	var screen_size := 18
	for faction in sim.rules.faction_count:
		var core := sim.rules.cores[faction]
		if sim._match_live() and not sim.fog.is_visible(0, core): continue
		var x := float(core % width)
		var y := float(core / width)
		var color := _faction_color(faction)
		if faction == 0:
			draw_rect(Rect2(x - 2, y - 2, 5, 5), Color(color.r, color.g, color.b, 0.95), false, 0.22)
		var name := "Du" if faction == 0 else "KI %d" % faction
		var text_px := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, screen_size)
		var plate := Rect2(x - (text_px.x + 16.0) / zoom * 0.5, y - 2.5 - (screen_size + 10.0) / zoom, (text_px.x + 16.0) / zoom, (screen_size + 10.0) / zoom)
		draw_rect(plate, Color(0.05, 0.06, 0.08, 0.92), true)
		draw_rect(Rect2(plate.position.x, plate.position.y, 4.0 / zoom, plate.size.y), color, true)
		var baseline := Vector2(plate.position.x + 8.0 / zoom, plate.position.y + (screen_size + 1.0) / zoom)
		draw_set_transform(baseline, 0.0, Vector2.ONE / zoom)
		draw_string(font, Vector2.ZERO, name, HORIZONTAL_ALIGNMENT_LEFT, -1, screen_size, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sites() -> void:
	var rows: Array = sim.fog.remembered_sites(0) if sim._match_live() else sim.construction.sites.records
	for row in rows:
		if row.destroyed: continue
		var rect: Rect2i = row.rect
		var tint := _faction_color(row.owner)
		var fill := tint
		fill.a = 0.45 if row.ready else 0.18
		draw_rect(Rect2(rect), fill, true)
		draw_rect(Rect2(rect), tint, false, 0.16)
		if row.owner == 0 and row.id == sim.construction.selected:
			draw_rect(Rect2(rect).grow(0.15), Color.WHITE, false, 0.1)
		var fraction := float(row.hp) / float(row.max_hp) if row.ready else float(row.work) / float(row.required)
		draw_rect(Rect2(rect.position.x, rect.end.y + 0.2, rect.size.x, 0.25), Color(0.1, 0.1, 0.1), true)
		draw_rect(Rect2(rect.position.x, rect.end.y + 0.2, rect.size.x * fraction, 0.25), tint, true)
		if row.kind == 2:
			var middle := Vector2(rect.position) + Vector2(rect.size) * 0.5
			draw_line(middle - Vector2(0.7, 0.7), middle + Vector2(0.7, 0.7), tint, 0.2)
			draw_line(middle - Vector2(0.7, -0.7), middle + Vector2(0.7, -0.7), tint, 0.2)
		if row.kind == 0:
			var middle := Vector2(rect.position) + Vector2(rect.size) * 0.5
			draw_line(middle - Vector2(0.8, 0), middle + Vector2(0.8, 0), tint, 0.25)
			draw_line(middle - Vector2(0, 0.8), middle + Vector2(0, 0.8), tint, 0.25)

class_name WorldMinimap
extends Control
## Kleine, anklickbare Weltübersicht. Verwendet die bereits erzeugte Welttextur.
## Keine zusätzliche Material- oder Arbeiter-Simulation.

var world: WorldState
var renderer: WorldRenderer
var fog_view: FogOverlay
var camera: CameraController

var _elapsed := 0.0
var _marker_buffer := PackedFloat32Array()
var _unit_markers: MultiMesh
static var _unit_mesh: ArrayMesh


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Klicken, um die Kamera zur gewünschten Position zu bewegen."
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	if world == null or renderer == null:
		return
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Materials.BACKDROP, true)
	var texture := fog_view.minimap_texture() if fog_view != null else renderer.current_texture()
	if texture == null:
		return
	# Weltverhältnis statt verzerrter Darstellung.
	var factor := minf(size.x / float(world.width), size.y / float(world.height))
	var map_size := Vector2(world.width * factor, world.height * factor)
	var origin := (size - map_size) * 0.5
	var map_rect := Rect2(origin, map_size)
	draw_texture_rect(texture, map_rect, false)
	draw_rect(map_rect, Color(1, 1, 1, 0.28), false, 1.0)
	# Only player knowledge is allowed to produce minimap markers.
	if fog_view != null and fog_view.sim != null and fog_view.sim._match_live():
		var sim := fog_view.sim
		for site in sim.fog.remembered_sites(fog_view.faction):
			var rect: Rect2i = site.rect
			var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
			var color := MatchRules.FACTION_COLORS[int(site.owner)]
			draw_circle(origin + center * factor, 2.5, color)
		_sync_unit_markers(sim, fog_view.faction, origin, factor)
		if _unit_markers.visible_instance_count > 0: draw_multimesh(_unit_markers, null)



	if camera != null:
		var viewport_size := camera.get_viewport_rect().size
		var zoom := maxf(camera.zoom.x, 0.001)
		var visible := WorldCoordinates.visible_world_rect(camera.position, zoom, viewport_size)
		visible = visible.intersection(Rect2(Vector2.ZERO, Vector2(world.width, world.height)))
		if visible.has_area():
			var marker := Rect2(
				origin + visible.position * factor,
				visible.size * factor
			)
			draw_rect(marker, Color(1, 1, 1, 0.95), false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if camera == null or world == null:
		return
	var factor := minf(size.x / float(world.width), size.y / float(world.height))
	if factor <= 0.0:
		return
	var map_size := Vector2(world.width * factor, world.height * factor)
	var origin := (size - map_size) * 0.5
	var local_pos: Vector2 = (event.position - origin) / factor
	camera.focus_world(local_pos)
	accept_event()
	queue_redraw()


func _sync_unit_markers(sim: Simulation, faction: int, origin: Vector2, factor: float) -> void:
	if _unit_markers == null:
		if _unit_mesh == null:
			_unit_mesh = ArrayMesh.new()
			var vertices := PackedVector3Array()
			for segment in 16:
				vertices.append(Vector3.ZERO)
				var angle := TAU * segment / 16.0
				vertices.append(Vector3(cos(angle), sin(angle), 0))
				angle = TAU * (segment + 1) / 16.0
				vertices.append(Vector3(cos(angle), sin(angle), 0))
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			_unit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_unit_markers = MultiMesh.new()
		_unit_markers.transform_format = MultiMesh.TRANSFORM_2D
		_unit_markers.use_colors = true
		_unit_markers.mesh = _unit_mesh
	var needed := sim.workers.count + sim.army.count
	if _unit_markers.instance_count < needed: _unit_markers.instance_count = needed
	_marker_buffer.resize(_unit_markers.instance_count * 12)
	var index := 0
	var sight: PackedByteArray = sim.fog.visible[faction]
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) != faction: continue
		var cell := int(sim.workers.cell[id])
		if sight[cell] == 0: continue
		var at := index * 12
		_marker_buffer[at] = 1.2
		_marker_buffer[at + 3] = origin.x + (cell % world.width) * factor
		_marker_buffer[at + 5] = 1.2
		_marker_buffer[at + 7] = origin.y + (cell / world.width) * factor
		_marker_buffer[at + 8] = Color.WHITE.r
		_marker_buffer[at + 9] = Color.WHITE.g
		_marker_buffer[at + 10] = Color.WHITE.b
		_marker_buffer[at + 11] = Color.WHITE.a
		index += 1
	for id in sim.army.count:
		if int(sim.army.owners[id]) != faction: continue
		var cell := int(sim.army.cells[id])
		if sight[cell] == 0: continue
		var at := index * 12
		_marker_buffer[at] = 1.5
		_marker_buffer[at + 3] = origin.x + (cell % world.width) * factor
		_marker_buffer[at + 5] = 1.5
		_marker_buffer[at + 7] = origin.y + (cell / world.width) * factor
		_marker_buffer[at + 8] = UiTheme.ACCENT.r
		_marker_buffer[at + 9] = UiTheme.ACCENT.g
		_marker_buffer[at + 10] = UiTheme.ACCENT.b
		_marker_buffer[at + 11] = UiTheme.ACCENT.a
		index += 1
	# Godot 4.x public buffer layout: 8 transform floats + RGBA per instance.
	_unit_markers.buffer = _marker_buffer
	_unit_markers.visible_instance_count = index

class_name CombatEffects
extends Node2D
## Bounded, transient squares in one MultiMesh. No nodes or gameplay per particle.
const MAX_EFFECTS := 64
const MAX_QUADS := 2048
const ATTACK := 0
const HIT := 1
const DEATH := 2
var sim: Simulation
var clock: TickClock
var viewer := 0
var glow_enabled := true
## Review only: live matches still have one warrior level.
@export_range(1, 3) var visual_level := 1
var effects: Array[Dictionary] = []
var dropped := 0
var quad_count := 0
var _mesh: MultiMesh
var _buffer := PackedFloat32Array()
var _death_budget_full := false
var _sight := PackedByteArray()

func _ready() -> void:
	bind_events()
	_mesh = MultiMesh.new()
	_mesh.transform_format = MultiMesh.TRANSFORM_2D
	_mesh.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mesh.mesh = quad
	_mesh.instance_count = MAX_QUADS
	_mesh.visible_instance_count = 0
	_buffer.resize(MAX_QUADS * 12)

func bind_events() -> void:
	if not sim.army.combat_attack.is_connected(_on_attack): sim.army.combat_attack.connect(_on_attack)
	if not sim.army.combat_hit.is_connected(_on_hit): sim.army.combat_hit.connect(_on_hit)
	if not sim.army.combat_death.is_connected(_on_death): sim.army.combat_death.connect(_on_death)

func _process(delta: float) -> void:
	advance(0.0 if clock != null and clock.paused else delta * (clock.speed if clock != null else 1))
	compose()

func advance(seconds: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		var e := effects[index]
		e.age = float(e.age) + maxf(0.0, seconds)
		if float(e.age) >= float(e.life) or not _seen(int(e.cell)) or (int(e.kind) == ATTACK and not _seen(int(e.origin))):
			effects.remove_at(index)
			_death_budget_full = false

func _seen(cell: int) -> bool:
	return cell >= 0 and cell < sim.world.cell_count() and (not sim._match_live() or sim.fog.is_visible(viewer, cell))

func _center(cell: int) -> Vector2:
	return Vector2(cell % sim.world.width + 0.5, cell / sim.world.width + 0.5)

func _admit(e: Dictionary) -> void:
	if not _seen(int(e.cell)): return
	if not _on_screen(int(e.cell)): return
	if effects.size() >= MAX_EFFECTS:
		# Deaths replace a lesser effect so a crowded battle still has a clear loss cue.
		if int(e.kind) == DEATH:
			if _death_budget_full:
				dropped += 1
				return
			for index in effects.size():
				if int(effects[index].kind) != DEATH:
					effects.remove_at(index)
					break
		if effects.size() >= MAX_EFFECTS:
			if int(e.kind) == DEATH: _death_budget_full = true
			dropped += 1
			return
	effects.append(e)

func _on_screen(cell: int) -> bool:
	return not is_inside_tree() or get_viewport_rect().grow(96.0).has_point(get_global_transform_with_canvas() * _center(cell))

func _on_attack(uid: int) -> void:
	# Reserve half the budget for impacts/deaths in a simultaneous mass volley.
	if effects.size() >= MAX_EFFECTS / 2: return
	var index: int = sim.army.slots[uid]
	var origin := sim.army.cells[index]
	if not _seen(origin) or not _on_screen(origin): return
	var enemy := sim.army._enemy(sim, index, 1)
	if not enemy.is_empty(): _strike(origin, int(enemy.cell), sim.army.owners[index])

func _strike(origin: int, target: int, owner: int) -> void:
	if _seen(origin) and _seen(target):
		_admit({"kind": ATTACK, "origin": origin, "cell": target, "owner": owner, "age": 0.0, "life": 0.16, "level": visual_level})

func _on_hit(target: int, target_owner: int) -> void:
	if effects.size() >= MAX_EFFECTS: return
	# A visible victim may be hit by an unseen attacker; never reveal its origin/color.
	_admit({"kind": HIT, "cell": target, "owner": target_owner, "age": 0.0, "life": 0.13})

func _on_death(cell: int, owner: int, warrior: bool) -> void:
	if effects.size() >= MAX_EFFECTS and _death_budget_full: return
	_admit({"kind": DEATH, "cell": cell, "owner": owner, "age": 0.0, "life": 0.48 if warrior else 0.38, "pieces": 12 if warrior else 8})

func compose() -> void:
	if _mesh == null: return
	if effects.is_empty() and quad_count == 0 and sim.defense.projectiles.is_empty() and sim.defense.beams.is_empty(): return
	_sight = sim.fog.visible[viewer] if sim._match_live() else PackedByteArray()
	quad_count = 0
	_compose_defense()
	for e in effects:
		if not _seen(int(e.cell)): continue
		var p := _center(int(e.cell))
		var age := float(e.age)
		var t := age / float(e.life)
		var color := SpriteCatalog.team_color(int(e.owner))
		var fade := 1.0 - t
		match int(e.kind):
			ATTACK:
				if not _seen(int(e.origin)): continue
				var start := _center(int(e.origin))
				# Brief core pulse, fixed orientation; then a short melee light stroke.
				if t < 0.4: _square(start, 0.40, Color(color, (1.0 - t / 0.4) * 0.85))
				var head := start.lerp(p, minf(1.0, t * 1.8))
				for trail in int(e.level):
					var at := head.lerp(start, trail * 0.14)
					_square(at, 0.15 + int(e.level) * 0.025, Color(color, fade / (trail + 1)))
				_square(head, 0.08, Color(1, 1, 1, fade))
				if int(e.level) == 3: _ring(start, 0.5 + t * 0.55, Color(color, fade * 0.65))
			HIT:
				# Inset flash leaves the square unit's team rim readable.
				_square(p, 0.58, Color(1, 1, 1, fade * 0.85))
				for spark in 4:
					var direction := Vector2.RIGHT.rotated(spark * PI / 2.0)
					_square(p + direction * (0.35 + t * 0.40), 0.07, Color(color, fade))
			DEATH:
				if t < 0.15: _square(p, 0.60, Color(1, 1, 1, 1.0 - t / 0.15))
				for piece in int(e.pieces):
					# Local arithmetic, never the simulation/global RNG.
					var angle := TAU * piece / int(e.pieces) + (int(e.cell) % 7) * 0.11
					var direction := Vector2(cos(angle), sin(angle))
					var speed := 0.75 + (piece * 7 % 5) * 0.13
					var at := p + direction * (0.14 + speed * (1.0 - pow(1.0 - t, 2)))
					var tint := Color.WHITE if piece % 4 == 0 else color
					_square(at, (0.09 + (piece % 3) * 0.025) * (1.0 - t * 0.5), Color(tint, fade * fade))
	_mesh.buffer = _buffer
	_mesh.visible_instance_count = quad_count
	queue_redraw()

func _compose_defense() -> void:
	var shown := 0
	for shot in sim.defense.projectiles:
		if not _seen(int(shot.cell)) or not _on_screen(int(shot.cell)): continue
		var p := _center(int(shot.cell))
		var tint := SpriteCatalog.team_color(int(shot.owner))
		var direction := (p - _center(int(shot.previous))).normalized()
		for tail in 3: _square(p - direction * (tail + 1) * 0.12, 0.10, Color(tint, 0.65 / (tail + 1)))
		_square(p, 0.22, tint)
		_square(p, 0.09, Color.WHITE)
		shown += 1
		if shown >= 64: break
	shown = 0
	for beam in sim.defense.beams:
		if not sim.construction.sites.valid(int(beam.site)): continue
		var origin: int = sim.construction.center(int(beam.site))
		if not _seen(origin) or not _seen(int(beam.cell)) or not _on_screen(int(beam.cell)): continue
		var start := _center(origin)
		var end := _center(int(beam.cell))
		var tint := SpriteCatalog.team_color(int(beam.owner))
		var steps := maxi(1, ceili(start.distance_to(end) / 0.12))
		for point in steps + 1:
			var p := start.lerp(end, float(point) / steps)
			_square(p, 0.19, Color(tint, 0.85))
			_clipped(Rect2(p - Vector2.ONE * 0.035, Vector2.ONE * 0.07), Color(0.9, 1, 1, 0.95))
		shown += 1
		if shown >= 16: break

func _ring(center: Vector2, size: float, color: Color) -> void:
	var r := Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size)
	for rect in [Rect2(r.position, Vector2(size, 0.045)), Rect2(r.position + Vector2(0, size - 0.045), Vector2(size, 0.045)), Rect2(r.position, Vector2(0.045, size)), Rect2(r.position + Vector2(size - 0.045, 0), Vector2(0.045, size))]:
		_clipped(rect, color)

func _square(center: Vector2, size: float, color: Color) -> void:
	if glow_enabled: _clipped(Rect2(center - Vector2.ONE * size, Vector2.ONE * size * 2), Color(color, color.a * 0.12))
	_clipped(Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), color)

func _clipped(rect: Rect2, color: Color) -> void:
	# Clip whole quads, including halos, at current fog cell boundaries.
	# Even a visible death beside a hidden cell cannot paint into that cell.
	for y in range(maxi(0, int(floor(rect.position.y))), mini(sim.world.height, int(ceil(rect.end.y)))):
		for x in range(maxi(0, int(floor(rect.position.x))), mini(sim.world.width, int(ceil(rect.end.x)))):
			if not _sight.is_empty() and _sight[y * sim.world.width + x] == 0: continue
			if quad_count >= MAX_QUADS: return
			var cut := rect.intersection(Rect2(x, y, 1, 1))
			if not cut.has_area(): continue
			var at := quad_count * 12
			_buffer[at] = cut.size.x
			_buffer[at + 3] = cut.get_center().x
			_buffer[at + 5] = cut.size.y
			_buffer[at + 7] = cut.get_center().y
			_buffer[at + 8] = color.r
			_buffer[at + 9] = color.g
			_buffer[at + 10] = color.b
			_buffer[at + 11] = color.a
			quad_count += 1

func _draw() -> void:
	if _mesh != null and quad_count > 0: draw_multimesh(_mesh, null)

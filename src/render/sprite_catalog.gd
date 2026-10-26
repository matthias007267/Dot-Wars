class_name SpriteCatalog
extends RefCounted
## One atlas definition for world sprites, portraits and command icons.
const ATLAS = preload("res://assets/pixel/tactical_atlas.tres")
static var _icons := {}

static func row(key: String) -> int:
	return int(ATLAS.rows.get(key, 0))

static func region(key: String, tick := 0) -> Rect2:
	var frame := posmod(tick / ATLAS.frame_ticks, ATLAS.frames)
	return Rect2(frame * ATLAS.cell_size, row(key) * ATLAS.cell_size, ATLAS.cell_size, ATLAS.cell_size)

static func team_color(owner: int) -> Color:
	return Color("ffd343") if owner == 0 else Color("ff4050") if owner == 1 else MatchRules.FACTION_COLORS[clampi(owner, 0, 3)]

static func worker_row(state: int) -> int:
	match state:
		WorkerStore.STATE_MOVING: return row("worker.move")
		WorkerStore.STATE_MINING: return row("worker.mine")
		WorkerStore.STATE_BUILDING: return row("worker.build")
		WorkerStore.STATE_BLOCKED: return row("worker.blocked")
	return row("worker.idle")

static func warrior_row(army: ArmyState, index: int, tick: int) -> int:
	if army.last_attack[index] >= 0 and tick - army.last_attack[index] >= 0 and tick - army.last_attack[index] < 3:
		return row("warrior.attack")
	if army.next_move[index] > tick: return row("warrior.move")
	return row("warrior.idle")

static func facing(origin: int, target: int, width: int) -> int:
	if target < 0 or origin == target: return 0
	var delta := Vector2i(target % width - origin % width, target / width - origin / width)
	if absi(delta.x) > absi(delta.y): return 1 if delta.x > 0 else 3
	return 2 if delta.y > 0 else 0

static func configure_units(effect: ShaderMaterial) -> void:
	effect.set_shader_parameter("sprite_body", ATLAS.body)
	effect.set_shader_parameter("sprite_team", ATLAS.team_mask)
	effect.set_shader_parameter("sprite_grid", Vector2(ATLAS.frames, ATLAS.body.get_height() / ATLAS.cell_size))
	effect.set_shader_parameter("sprite_cell_size", float(ATLAS.cell_size))
	effect.set_shader_parameter("sprite_frame_ticks", float(ATLAS.frame_ticks))
	for owner in 4:
		var tint := team_color(owner)
		effect.set_shader_parameter("sprite_faction_%d" % owner, Vector3(tint.r, tint.g, tint.b))
	effect.set_shader_parameter("sprites_enabled", true)

static func draw(canvas: CanvasItem, key: String, area: Rect2, tint: Color, tick := 0, brightness := 1.0) -> void:
	var source := region(key, tick)
	var shade := Color(brightness, brightness, brightness, 1.0)
	canvas.draw_texture_rect_region(ATLAS.body, area, source, shade)
	canvas.draw_texture_rect_region(ATLAS.team_mask, area, source, Color(tint.r * brightness, tint.g * brightness, tint.b * brightness))

static func icon(kind: String) -> Texture2D:
	if _icons.has(kind): return _icons[kind]
	var key := kind + ".idle" if kind in ["worker", "warrior", "research"] else kind
	if not ATLAS.rows.has(key): key = "pause"
	var source := Rect2i(region(key))
	var body := ATLAS.body.get_image().get_region(source)
	var mask := ATLAS.team_mask.get_image().get_region(source)
	var tint := team_color(0)
	for y in ATLAS.cell_size:
		for x in ATLAS.cell_size:
			var pixel := mask.get_pixel(x, y)
			if pixel.a > 0:
				body.set_pixel(x, y, Color(tint.r * pixel.r, tint.g * pixel.g, tint.b * pixel.b, pixel.a))
	body.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(body)
	_icons[kind] = texture
	return texture

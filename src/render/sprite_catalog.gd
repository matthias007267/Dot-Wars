class_name SpriteCatalog
extends RefCounted
## One catalog for square units, building sprites, portraits and command icons.
const ATLAS = preload("res://assets/pixel/tactical_atlas.tres")
const UNITS = preload("res://assets/pixel/square_units.tres")
static var _icons := {}

static func atlas_for(key: String) -> SpriteAtlas:
	return UNITS if key.begins_with("worker.") or key.begins_with("warrior.") else ATLAS

static func row(key: String) -> int:
	return int(atlas_for(key).rows.get(key, 0))

static func region(key: String, tick := 0) -> Rect2:
	var atlas := atlas_for(key)
	var frame := posmod(tick / atlas.frame_ticks, atlas.frames)
	return Rect2(frame * atlas.cell_size, row(key) * atlas.cell_size, atlas.cell_size, atlas.cell_size)

static func team_color(owner: int) -> Color:
	return Color("ffd343") if owner == 0 else Color("ff4050") if owner == 1 else MatchRules.FACTION_COLORS[clampi(owner, 0, 3)]

static func worker_row(state: int) -> int:
	match state:
		WorkerStore.STATE_MOVING: return row("worker.move")
		WorkerStore.STATE_MINING: return row("worker.mine")
		WorkerStore.STATE_BUILDING: return row("worker.build")
		WorkerStore.STATE_BLOCKED: return row("worker.blocked")
	return row("worker.idle")

static func warrior_activity(army: ArmyState, index: int, tick: int) -> int:
	if army.last_attack[index] >= 0 and tick - army.last_attack[index] >= 0 and tick - army.last_attack[index] < 3:
		return 2
	return 1 if army.next_move[index] > tick else 0

static func warrior_row(level := 1) -> int:
	return row("warrior.%d" % clampi(level, 1, 3))

static func configure_units(effect: ShaderMaterial) -> void:
	effect.set_shader_parameter("sprite_body", UNITS.body)
	effect.set_shader_parameter("sprite_team", UNITS.team_mask)
	effect.set_shader_parameter("sprite_grid", Vector2(UNITS.frames, UNITS.body.get_height() / UNITS.cell_size))
	effect.set_shader_parameter("sprite_cell_size", float(UNITS.cell_size))
	effect.set_shader_parameter("sprite_frame_ticks", float(UNITS.frame_ticks))
	for owner in 4:
		var tint := team_color(owner)
		effect.set_shader_parameter("sprite_faction_%d" % owner, Vector3(tint.r, tint.g, tint.b))
	effect.set_shader_parameter("sprites_enabled", true)

static func draw(canvas: CanvasItem, key: String, area: Rect2, tint: Color, tick := 0, brightness := 1.0) -> void:
	var source := region(key, tick)
	var atlas := atlas_for(key)
	var shade := Color(brightness, brightness, brightness, 1.0)
	canvas.draw_texture_rect_region(atlas.body, area, source, shade)
	canvas.draw_texture_rect_region(atlas.team_mask, area, source, Color(tint.r * brightness, tint.g * brightness, tint.b * brightness))

static func icon(kind: String) -> Texture2D:
	if _icons.has(kind): return _icons[kind]
	var key := kind + ".idle" if kind in ["worker", "warrior", "research"] else kind
	if not atlas_for(key).rows.has(key): key = "pause"
	var atlas := atlas_for(key)
	var source := Rect2i(region(key))
	var body := atlas.body.get_image().get_region(source)
	var mask := atlas.team_mask.get_image().get_region(source)
	var tint := team_color(0)
	for y in atlas.cell_size:
		for x in atlas.cell_size:
			var pixel := mask.get_pixel(x, y)
			if pixel.a > 0:
				body.set_pixel(x, y, Color(tint.r * pixel.r, tint.g * pixel.g, tint.b * pixel.b, pixel.a))
	body.resize(32, 32, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(body)
	_icons[kind] = texture
	return texture

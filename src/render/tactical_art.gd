class_name TacticalArt
extends RefCounted
## Original procedural pixel silhouettes, shared by world buildings and command icons.
static var _icons := {}
const GOLD := Color("ffd343")
const CYAN := Color("58dafa")
const DARK := Color("111923")
const METAL := Color("455564")

static func tint(owner: int) -> Color:
	return GOLD if owner == 0 else Color("ff4050") if owner == 1 else MatchRules.FACTION_COLORS[mini(owner, 3)]

static func building(canvas: CanvasItem, kind: int, area: Rect2, color: Color, ready := true, brightness := 1.0) -> void:
	var origin := area.position
	var unit := area.size / 16.0
	# Pixel coordinates scale exactly with the existing collision footprint.
	var body := Color("202d39")
	_rect(canvas, origin, unit, Rect2(1, 3, 14, 12), Color(0.02, 0.025, 0.035, 0.85), brightness)
	_rect(canvas, origin, unit, Rect2(2, 4, 12, 10), METAL, brightness)
	_rect(canvas, origin, unit, Rect2(3, 5, 10, 8), body, brightness)
	for x in [1, 12]:
		_rect(canvas, origin, unit, Rect2(x, 6, 3, 7), DARK, brightness)
		_rect(canvas, origin, unit, Rect2(x + 1, 6, 1, 5), color.darkened(0.15), brightness)
		_rect(canvas, origin, unit, Rect2(x, 12, 3, 1), Color("8494a1"), brightness)
	_rect(canvas, origin, unit, Rect2(4, 13, 8, 2), DARK, brightness)
	for x in [4, 7, 10]: _rect(canvas, origin, unit, Rect2(x, 14, 2, 1), color, brightness)
	if not ready:
		for y in [4, 8, 12]: _rect(canvas, origin, unit, Rect2(3, y, 10, 1), color.darkened(0.2), brightness)
		_rect(canvas, origin, unit, Rect2(7, 3, 2, 11), METAL.lightened(0.2), brightness)
		return
	match kind:
		0: # Reactor with four metal braces and a bright protected heart.
			_rect(canvas, origin, unit, Rect2(4, 3, 8, 9), color.darkened(0.42), brightness)
			_rect(canvas, origin, unit, Rect2(5, 4, 6, 7), color, brightness)
			_rect(canvas, origin, unit, Rect2(6, 5, 4, 5), Color("fff5b8") if color == GOLD else color.lightened(0.65), brightness)
			for x in [3, 11]: _rect(canvas, origin, unit, Rect2(x, 3, 2, 3), METAL.lightened(0.25), brightness)
		1: # Compact production hub.
			_rect(canvas, origin, unit, Rect2(5, 5, 6, 7), color.darkened(0.25), brightness)
			_rect(canvas, origin, unit, Rect2(6, 6, 4, 4), color, brightness)
			_rect(canvas, origin, unit, Rect2(7, 1, 2, 5), METAL.lightened(0.3), brightness)
			_rect(canvas, origin, unit, Rect2(7, 1, 2, 2), color.lightened(0.6), brightness)
		2: # Interception aerials: no implied turret/weapon.
			_rect(canvas, origin, unit, Rect2(7, 2, 2, 10), color, brightness)
			_rect(canvas, origin, unit, Rect2(4, 2, 8, 1), color.lightened(0.4), brightness)
			_rect(canvas, origin, unit, Rect2(4, 2, 1, 5), color, brightness)
			_rect(canvas, origin, unit, Rect2(11, 2, 1, 5), color, brightness)
		3: # Cyan research prism with faction-colored housing.
			_rect(canvas, origin, unit, Rect2(5, 1, 6, 10), DARK, brightness)
			_rect(canvas, origin, unit, Rect2(6, 1, 4, 9), CYAN, brightness)
			_rect(canvas, origin, unit, Rect2(7, 2, 1, 7), Color("dcfbff"), brightness)
			_rect(canvas, origin, unit, Rect2(8, 3, 1, 7), Color("2388cf"), brightness)
			_rect(canvas, origin, unit, Rect2(5, 10, 6, 2), color, brightness)
	_rect(canvas, origin, unit, Rect2(3, 4, 2, 1), Color("aab5bc"), brightness)

static func _rect(canvas: CanvasItem, origin: Vector2, unit: Vector2, rect: Rect2, color: Color, brightness := 1.0) -> void:
	canvas.draw_rect(Rect2(origin + rect.position * unit, rect.size * unit), Color(color.r * brightness, color.g * brightness, color.b * brightness, color.a))

static func icon(kind: String) -> Texture2D:
	if _icons.has(kind): return _icons[kind]
	var shape := ""
	match kind:
		"worker": shape = '<path d="M8 10h16v17H8z" fill="#ffe05b"/><path d="M6 9h20v5H6z" fill="#a98928"/><path d="M10 7h12v7H10z" fill="#fff3a6"/><path d="M10 17h12v3H10z" fill="#544721"/>'
		"warrior": shape = '<path d="M7 8h18v15l-9 6-9-6z" fill="#d9b33f"/><path d="M11 10h10v12l-5 4-5-4z" fill="#fff0a3"/><path d="M14 12h4v12h-4zM10 16h12v4H10z" fill="#917427"/>'
		"core", "outpost", "research", "interceptor":
			shape = '<path d="M5 14h22v14H5z" fill="#46596c"/><path d="M8 10h16v17H8z" fill="#b08626"/><path d="M11 12h10v12H11z" fill="#ffdf57"/><path d="M3 18h4v9H3zM25 18h4v9h-4z" fill="#bd9430"/>'
			if kind == "research": shape += '<path d="M12 3h8v17h-8z" fill="#29bde9"/><path d="M14 4h2v14h-2z" fill="#d5faff"/>'
			elif kind == "interceptor": shape += '<path d="M15 2h2v16h-2zM7 3h18v3H7zM7 4h2v7H7zM23 4h2v7h-2z" fill="#ffe57e"/>'
			elif kind == "core": shape += '<path d="M12 8h8v12h-8z" fill="#fff5bb"/>'
			else: shape += '<path d="M15 3h2v9h-2z" fill="#fff0ad"/>'
		"network": shape = '<path d="M5 8h10v16h12" fill="none" stroke="#fbd744" stroke-width="3"/><path d="M3 6h5v5H3zM12 5h6v6h-6zM24 21h6v6h-6z" fill="#fff3ac"/>'
		"repair": shape = '<path d="M7 5l6 6 5-5 2-4 7 7-4 2-5 5-9 13-6-6 12-10-5-5z" fill="#90d5ef"/>'
		"demolish": shape = '<path d="M7 5l20 20-4 4L3 9zM25 4L4 25l4 4L29 8z" fill="#fa686a"/>'
		"research_tree": shape = '<path d="M6 7h20M16 7v18M6 25h20" stroke="#6edcf1" stroke-width="2"/><path d="M3 3h7v7H3zM22 3h7v7h-7zM12 21h8v8h-8z" fill="#c0f7ff"/>'
		_: shape = '<path d="M9 6h5v20H9zM19 6h5v20h-5z" fill="#a5cedd"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">' + shape + '</svg>'
	var image := Image.new()
	image.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(image)
	_icons[kind] = texture
	return texture

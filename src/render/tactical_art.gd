class_name TacticalArt
extends RefCounted
## Compatibility entry points: all world and HUD art now comes from SpriteCatalog.

static func tint(owner: int) -> Color:
	return SpriteCatalog.team_color(owner)

static func building(canvas: CanvasItem, kind: int, area: Rect2, color: Color, ready := true, brightness := 1.0, state := "idle", tick := 0, weapon_level := 1) -> void:
	if kind == 4 and ready:
		canvas.draw_texture_rect(TowerArt.texture(color, weapon_level), area, false, Color(brightness, brightness, brightness))
		return
	var key: String = ["core", "outpost", "interceptor", "research.idle"][clampi(kind, 0, 3)]
	if not ready: key = "research.construction"
	elif kind == 3: key = "research." + state
	SpriteCatalog.draw(canvas, key, area, color, tick, brightness)

static func icon(kind: String) -> Texture2D:
	return SpriteCatalog.icon(kind)

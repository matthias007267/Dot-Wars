class_name TowerArt
extends RefCounted
## Symmetric metal platform and emitter, cached for all factions/three levels.
static var _textures := {}
static func texture(tint: Color, level := 1) -> Texture2D:
	var key := [tint, level]
	if _textures.has(key): return _textures[key]
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var p := mini(x, 31 - x)
			var q := mini(y, 31 - y)
			var color := Color.TRANSPARENT
			if p >= 2 and q >= 2: color = Color("101b24")
			if p >= 4 and q >= 4: color = Color("627480")
			if p >= 5 and q >= 5: color = Color("243440")
			if p >= 6 and q >= 6 and (p == 6 or q == 6): color = tint.darkened(0.25)
			if p >= 6 and p <= 9 and q >= 6 and q <= 9: color = Color("b4c1c5")
			if p >= 8 and q >= 8: color = Color("0b121c")
			if p >= 10 and q >= 10: color = tint
			if p >= 11 and q >= 11: color = Color("263b4d")
			if p >= 13 and q >= 13: color = tint.lightened(0.55) if level < 3 else Color("a0f8ff")
			if level >= 2 and ((p == 9 and q >= 12) or (q == 9 and p >= 12)): color = Color("b4c1c5")
			if level == 3 and ((p == 12 and q >= 12) or (q == 12 and p >= 12)): color = Color("39b9e2")
			image.set_pixel(x, y, color)
	var result := ImageTexture.create_from_image(image)
	_textures[key] = result
	return result

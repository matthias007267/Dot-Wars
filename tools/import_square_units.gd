extends SceneTree
## Offline asset import: transparent generated strip -> aligned body/team atlas.
## No gameplay dependency and no drawing/redesign of the approved source art.
const SOURCE := "res://assets/pixel/square_units_source.png"
const SIZE := 32

func _init() -> void:
	var source := Image.load_from_file(SOURCE)
	if source == null:
		quit(1)
		return
	var columns: Array[Vector2i] = []
	var start := -1
	for x in source.get_width() + 1:
		var occupied := false
		if x < source.get_width():
			for y in source.get_height():
				if source.get_pixel(x, y).a >= 0.5:
					occupied = true
					break
		if occupied and start < 0: start = x
		elif not occupied and start >= 0:
			if x - start > source.get_width() / 20: columns.append(Vector2i(start, x))
			start = -1
	if columns.size() != 4:
		printerr("Expected four separate square sprites, found ", columns.size())
		quit(1)
		return
	var body := Image.create(SIZE, SIZE * 4, false, Image.FORMAT_RGBA8)
	var team := Image.create(SIZE, SIZE * 4, false, Image.FORMAT_RGBA8)
	for index in 4:
		var column := columns[index]
		var top := source.get_height()
		var bottom := 0
		for y in source.get_height():
			for x in range(column.x, column.y):
				if source.get_pixel(x, y).a >= 0.5:
					top = mini(top, y)
					bottom = maxi(bottom, y + 1)
		var sprite := source.get_region(Rect2i(column.x, top, column.y - column.x, bottom - top))
		sprite.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
		for y in SIZE:
			for x in SIZE:
				var pixel := sprite.get_pixel(x, y)
				if pixel.a < 0.5: continue
				pixel.a = 1.0
				# Saturated yellow/gold becomes a neutral shading mask; metal stays neutral.
				if pixel.s >= 0.5 and pixel.h > 0.075 and pixel.h < 0.20:
					team.set_pixel(x, index * SIZE + y, Color(pixel.r, pixel.r, pixel.r, 1.0))
				else:
					body.set_pixel(x, index * SIZE + y, pixel)
		print("SQUARE IMPORT ", index, " source=", Rect2i(column.x, top, column.y - column.x, bottom - top))
	if body.save_png("res://assets/pixel/square_units_body.png") != OK or team.save_png("res://assets/pixel/square_units_team.png") != OK:
		quit(1)
		return
	print("SQUARE IMPORT: four 32px sprites, separate faction mask")
	quit()

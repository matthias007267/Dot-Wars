extends SceneTree
## Offline extraction of the approved art, with no runtime dependency on source PNG.
func spans(image: Image, vertical: bool, rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := -1
	var length := rect.size.y if vertical else rect.size.x
	for n in length + 1:
		var occupied := false
		if n < length:
			for cross in (rect.size.x if vertical else rect.size.y):
				var p := rect.position + (Vector2i(cross, n) if vertical else Vector2i(n, cross))
				if image.get_pixelv(p).a > 0.5:
					occupied = true
					break
		if occupied and start < 0: start = n
		elif not occupied and start >= 0:
			if n - start > 40: result.append(Vector2i(start, n))
			start = -1
	return result

func _init() -> void:
	var source := Image.load_from_file("res://assets/pixel/ore_tiles_source.png")
	var rows := spans(source, true, Rect2i(Vector2i.ZERO, source.get_size()))
	if rows.size() != 2:
		printerr("Expected two source rows")
		quit(1)
		return
	var atlas := Image.create(32, 320, false, Image.FORMAT_RGBA8)
	var index := 0
	for row in rows:
		var columns := spans(source, false, Rect2i(0, row.x, source.get_width(), row.y - row.x))
		if columns.size() != 5:
			quit(1)
			return
		for column in columns:
			var sprite := source.get_region(Rect2i(column.x, row.x, column.y - column.x, row.y - row.x))
			sprite.resize(32, 32, Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(sprite, Rect2i(0, 0, 32, 32), Vector2i(0, index * 32))
			index += 1
	var error := atlas.save_png("res://assets/pixel/ore_tiles.png")
	print("ORE IMPORT: ", index, " sprites, error=", error)
	quit(0 if error == OK else 1)

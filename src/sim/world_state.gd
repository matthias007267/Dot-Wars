class_name WorldState
extends RefCounted
## Weltzustand als flache Arrays. Index einer Zelle = y * width + x.

var width: int
var height: int
var chunk_size: int
var chunks_x: int
var chunks_y: int

var cells := PackedByteArray()
## Visual mining history, retained under foundations and independent of resources.
var excavated := PackedByteArray()
## Abbaufortschritt je Zelle in Arbeitspunkten (immer kleiner als die Haltbarkeit).
var progress := PackedInt32Array()
## Niederes Glied des Restbruchs, Basis 2^31. Kleiner als der Nenner, solange der Rest hier hineinpasst.
var progress_frac := PackedInt32Array()
## Weitere Glieder desselben Restbruchs. Leer, solange `progress_frac` den ganzen Rest trägt.
var progress_frac_high := {}

## Zählt jede Änderung an `cells`. Abgeleitete Daten erkennen damit Veralterung.
var revision: int = 0
## Indizes der Zellen, deren Material sich geändert hat, in derselben Reihenfolge.
var change_log := PackedInt32Array()
## Material vor der Änderung, gleiche Indizes wie `change_log`.
var change_from := PackedInt32Array()
## Steigt, wenn das Protokoll verworfen wird. Wer es liest, muss dann neu aufbauen.
var change_epoch: int = 0
var solid_count: int = 0
## Unzerstörbare Zellen. Sie zählen zu solid_count, aber nicht zum abbaubaren Bestand.
var indestructible_count: int = 0
## Durch Spielmechanik (Abbau) entfernte Zellen. Generator-Aushub zählt nicht.
var mined_count: int = 0
## Leer gelegte Zellen, die nicht als Abbau zählen. Die Kern-Erweiterung nutzt das.
var opened_count: int = 0

var _chunk_dirty := PackedByteArray()
var _dirty_chunks := PackedInt32Array()
## Abbaubare Zellen mit mindestens einer leeren Nachbarzelle, je Chunk.
var face_lists: Array = []
var face_slot := PackedInt32Array()
var face_count: int = 0
## Steigt, wenn sich das Material einer Zelle ändert. DigAreas hängt sich daran.
signal material_changed(idx: int, old: int, now: int)


func _init(p_width: int, p_height: int, p_chunk_size: int = 32, fill_material: int = Materials.SOFT) -> void:
	width = p_width
	height = p_height
	chunk_size = p_chunk_size
	chunks_x = ceili(float(width) / chunk_size)
	chunks_y = ceili(float(height) / chunk_size)
	cells.resize(width * height)
	cells.fill(fill_material)
	excavated.resize(width * height)
	progress.resize(width * height)
	progress.fill(0)
	progress_frac.resize(width * height)
	progress_frac.fill(0)
	solid_count = 0 if fill_material == Materials.EMPTY else width * height
	indestructible_count = width * height if fill_material == Materials.INDESTRUCTIBLE else 0
	_chunk_dirty.resize(chunks_x * chunks_y)
	_chunk_dirty.fill(1)
	for chunk in chunks_x * chunks_y:
		_dirty_chunks.append(chunk)
		face_lists.append(PackedInt32Array())
	face_slot.resize(width * height)
	face_slot.fill(-1)


func cell_count() -> int:
	return width * height


func index(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func is_solid(idx: int) -> bool:
	return cells[idx] != Materials.EMPTY


## Setzt ein Material (Generierung, Tests). Setzt den Abbaufortschritt zurück.
func set_material(idx: int, material: int) -> void:
	var old := cells[idx]
	if old == material:
		return
	if old == Materials.EMPTY:
		solid_count += 1
	elif material == Materials.EMPTY:
		solid_count -= 1
	if old == Materials.INDESTRUCTIBLE:
		indestructible_count -= 1
	if material == Materials.INDESTRUCTIBLE:
		indestructible_count += 1
	cells[idx] = material
	progress[idx] = 0
	progress_frac[idx] = 0
	if progress_frac_high.has(idx):
		progress_frac_high.erase(idx)
	_update_face(idx)
	_update_face_neighbors(idx)
	revision += 1
	change_log.append(idx)
	change_from.append(old)
	material_changed.emit(idx, old, material)
	if change_log.size() > 100000:
		change_log = PackedInt32Array()
		change_from = PackedInt32Array()
		change_epoch += 1
	_mark_dirty(idx)


## Entfernt eine feste Zelle durch Abbau. Gibt false zurück, wenn sie bereits leer war.
func mine_cell(idx: int) -> bool:
	if not Materials.is_mineable(cells[idx]):
		return false
	excavated[idx] = 1
	set_material(idx, Materials.EMPTY)
	mined_count += 1
	return true


func carve_rect(rect: Rect2i) -> void:
	var clipped := rect.abs().intersection(Rect2i(0, 0, width, height))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			set_material(y * width + x, Materials.EMPTY)


## Legt eine abbaubare Zelle leer, ohne sie als Abbau zu zählen.
func open_without_mining(idx: int) -> void:
	if not Materials.is_mineable(cells[idx]):
		return
	set_material(idx, Materials.EMPTY)
	opened_count += 1


## Anteil der abgebauten Zellen an allen ursprünglich abbaubaren Zellen (0..1).
func mined_fraction() -> float:
	var minable := solid_count - indestructible_count + mined_count + opened_count
	return 0.0 if minable == 0 else float(mined_count) / minable


## Nächstgelegene leere Zelle (Chebyshev-Ringe, Reihenfolge deterministisch) oder -1.
func find_nearest_empty(x: int, y: int) -> int:
	var max_radius := maxi(width, height)
	for radius in max_radius:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cx := x + dx
				var cy := y + dy
				if in_bounds(cx, cy) and cells[cy * width + cx] == Materials.EMPTY:
					return cy * width + cx
	return -1


func chunk_rect(chunk: int) -> Rect2i:
	var cx := chunk % chunks_x
	var cy := chunk / chunks_x
	var x := cx * chunk_size
	var y := cy * chunk_size
	return Rect2i(x, y, mini(chunk_size, width - x), mini(chunk_size, height - y))


## Liefert alle seit dem letzten Aufruf geänderten Chunks (jeden höchstens einmal).
func consume_dirty_chunks() -> PackedInt32Array:
	var result := _dirty_chunks
	_dirty_chunks = PackedInt32Array()
	for chunk in result:
		_chunk_dirty[chunk] = 0
	return result


func note_progress(idx: int) -> void:
	_mark_dirty(idx)


## Baut die Flächenliste neu. Nötig, wenn Zellen am Array vorbeigehend gesetzt wurden.
func rebuild_faces() -> void:
	face_count = 0
	face_slot.fill(-1)
	for list in face_lists:
		var faces: PackedInt32Array = list
		faces.resize(0)
	for idx in cell_count():
		if _is_face(idx):
			_add_face(idx)


## True, wenn irgendeine Fläche höchstens `radius` Schritte (Manhattan) von einem Ursprung liegt.
## Negativer Radius heißt: irgendwo auf der Karte.
func has_face_within(origins: PackedInt32Array, radius: int) -> bool:
	if face_count <= 0 or origins.is_empty():
		return false
	if radius < 0:
		return true
	var seen := PackedByteArray()
	seen.resize(chunks_x * chunks_y)
	var cs := chunk_size
	for origin in origins:
		var ox := origin % width
		var oy := int(origin / width)
		var x0 := maxi(0, ox - radius) / cs
		var y0 := maxi(0, oy - radius) / cs
		var x1 := mini(width - 1, ox + radius) / cs
		var y1 := mini(height - 1, oy + radius) / cs
		for cy in range(y0, y1 + 1):
			for cx in range(x0, x1 + 1):
				var chunk := cy * chunks_x + cx
				if seen[chunk] == 1:
					continue
				seen[chunk] = 1
				var list: PackedInt32Array = face_lists[chunk]
				for idx in list:
					var x := idx % width
					var y := int(idx / width)
					for other in origins:
						if absi(x - other % width) + absi(y - int(other / width)) <= radius:
							return true
	return false


func _is_face(idx: int) -> bool:
	if not Materials.is_mineable(cells[idx]):
		return false
	var x := idx % width
	var count := cell_count()
	if idx >= width and cells[idx - width] == Materials.EMPTY:
		return true
	if x < width - 1 and cells[idx + 1] == Materials.EMPTY:
		return true
	if idx + width < count and cells[idx + width] == Materials.EMPTY:
		return true
	if x > 0 and cells[idx - 1] == Materials.EMPTY:
		return true
	return false


func _update_face(idx: int) -> void:
	var exposed := _is_face(idx)
	var slot := face_slot[idx]
	if exposed and slot < 0:
		_add_face(idx)
	elif not exposed and slot >= 0:
		_remove_face(idx)


func _update_face_neighbors(idx: int) -> void:
	var x := idx % width
	var count := cell_count()
	if idx >= width:
		_update_face(idx - width)
	if x < width - 1:
		_update_face(idx + 1)
	if idx + width < count:
		_update_face(idx + width)
	if x > 0:
		_update_face(idx - 1)


func _add_face(idx: int) -> void:
	var list: PackedInt32Array = face_lists[_chunk_index(idx)]
	face_slot[idx] = list.size()
	list.append(idx)
	face_count += 1


func _remove_face(idx: int) -> void:
	var list: PackedInt32Array = face_lists[_chunk_index(idx)]
	var slot := face_slot[idx]
	var last := list[list.size() - 1]
	list[slot] = last
	face_slot[last] = slot
	list.resize(list.size() - 1)
	face_slot[idx] = -1
	face_count -= 1


func _chunk_index(idx: int) -> int:
	var x := idx % width
	var y := int(idx / width)
	return int(y / chunk_size) * chunks_x + int(x / chunk_size)


func state_hash() -> int:
	var base := hash([hash(cells), hash(excavated), hash(progress), hash(progress_frac), mined_count, opened_count, solid_count])
	if progress_frac_high.is_empty():
		return base
	var keys: Array = progress_frac_high.keys()
	keys.sort()
	var packed := PackedInt32Array()
	for key in keys:
		packed.append(int(key))
		var limbs: Array = progress_frac_high[key]
		packed.append(limbs.size())
		for limb in limbs:
			packed.append(int(limb))
	return hash([base, hash(packed)])


func _mark_dirty(idx: int) -> void:
	var chunk := (idx / width / chunk_size) * chunks_x + (idx % width) / chunk_size
	if _chunk_dirty[chunk] == 0:
		_chunk_dirty[chunk] = 1
		_dirty_chunks.append(chunk)

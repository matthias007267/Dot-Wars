class_name WorldState
extends RefCounted
## Weltzustand als flache Arrays. Index einer Zelle = y * width + x.

var width: int
var height: int
var chunk_size: int
var chunks_x: int
var chunks_y: int

var cells := PackedByteArray()
## Abbaufortschritt je Zelle in Arbeitspunkten (immer kleiner als die Haltbarkeit).
var progress := PackedInt32Array()
## Restbrüche der Abbauleistung, kleiner als der aktuelle Nenner.
var progress_frac := PackedInt32Array()

## Zählt jede Änderung an `cells`. Abgeleitete Daten erkennen damit Veralterung.
var revision: int = 0
var solid_count: int = 0
## Unzerstörbare Zellen. Sie zählen zu solid_count, aber nicht zum abbaubaren Bestand.
var indestructible_count: int = 0
## Durch Spielmechanik (Abbau) entfernte Zellen. Generator-Aushub zählt nicht.
var mined_count: int = 0

var _chunk_dirty := PackedByteArray()
var _dirty_chunks := PackedInt32Array()


func _init(p_width: int, p_height: int, p_chunk_size: int = 32, fill_material: int = Materials.SOFT) -> void:
	width = p_width
	height = p_height
	chunk_size = p_chunk_size
	chunks_x = ceili(float(width) / chunk_size)
	chunks_y = ceili(float(height) / chunk_size)
	cells.resize(width * height)
	cells.fill(fill_material)
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
	revision += 1
	_mark_dirty(idx)


## Entfernt eine feste Zelle durch Abbau. Gibt false zurück, wenn sie bereits leer war.
func mine_cell(idx: int) -> bool:
	if not Materials.is_mineable(cells[idx]):
		return false
	set_material(idx, Materials.EMPTY)
	mined_count += 1
	return true


func carve_rect(rect: Rect2i) -> void:
	var clipped := rect.abs().intersection(Rect2i(0, 0, width, height))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			set_material(y * width + x, Materials.EMPTY)


## Anteil der abgebauten Zellen an allen ursprünglich abbaubaren Zellen (0..1).
func mined_fraction() -> float:
	var minable := solid_count - indestructible_count + mined_count
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


func state_hash() -> int:
	return hash([hash(cells), hash(progress), hash(progress_frac), mined_count, solid_count])


func _mark_dirty(idx: int) -> void:
	var chunk := (idx / width / chunk_size) * chunks_x + (idx % width) / chunk_size
	if _chunk_dirty[chunk] == 0:
		_chunk_dirty[chunk] = 1
		_dirty_chunks.append(chunk)

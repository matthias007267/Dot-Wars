class_name DigAreas
extends RefCounted
## Abbaugebiete je Gruppe: Rechteckliste (für die Zielsuche) und Maske (für O(1)-Abfragen).

var group_count: int
var width: int
var height: int
## Je Gruppe ein Array[Rect2i], bereits auf die Welt zugeschnitten.
var rects: Array = []
## Je Gruppe ein PackedByteArray (1 = Zelle gehört zum Abbaugebiet).
var masks: Array = []
## Ändert sich bei jeder semantischen Änderung der Gebiete (nicht beim Aufräumen).
var revision: int = 0


func _init(p_width: int, p_height: int, p_group_count: int) -> void:
	width = p_width
	height = p_height
	group_count = p_group_count
	for g in group_count:
		rects.append([] as Array[Rect2i])
		var mask := PackedByteArray()
		mask.resize(width * height)
		mask.fill(0)
		masks.append(mask)


## Fügt ein Abbaugebiet hinzu. Liegt es teilweise außerhalb, wird es zugeschnitten.
## Gibt false zurück, wenn nichts übrig bleibt oder die Gruppe ungültig ist.
func assign_rect(group_id: int, rect: Rect2i) -> bool:
	if group_id < 0 or group_id >= group_count:
		return false
	var clipped := rect.abs().intersection(Rect2i(0, 0, width, height))
	if not clipped.has_area():
		return false
	var group_rects: Array[Rect2i] = rects[group_id]
	group_rects.append(clipped)
	var mask: PackedByteArray = masks[group_id]
	for y in range(clipped.position.y, clipped.end.y):
		var row := y * width
		for x in range(clipped.position.x, clipped.end.x):
			mask[row + x] = 1
	revision += 1
	return true


func add_group() -> void:
	rects.append([] as Array[Rect2i])
	var mask := PackedByteArray()
	mask.resize(width * height)
	mask.fill(0)
	masks.append(mask)
	group_count += 1


func clear_group(group_id: int) -> void:
	if group_id < 0 or group_id >= group_count:
		return
	var group_rects: Array[Rect2i] = rects[group_id]
	group_rects.clear()
	var mask: PackedByteArray = masks[group_id]
	mask.fill(0)
	revision += 1


func is_marked(group_id: int, cell_idx: int) -> bool:
	var mask: PackedByteArray = masks[group_id]
	return mask[cell_idx] == 1


## Entfernt Rechtecke ohne verbleibendes festes Material. Ändert die Semantik nicht
## (leere Zellen sind ohnehin nicht abbaubar) und erhöht deshalb `revision` nicht.
func remove_rects(group_id: int, rect_indices: PackedInt32Array) -> void:
	var group_rects: Array[Rect2i] = rects[group_id]
	for i in range(rect_indices.size() - 1, -1, -1):
		group_rects.remove_at(rect_indices[i])


func state_hash() -> int:
	return hash([hash(rects), hash(masks), revision])

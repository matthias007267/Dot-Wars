class_name DotOrder
extends RefCounted
## Auswahl und Abordnung. Arbeiter und spätere Krieger sind Dot-Fraktionen mit fester Priorität.
## Eine Auswahl behält nur die Fraktion mit der höchsten Priorität. Manuelle Befehle gehen nur an diese Auswahl.

const KIND_WORKER := 0
const KIND_WARRIOR := 1


static func kind_of(_sim: Simulation, _id: int) -> int:
	return KIND_WORKER


static func priority(kind: int) -> int:
	if kind == KIND_WARRIOR:
		return 2
	if kind == KIND_WORKER:
		return 1
	return 0


## Behält die IDs, deren Art die höchste Priorität in dieser Menge hat.
static func filter_highest(ids: PackedInt32Array, kinds: PackedByteArray) -> PackedInt32Array:
	var best := -1
	for index in ids.size():
		best = maxi(best, priority(int(kinds[index])))
	var kept := PackedInt32Array()
	if best < 0:
		return kept
	for index in ids.size():
		if priority(int(kinds[index])) == best:
			kept.append(ids[index])
	return kept


## Etwa 10 % der Arbeiter dieser Fraktion, die dem Ziel am nächsten stehen. Mindestens einer.
static func nearest_share(sim: Simulation, faction: int, target: int, rect: Rect2i) -> PackedInt32Array:
	var ranked: Array = []
	var width := sim.world.width
	for id in sim.workers.count:
		if int(sim.workers.faction[id]) != faction:
			continue
		var cell := sim.workers.cell[id]
		ranked.append([_distance(cell, target, rect, width), id])
	ranked.sort()
	var kept := PackedInt32Array()
	if ranked.is_empty():
		return kept
	var count := maxi(1, roundi(float(ranked.size()) * 0.1))
	for index in mini(count, ranked.size()):
		kept.append(int(ranked[index][1]))
	return kept


static func _distance(cell: int, target: int, rect: Rect2i, width: int) -> int:
	var x := cell % width
	var y := cell / width
	if rect.has_area():
		var clamped_x := clampi(x, rect.position.x, rect.end.x - 1)
		var clamped_y := clampi(y, rect.position.y, rect.end.y - 1)
		return absi(x - clamped_x) + absi(y - clamped_y)
	if target < 0:
		return 0
	return absi(x - (target % width)) + absi(y - int(target / width))

class_name Materials
extends RefCounted
## Materialtabelle. Die Zellwerte in `WorldState.cells` sind Indizes in diese Tabellen.
## Farben sind die einzige Stelle, an der die Darstellung die Materialien kennt.

const EMPTY := 0
const SOFT := 1
const MEDIUM := 2
const HARD := 3
const INDESTRUCTIBLE := 4
const COUNT := 5

const HARDNESS: Array[int] = [0, 1, 3, 8, -1]

const COLORS: Array[Color] = [
	Color(0.07, 0.08, 0.10),
	Color(0.30, 0.74, 0.32),
	Color(0.78, 0.46, 0.16),
	Color(0.38, 0.52, 0.74),
	Color(0.20, 0.20, 0.22),
]


static func hardness(material: int) -> int:
	return HARDNESS[material]


static func is_mineable(material: int) -> bool:
	return material == SOFT or material == MEDIUM or material == HARD


## Fortschrittspunkte bis zum vollständigen Abbau.
## Beim Standard von 20 Punkten je Härtestufe entspricht das einer Simulationssekunde je Härte.
## Unzerstörbares Material hat keine Haltbarkeit.
static func durability(material: int, work_per_hardness: int) -> int:
	if not is_mineable(material):
		return 0
	return HARDNESS[material] * work_per_hardness

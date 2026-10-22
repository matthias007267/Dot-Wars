class_name Materials
extends RefCounted
## Materialtabelle. Die Zellwerte in `WorldState.cells` sind Indizes in diese Tabellen.

const EMPTY := 0
const SOFT := 1
const MEDIUM := 2
const HARD := 3
const COUNT := 4

const HARDNESS: Array[int] = [0, 1, 3, 8]

const COLORS: Array[Color] = [
	Color(0.05, 0.05, 0.07),
	Color(0.56, 0.42, 0.27),
	Color(0.42, 0.45, 0.52),
	Color(0.20, 0.21, 0.30),
]


static func hardness(material: int) -> int:
	return HARDNESS[material]


## Arbeitspunkte, die für den vollständigen Abbau einer Zelle nötig sind.
static func durability(material: int, work_per_hardness: int) -> int:
	return HARDNESS[material] * work_per_hardness

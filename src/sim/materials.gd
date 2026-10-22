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

## Premium Pixel Tactics. Leer ist der Tunnel, nicht der Hintergrund hinter der Welt.
const COLORS: Array[Color] = [
	Color8(0x16, 0x1C, 0x24),
	Color8(0x57, 0xC9, 0x6D),
	Color8(0xD3, 0x82, 0x2C),
	Color8(0x5C, 0x86, 0xDB),
	Color8(0x39, 0x3F, 0x49),
]
## Nur die Darstellung. Die Zelle bleibt unzerstörbares Material.
const PIT_COLOR := Color8(0xC7, 0x7A, 0xFF)
const BACKDROP := Color8(0x0D, 0x10, 0x15)


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

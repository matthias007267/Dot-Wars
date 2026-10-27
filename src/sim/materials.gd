class_name Materials
extends RefCounted
## Materialtabelle. Die Zellwerte in `WorldState.cells` sind Indizes in diese Tabellen.
## Palette und IDs verbinden Simulation, Minimap und Terrain-Atlas.

const EMPTY := 0
const SOFT := 1
const MEDIUM := 2
const HARD := 3
const INDESTRUCTIBLE := 4
const ROCK := SOFT
const COPPER := 5
const IRON := 6
const SILVER := 7
const GOLD := 8
const COBALT := 9
const CHROME := 10
const TITANIUM := 11
const DIAMOND := 12
const COUNT := 13
const ORES := [COPPER, IRON, SILVER, GOLD, COBALT, CHROME, TITANIUM, DIAMOND]
const ENERGY: Array[int] = [0, 1, 3, 8, 0, 3, 8, 25, 80, 250, 800, 4000, 20000]
# IDs 2/3 retain old material semantics for existing worlds and regression fixtures.
const WORK: Array[int] = [0, 1, 3, 8, 0, 1, 2, 4, 8, 16, 32, 64, 128]
const NAMES := ["Frei", "Gestein", "Altgestein mittel", "Altgestein hart", "Obsidian · unzerstörbar", "Kupfer", "Eisen", "Silber", "Gold", "Kobalt", "Chrom", "Titan", "Diamant"]

const HARDNESS: Array[int] = [0, 1, 3, 8, -1, 1, 2, 3, 4, 5, 6, 7, 8]

## Premium Pixel Tactics. Leer ist der Tunnel, nicht der Hintergrund hinter der Welt.
const COLORS: Array[Color] = [
	Color8(0x16, 0x1C, 0x24),
	Color8(0x5F, 0x6B, 0x78),
	Color8(0xD3, 0x82, 0x2C),
	Color8(0x5C, 0x86, 0xDB),
	Color8(0x39, 0x3F, 0x49),
	Color("b96b36"), Color("8e929b"), Color("d9e1ef"), Color("e8bc39"),
	Color("274de0"), Color("22ae78"), Color("ab87cb"), Color("63e0f0"),
]
## Nur die Darstellung. Die Zelle bleibt unzerstörbares Material.
const PIT_COLOR := Color8(0xC7, 0x7A, 0xFF)
## Freie Kernfläche. Leer wie ein Tunnel, aber als Fläche erkennbar. Kein eigenes Material.
const PLAZA_COLOR := Color8(0x5A, 0x3D, 0x78)
## Quelle. Die Zelle bleibt leer und begehbar.
const SOURCE_COLOR := Color8(0xB8, 0xF2, 0x5A)
## Veredler. Die Zelle bleibt leer und begehbar.
const REFINERY_COLOR := Color8(0x9E, 0xF6, 0xE8)
const BACKDROP := Color8(0x0D, 0x10, 0x15)


static func hardness(material: int) -> int:
	return HARDNESS[material]


static func is_mineable(material: int) -> bool:
	return material > EMPTY and material < COUNT and material != INDESTRUCTIBLE


## Fortschrittspunkte bis zum vollständigen Abbau.
## Neue Erzhärten 1–8 benötigen bei 20 Punkten/s die Dauer 1/2/4/8/16/32/64/128 s.
## Unzerstörbares Material hat keine Haltbarkeit.
static func durability(material: int, work_per_hardness: int) -> int:
	if not is_mineable(material):
		return 0
	return WORK[material] * work_per_hardness

static func energy(material: int) -> int:
	return ENERGY[material] if material >= 0 and material < COUNT else 0

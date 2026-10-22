class_name Upgrades
extends RefCounted
## Energie und Käufe eines Durchlaufs. Kosten und Wirkungen sind Ganzzahlen.

const SPEED_BASE := 25
const DIG_BASE := 50
const FUSION2_COST := 100
const FUSION3_COST := 250

const KIND_SPEED := 0
const KIND_DIG := 1
const KIND_FUSION2 := 2
const KIND_FUSION3 := 3

var energy: int = 0
var speed_level: int = 0
var dig_level: int = 0
var fusion2: bool = false
var fusion3: bool = false
var purchased: int = 0


func speed_cost() -> int:
	return SPEED_BASE * (speed_level + 1)


func dig_cost() -> int:
	return DIG_BASE * (dig_level + 1)


func fusion2_cost() -> int:
	return FUSION2_COST


func fusion3_cost() -> int:
	return FUSION3_COST


func max_size() -> int:
	if fusion3:
		return 3
	if fusion2:
		return 2
	return 1


## Bewegungspunkte je Takt. 50 sind ein Schritt alle zwei Takte. Obergrenze ist ein Schritt je Takt.
func move_points(base_period: int) -> int:
	var points := 100 / base_period
	var num := points
	var den := 1
	for _level in speed_level:
		num *= 6
		den *= 5
	return mini(100, num / den)


## Zähler und Nenner der Abbauleistung. Basis 1/1, jede Stufe multipliziert mit 5/4.
func dig_fraction() -> Vector2i:
	var num := 1
	var den := 1
	for _level in dig_level:
		num *= 5
		den *= 4
	return Vector2i(num, den)


func try_buy(kind: int) -> bool:
	var cost := _cost(kind)
	if cost < 0 or energy < cost:
		return false
	energy -= cost
	purchased += 1
	match kind:
		KIND_SPEED:
			speed_level += 1
		KIND_DIG:
			dig_level += 1
		KIND_FUSION2:
			fusion2 = true
		KIND_FUSION3:
			fusion3 = true
	return true


func state_hash() -> int:
	return hash([energy, speed_level, dig_level, fusion2, fusion3, purchased])


func _cost(kind: int) -> int:
	match kind:
		KIND_SPEED:
			return speed_cost()
		KIND_DIG:
			return dig_cost()
		KIND_FUSION2:
			return -1 if fusion2 else FUSION2_COST
		KIND_FUSION3:
			return -1 if fusion3 or not fusion2 else FUSION3_COST
	return -1

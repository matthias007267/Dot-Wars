class_name Upgrades
extends RefCounted
## Energie und Käufe eines Durchlaufs. Kosten und Wirkungen sind Ganzzahlen.

const SPEED_BASE := 25
const SPEED_MAX := 5
const ENERGY_SPEED_BASE := 30
const ENERGY_SPEED_MAX := 5
const DIG_BASE := 50
const FUSION2_COST := 100
const FUSION3_COST := 250
const CORE_BASE := 40
const CORE_MAX := 4
const RESEARCH_BASE := 50
const RESEARCH_MAX := 5
## Takte zwischen zwei Schritten. Index ist die gekaufte Stufe. 8 ist der langsame Start.
const PACE_LADDER := [8, 6, 4, 3, 2, 1]

const KIND_SPEED := 0
const KIND_DIG := 1
const KIND_FUSION2 := 2
const KIND_FUSION3 := 3
const KIND_CORE := 4
const KIND_ENERGY_SPEED := 5
const KIND_RESEARCH := 6

var energy: int = 0
var speed_level: int = 0
var energy_speed_level: int = 0
## Jede Stufe multipliziert die Abbauleistung mit 5/4. Gerechnet wird das in `MiningSystem`.
var dig_level: int = 0
var fusion2: bool = false
var fusion3: bool = false
var core_level: int = 0
var research_level: int = 0
var purchased: int = 0


func speed_cost() -> int:
	if speed_level >= SPEED_MAX:
		return -1
	return SPEED_BASE * (speed_level + 1)


func energy_speed_cost() -> int:
	if energy_speed_level >= ENERGY_SPEED_MAX:
		return -1
	return ENERGY_SPEED_BASE * (energy_speed_level + 1)


func dig_cost() -> int:
	return DIG_BASE * (dig_level + 1)


func fusion2_cost() -> int:
	return FUSION2_COST


func fusion3_cost() -> int:
	return FUSION3_COST


func core_cost() -> int:
	if core_level >= CORE_MAX:
		return -1
	return CORE_BASE * (core_level + 1)


func research_cost() -> int:
	if research_level >= RESEARCH_MAX:
		return -1
	return RESEARCH_BASE * (research_level + 1)


func max_size() -> int:
	if fusion3:
		return 3
	if fusion2:
		return 2
	return 1


## Takte zwischen zwei Arbeiterschritten. Stufe 0 nutzt die konfigurierte Periode.
func worker_period(configured: int) -> int:
	if speed_level <= 0:
		return maxi(1, configured)
	return PACE_LADDER[mini(speed_level, PACE_LADDER.size() - 1)]


## Takte zwischen zwei Energieschritten. Stufe 0 ist der langsame Start.
func energy_period() -> int:
	return PACE_LADDER[mini(energy_speed_level, PACE_LADDER.size() - 1)]


func next_worker_period(configured: int) -> int:
	if speed_level >= SPEED_MAX:
		return 1
	if speed_level <= 0:
		return PACE_LADDER[1]
	return PACE_LADDER[mini(speed_level + 1, SPEED_MAX)]


func next_energy_period() -> int:
	if energy_speed_level >= ENERGY_SPEED_MAX:
		return 1
	return PACE_LADDER[mini(energy_speed_level + 1, ENERGY_SPEED_MAX)]


func pace_text(period: int) -> String:
	if period <= 1:
		return "jeder Takt"
	return "alle %d Takte" % period


func try_buy(kind: int) -> bool:
	var cost := _cost(kind)
	if cost < 0 or energy < cost:
		return false
	energy -= cost
	purchased += 1
	match kind:
		KIND_SPEED:
			speed_level += 1
		KIND_ENERGY_SPEED:
			energy_speed_level += 1
		KIND_DIG:
			dig_level += 1
		KIND_FUSION2:
			fusion2 = true
		KIND_FUSION3:
			fusion3 = true
		KIND_CORE:
			core_level += 1
		KIND_RESEARCH:
			research_level += 1
	return true


func state_hash() -> int:
	return hash([
		energy, speed_level, energy_speed_level, dig_level, fusion2, fusion3, core_level, research_level, purchased,
	])


func _cost(kind: int) -> int:
	match kind:
		KIND_SPEED:
			return speed_cost()
		KIND_ENERGY_SPEED:
			return energy_speed_cost()
		KIND_DIG:
			return dig_cost()
		KIND_FUSION2:
			return -1 if fusion2 else FUSION2_COST
		KIND_FUSION3:
			return -1 if fusion3 or not fusion2 else FUSION3_COST
		KIND_CORE:
			return core_cost()
		KIND_RESEARCH:
			return research_cost()
	return -1

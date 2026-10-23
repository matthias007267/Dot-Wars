class_name SimConfig
extends RefCounted
## Alle Parameter der Simulation. Wird vor dem Start validiert und danach nicht mehr verändert.

const TICKS_PER_SECOND := 20
const MAX_GROUPS := 8
const MAX_DURABILITY := 1_000_000

## Räumung ist der bisherige Sieg. Förderung zählt gelieferte Energie. Veredelung zählt nur veredelte Dots.
const MODE_CLEARING := 0
const MODE_EXTRACTION := 1
const MODE_REFINING := 2
const MODE_MATCH := 3
## Vorläufige Modusziele. Sie gelten nur in ihrem Modus.
const EXTRACTION_GOAL := 1000
const REFINING_GOAL := 400
## Schwierigkeit der KI. Mittel ist der bisherige Plan. Gemischt verteilt die Pläne.
const DIFFICULTY_EASY := 0
const DIFFICULTY_NORMAL := 1
const DIFFICULTY_HARD := 2
const DIFFICULTY_MIXED := 3

var world_size: int = 256
var world_seed: int = 1337
var chunk_size: int = 32
var mode: int = MODE_CLEARING
## Nur Mehrspieler. 0 lässt Räumung, Förderung und Veredelung unverändert.
var ai_count: int = 0
## Bitmaske aus MatchRules. Standard sind alle vier Ziele.
var victory_mask: int = 15
## Nur Mehrspieler. Einzelspieler lässt den Wert stehen und ignoriert ihn.
var difficulty: int = DIFFICULTY_NORMAL

var initial_workers: int = 5
var tunnel_arm_length: int = 5

## Verteilung der Materialien in Prozent (Rest = hartes Material).
var soft_percent: int = 45
var medium_percent: int = 35

## Zielquoten der Gruppen in ganzen Prozent. Summe muss 100 ergeben.
var group_quotas: PackedInt32Array = PackedInt32Array([50, 50])

## Fortschrittspunkte je Härtestufe.
## 20 Punkte sind eine Arbeitseinheit und damit eine Simulationssekunde.
## Ein Basis-Arbeiter braucht für Härte 8 deshalb genau 8 Sekunden.
var work_per_hardness: int = TICKS_PER_SECOND
## Fortschrittspunkte, die ein Arbeiter pro Tick beiträgt.
var dig_power: int = 1
## Ein Arbeiter bewegt sich alle `move_period_ticks` Takte um eine Zelle.
## 8 ist der langsame Start. Die Fähigkeit Arbeiter verkürzt das in Stufen bis auf 1.
var move_period_ticks: int = 8

## Zellbesuche pro Tick und Gruppe für die Zielsuche.
var field_budget_per_tick: int = 2048
## Maximale Zahl untersuchter Zellen bei der Suche nach einem freien Entstehungsort.
var spawn_search_limit: int = 2048


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if mode < MODE_CLEARING or mode > MODE_MATCH:
		errors.append("mode muss Räumung, Förderung, Veredelung oder Mehrspieler sein")
	if mode == MODE_MATCH and (ai_count < 1 or ai_count > 3):
		errors.append("ai_count muss zwischen 1 und 3 liegen")
	if mode == MODE_MATCH and (victory_mask & 15) == 0:
		errors.append("mindestens ein Spielziel")
	if mode == MODE_MATCH and world_size < 32:
		errors.append("Mehrspieler braucht mindestens 32 Zellen")
	if difficulty < DIFFICULTY_EASY or difficulty > DIFFICULTY_MIXED:
		errors.append("difficulty muss leicht, mittel, schwer oder gemischt sein")
	if world_size < 16 or world_size > 4096:
		errors.append("world_size muss zwischen 16 und 4096 liegen")
	if chunk_size < 8 or chunk_size > 128:
		errors.append("chunk_size muss zwischen 8 und 128 liegen")
	if initial_workers < 1:
		errors.append("initial_workers muss mindestens 1 sein")
	if tunnel_arm_length < 1 or tunnel_arm_length * 2 + 2 > world_size:
		errors.append("tunnel_arm_length passt nicht in die Welt")
	if soft_percent < 0 or medium_percent < 0 or soft_percent + medium_percent > 100:
		errors.append("Materialanteile müssen ≥ 0 sein und höchstens 100 ergeben")
	if work_per_hardness < 1 or work_per_hardness * 8 > MAX_DURABILITY:
		errors.append("work_per_hardness ungültig (1 bis %d)" % (MAX_DURABILITY / 8))
	if dig_power < 1:
		errors.append("dig_power muss mindestens 1 sein")
	if move_period_ticks < 1:
		errors.append("move_period_ticks muss mindestens 1 sein")
	if field_budget_per_tick < 64:
		errors.append("field_budget_per_tick muss mindestens 64 sein")
	if spawn_search_limit < 1:
		errors.append("spawn_search_limit muss mindestens 1 sein")
	errors.append_array(GroupQuotas.validate(group_quotas))
	return errors


## Sekunden, die ein Arbeiter mit dem gesetzten dig_power für diese Härte braucht.
func seconds_for_hardness(hardness: int) -> float:
	return float(hardness * work_per_hardness) / float(dig_power * TICKS_PER_SECOND)


## Liest `--size=N` und `--seed=N` aus den Benutzerargumenten (hinter `--`).
static func from_cmdline(args: PackedStringArray) -> SimConfig:
	var config := SimConfig.new()
	for arg in args:
		if arg.begins_with("--size="):
			config.world_size = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--seed="):
			config.world_seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--mode="):
			config.mode = _mode_from_arg(arg.get_slice("=", 1))
			if config.mode == MODE_MATCH and config.ai_count < 1:
				config.ai_count = 1
		elif arg.begins_with("--ai="):
			config.ai_count = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--siege="):
			config.victory_mask = _victories_from_arg(arg.get_slice("=", 1))
		elif arg.begins_with("--schwierigkeit="):
			config.difficulty = _difficulty_from_arg(arg.get_slice("=", 1))
	return config


static func _mode_from_arg(name: String) -> int:
	match name:
		"foerderung", "1":
			return MODE_EXTRACTION
		"veredelung", "2":
			return MODE_REFINING
		"mehrspieler", "match", "3":
			return MODE_MATCH
		_:
			return MODE_CLEARING


static func difficulty_name(level: int) -> String:
	match level:
		DIFFICULTY_EASY:
			return "Leicht"
		DIFFICULTY_HARD:
			return "Schwer"
		DIFFICULTY_MIXED:
			return "Gemischt"
		_:
			return "Mittel"


static func _difficulty_from_arg(name: String) -> int:
	match name:
		"leicht", "0":
			return DIFFICULTY_EASY
		"schwer", "2":
			return DIFFICULTY_HARD
		"gemischt", "3":
			return DIFFICULTY_MIXED
		_:
			return DIFFICULTY_NORMAL


static func _victories_from_arg(name: String) -> int:
	if name.is_valid_int():
		return name.to_int()
	var mask := 0
	for part in name.split(","):
		match part:
			"ausloeschen":
				mask |= 1
			"forschung":
				mask |= 2
			"reliquien":
				mask |= 4
			"huegel":
				mask |= 8
	return 15 if mask == 0 else mask

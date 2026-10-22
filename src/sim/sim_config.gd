class_name SimConfig
extends RefCounted
## Alle Parameter der Simulation. Wird vor dem Start validiert und danach nicht mehr verändert.

const TICKS_PER_SECOND := 20
const MAX_GROUPS := 8
const MAX_DURABILITY := 1_000_000

var world_size: int = 256
var world_seed: int = 1337
var chunk_size: int = 32

var initial_workers: int = 5
var tunnel_arm_length: int = 5

## Verteilung der Materialien in Prozent (Rest = hartes Material).
var soft_percent: int = 45
var medium_percent: int = 35

## Zielquoten der Gruppen in ganzen Prozent. Summe muss 100 ergeben.
var group_quotas: PackedInt32Array = PackedInt32Array([50, 50])

## Arbeitspunkte je Härtestufe, die zum vollständigen Abbau nötig sind.
var work_per_hardness: int = 10
## Arbeitspunkte, die ein Arbeiter pro Tick beiträgt.
var dig_power: int = 1
## Ein Arbeiter bewegt sich alle `move_period_ticks` Takte um eine Zelle.
var move_period_ticks: int = 2

## Zellbesuche pro Tick und Gruppe für die Zielsuche.
var field_budget_per_tick: int = 8192
## Maximale Zahl untersuchter Zellen bei der Suche nach einem freien Entstehungsort.
var spawn_search_limit: int = 2048


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
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


## Liest `--size=N` und `--seed=N` aus den Benutzerargumenten (hinter `--`).
static func from_cmdline(args: PackedStringArray) -> SimConfig:
	var config := SimConfig.new()
	for arg in args:
		if arg.begins_with("--size="):
			config.world_size = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--seed="):
			config.world_seed = arg.get_slice("=", 1).to_int()
	return config

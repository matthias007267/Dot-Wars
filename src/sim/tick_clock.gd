class_name TickClock
extends RefCounted
## Wandelt Echtzeit in ganzzahlige Simulationstakte um (feste 20 Hz) und unterstützt Pause.
##
## Rechnet in ganzen Mikrosekunden, damit die Taktzahl unabhängig von der Aufteilung der
## Frame-Zeiten exakt reproduzierbar ist.

const STEP_USEC := 1_000_000 / SimConfig.TICKS_PER_SECOND

## Begrenzt den Aufholbedarf nach einem langen Frame (verhindert die „Spirale des Todes“).
var max_ticks_per_advance: int = 5
var paused: bool = false
## 1, 2 oder 4. Wirkt auf die angesammelte Zeit, nicht auf die Taktlänge.
var speed: int = 1

## Nur Diagnose: Ereignisse und Zeitverlust am bestehenden Aufhollimit.
var catch_up_limit_hits: int = 0
var discarded_usec: int = 0

var _accumulator_usec: int = 0
var _last_wall_usec: int = -1


## Gibt die Zahl der jetzt auszuführenden Takte zurück. Während der Pause: immer 0,
## ohne dass sich Zeit ansammelt.
func advance(delta_seconds: float) -> int:
	if paused:
		return 0
	var factor := speed if speed > 0 else 1
	_accumulator_usec += int(roundf(delta_seconds * 1_000_000.0)) * factor
	var ticks := mini(_accumulator_usec / STEP_USEC, max_ticks_per_advance)
	if ticks == max_ticks_per_advance:
		catch_up_limit_hits += 1
		discarded_usec += _accumulator_usec - ticks * STEP_USEC
	_accumulator_usec = 0 if ticks == max_ticks_per_advance else _accumulator_usec - ticks * STEP_USEC
	return ticks


## Godots Frame-delta kann bei langen Frames Zeit auslassen. Die Simulation misst
## deshalb ihre eigene Echtzeit. Pause und das bestehende Aufhollimit bleiben gleich.
func advance_wall_time(now_usec: int) -> int:
	if _last_wall_usec < 0:
		_last_wall_usec = now_usec
		return 0
	var elapsed := maxi(0, now_usec - _last_wall_usec)
	_last_wall_usec = now_usec
	return advance(elapsed / 1000000.0)


func reset() -> void:
	_last_wall_usec = -1
	_accumulator_usec = 0
	catch_up_limit_hits = 0
	discarded_usec = 0

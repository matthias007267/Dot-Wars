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

var _accumulator_usec: int = 0


## Gibt die Zahl der jetzt auszuführenden Takte zurück. Während der Pause: immer 0,
## ohne dass sich Zeit ansammelt.
func advance(delta_seconds: float) -> int:
	if paused:
		return 0
	_accumulator_usec += int(roundf(delta_seconds * 1_000_000.0))
	var ticks := mini(_accumulator_usec / STEP_USEC, max_ticks_per_advance)
	_accumulator_usec = 0 if ticks == max_ticks_per_advance else _accumulator_usec - ticks * STEP_USEC
	return ticks


func reset() -> void:
	_accumulator_usec = 0

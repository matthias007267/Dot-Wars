# DOT WARS

Minimalistisches Echtzeit-Strategiespiel mit Godot 4. Die verbindlichen Regeln stehen in `docs/GAME_DESIGN.md`, die Architektur in `docs/ARCHITECTURE.md`, der Phasenstand in `docs/ROADMAP.md`. Agenten arbeiten nach `AGENTS.md`.

Der aktuelle Stand ist die Projektgrundlage plus ein headlesser Simulationsprototyp. Die Hauptszene zeigt diesen Stand. Eine spielbare Weltansicht gibt es noch nicht.

## Voraussetzungen

* Godot 4.3, Standardvariante (nicht .NET)
* Git

Godot 4.3 wird lokal und in GitHub Actions verwendet.

## Projekt starten

```bash
godot --path .
```

Andere Entwicklungsgröße oder anderer Seed, die Argumente stehen hinter `--`:

```bash
godot --path . -- --size=64 --seed=7
```

Die Szene prüft die Konfiguration, erzeugt die Simulation und zeigt Weltgröße, Seed, Arbeiterzahl und die Abbaudauern. Härte 8 dauert 8 Sekunden. Bei einem Fehler beendet sich das Programm mit Code 1.

Headless, ohne Fenster:

```bash
godot --headless --path . --quit-after 8
```

Eine erfolgreiche Prüfung schreibt `DOT WARS bereit` in die Ausgabe.

## Tests

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

Ein optionaler Filter wählt Dateien:

```bash
godot --headless --path . -s tests/run_tests.gd -- mining
```

Der Runner endet mit Code 1, wenn eine Prüfung fehlschlägt oder kein Test läuft. GitHub Actions führt dieselben Tests und den Headless-Start aus.

## Benchmark

Der Benchmark misst nur die Simulation, nicht die Bildrate.

```bash
godot --headless --path . -s bench/benchmark.gd -- --workers=1000,10000 --ticks=200
```

Ergebnisse und die Grenzen der Messung stehen in `docs/PERFORMANCE.md`.

## Struktur

```
src/sim/                 headlesse Simulation
src/main.gd              Hauptszene
scenes/main.tscn
tests/                   Test-Runner und Fälle
bench/benchmark.gd
docs/                    Regeln, Architektur, Entscheidungen, Roadmap, Messungen
.github/workflows/       CI
```

## Phasen

Es wird nur die ausdrücklich freigegebene Phase umgesetzt. Danach wird auf die nächste Freigabe gewartet. Der Stand steht in `docs/ROADMAP.md`.

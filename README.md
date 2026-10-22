# DOT WARS

Minimalistisches Echtzeit-Strategiespiel mit Godot 4. Die verbindlichen Regeln stehen in `docs/GAME_DESIGN.md`, die Architektur in `docs/ARCHITECTURE.md`, der Phasenstand in `docs/ROADMAP.md`. Agenten arbeiten nach `AGENTS.md`.

Der aktuelle Stand zeigt die generierte Dot-Welt mit fünf Arbeitern. Ein Linksklick auf eine leere Zelle setzt das gemeinsame Laufziel. Ohne Abbauauftrag wird nichts abgebaut.

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

Die Szene prüft die Konfiguration, zeichnet die Welt und lässt die Arbeiter mit 20 Takten pro Sekunde laufen. Härte 8 dauert in der Simulation 8 Sekunden. Bei einem Fehler beendet sich das Programm mit Code 1.

Steuerung im Fenster:

* Linksklick auf eine leere Zelle setzt das Laufziel für beide Gruppen. Ein Klick auf Material wird verworfen.
* Leertaste pausiert die Simulation und setzt sie fort. Während der Pause läuft keine Zeit nach.
* Mausrad zoomt zur Cursorposition
* Rechte oder mittlere Maustaste verschiebt die Ansicht, ebenso WASD und die Pfeiltasten
* `G` schaltet das Zellraster ein, sobald eine Zelle mindestens 8 Pixel groß ist
* `C` schaltet die Chunk-Grenzen ein

Gelb und Cyan sind die beiden Gruppen. Die Arbeiter stehen zu Beginn auf dem Starttunnel.

Der Zoom reicht von der ganzen Welt im Fenster bis zu 40 Pixeln je Zelle. Gestartet wird mit 10 Pixeln je Zelle auf dem Starttunnel.

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

Der Simulations-Benchmark misst keine Bildrate. Die Darstellung hat einen eigenen Messlauf.

```bash
godot --headless --path . -s bench/benchmark.gd -- --workers=1000,10000 --ticks=200
godot --path . -- --size=1000 --frames=150 --window=1920x1080
```

Ergebnisse und die Grenzen der Messung stehen in `docs/PERFORMANCE.md`.

## Struktur

```
src/sim/                 headlesse Simulation
src/main.gd              Hauptszene, Takt, Laufziel, Pause
src/render/              Kamera, Weltbild, Arbeiter, Koordinaten
scenes/main.tscn
tests/                   Test-Runner und Fälle
bench/benchmark.gd
docs/                    Regeln, Architektur, Entscheidungen, Roadmap, Messungen
.github/workflows/       CI
```

## Phasen

Es wird nur die ausdrücklich freigegebene Phase umgesetzt. Danach wird auf die nächste Freigabe gewartet. Der Stand steht in `docs/ROADMAP.md`.

# DOT WARS

Minimalistisches Echtzeit-Strategiespiel mit Godot 4. Die verbindlichen Regeln stehen in `docs/GAME_DESIGN.md`, die Architektur in `docs/ARCHITECTURE.md`, der Phasenstand in `docs/ROADMAP.md`. Agenten arbeiten nach `AGENTS.md`.

`godot --path .` öffnet das Startmenü. „Neues Spiel“ startet die Welt. Das reduzierte HUD zeigt Masse, Energie, Abbaufortschritt und Missionsziele. Farbgruppen werden intern verwaltet und erscheinen nicht mehr als eigene Spielereinstellung. Beim Abbau entstehen ausschließlich Energie-Dots (Härte 1/3/8 → 1/3/8), die zum Energiekern transportiert werden. Nur eingelagerte Energie kann ausgegeben werden.

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

* „Abbau“ ist der Startmodus. Ziehen mit der linken Taste markiert das Abbaugebiet des Schwarms. Die Fläche bleibt als Rahmen sichtbar.
* „Bewegen“ und ein Klick in einen Tunnel setzen den Sammelpunkt. Er wird als farbige Zelle gezeichnet.
* „Opfern“ schickt die letzte Schwarmfarbe zum Opferloch. Ein zweiter Klick holt sie zurück. Die Leiste zeigt, welche Farbe opfert.
* „1×1“, „2×2“ und „3×3“ setzen die Wunschgröße. 2×2 und 3×3 brauchen das passende Upgrade.
* „Upgrades“ öffnet Tempo, Abbau und Verschmelzung. „1×“ wechselt auf 2× und 4×.
* „Speichern“ und „Laden“ nutzen `user://slot.dw`, ebenso F5 und F9. Alle 600 Takte entsteht `user://autosave.dw`.
* Leertaste oder „Pause“ hält die Simulation an. F11 schaltet Vollbild.
* Die Übersicht unten rechts springt die Kamera. Mausrad zoomt zur Cursorposition.
* Rechte oder mittlere Maustaste verschiebt die Ansicht, ebenso WASD und die Pfeiltasten.
* `G` schaltet das Zellraster ein, sobald eine Zelle mindestens 8 Pixel groß ist.
* `C` schaltet die Chunk-Grenzen ein.

Ohne Argumente erscheint das Menü. `--size`, `--seed`, `--play` oder ein Headless-Start überspringen es. Aktuell gibt es nur zwei bewegliche Dot-Arten: gelbe Arbeiter und cyanfarbene Energie-Dots. Rote Krieger-Dots sind für später geplant. Interne Farbgruppen teilen sich dieselbe Arbeiterfarbe.

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
src/main.gd              Menü, Takt, Aufträge
src/ui/                  Startmenü, reduziertes HUD, klickbare Minimap
src/render/              Kamera, Weltbild, Arbeiter, Auftragsrahmen, Koordinaten
scenes/main.tscn
tests/                   Test-Runner und Fälle
bench/benchmark.gd
docs/                    Regeln, Architektur, Entscheidungen, Roadmap, Messungen
.github/workflows/       CI
```

## Phasen

Die Phasen 1 bis 10 liegen in Review auf demselben Pull Request. Der Stand steht in `docs/ROADMAP.md`. Veröffentlichung und Windows-Export stehen in `docs/RELEASE.md`.

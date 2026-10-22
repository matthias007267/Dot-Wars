# Architektur

Engine ist Godot 4.3 mit GDScript und dem Renderer `gl_compatibility`. Zielplattform ist Windows. Linux wird für headless Tests genutzt.

## Grundsatz

Die Simulation kennt keine Szene. Alles unter `src/sim/` sind `RefCounted`-Klassen ohne Nodes, Eingabe oder Zeichenbefehle. Darstellung und UI lesen den Zustand und schreiben nur über die API von `Simulation`.

Es gibt keine Node pro Zelle und keine pro Arbeiter. Welt und Arbeiter liegen in Packed-Arrays. Systeme sind zustandslose Funktionen über diese Daten, damit sie später durch eine GDExtension mit gleicher Signatur ersetzt werden können.

Die Simulation läuft mit 20 Takten pro Sekunde. Spielregeln rechnen mit ganzen Zahlen. Gleicher Seed und gleiche Befehle ergeben denselben `state_hash()`.

## Struktur

```
src/sim/          Simulation, headless
src/main.gd       Menü, Takt, Mausaufträge, Pause
src/ui/           Startmenü, reduziertes HUD und Weltübersicht
src/render/       Kamera, Weltbild, Arbeiter, Auftragsrahmen, Koordinaten
scenes/main.tscn
tests/            projekteigener Test-Runner und Tests
bench/            headless Benchmark
docs/             verbindliche Dokumentation
.github/workflows/tests.yml
```

| Modul | Aufgabe |
|---|---|
| `SimConfig` | Weltgröße, Seed, Quoten, Abbau- und Bewegungswerte, Prüfung |
| `Materials` | Härte 1, 3, 8, unzerstörbar, Farben |
| `WorldCoordinates` | Zelle, Welt, Bildschirm |
| `WorldRenderer` | eine Textur, Chunk-Aktualisierung, Raster, Texturzugriff für Minimap |
| `WorkerRenderer` | zweite Textur, Fußabdruck je Einheit, nur geänderte Pixel |
| `OrderOverlay` | Rahmen der Abbaugebiete und Markierung der Sammelpunkte |
| `CameraController` | Zoom, Verschieben, Grenzen, Minimap-Sprung |
| `WorldState` | Zellen, Fortschritt, Chunk-Dirty-Flags |
| `WorldGenerator` | reproduzierbare Welt und Starttunnel |
| `WorkerStore` | Einheiten als Struct-of-Arrays, Zelle, Gruppe, Fraktion, Größe, Masse |
| `DigAreas` | Rechtecke und Masken je Gruppe |
| `FlowField` | gemeinsame, budgetierte Zielsuche je Gruppe, plus Laufziel |
| `MovementSystem` | orthogonale Schritte |
| `MiningSystem` | Zielwahl und Fortschritt an der Zelle, Bruchleistung großer Einheiten |
| `FusionSystem` | Wunschgröße, Masse bleibt erhalten |
| `SacrificeSystem` | Einlieferung am Opferloch, letzte Masse bleibt |
| `Upgrades` | Energie, Kosten, Tempo, Abbau, Verschmelzungsstufen |
| `SaveGame` | Speicherstand Version 1 |
| `SpawnSystem` | ein neuer Arbeiter pro Feld, Warteschlange |
| `GroupQuotas` | Quotenprüfung und Defizitverfahren |
| `TickClock` | feste Takte, Pause ohne Nachholen |
| `Simulation` | Reihenfolge der Systeme, Statistik, Invarianten |

Verschmelzung, Opferloch, Upgrades, Siegbedingungen und Speicherstände hängen an `Simulation.tick_once`. Leere Platzhalterklassen werden nicht angelegt.

## Welt und Arbeiter

`cells` ist ein `PackedByteArray`, Index `y * width + x`. `progress` speichert Fortschrittspunkte, die noch unter der Haltbarkeit liegen. Chunks sind standardmäßig 32×32. Jede Änderung markiert genau einen Chunk. `revision` zählt Weltänderungen.

Ein Basis-Arbeiter hat Zelle, Gruppe, Fraktion, Zustand, Ziel und den Tick der letzten Bewegung. Die Fraktion ist ein Byte und steht beim Anlegen auf 0. `occupant` bildet die Zelle auf die Arbeiter-ID ab. IDs sind im Prototyp dicht, weil Arbeiter noch nicht entfernt werden.

## Takt

`Simulation.tick_once` macht in dieser Reihenfolge: Zielsuche, Bewegung, Abbau, Entstehung, Verschmelzung, Opferung, danach die Siegprüfung. Innerhalb eines Systems gilt aufsteigende ID. Das ist die Konfliktauflösung und hält den Takt deterministisch.

`TickClock` wandelt Frame-Zeit in Takte um, 50 ms pro Takt, höchstens fünf Takte pro Frame. In der Pause vergeht keine Simulationszeit.

## Abbauzeit

Haltbarkeit = Härte × `work_per_hardness`. Der Standard von `work_per_hardness` ist 20, also eine Simulationssekunde je Härtepunkt. `dig_power` 1 ist ein Fortschrittspunkt pro Tick. Härte 8 braucht 160 Punkte und damit 8 Sekunden. Der Fortschritt liegt an der Zelle. Die erste Prüfung im Tick, die die Haltbarkeit erreicht, entfernt die Zelle. Weitere Arbeiter desselben Ticks sehen eine leere Zelle.

## Zielsuche

Pro Gruppe gibt es ein Flow-Field. Quellen sind leere Zellen neben festem, markiertem Material und, wenn gesetzt, eine leere Laufzielzelle. Eine Multi-Source-BFS schreibt Distanz und Richtung in einen Hintergrundpuffer und wird erst nach Abschluss sichtbar. Pro Tick gilt ein festes Budget an Zellbesuchen. Ein neues Laufziel startet den Aufbau neu.

Das Feld ist ein Hinweis. Bewegung und Abbau prüfen den aktuellen Weltzustand. Zellen ohne Verbindung bleiben ohne Richtung, der Arbeiter wartet.

Bis zu 32 Materialänderungen korrigieren das letzte veröffentlichte Feld. Größere Änderungen, ein neues Gebiet und ein neues Laufziel bauen es vollständig neu auf. Die Grenze und der Abhängigkeitskegel stehen in D-020.

## Entstehung

Jede abgebaute Zelle wird ein FIFO-Eintrag. Ist der Ort belegt, sucht eine BFS in der Reihenfolge Nord, Ost, Süd, West die nächste freie leere Zelle. Findet sie keine, bleibt der Eintrag liegen. Die Gruppe wählt `GroupQuotas.pick_group`: kleinster Quotient Anzahl/Quote, bei Gleichstand die größere Quote, danach der kleinere Index. Quote 0 wird nie gewählt.

Masseninvariante: lebende Masse plus wartende Entstehungen = Startmasse plus abgebaute Zellen minus geopferte Masse. `Simulation.check_invariants()` prüft das zusammen mit der Belegung.

## Darstellung

`WorldRenderer` schreibt die Zellen in ein RGBA-Bild, ein Pixel pro Zelle, und lädt es als eine Textur mit nächstem Nachbarn. Nach dem ersten Bild werden nur noch schmutzige Chunks neu gemalt. `_draw` zeichnet diese eine Textur. Rasterlinien erscheinen ab 8 Pixeln je Zelle und nur im sichtbaren Ausschnitt. Chunk-Grenzen sind zuschaltbar.

`WorldCoordinates` rechnet ohne Szene zwischen Bildschirm, Welt und Zelle. Die Kamera hat keine Drehung. Bildmitte ist die Kameraposition.

`WorkerRenderer` schreibt die Arbeiter in eine zweite RGBA-Textur mit transparentem Grund. Die Farben stehen in `Simulation.GROUP_PALETTE`; die ersten beiden sind Gelb `#FFE45E` und Blau `#53C7FF`. Die Textur wird neu gefüllt, wenn ein neuer Simulationstakt gezeichnet wird. `_draw` zeichnet diese eine Textur. Es gibt keine Node pro Arbeiter und keinen Lichtakzent je Einheit. Die Opferlochzelle wird beim Malen `#C77AFF`, ohne den Materialwert zu ändern.

Die Hauptszene erzeugt die Simulation, zeichnet Welt und Arbeiter und treibt `TickClock` mit 20 Hz. `GameHud` bündelt Spielerbefehle für alle arbeitenden internen Farbgruppen und zeigt die Schwarmfarben. Abbau zieht ein Gebiet auf, Bewegung setzt per Linksklick einen gemeinsamen Sammelpunkt; eine Teilgruppe übernimmt auf Anforderung die Opferung. `OrderOverlay` zeichnet diese Aufträge. Quotenverwaltung existiert nur noch intern. `WorldMinimap` zeigt die vorhandene Welttextur und lässt die Kamera zum angeklickten Punkt springen. Die Leertaste schaltet die Pause. Eine ungültige Konfiguration oder eine verletzte Startinvariante beendet das Programm mit Code 1.

## Tests

`godot --headless --path . -s tests/run_tests.gd` führt jede Methode mit Präfix `test_` in `tests/test_*.gd` aus. Der Runner ist Teil des Projekts. Es gibt keine zusätzliche Testbibliothek. Exit-Code 1 bedeutet Fehler oder keine Tests. GitHub Actions installiert Godot 4.3, importiert das Projekt, führt die Tests aus und startet die Hauptszene headless.

## Erweiterungspunkte, ohne Implementierung

| Späteres System | Anknüpfung |
|---|---|
| Mehrere Fraktionen | `WorkerStore.faction` ist vorhanden. Die Ansicht setzt immer 0. |
| GDExtension | `MovementSystem`, `MiningSystem`, `FlowField` haben datenorientierte Signaturen |

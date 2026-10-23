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
| `EnergyRenderer` | cyanfarbene Energie-Dots, unter den Arbeitern |
| `WorkerRenderer` | zweite Textur, Fußabdruck je Einheit, nur geänderte Pixel |
| `OrderOverlay` | Rahmen der Abbaugebiete und Markierung der Sammelpunkte |
| `CameraController` | Zoom, Verschieben, Grenzen, Minimap-Sprung |
| `WorldState` | Zellen, Fortschritt, Chunk-Dirty-Flags |
| `WorldGenerator` | reproduzierbare Welt und Starttunnel |
| `WorkerStore` | Einheiten als Struct-of-Arrays, Zelle, Gruppe, Fraktion, Größe, Masse |
| `DigAreas` | Rechtecke und Masken je Gruppe |
| `FlowField` | gemeinsame, budgetierte Zielsuche je Gruppe, plus Laufziel |
| `MovementSystem` | orthogonale Schritte |
| `MiningSystem` | Zielwahl und Fortschritt an der Zelle; Abschluss erzeugt Energie-Dots nach Härte |
| `EnergyStore` | Energie-Dots auf dem Weg zum Kern, Arbeiter haben Vorrang |
| `CoreZone` | freie Fläche um den Kern, Maske und Aushub ohne Abbau |
| `FusionSystem` | Wunschgröße, Masse bleibt erhalten |
| `SacrificeSystem` | leere Nachbarzellen des Energiekerns als Ablage |
| `Upgrades` | Energie, Kosten, Tempo, Abbau, Verschmelzung, Kernfläche |
| `SaveGame` | Speicherstand Version 2; Version 1 wird abgelehnt |
| `SpawnSystem` | gekaufte Arbeiter, Warteschlange am Kern |
| `GroupQuotas` | Quotenprüfung und Defizitverfahren |
| `TickClock` | feste Takte, Pause ohne Nachholen |
| `Simulation` | Reihenfolge der Systeme, Statistik, Invarianten |

Verschmelzung, Opferloch, Upgrades, Siegbedingungen und Speicherstände hängen an `Simulation.tick_once`. Leere Platzhalterklassen werden nicht angelegt.

## Welt und Arbeiter

`cells` ist ein `PackedByteArray`, Index `y * width + x`. `progress` speichert Fortschrittspunkte, die noch unter der Haltbarkeit liegen. Chunks sind standardmäßig 32×32. Jede Änderung markiert genau einen Chunk. `revision` zählt Weltänderungen.

Ein Basis-Arbeiter hat Zelle, Gruppe, Fraktion, Zustand, Ziel und den Tick der letzten Bewegung. Die Fraktion ist ein Byte und steht beim Anlegen auf 0. `occupant` bildet die Zelle auf die Arbeiter-ID ab. IDs bleiben dicht: das Entfernen einer Fraktion tauscht die letzte ID in die Lücke.

## Takt

`Simulation.tick_once` macht in dieser Reihenfolge: Abbauhilfe, Zielsuche, Bewegung, Abbau, Entstehung, Verschmelzung, Nachwuchs der Quellen, Veredelung, Energietransport, im Mehrspieler danach KI, Kernschaden, Reliquien und Hügel, danach die Siegprüfung des gewählten Modus. Die Abbauhilfe ergänzt einen Pfad oder die nächste Ressource, sobald das veröffentlichte Wegfeld fertig ist und kein Arbeiter es erreicht. Die KI folgt dabei ihrer Schwierigkeit: Leicht bleibt an der Basis, Mittel gräbt die Karte, Schwer gräbt einen Korridor zum Ziel. Innerhalb eines Systems gilt aufsteigende ID. Das ist die Konfliktauflösung und hält den Takt deterministisch.

`TickClock` wandelt Frame-Zeit in Takte um, 50 ms pro Takt, höchstens fünf Takte pro Frame. In der Pause vergeht keine Simulationszeit.

## Abbauzeit

Haltbarkeit = Härte × `work_per_hardness`. Der Standard von `work_per_hardness` ist 20, also eine Simulationssekunde je Härtepunkt. `dig_power` 1 ist ein Fortschrittspunkt pro Tick. Härte 8 braucht 160 Punkte und damit 8 Sekunden. Jede gekaufte Abbaustufe multipliziert diese Punkte mit 5/4. Die Bruchrechnung bleibt exakt, auch wenn Zähler und Nenner nicht mehr in 32 Bit passen. Der Fortschritt und der Restbruch liegen an der Zelle. Die erste Prüfung im Tick, die die Haltbarkeit erreicht, entfernt die Zelle. Weitere Arbeiter desselben Ticks sehen eine leere Zelle.

## Zielsuche

Pro Gruppe gibt es ein Flow-Field. Quellen sind leere Zellen neben festem, markiertem Material und, wenn gesetzt, eine leere Laufzielzelle. Eine Multi-Source-BFS schreibt Distanz und Richtung in einen Hintergrundpuffer und wird erst nach Abschluss sichtbar. Pro Tick gilt ein festes Budget an Zellbesuchen. Ein neues Gebiet oder ein neues Laufziel startet den Aufbau neu. Eine geöffnete Zelle setzt einen laufenden Vollaufbau nicht zurück. Nach dem Veröffentlichen folgt höchstens eine Korrektur.

Das Feld ist ein Hinweis. Bewegung und Abbau prüfen den aktuellen Weltzustand. Zellen ohne Verbindung bleiben ohne Richtung, der Arbeiter wartet.

Bis zu 32 Materialänderungen korrigieren das letzte veröffentlichte Feld. Größere Änderungen, ein neues Gebiet und ein neues Laufziel bauen es vollständig neu auf. Die Grenze und der Abhängigkeitskegel stehen in D-020.

## Entstehung und Energie

Abbau schreibt keine Arbeiter in die Warteschlange. Ein gekaufter Arbeiter ist ein FIFO-Eintrag an einer Zelle beim Energiekern. Ist der Ort belegt, sucht eine BFS in der Reihenfolge Nord, Ost, Süd, West die nächste freie leere Zelle. Findet sie keine, bleibt der Eintrag liegen. Die Gruppe wählt `GroupQuotas.pick_group`: kleinster Quotient Anzahl/Quote, bei Gleichstand die größere Quote, danach der kleinere Index. Quote 0 wird nie gewählt.

Ein abgebautes Feld der Härte 1, 3 oder 8 legt ebenso viele Energie-Dots auf diese Zelle. Sie laufen über ein gemeinsames Distanzfeld zu den leeren Nachbarn des Kerns und zählen erst dort. Ohne Fähigkeit ist das ein Schritt alle 8 Takte, danach die Stufen aus D-028. Ab Kernstufe 1 ist die ganze freie Kernfläche die Ablage. Mehrere Energie-Dots teilen eine Zelle. Ein Energie-Dot betritt keine Zelle, auf der ein Arbeiter steht. Das Distanzfeld wird bei Tunneländerungen höchstens alle zehn Takte neu gerechnet. `CoreZone.plan` beschreibt Maske und Aushub. `Simulation._buy_core` setzt Arbeiter vorher nach außen, legt den Ring mit `open_without_mining` leer und sperrt die Maske in Zielsuche, Bewegung und Entstehung.

Masseninvariante: lebende Masse plus wartende Käufe = Startmasse plus gekaufte Arbeiter. Energieinvariante: erzeugt = geliefert + unterwegs. `Simulation.check_invariants()` prüft beides zusammen mit der Belegung.

## Darstellung

`WorldRenderer` schreibt die Zellen in ein RGBA-Bild, ein Pixel pro Zelle, und lädt es als eine Textur mit nächstem Nachbarn. Nach dem ersten Bild werden nur noch schmutzige Chunks neu gemalt. `_draw` zeichnet diese eine Textur. Rasterlinien erscheinen ab 8 Pixeln je Zelle und nur im sichtbaren Ausschnitt. Chunk-Grenzen sind zuschaltbar.

`WorldCoordinates` rechnet ohne Szene zwischen Bildschirm, Welt und Zelle. Die Kamera hat keine Drehung. Bildmitte ist die Kameraposition.

Leere Zellen der Kernfläche werden `#5A3D78`, der Kern selbst `#C77AFF`. Beides steht nur in der Welttextur. `GameHud` zeigt die Kernstufe in der Statuskarte; der Kauf bleibt im Fähigkeiten-Fenster.

`EnergyRenderer` zeichnet jede Zelle mit mindestens einem Energie-Dot als `#53C7FF`. `WorkerRenderer` liegt darüber und schreibt die Arbeiter in eine zweite RGBA-Textur. Alle Gruppenfarben in `Simulation.GROUP_PALETTE` sind Gelb `#FFE45E`. Die Textur wird neu gefüllt, wenn ein neuer Simulationstakt gezeichnet wird. Es gibt keine Node pro Dot. Die Energiekernzelle wird beim Malen `#C77AFF`, ohne den Materialwert zu ändern.

Die Hauptszene erzeugt die Simulation, zeichnet Welt und Arbeiter und treibt `TickClock` mit 20 Hz. `GameHud` nimmt die Auswahl und den Marsch entgegen. Die linke Taste wählt, die rechte schickt oder erobert. Ohne Auswahl geht etwa ein Zehntel in eine Befehlsgruppe mit Quote 0. Die Leiste hat einen Knopf für das Fähigkeiten-Fenster. Die Knoten stehen in diesem Fenster, gruppiert nach Kern, Bewegung, Schwarm und Bauen. Bauen setzt Quelle oder Veredler per Linksklick auf einen freien Tunnel. `OrderOverlay` zeichnet Auswahl, Aufträge und den Zug. Die Kamera folgt der mittleren Taste. Quotenverwaltung existiert nur noch intern. `WorldMinimap` zeigt die vorhandene Welttextur und lässt die Kamera zum angeklickten Punkt springen. Die Leertaste schaltet die Pause. Eine ungültige Konfiguration oder eine verletzte Startinvariante beendet das Programm mit Code 1. Der Modus steht in `SimConfig` und wird im Startmenü gesetzt.

## Tests

`godot --headless --path . -s tests/run_tests.gd` führt jede Methode mit Präfix `test_` in `tests/test_*.gd` aus. Der Runner ist Teil des Projekts. Es gibt keine zusätzliche Testbibliothek. Exit-Code 1 bedeutet Fehler oder keine Tests. GitHub Actions installiert Godot 4.3, importiert das Projekt, führt die Tests aus und startet die Hauptszene headless.

## Erweiterungspunkte, ohne Implementierung

| Späteres System | Anknüpfung |
|---|---|
| Mehrere Fraktionen | `WorkerStore.faction` ist vorhanden. Die Ansicht setzt immer 0. |
| GDExtension | `MovementSystem`, `MiningSystem`, `FlowField` haben datenorientierte Signaturen |

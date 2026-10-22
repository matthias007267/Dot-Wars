# Entscheidungen

Beschlossene Punkte stehen fest, bis sie ausdrücklich geändert werden. Offene Punkte werden nicht still entschieden.

## Beschlossen

### D-001 Abbauzeit

Datum: 22. Oktober 2026.

Eine Arbeitseinheit ist eine Simulationssekunde. Ein Basis-Arbeiter leistet eine Arbeitseinheit pro Sekunde. Härte 8 dauert damit 8 Sekunden, Härte 3 dauert 3 Sekunden, Härte 1 dauert 1 Sekunde.

Umsetzung: 20 Simulationstakte sind eine Sekunde. `work_per_hardness` ist 20 Fortschrittspunkte. `dig_power` ist 1 Punkt pro Tick. Haltbarkeit = Härte × 20. Mehrere Arbeiter addieren ihre Punkte im selben Tick. Die Werte bleiben in `SimConfig` zentral änderbar. Der ausgelieferte Standard erfüllt diese Regel.

Der vorherige Prototyp nutzte 10 Punkte je Härtestufe und damit 4 Sekunden für Härte 8. Diese Tests sind auf die beschlossene Dauer umgestellt.

### D-002 Vorhandener Prototyp bleibt

Datum: 22. Oktober 2026.

Phase 1 ersetzt den Simulationsprototyp nicht und baut ihn nicht zur spielbaren Partie aus. Dokumentation, CI, Test-Runner und die minimale Hauptszene liegen darüber. Phasen 2 bis 5 gelten trotzdem als nicht begonnen, weil ihre Abnahme (Darstellung, Bedienung, drei Gruppen) nicht erfüllt ist.

### D-003 Test-Runner ohne externe Bibliothek

Datum: 22. Oktober 2026.

Der Runner unter `tests/run_tests.gd` bleibt. Eine zweite Testbibliothek würde dieselbe Prüfung doppelt abbilden.

### D-004 Engine

Datum: 22. Oktober 2026.

Godot 4.3, GDScript, Renderer `gl_compatibility`. Dieselbe Version nutzt die CI.

### D-005 Quoten mit Summe ungleich 100 % werden abgelehnt

Datum: 22. Oktober 2026, Bestand des Prototyps, nicht neu entschieden.

`GroupQuotas.validate` verlangt eine Summe von genau 100 %. Es gibt keine stille Normalisierung. Phase 5 darf das nur mit einer neuen Entscheidung ändern.

### D-006 Gleichstand bei der Gruppenwahl

Datum: 22. Oktober 2026, Bestand des Prototyps.

Gewonnen hat die Gruppe mit dem kleinsten Quotienten Anzahl/Quote. Bei Gleichstand gewinnt die größere Quote, danach der kleinere Gruppenindex. Der Vergleich ist eine Kreuzmultiplikation ohne Gleitkommazahlen.

### D-007 Farben und unzerstörbares Material

Datum: 22. Oktober 2026.

Weich ist Grün, mittel Braun/Orange, hart Blau/Grau, unzerstörbar Dunkelgrau. Leer ist ein dunkles Blau-Schwarz, damit es sich vom unzerstörbaren Grau abhebt. Die Farben stehen nur in `Materials.COLORS`.

Unzerstörbare Zellen haben keine Haltbarkeit. `WorldState.mine_cell` lehnt sie ab. Sie zählen nicht zum abbaubaren Bestand der Massen- und Fortschrittsquote.

### D-008 Reservierte Opferlochzelle

Datum: 22. Oktober 2026.

`WorldGenerator.sacrifice_cell` liegt bei `(width / 2 + 1, height / 2 + 1)`. Die Zelle ist unzerstörbar und orthogonal an den Starttunnel angrenzend. Ein Feld von 4×4 Zellen nordwestlich des Tunnels ist ebenfalls unzerstörbar, damit der Typ in der Ansicht sichtbar ist. Einlieferungsregeln, Energie und der Schutz vor vollständiger Opferung bleiben Phase 7.

### D-009 Darstellung

Datum: 22. Oktober 2026.

Eine Zelle ist eine Welteinheit und ein Pixel in einer gemeinsamen Textur. Geändert wird nur der betroffene Chunk, gezeichnet wird ein Rechteck. Es gibt keine Node pro Zelle. Der Zoom startet bei 10 Pixeln je Zelle, geht bis 40 hinauf und bis zur ganzen Welt im Fenster hinunter. Das Mausrad zoomt zur Cursorposition.

### D-010 Laufziel ohne Abbau in der Ansicht

Datum: 22. Oktober 2026.

Phase 3 zeigt die Arbeiter und lässt sie laufen. Ein Linksklick auf eine leere Zelle setzt dasselbe Laufziel für jede Gruppe. Ein Klick auf Material wird verworfen. Das Flow-Field der Gruppe erhält diese Zelle als zusätzliche Quelle. Zellen ohne Verbindung behalten keine Richtung, der Arbeiter wartet. Steht ein Arbeiter auf dem Ziel und hat die Gruppe keinen Abbauauftrag, bleibt er stehen.

Die Abbaulogik bleibt in der Simulation und in den Tests. Die Hauptszene weist kein Abbaugebiet zu, deshalb steigt die abgebaute Masse im Fenster nicht.

Die Leertaste schaltet `TickClock.paused`. In der Pause wird keine Zeit gesammelt.

Arbeiter liegen weiter in `WorkerStore`. `faction` ist ein zusätzliches Byte und steht beim Anlegen auf 0. Gezeichnet werden sie in einer zweiten Textur, ein Pixel pro Zelle, Gelb für Gruppe 0 und Cyan für Gruppe 1. Es gibt keine Node pro Arbeiter.

## Offen

### O-002 Weitere Fraktionen

Die Fraktions-ID liegt neben der Gruppe. Neue Arbeiter bekommen Fraktion 0, und die Ansicht verwendet nur diese Fraktion. Mehrere Fraktionen, Besitz und getrennte Aufträge je Fraktion sind nicht umgesetzt.

### O-003 Prozent-Upgrades auf dem Ganzzahl-Takt

+25 % Abbauleistung sind 1,25 Punkte pro Tick, wenn ein Punkt ein Zwanzigstel einer Arbeitseinheit ist. Phase 7 legt die Rundung fest, bevor das Upgrade wirkt. Die Abbauzeit aus D-001 wird dafür nicht wieder verändert.

### O-004 Neuaufbau der Zielsuche

Der Prototyp plant bei jeder Weltänderung und bei einem neuen Laufziel einen vollständigen Neuaufbau des Flow-Fields der Gruppe. Die Regel will eine selektive Aktualisierung. Das bleibt eine Aufgabe der Wegfindungs- und Performancephasen.

### O-005 Schutzregel am Opferloch

Es muss unmöglich sein, versehentlich alle handlungsfähigen Arbeiter zu opfern. Die konkrete Regel ist noch nicht gewählt.

### O-006 Normalisierung der Quoten in der Oberfläche

Die Summe muss 100 % ergeben. Ob die Oberfläche eine Eingabe auf 100 % normalisiert oder sie ablehnt, ist für Phase 5 offen. Der Prototyp lehnt ab.

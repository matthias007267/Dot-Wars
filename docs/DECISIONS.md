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

Arbeiter liegen weiter in `WorkerStore`. `faction` ist ein zusätzliches Byte und steht beim Anlegen auf 0. Gezeichnet werden sie in einer zweiten Textur, ein Pixel pro Zelle. Es gibt keine Node pro Arbeiter.

### D-011 Aufträge je gewählter Gruppe

Datum: 22. Oktober 2026.

Ein kurzer Linksklick setzt das Laufziel nur für die gewählte Gruppe. Ein Zug mit der linken Taste markiert ihr Abbaugebiet. Die Tasten 1 bis 8 wählen die Gruppe. Rechte und mittlere Taste verschieben weiterhin die Kamera. D-010 gilt für den Stand von Phase 3; die spätere Bedienung ersetzt das gemeinsame Ziel.

### D-012 Gruppen anlegen und schließen

Datum: 22. Oktober 2026.

Eine neue Gruppe beginnt mit Quote 0 %, damit die Summe 100 % bleibt. Schließen ist nur möglich, solange eine andere Gruppe offen bleibt. Ihre Arbeiter und ihre Quote gehen an die offene Gruppe mit dem kleinsten Index. Die Gesamtmasse ändert sich nicht.

### D-013 Quoteneingabe

Datum: 22. Oktober 2026. Schließt O-006.

Die Oberfläche normalisiert eine Summe ungleich 100 % nicht. Der Versuch wird abgelehnt und der bisherige Stand bleibt.

### D-014 Schutzregel am Opferloch

Datum: 22. Oktober 2026. Schließt O-005.

Eine Einheit wird nur geopfert, wenn danach mindestens Masse 1 im Spiel bleibt. Wartende Entstehungen zählen mit. Würde die Opferung die letzte Masse entfernen, unterbleibt sie und der Opferauftrag dieser Gruppe endet. Energie ist gleich der geopferten Masse.

### D-015 Bewegungs-Upgrade

Datum: 22. Oktober 2026.

Der Grundtakt bleibt unverändert: ein Schritt alle `move_period_ticks` Takte, versetzt nach Arbeiter-ID. Ab der ersten gekauften Stufe sammelt jede Einheit Punkte. 100 Punkte sind ein Schritt, höchstens einer je Takt. Startwert ist `100 / move_period_ticks`. Jede Stufe multipliziert mit 6/5, ganzzahlig. Bei Periode 2 sind das 50, 60, 72, 86 und danach 100.

Kosten: 25 × (gekaufte Stufe + 1).

### D-016 Abbau-Upgrade

Datum: 22. Oktober 2026. Schließt O-003.

Die Haltbarkeit aus D-001 bleibt. Jede Stufe multipliziert die Leistung mit 5/4, als Bruch ohne Rundungsverlust. Eine Stufe macht aus einem Punkt je Takt 5/4 Punkte. Härte 1 dauert dann 16 Takte statt 20. Große Einheiten nutzen dieselbe Bruchrechnung auf ihrer eigenen Grundleistung.

Kosten: 50 × (gekaufte Stufe + 1).

### D-017 Verschmelzungs-Upgrades

Datum: 22. Oktober 2026.

2×2 kostet einmalig 100 Energie und schaltet die Wunschgröße 2 frei. 3×3 kostet einmalig 250, setzt 2×2 voraus und schaltet die Wunschgröße 3 frei. 250 ist ein vorläufiger Balancingwert. Ohne diese Käufe bleibt die Wunschgröße 1.

### D-018 Verschmelzung

Datum: 22. Oktober 2026.

Größe 1 hat Masse 1 und Leistung 1, Größe 2 hat Masse 4 und Leistung 6, Größe 3 hat Masse 9 und Leistung 15. Verschmolzen wird nur innerhalb derselben Gruppe und Fraktion, auf ein freies Quadrat, höchstens vier Mal je Gruppe und Takt. Eine andere Wunschgröße zerlegt die Einheit zuerst in Basis-Arbeiter auf ihrer eigenen Fläche. Enge Lücken, die das Quadrat nicht fassen, sind nicht passierbar.

### D-019 Speicherstand

Datum: 22. Oktober 2026.

Formatversion 1, geschrieben mit `var_to_bytes`. Manuell unter `user://slot.dw` (F5, F9), automatisch alle 600 Simulationstakte unter `user://autosave.dw`. Eine falsche Version oder ein verletzter Zustand wird abgelehnt. Nach dem Laden setzt dieselbe Befehlsfolge die Simulation gleich fort.

### D-020 Lokale Korrektur der Zielsuche

Datum: 22. Oktober 2026.

Bis zu 32 Materialänderungen seit dem letzten veröffentlichten Feld korrigieren dieses Feld an Ort und Stelle. Verlorene Abbaupositionen nehmen die Zellen mit, deren nächster Schritt auf sie zulief. Geöffnete Zellen und diese Nachbarschaft werden neu angesetzt; ein kürzerer Weg ersetzt einen längeren. Das Ergebnis bleibt unsichtbar, bis die budgetierte Ausbreitung fertig ist. Öffnet sich währenddessen eine weitere Zelle, beginnt die Korrektur erneut beim letzten veröffentlichten Feld, solange zusammen höchstens 32 Änderungen betroffen sind.

Vollständig neu aufgebaut wird das Feld beim ersten Mal, bei einem neuen Gebiet, bei einem neuen Laufziel, ab 33 Änderungen, wenn das Änderungsprotokoll verworfen wird, und wenn der Abhängigkeitskegel 8192 Zellen überschreitet. Der letzte Fall begrenzt die Arbeit in einem Takt. Ein leeres Abbaurechteck wird beim Veröffentlichen entfernt und löst keinen Neuaufbau aus.

Gemessen am 22. Oktober 2026, Seed 1337, markierte linke Hälfte, eine abgebaute Randzelle neben einer leeren Zelle: 0,08 ms auf der 256er-Welt und 0,72 ms auf der 1.000er-Welt. Dieselbe vollständige Berechnung dauerte im Median 29,8 ms bzw. 455 ms. Geändert haben sich zwei Distanzen. Der Lauf nahm die lokale Korrektur, nicht den Neuaufbau.

## Offen

### O-002 Weitere Fraktionen

Die Fraktions-ID liegt neben der Gruppe. Neue Arbeiter bekommen Fraktion 0, und die Ansicht verwendet nur diese Fraktion. Mehrere Fraktionen, Besitz und getrennte Aufträge je Fraktion sind nicht umgesetzt.

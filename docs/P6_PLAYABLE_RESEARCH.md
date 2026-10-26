# P6-Folgeauftrag: KI, Transport, Bedienung, Sicht und Forschungsbaum

Basis: `main` bei `20a5059` (PR #8 gemergt). Umsetzung auf `feat/p6-playable-research` in einem **neuen** Review-PR. Der aktuelle Auftrag umfasst ausdrücklich die sechs nach dem Soll/Ist-Abgleich angebotenen Punkte. Kein Merge, kein Release und kein Auftrag für Weltumbau, Online-Multiplayer, Reliquien, neue Farmen/Mauern/Sensoren oder Musik.

## Beschlüsse und vorläufige Werte

Der Nutzer bestätigte die beiden Rückfragen ausdrücklich mit „Diese vorläufigen Regeln verwenden“ beziehungsweise „Diese vorläufigen Werte verwenden“:

- Leitungsabriss pausiert bereits bezahlte Sendungen **an ihrer tatsächlichen Zelle**. Wiederanschluss setzt sie fort, ohne Teleport oder Rückerstattung.
- Bei Zerstörung des Forschungszentrums gehen dessen Puffer und zugehörige Sendungen verloren; keine Erstattung oder kostenlose Technologie. `lost_energy` erfasst den Verlust genau einmal und wird gespeichert.
- Quellverlust vernichtet bereits bezahlte, noch zustellbare Sendungen nicht. Neuer Versand bevorzugt eigene Hauptkerne, danach verbundene eigene Außenposten als Ersatzversorgung.
- **Außenposten:** Voraussetzung `speed`, 90 Energie, 260 Takte, eine Stufe.
- **Abfangstation:** Voraussetzung `energy_speed`, 90 Energie, 260 Takte, eine Stufe.
- **Energieeffizienz:** Voraussetzung `energy_speed`, drei Stufen; Katalogpreis 80 Energie und 240 Takte × Zielstufe. 10/20/30 % weniger Forschungsenergie, keine verkürzte Forschungsdauer. Rundung auf volle Energie nach oben, mindestens eine Einheit. Aktive Effizienz gilt auch für später gestartete Effizienzforschung.
- Kosten werden bei Auftragsbeginn aus dem Effizienzstand berechnet und **für diesen Auftrag eingefroren**. Eine parallel abgeschlossene Effizienzforschung verändert laufende Aufträge nicht. Der beim Start geltende Effizienzstand wird mitgespeichert und geprüft.

Diese Zahlen sind bestätigte **Prototypwerte**, keine finale Balance.

## 1. KI-Netzversorgung

`src/sim/research_ai.gd` integriert sich vor der bisherigen Bau-/Wirtschaftsentscheidung in `MatchRules._ai`. Ein deterministischer 100-Takt-Planungstermin legt eigene Leitungen zwischen fertigem Kern und Forschungszentrum über dieselben freien Zellen wie beim Spieler. Vorhandene Leitungen werden bevorzugt. Keine kostenlose Terrainöffnung, keine fremden Leitungen und keine direkte Energiegutschrift.

Die KI startet unterschiedliche verfügbare Basistechnologien über `ResearchSystem.start`, während normale bezahlte Sendungen den Fortschritt ermöglichen. Sie bevorzugt in Forschungssieg-Partien die Siegtechnologie. Schwierigkeitsstufen verändern weder Preise noch Forschungsdauer. Eine minimale Reserve von einer Energie verhindert, dass Einheitenkäufe die nächste Lieferung dauerhaft verdrängen. Neuplanung kann abgerissene Verbindungen wiederherstellen.

Prüfung: `tests/test_research_ai.gd` enthält echte Lieferungen, Abschluss, Fraktionsgrenzen, Wiederanschluss, unpassierbare Terraintrennung und deterministische Fortsetzung eines gespeicherten KI-Netzes. Leicht/Mittel/Schwer werden zusätzlich über den regulären Simulationstakt geprüft.

## 2. Transportausfälle und Abriss

`EnergyNetwork` verwendet deterministische Mehrquellen-Dijkstra-Suche mit Heap (neue Zelle kostet 11, bestehende eigene Leitung 1; maximal 65.536 besuchte Zustände pro Planung). Die Eigentümerabfrage besitzt einen Index. Sendungsrouten werden von der **aktuellen Position** zum Empfänger berechnet; Ziel-Wegefelder werden bis zu Netz-/Terrain-/Gebäuderevisionen wiederverwendet. Eine neue kürzeste Route darf eine bezahlte Sendung nicht an einer inzwischen veralteten Quellroute festhalten. Auch wenn eine entfernte Zelle inzwischen eine fremde Leitung trägt, bleibt eigenes bezahltes Transportgut dort speicherbar pausiert; erst eine wieder eigene Verbindung erlaubt Bewegung.

`ResearchSystem` verwirft ungültige Ziele vor Bewegung/Versand, prüft Besitzer und fertigen Gebäudetyp, pausiert auf entfernten Leitungen, verwendet Ersatzversorgung und versendet nicht über den verbleibenden Energiebedarf hinaus. Verluste sowie laufende Sendungen sind im Snapshot/State-Hash enthalten. Ungültiger Restore bleibt atomar.

Arbeiterabriss wählt erreichbare freie eigene Arbeiter nach Entfernung aus. Er benötigt 20 % der ursprünglichen Bauarbeit plus Anreise. Treffer während des Abrisses löschen den Auftrag nicht mehr still. Hauptkerne bleiben vor Q-Abriss geschützt. Die vorhandenen gesonderten Einzellengebäude Quelle/Veredler bleiben ein Altmodell; ihre vollständige Überführung in den neuen Gebäudekatalog ist weiterhin Folgearbeit.

Ein Gebäudebau darf keine bestehenden Leitungen überdecken: zuerst per Q freiräumen. Damit bleiben Kollision, Transport und gespeicherte Netze konsistent.

## 3. Bedienprüfung in grafischem Godot

`bench/p6_live_check.gd` läuft mit echter OpenGL-Ausgabe unter Xvfb/Mesa-Software-Rendering. Der Check hängt eine deterministische Zwei-Fraktionen-Partie an die tatsächliche Hauptszene und bedient deren HUD und Pointer-/Tastaturhandler. Zusätzliche eigene Krieger sind nur eine temporäre Sicht-Fixture für den Netz-Zug und werden vor den Welt-Screenshots entfernt.

Geprüft werden: Forschungszentrum per HUD bezahlen und mit Arbeitern fertigstellen; beschädigen und über HUD reparieren; E aktivieren; Maus-Start/Ziel-Vorschau ohne frühe Platzierung; erst beim Loslassen bauen; E beenden; Forschung über Knoten und Startknopf starten; Q-Leitung sofort entfernen und Modus beenden; mit laufenden Sendungen speichern; echten Verbrauch/Glow und Abschluss erreichen; Gebäude anschließend durch Arbeiter abreißen. Der Test endet bei einer fehlgeschlagenen Prüfung mit Exit 1.

Befehl mit installiertem Xvfb aus dem Repository:

```sh
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1600x1000x24' \
  godot --audio-driver Dummy --path . -s bench/p6_live_check.gd
```

Erzeugte Belege: `/tmp/p6-research-tree.png`, `/tmp/p6-powered.png`, `/tmp/p6-world.png`. Lokal wurden diese Bilder visuell angesehen. Die CI führt denselben Check aus und speichert Bilder und Log im Artefakt `p6-visual-check`.

Dies ist ein **automatisierter grafischer Funktionstest**, keine manuell durchgespielte Windows-Partie, keine Audioprüfung und keine 1k/10k-Performanceabnahme.

## 4. Sichtschutz

Die neuen Netz-/Sendungs-/Glow-Ausgabepfade filtern **vor dem Zeichnen**: eigene Infrastruktur ist bekannt; fremde Infrastruktur und Verbrauchsaktivität nur bei aktueller Sicht. Die separate Overlay-Ebene liegt über dem Fog, damit dieser bekannte eigene Leitungen nicht wieder verdeckt. Fremde Tätigkeit wird nicht als aktualisiertes Gebäudegedächtnis angezeigt.

Netzvorschauen und neue Bauplätze verwenden nur aktuell sichtbare Zellen. Verborgene Gegnergebäude lassen sich nicht durch Blindplatzierung oder Blindabriss sondieren. Eigene bekannte Leitungen lassen sich dagegen auch außerhalb aktueller Sicht per Q entfernen. E/Q-Wechsel verwerfen angefangene Pointer-Züge; das Öffnen des Forschungsfensters beendet widersprüchliche Baumodi. Ein Bauknopf im Forschungsfenster schließt dieses, damit der anschließende Weltklick erreichbar ist.

Headless-Regressionen prüfen die Daten, die diese Zeichenpfade tatsächlich verwenden. Der neue Overlay-Umfang ist damit abgesichert; ein vollständiger Audit sämtlicher historischer HUD-/Minimap-/Netzwerkkanäle wird nicht behauptet.

## 5. Reguläre Freischaltungen und Effizienz

`ResearchSystem.CATALOG` enthält nun neun Technologien. `ConstructionSystem.unlocked` prüft die neue Fraktionsforschung, zusätzlich zu den separat bestehenden Testlaborflags. Normale Außenposten-/Abfangstationskäufe benötigen keine Debugfreigabe mehr. HUD, Bauprüfung und KI lesen dieselben Regeln. Save/Load erhält Forschung und Freischaltungen; die Energieeffizienz ist fraktionsgebunden.

Tests: Voraussetzungen, fremde Fraktion ohne Freischaltung, normaler Bau nach Forschung, Speicherung, alle drei Effizienzstufen, unveränderte Dauer, Maximallevel und parallel weitergeltender alter Auftragspreis.

## 6. Grafischer Forschungsbaum

`src/ui/research_tree_view.gd` ersetzt die vier Textlisten durch einen datengetriebenen Knotenbaum mit vier farblich unterscheidbaren Zweigen, gerichteten Voraussetzungslinien und um Zwischenknoten geführten langen Verbindungen. Mausrad und −/+ zoomen, mittlere Maustaste verschiebt, „Ansicht“ setzt zurück. Gesperrte Knoten bleiben inspizierbar; ein eigener Startknopf verhindert versehentlichen Start und bleibt bei fehlenden Voraussetzungen/belegtem Zentrum gesperrt.

Details zeigen Stufe, Kosten, Forschungsdauer, Fortschritt, bereits verbrauchte Energie, fehlende Zufuhr, Puffer, unterwegs befindliche eigene Energie sowie parallele eigene Aufträge. Keine Gegner-Forschungsdetails. Eine Auswahl hebt den Knoten hervor. Tests prüfen Katalogvollständigkeit, Abhängigkeitsanordnung, gesperrte Auswahl und Zoomgrenzen; der grafische Durchlauf prüft Auswahl und Start.

## Verifikation und verbleibende Grenzen

Die vollständigen Prüfungen werden vor dem neuen PR-Abschluss mit Godot 4.3 ausgeführt: nativer Build, Import, native Suite, GDScript-Fallback, Hauptszene und grafischer P6-Check. Das tatsächliche GitHub-Actions-Ergebnis einschließlich Commit und Link steht im PR-Abschlussprotokoll. Ein lokal erfolgreicher Lauf wird nicht als bereits erfolgreicher GitHub-Lauf ausgegeben.

Grenzen: kein neues Netzwerkspiel, keine endgültige Balance, keine neue Farm-/Bohrer-/Mauer-/Sensormechanik, keine Dauerbuffs und keine große Langzeit-Leistungsmessung. Die alte Quelle-/Veredler-Abrissmigration bleibt außerhalb dieses begrenzten SettlementStore-Auftrags. Historische 80-Punkte- und CI-Berichte vom vorigen Auftrag bleiben Snapshots und werden durch diesen Nachtrag ergänzt.

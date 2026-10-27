# Architektur – Ist-Stand und Konzeptabgleich

Aktueller Auftrag D-082/D-083: `BuildingDefense` hält Unterhaltsfristen und echte Waffenprojektile; Forschung bezahlt den Gesamtpreis beim Start. `EnergyNetwork.prepare_power` verwendet einen invalidierten Komponenten-Cache statt Einzelenergie-Wegen. Shader-Netzfluss ist rein visuell, Abbau-Dots bleiben physisch. Details, Migration und Messung: [GRID_DEFENSE.md](GRID_DEFENSE.md).

Weltauftrag D-075/D-076: `CavernGenerator` erzeugt getrennte Tunnelnetze, ein dauerhaftes Wandgerüst und seltene Erzadern. `WorldState.released` zählt die während des Abbaus freigesetzte Energie; `MiningSystem` zahlt kumulativ und speicherfest aus. Material-IDs wählen einen quadratischen Terrain-Atlas, Fog verwendet nur Fraktionswissen. Die historischen Prototypformeln unten sind dadurch für neue Ressourcen ersetzt. Aktueller Stand: [ORE_WORLD.md](ORE_WORLD.md).

Energiephase D-062: `EnergyStore` enthält parallele Routenverlust-/Puffer-/Freigabefelder und Bilanzzähler; `energy_transport.gd` verbindet exakte gemeinsame Terrainfelder mit stabilen Stationskontakten und gemeinsamer Array-Kompaktion. Gebäudetyp 2 ist Abfangstation und wird aus Produktion/Empfang/Schutz ausgeschlossen. Additive SaveGame-V2-Daten validieren Besitz, Frist, Ort und Station. Details: [ENERGY_PHASE.md](ENERGY_PHASE.md).

Folgephase D-060: `WorkerStore.build_mode` unterscheidet Bau/Reparatur innerhalb des bestehenden Zustands 4; `SettlementStore.paid` erhält den tatsächlich gezahlten Preis für Abbrüche. `ConstructionSystem` enthält Reparatur/Abbruch und die gemeinsame Platzierungs-/Wegeprüfung. `construction_ai.gd` plant deterministisch über gespeicherten Takt und vorhandene Zustände, mit begrenzter Kandidatensuche und ohne neue Nodes/Threads. Additive Version-2-Speicherung; Details in [MAINTENANCE_PHASE.md](MAINTENANCE_PHASE.md).

Bauphase D-059: `SettlementStore` hält stabile Gebäude-/Baustellen-IDs und Flächen; `ConstructionSystem` verbindet Zahlung, gemeinsame Arbeiter-Randarbeit, Produktionsorte, Empfangsränder und Schutzprüfung. Arbeiterzuweisungen liegen swapfest in `WorkerStore.build_site`. Weltzellen sperren Bauflächen für bestehende native Wege; SaveGame V2 enthält additive Bau-/Produktionsbindungen. `MatchRules.cores/core_hp` sind Kompatibilitätsspiegel. Details und Altstandgrenzen: [CONSTRUCTION_PHASE.md](CONSTRUCTION_PHASE.md).

Stand des Abgleichs: 25. Oktober 2026. **Einheitenphase umgesetzt, weitere Zielsysteme bleiben offen.** Aktuelle Details in [UNIT_PROTOTYPE.md](UNIT_PROTOTYPE.md). Die beschlossenen Zielregeln stehen in [GAME_DESIGN.md](GAME_DESIGN.md), konkrete Abweichungen und spätere Pakete in [CONCEPT_SYNC.md](CONCEPT_SYNC.md). Die folgenden Bestandsabschnitte beschreiben den Prototyp; der letzte Abschnitt nennt erforderliche Entwurfsentscheidungen, keine bereits gewählte neue Architektur.

## Ist-Architektur des Prototyps

Engine ist Godot 4.3 mit GDScript, optionalem C-GDExtension-Rechenkern und dem Renderer `gl_compatibility`. Zielplattform ist Windows. Linux wird für headless Tests genutzt.

## Grundsatz

Die Simulation kennt keine Szene. Alles unter `src/sim/` sind `RefCounted`-Klassen ohne Nodes, Eingabe oder Zeichenbefehle. Darstellung und UI lesen den Zustand und schreiben nur über die API von `Simulation`.

Es gibt keine Node pro Zelle und keine pro Arbeiter. Welt und Arbeiter liegen in Packed-Arrays. Die Daten bleiben in der Simulation. Native Rasteroperationen sind bereits optional vorhanden; GDScript bleibt ausführbare Referenz und Fallback. Bauanleitung und unterstützte Operationen stehen in [native/README.md](../native/README.md).

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
| `WorldGenerator` | reproduzierbarer Materialkörper und kompakte Startlichtungen |
| `WorkerStore` | Einheiten als Struct-of-Arrays, Zelle, Gruppe, Fraktion, Größe, Masse |
| `DigAreas` | Rechtecke und Masken je Gruppe |
| `FlowField` | gemeinsame, budgetierte Zielsuche je Gruppe, plus Laufziel |
| `MovementSystem` | orthogonale Schritte, native Bewegung normaler Arbeiter und Referenz für größere Einheiten |
| `MiningSystem` | Zielwahl, Fortschritt und kumulative anteilige Energieausgabe; Härte, Dauer und Ertrag sind getrennt |
| `EnergyStore` | Energie-Dots auf dem Weg zum Kern, Arbeiter haben Vorrang |
| `CoreZone` | freie Fläche um den Kern, Maske und Aushub ohne Abbau |
| `ArmyState` | Dichte Kriegerdaten, stabile IDs, Produktion, Bewegung, Nahkampf und Verluste |
| `SacrificeSystem` | leere Nachbarzellen des Energiekerns als Ablage |
| `Upgrades` | Energie, Kosten, Tempo, Abbau, Kernfläche; alte Fusionsflags nur als Ladebestand |
| `SaveGame` | Speicherstand Version 2; Version 1 wird abgelehnt |
| `SpawnSystem` | gekaufte Arbeiter, Warteschlange am Kern |
| `GroupQuotas` | Quotenprüfung und Defizitverfahren |
| `TickClock` | feste Takte, Pause ohne Nachholen |
| `Simulation` | Reihenfolge der Systeme, Statistik, Invarianten |

Armee, Energiekern, Upgrades, Match-Siegbedingungen und Speicherstände hängen an `Simulation.tick_once`. Leere Platzhalterklassen werden nicht angelegt.

## Welt und Arbeiter

`cells` ist ein `PackedByteArray`, Index `y * width + x`. `progress` speichert Fortschrittspunkte, die noch unter der Haltbarkeit liegen. Chunks sind standardmäßig 32×32. Jede Änderung markiert genau einen Chunk. `revision` zählt Weltänderungen.

Ein Basis-Arbeiter hat Zelle, Gruppe, Fraktion, Zustand, Ziel und den Tick der letzten Bewegung. Die Fraktion ist ein Byte und steht beim Anlegen auf 0. `occupant` bildet die Zelle auf die Arbeiter-ID ab. IDs bleiben dicht: das Entfernen einer Fraktion tauscht die letzte ID in die Lücke.

## Takt

`Simulation.tick_once` macht in dieser Reihenfolge: Abbauhilfe, Zielsuche, Bewegung, Abbau, Arbeiterplatzierung, Nachwuchs der Quellen, Veredelung, Energietransport, Kriegerproduktion/-bewegung und gesammelte Nahkampftreffer, im Mehrspieler danach KI, Kernschaden, Reliquien und Hügel, danach die Siegprüfung des gewählten Modus. Die Abbauhilfe ergänzt einen Pfad oder die nächste Ressource, sobald das veröffentlichte Wegfeld fertig ist und kein Arbeiter es erreicht. Die KI folgt dabei ihrer Schwierigkeit: Leicht bleibt an der Basis, Mittel gräbt die Karte, Schwer gräbt einen Korridor zum Ziel. Innerhalb eines Systems gilt aufsteigende ID. Das ist die Konfliktauflösung und hält den Takt deterministisch.

`TickClock` wandelt monoton gemessene Echtzeit in Takte um, 50 ms pro Takt, höchstens fünf Takte pro Frame. Die eigene Aufholgrenze kann Überhang verwerfen; das ist keine garantierte reale Taktfrequenz. In der Pause vergeht keine Simulationszeit.

## Abbauzeit

Haltbarkeit = Härte × `work_per_hardness`. Der Standard von `work_per_hardness` ist 20, also eine Simulationssekunde je Härtepunkt. `dig_power` 1 ist ein Fortschrittspunkt pro Tick. Härte 8 braucht 160 Punkte und damit 8 Sekunden. Jede gekaufte Abbaustufe multipliziert diese Punkte mit 5/4. Die Bruchrechnung bleibt exakt, auch wenn Zähler und Nenner nicht mehr in 32 Bit passen. Der Fortschritt und der Restbruch liegen an der Zelle. Die erste Prüfung im Tick, die die Haltbarkeit erreicht, entfernt die Zelle. Weitere Arbeiter desselben Ticks sehen eine leere Zelle.

## Zielsuche

Pro Gruppe gibt es ein Flow-Field. Quellen sind leere Zellen neben festem, markiertem Material und der nächstmögliche Standpunkt eines Laufziels. Liegt der gewünschte Punkt in der erreichbaren Fläche, ist das der Punkt selbst, sonst die erreichbare leere Zelle mit dem kleinsten Manhattan-Abstand. Eine Multi-Source-BFS schreibt Distanz und Richtung in einen Hintergrundpuffer und wird erst nach Abschluss sichtbar. Pro Tick gilt ein festes Budget an Zellbesuchen. Ein neues Gebiet oder ein neues Laufziel startet nur den Aufbau dieser Gruppe neu. Eine geöffnete Zelle setzt einen laufenden Vollaufbau nicht zurück. Ohne Auftrag sucht sich eine Gruppe bis zu 32 nächste Felszellen, zuerst im Umkreis von 16 Zellen; die weiteren Stufen stehen in D-038. Ab Schwarm-Intelligenz Stufe 1 sucht jeder Dot daraus einen Fels, den seine Fraktion noch nicht belegt hat, und behält den nächsten Schritt, solange Ziel und Nachbarn gleich bleiben. Nach dem Veröffentlichen folgt höchstens eine Korrektur. Eine ferne Zelle ohne Anschluss an das Feld lässt die Richtungen stehen.

Das Feld ist ein Hinweis. Bewegung und Abbau prüfen den aktuellen Weltzustand. Zellen ohne Verbindung bleiben ohne Richtung, der Arbeiter wartet.

Bis zu 32 Materialänderungen korrigieren das letzte veröffentlichte Feld. Größere Änderungen, ein neues Gebiet und ein neues Laufziel bauen es vollständig neu auf. Die Grenze und der Abhängigkeitskegel stehen in D-020.

## Entstehung und Energie

Abbau schreibt keine Arbeiter in die Warteschlange. Ein gekaufter Arbeiter ist ein FIFO-Eintrag an einer Zelle beim Energiekern. Ist der Ort belegt, sucht eine BFS in der Reihenfolge Nord, Ost, Süd, West die nächste freie leere Zelle. Findet sie keine, bleibt der Eintrag liegen. Die Gruppe wählt `GroupQuotas.pick_group`: kleinster Quotient Anzahl/Quote, bei Gleichstand die größere Quote, danach der kleinere Index. Quote 0 wird nie gewählt.

Ein abgebautes Feld der Härte 1, 3 oder 8 legt ebenso viele Energie-Dots auf diese Zelle. Sie laufen über ein gemeinsames Distanzfeld zu den leeren Nachbarn des Kerns und zählen erst dort. Ohne Fähigkeit ist das ein Schritt alle 8 Takte, danach die Stufen aus D-028. Ab Kernstufe 1 ist die ganze freie Kernfläche die Ablage. Mehrere Energie-Dots teilen eine Zelle. Ein Energie-Dot betritt keine Zelle, auf der ein Arbeiter steht. Das Distanzfeld wird bei Tunneländerungen höchstens alle zehn Takte neu gerechnet. `CoreZone.plan` beschreibt Maske und Aushub. `Simulation._buy_core` setzt Arbeiter vorher nach außen, legt den Ring mit `open_without_mining` leer und sperrt die Maske in Zielsuche, Bewegung und Entstehung.

Masseninvariante des Prototyps: lebende Arbeitermasse plus wartende Käufe = Startmasse plus Spieler- und KI-Käufe minus entfernte Fraktionsmasse. Dies ist keine vollständige künftige Krieger-/Todesbilanz. Energieinvariante des Prototyps: erzeugt = geliefert + unterwegs. Verfall, neutrale Energie und Abfangpuffer sind darin noch nicht modelliert. `Simulation.check_invariants()` prüft beides zusammen mit der Belegung.

## Darstellung

`WorldRenderer` schreibt die Zellen in ein RGBA-Bild, ein Pixel pro Zelle, und lädt es als eine Textur mit nächstem Nachbarn. Nach dem ersten Bild werden nur noch schmutzige Chunks neu gemalt. `_draw` zeichnet diese eine Textur. Rasterlinien erscheinen ab 8 Pixeln je Zelle und nur im sichtbaren Ausschnitt. Chunk-Grenzen sind zuschaltbar.

`WorldCoordinates` rechnet ohne Szene zwischen Bildschirm, Welt und Zelle. Die Kamera hat keine Drehung. Bildmitte ist die Kameraposition.

Leere Zellen der Kernfläche werden `#5A3D78`, der Kern selbst `#C77AFF`. Beides steht nur in der Welttextur. `GameHud` zeigt die Kernstufe in der Statuskarte; der Kauf bleibt im Fähigkeiten-Fenster.

`EnergyRenderer` zeichnet jede Zelle mit mindestens einem Energie-Dot als `#53C7FF`. `WorkerRenderer` liegt darüber und schreibt die Arbeiter in eine zweite RGBA-Textur. Alle Gruppenfarben in `Simulation.GROUP_PALETTE` sind Gelb `#FFE45E`. Die Textur wird neu gefüllt, wenn ein neuer Simulationstakt gezeichnet wird. Es gibt keine Node pro Dot. Die Energiekernzelle wird beim Malen `#C77AFF`, ohne den Materialwert zu ändern.

Die Hauptszene erzeugt die Simulation, zeichnet Welt und Arbeiter und treibt `TickClock` mit 20 Hz. `GameHud` nimmt die Auswahl und den Marsch entgegen. Die linke Taste wählt, ein Rechtsklick schickt nur diese Auswahl. Die gehaltene rechte Taste verschiebt die Kamera, mit Strg markiert sie ein Gebiet. Ohne Auswahl bleibt der automatische Abbau. Ist der Befehl erledigt, sucht sich dieselbe Gruppe wieder die nächste Arbeitsfront. Die Leiste hat einen Knopf für das Fähigkeiten-Fenster. Die Knoten stehen in diesem Fenster, gruppiert nach Kern, Bewegung, Schwarm und Bauen. Bauen setzt Quelle oder Veredler per Linksklick auf einen freien Tunnel. `OrderOverlay` zeichnet Auswahl, Aufträge und den Zug. Die Kamera folgt der rechten und der mittleren Taste. Quotenverwaltung existiert nur noch intern. `WorldMinimap` zeigt die vorhandene Welttextur und lässt die Kamera zum angeklickten Punkt springen. Die Leertaste schaltet die Pause. Eine ungültige Konfiguration oder eine verletzte Startinvariante beendet das Programm mit Code 1. Der Modus steht in `SimConfig` und wird im Startmenü gesetzt.

## Tests

`godot --headless --path . -s tests/run_tests.gd` führt jede Methode mit Präfix `test_` in `tests/test_*.gd` aus. Der Runner ist Teil des Projekts. Es gibt keine zusätzliche Testbibliothek. Exit-Code 1 bedeutet Fehler oder keine Tests. GitHub Actions installiert Godot 4.3, importiert das Projekt, führt die Tests aus und startet die Hauptszene headless.

## Erweiterungspunkte, ohne Implementierung

| Späteres System | Anknüpfung |
|---|---|
| Mehrere Fraktionen | Lokaler Spieler und 1–3 KI-Fraktionen mit eigenen Konten sind vorhanden; Bündnisse und Netzwerk fehlen. |
| GDExtension | Bewegung normaler Arbeiter, Raster-/Wegsuche und Teile des Energietransports sind nativ beschleunigt; Referenz bleibt GDScript. |

## Auswirkungen des Zielkonzepts – Planung, keine gewählte neue Architektur

Die folgenden Punkte sind aus den Regeln abgeleitete Anforderungen und mögliche Lösungsrichtungen. Es werden keine neuen Klassen, Threads, Speicherformate oder Netzwerkprotokolle eingeführt.

### Welt und Nachbarschaft

Die heutige Welt besitzt globale Indizes und weltweite Arrays. Dirty-Chunks begrenzen Zeichenarbeit, nicht die resident gehaltene Welt. Nahezu endlose Welten benötigen eine Entscheidung über Koordinaten, Bereichsgrenzen, Generierung, Persistenz und aktive Daten. Nachladbare Weltbereiche mit begrenzter aktiver Fläche sind eine Möglichkeit, nicht eine bereits ausgewählte Architektur. Eine bloße Erhöhung von `world_size` reicht nicht als Nachweis.

Diagonaler Abbau betrifft mehr als `MiningSystem`: Nachbarschaft, Frontlisten, Pfadkosten, Eckregeln, Wegfelder, Eingaben, native Kerne und Referenztests müssen zusammenpassen. Ob auch jede Bewegung diagonal ist, wird vor einer Codeänderung entschieden.

### Einheiten, Belegung und deterministische Befehle

Die einzelne `occupant`-Arbeiter-ID pro Zelle bildet die neue typabhängige Durchquerung nicht vollständig ab. Getrennte Arbeiter-/Kriegerbelegungen oder eine äquivalente Struktur sind Entwurfsoptionen. Keine davon wird hier festgeschrieben. Kriegerblockade, erlaubtes Durchqueren eigener Arbeiter und mögliche gemeinsame Endpositionen müssen vor der Auswahl einer Struktur eindeutig sein.

Lebenspunkte, Angriffs- und Todeszustände sowie räumlich begrenzte Gegnerabfragen fehlen. Für mehrere Tausend Krieger ist eine lokale Nachbarschaftsabfrage naheliegend; ein globaler Vergleich aller Paare wäre ein Skalierungsrisiko. Die bestehenden nativen Kerne dürfen nicht mit neuen GDScript-Regeln auseinanderlaufen.

Swap-Entfernung hält interne Slots dicht, macht einen Slot aber nicht automatisch zu einer dauerhaften Identität. Für lang laufende Aufträge, Bauzuweisungen, Sichtgedächtnis und Netzwerkbefehle ist eine bewusste Identitätsentscheidung nötig. Stabile Entity-IDs mit Slot-Zuordnung sind ein Vorschlag, keine bereits eingeführte API.

### Gebäude, Produktion, Forschung und Niederlage

Allgemeine Gebäudezustände müssten Bauplan, ersten tatsächlichen Arbeiterbeitrag, Baufortschritt, Fertigstellung, Schaden, Reparatur und Zerstörung unterscheiden. Ein solcher Zustand darf die neue Niederlagebedingung nicht durch bloßes Vorhandensein eines Bauauftrags erfüllen. Hauptkerne und Außenposten teilen Produktionsgrundfunktionen; konkrete Gebäudeformen, Warteschlangen und Kosten sind vorab zu entscheiden.

Globale Forschungsaufträge benötigen eigene Zahlung-, Laufzeit- und Abschlusszustände. Sofortige Upgrade-Käufe und `research_level` des alten Siegmodus können das nicht vollständig darstellen. Forschungsfreischaltung ist eine Abhängigkeit produktiv verfügbarer Außenposten und sonstiger neuer Gebäude; die Reihenfolge späterer Pakete muss diese Schnittstelle berücksichtigen.

### Energie und Bilanzen

Die heutige Energie hat Position, Herkunft, Veredelungsmerkmal und Besitzer. Neu benötigt werden ein beschlossener Routen-Timer sowie eine Darstellung von Stationspuffern und neutraler Energie. Das alte Veredelungsmerkmal ist kein Diebstahlschutz. Transport, Besitzwechsel, Lieferung und Verfall müssen eindeutig verbucht werden; ob Puffer in „unterwegs“ enthalten sind oder getrennt zählen, ist vor der Implementierung festzulegen.

Die heutige Formel `generated = delivered + pending` ist eine Prototypinvariante. Im Zielmodell müssen mindestens Verfall und neutral/gepuffert gehaltene Energie berücksichtigt werden. Eine endgültige Bilanz oder Speichermigration wird hier nicht erfunden. Kriegerproduktion und Kampftode verlangen zudem getrennte Einheitenbilanzen; die alte Arbeitermasse allein genügt nicht.

### Spielerwissen und Netzwerk

Aktueller Weltzustand, aktuelle Sicht, erkundetes Gelände und letzte bekannte Gebäudezustände sind verschiedene Daten. Verbündete teilen das Wissen, nicht die Energiekonten. Die Minimap darf den unbekannten Teil nicht aus der bisherigen Originaltextur nachreichen. Dasselbe gilt für Auswahl, Vorschau, Feindstatistiken und Fehlermeldungen.

Ein späteres Autoritäts-/Synchronisationskonzept muss diese Wissensgrenzen berücksichtigen. Welche Daten ein Client erhält und wann Sichtwissen aktualisiert wird, ist eine offene Netzwerkentscheidung. Eine echte Lobby und entfernte menschliche Spieler sind im Prototyp nicht vorhanden.

### Speichern, Replays und Leistung

Speicherformat 2 bleibt unverändert. Ob spätere Felder versioniert ergänzt werden, ein neues Format nötig wird oder alte Solo-Stände als eigener Modus lesbar bleiben, ist vor einer Migration zu entscheiden. Wissen, Baustellen, Produktion, Forschungszeiten, Eigentümerwechsel und Routen-Timer müssten in einer zukünftigen Speicher-/Replay-Spezifikation berücksichtigt werden.

Große Arbeiterbenchmarks bleiben technische Stress- und Regressionstests. Das neue Skalierungsziel verlangt gemischte Populationen mit wenigen Arbeitern und mehreren Tausend Kriegern je Spieler, Kontaktkämpfen, Engstellen, Sichtblockaden und Energieverkehr. FPS, reale Takte/s, Frame-Spitzen, Speicher und deterministische Ergebnisse werden getrennt bewertet. Die heute unveränderten 20 Hz und die Aufholgrenze sind kein Nachweis, dass ein zukünftiger Kampf diese Ziele erreicht.

Konkrete Abhängigkeiten, offene Spielregeln und vorgeschlagene Abnahmefälle stehen in [CONCEPT_SYNC.md](CONCEPT_SYNC.md). Eine Umsetzung benötigt einen neuen ausdrücklichen Auftrag.

## Einheitenphase vom 25. Oktober 2026

`ArmyState` hält separate Packed-Arrays mit stabilen Krieger-IDs und dichter Slot-Zuordnung. `ArmyRenderer` aktualisiert eine gemeinsame Textur, keine Nodes je Krieger. Arbeitermoves und Spawn-/Kernevakuierungsziele berücksichtigen die Kriegerbelegung. Eigene Arbeiter werden nur während Kriegerdurchquerung übersprungen; die Endzelle bleibt exklusiv. Armee- und Arbeiterverluste werden getrennt bilanziert. Die UI akzeptiert gemischte Auswahl, Version-2-Saves enthalten additive Armeedaten. Alte geometrische Arbeiter-Hilfen dienen noch der Altstand-Kompatibilität; der aktive Fusionsschritt und seine UI sind entfernt.

Die Profilgruppe SPAWN umfasst derzeit auch Energie und Armee; ihr Name ist keine isolierte Spawnzeit. Marschfelder werden geteilt, lokale Verteidigung nutzt begrenzte Terrain-Suche. Weltänderungen invalidieren die Marschfelder; höchstens 16 Zielzellen bleiben gecacht. Budgetierung beliebig vieler individueller Marschziele, Stauauflösung und die vollständige 10.000-Krieger-Abnahme sind offen. Kein neues Threading, kein Weltstreaming, keine Netzwerkimplementierung.

## Performance-Folgephase D-054, 25. Oktober 2026

Der nach dem Einheitenprototyp ausdrücklich beauftragte nächste Schritt ist lokal umgesetzt: optionaler nativer Armee-Rechenpfad mit taktweise geprüfter GDScript-Referenz und effizienterer pixelgleicher Kriegerdarstellung. Im offenen 10.000er-Marschfall sinkt die Taktzeit von 95,63 auf 2,61 ms. Verbleibende lange Grafikframes sind noch nicht nach Ursache isoliert. Aktuelle Messungen, Tests, Bibliothekswechsel und Grenzen stehen in [ARMY_PERFORMANCE.md](ARMY_PERFORMANCE.md); frühere gegenteilige Leistungsbefunde sind historische Messungen vor diesem Folgeschritt, keine aktuellen Taktzeiten. Weitere Spielsysteme wurden nicht begonnen.


## Stabilitätsauftrag 1–3, 25. Oktober 2026

Die ausdrücklich beauftragten Punkte sind geprüft und gezielt korrigiert. [STABILITY_VALIDATION.md](STABILITY_VALIDATION.md) enthält die vollständigen Nachweise: Windows-Gerätebaum-Meldungen als Frame-Ursache und Filter im eigenen Spielfenster; exakte Viele-Ziele-Wege mit begrenztem Terrain-Cache/Sichtgraph; 30 simulierte Minuten Attrition sowie 15 Minuten mit großen Reservearmeen, Wirtschaft und Kampf; additives Resume gegen abweichende Fortsetzung nach dem Laden. Die 60-s-Grafikprüfung mit 100 Arbeitern und rund 10.000 Kriegern erreicht rund 60 FPS und 20 Takte/s ohne Frame über 50 ms. Einzelne CPU-Spitzen der Headless-Langtests und synchrones Speichern bleiben ausdrücklich als Grenzen ausgewiesen. Feste Taktung und Spielregeln bleiben gleich; keine neuen Welt-/Bau-/Sicht-/Forschungs-/Netzwerksysteme begonnen.

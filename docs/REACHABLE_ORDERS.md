# Erreichbare Marschziele und geteilte Wege

Auftrag D-084, 27. Oktober 2026. Basis ist main nach Merge von PR #15 (`2b85612`). Neuer Branch `feat/reachable-unit-orders`, eigener Review-PR, kein automatischer Merge. Die währenddessen nachgereichten Antworten zu Waffenunterhalt/Forschung bestätigen D-083; sie erfordern keine weitere Änderung dieser bereits gemergten Regeln.

## Arbeiter

Ein direkter Marsch oder ein Verbindungsweg zu einem unzugänglichen Abbaugebiet verwendet eine gruppenweite Dijkstra-Suche. Kosten werden **lexikografisch** verglichen:

1. Anzahl der zu öffnenden abbaubaren Blöcke.
2. Bei gleicher Blockzahl: summierte Grundarbeit aus `Materials.WORK`.
3. Danach Laufstrecke; vollständige Gleichstände über feste Nachbarschafts-/Zell-ID-Reihenfolge.

Ein freier Umweg ist damit jedem Abbau vorzuziehen. Eine längere Verbindung mit einem Block gewinnt gegen eine kurze mit drei Blöcken. Bei gleicher Blockzahl wird weiches Gestein gegenüber Diamant bevorzugt. Ein Diamant gewinnt weiterhin gegen zwei weiche Blöcke: Der ausdrückliche Wunsch „weniger Blöcke bevorzugen“ ist die erste Priorität, keine Garantie der kürzesten Gesamtdauer. Laufzeitforschung, vorhandener Teilfortschritt oder temporäres Gedränge ändern diese Grundbewertung nicht. Alle Forschungsstufen, einschließlich Schwarmintelligenz 0, erhalten denselben Basispfad.

Obsidian, Gebäudefundamente und gesperrte Kernflächen werden nicht durchquert/markiert. Ein direkt angeklicktes unzerstörbares Ziel löst keine unnötige Suche durch alle Ressourcen aus; der vorhandene Annäherungsbefehl läuft zum erreichbaren Rand. Die bestehenden Korridorbreiten 1/3/5/7/9 je Auftragsschwarm bleiben erhalten. Die Kosten bewerten den mittleren Verbindungspfad; breitere Schwärme können wie bisher zusätzlich seitliches Material abbauen.

Ein echter Ausführungsfehler ist mitbehoben: Während ein Marsch noch markierte Abbauarbeit hat, darf ein näher am Endziel liegender anderer Wand-Haltepunkt nicht mit diesen Arbeitspositionen konkurrieren. Erst nach der geplanten Abbauarbeit führt das Feld zum eigentlichen Endpunkt. Eine Änderung dieses Modus startet auch einen laufenden inkrementellen Feldaufbau korrekt neu.

## Krieger und die Fünfertrupp-Idee

Die vorhandene Armee berechnete bereits gemeinsame Terrainfelder pro Ziel, mit einem begrenzten Cache und exakten nativen Freiraum-/Ecken-Abkürzungen. Fünf Krieger mit einem gemeinsamen Ziel benötigen deshalb auch ohne feste Truppproduktion keine fünf globalen Suchläufe. Ein festes Fünferprodukt spart diesen Suchanteil nicht zusätzlich; Belegung, individuelle HP, Nahkampf und Darstellung müssen weiterhin pro Dot verarbeitet werden.

Umgesetzt wird daher die gemeinsame Koordination über **ein Ziel-Wegfeld für beliebig viele ausgewählte Krieger**. Produktion und Einzelauswahl bleiben erhalten. Jeder Krieger behält seine Lebenspunkte, stabile ID, Belegung und Kampflogik. Es gibt weder Gruppenschaden noch eine zusätzliche Node pro Trupp oder Krieger. Kein fünffacher Gesamtgeschwindigkeitsgewinn wird behauptet.

Ist das Ziel erreichbar, bleibt die bestehende kürzeste freie Bewegung erhalten. Für jede andere zusammenhängende freie Höhle enthält das gemeinsame Feld nun einen eigenen nächsten Standpunkt: kleinster Manhattan-Abstand zum ursprünglich angeklickten Ziel. Bei Gleichstand bilden alle gleich nahen Randzellen gemeinsame Quellen; dadurch wählt jeder Krieger den kürzesten freien Laufweg zu einem davon. Ein bereits passend stehender Krieger bleibt stehen. Auch ein Gebäudeklick behält den angeklickten Punkt und wählt nicht pauschal dessen erstes Randfeld. Krieger laufen auf freien Wegen dorthin, bleiben vor belegten Zellen stehen und graben nicht. Auch ein vollständig ummauertes oder im schwarzen Nebel liegendes Ziel funktioniert. Die interne Terrain-Wegsuche schreibt keine Fog-/Erinnerungsdaten und verrät keine fremden Aufträge oder HP. Normale Sicht entsteht weiterhin nur über tatsächliche Einheiten-/Gebäudequellen.

Der Originalauftrag wird gespeichert. Ein Durchbruch oder eine neue Terrainbarriere invalidiert die Route; nach Öffnung laufen die Krieger ohne neuen Klick weiter, nach Schließung nähern sie sich erneut. Dynamische Einheitenbelegung bleibt außerhalb des Terraincaches und wird vor jedem Schritt geprüft. Kampf und örtliche Gegnerverfolgung haben ihre bisherigen Prioritäten.

## Rechenkern und Speicherung

Native **v12** ergänzt `excavation_path` mit von GDScript übergebener Materialarbeit und `army_step_reachable` als Kennzeichen der neuen Armeeregel. Der gewichtete Auftragspfad hat dieselbe ausführbare GDScript-Referenz; alte DLLs ohne die neue Armeemethode dürfen nicht versehentlich die alte Stopplogik verwenden. Sie fallen für die Armee auf die aktuelle Referenz zurück. Bestehende Bewegung, Fog und Energietransporte bleiben erhalten.

Windows: `native/build.ps1` neu ausführen, anschließend Godot/Spiel vollständig neu starten. Ein laufender v11-Prozess lädt die Änderung nicht nach. In dieser Cloud ist Linux/Godot 4.3 ausgeführt; ein Windows-Lauf ist dadurch nicht nachgewiesen.

Version 2 bleibt bestehen. Die zwei optionalen, streng booleschen Resume-Felder `mining_first`/`built_mining_first` erhalten den Zustand mitten im budgetierten Arbeiter-Feldaufbau. Altstände ohne diese Felder bleiben lesbar; ungültige Typen werden vor Übernahme abgelehnt. Terrainfelder/Diagnosezähler sind abgeleitet und keine neuen Spielwerte.

## Nachweise

`tests/test_reachable_orders.gd` enthält 17 neue Verhaltenstests: längerer Ein-Block-Weg, freier Umweg, Material-/Laufweg-Gleichstände, Blockzahlvorrang, automatische Verbindung zu einem Abbaugebiet, exaktes Resume mitten im Aufbau, Obsidian/Kernmaske, getrennte Höhlen, festes vollständig eingeschlossenes Ziel, Durchbruch nach Save/Load, schwarzer Nebel ohne Wissensänderung, geteiltes Feld mit individuellen HP, 35 native/Referenz-Zufallswelten über alle Materialien, viele getrennte Ziele, spätere Wegschließung alte/beschädigte Resume-Daten und den echten HUD-Klick auf ein Gebäude von der Ostseite.

Lokal: erster vollständiger Durchlauf mit 404 Tests (beide Varianten) grün; nach Erweiterung alle 17 neuen Tests nativ mit 259 und in GDScript mit 223 Prüfungen grün. Die bestehenden GPU-Bedienprüfungen für P6, Nahkampf und Verteidigung bestehen mit `0 failures`. Der abschließende vollständige CI-Lauf einschließlich aller zehn vorhandenen Grafikprüfungen wird mit Commit und tatsächlichem Ergebnis im Review-PR dokumentiert.

Isolierter lokaler Armee-Benchmark, 256×256, 10.000 unabhängige Krieger, ein gemeinsamer Auftrag, 120 Takte, erste 20 Takte vom Mittel ausgeschlossen:

| Fall | Mittel Armee-Schritt | Kalter erster Schritt | Bewegte Krieger | volle Felder |
| --- | ---: | ---: | ---: | ---: |
| Erreichbares Ziel, vorher | 1,103 ms | 1,446 ms | 10.000 | 0 (Freiraumnachweis) |
| Erreichbares Ziel, nachher | 1,504 ms | 2,099 ms | 10.000 | 0 (Freiraumnachweis) |
| Abgetrenntes Ziel, vorher | 1,100 ms | 1,294 ms | **0** | 1 |
| Abgetrenntes Ziel, nachher | 1,606 ms | 2,597 ms | **10.000** | **1** |

Es sind einzelne Messläufe auf derselben Cloud-Umgebung, keine statistisch kontrollierten CPU-Vergleiche. Größter gemessener Schritt im letzten Lauf: 3,902 ms beim erreichbaren und 11,199 ms beim abgetrennten Ziel. Die neue Funktion bewegt die zuvor untätigen Krieger; der Vergleich ist kein Nachweis einer Beschleunigung gegenüber der alten Untätigkeit. Er belegt, dass auch die neue Annäherung keinen globalen Suchlauf pro Dot benötigt. Laufende Frames, Rendering/Fog, volle Schlachten, andere Hardware und 10.000 verschiedene individuelle Ziele sind nicht durch diese Armee-Mittelwerte abgenommen. Die nativen Terrainfelder bleiben auf 32 MiB/128 Felder begrenzt, die GDScript-Referenz auf 16 Ziele. Viele unterschiedliche Ziele und häufig wechselndes Terrain kosten weiter zusätzliche Arbeit.

Separater einmaliger gewichteter Arbeiterauftrag auf derselben Kartengröße mit großem Gesteinsbereich: native Suche **8,009 ms**, GDScript **766,028 ms**, identische 401 Pfadzellen. Das ist Auftragserstellung, keine Arbeit pro Dot/Takt. Der native Pfad ist für große Karten wichtig; die Referenz dient auch als korrekter Fallback, kann dabei aber sichtbare Pausen verursachen.

Reproduktion:

```sh
bash native/build.sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --headless --path . -s bench/reachable_orders_benchmark.gd -- --require-native
```

CI führt den neuen Benchmark mit Bewegungs-/Bilanz-/Feldanzahlprüfung aus und speichert das Messprotokoll als Artefakt. Zeitwerte werden ausgewiesen, ohne hardwareabhängige Millisekundengrenzen als Funktionstest zu erzwingen.

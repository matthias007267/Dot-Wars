# Armee-Performance: nächster freigegebener Schritt

**Aktueller Folgestand:** Die später ausdrücklich beauftragte Stabilitätsprüfung Punkte 1 bis 3 ist umgesetzt. [STABILITY_VALIDATION.md](STABILITY_VALIDATION.md) dokumentiert den Windows-Gerätemeldungs-Fix, exakte Viele-Ziele-Wege, gemischte Langtests und additives Resume. Die folgenden älteren Messungen und Bibliotheksgrenzen sind historischer Stand vor dieser Folgephase.

25. Oktober 2026. Folgeauftrag „gehe jetzt den nächsten Schritt vor“ nach dem Einheitenprototyp. Umfang: die nachgewiesenen Armee-Engpässe optimieren, Regeln und Simulationstakt erhalten, Referenzgleichheit und Grafikleistung prüfen. Keine Bau-, Forschungs-, Sicht- oder Netzwerkphase begonnen.

## Ergebnis und praktische Grenze

Im reproduzierbaren 256er-Marsch-/Annäherungsfall mit 10.000 anfänglichen Kriegern fällt die durchschnittliche vollständige Taktzeit von **95,63 auf 2,61 ms**. 2.000 Krieger fallen von 18,49 auf 0,73 ms. Alle vier ursprünglichen Lastfälle behalten exakt ihre Endhashes und konsistente Belegung/Mengenbilanzen. Die feste 20-Hz-Taktung, Angriffsraten, Bewegungspausen und Aufholgrenze wurden nicht geändert.

Der isolierte Grafikvergleich mit identischem 60-FPS-Limit und 10.000 anfänglichen Kriegern erreicht mit dem neuen Kern **53,84 FPS und 19,68 tatsächliche Takte/s**, die explizite Armee-Referenz **1,78 FPS und 8,90 Takte/s**. Ein zweiter nativer Lauf mit zusätzlicher Titelzeitmessung erreicht 48,41 FPS und 19,26 Takte/s. Die 20-Hz-Taktung ist damit weitgehend erreichbar, die Frame-Konstanz noch nicht vollständig zufriedenstellend. Beide isolierten Läufe erfolgen nach geordnetem Schließen der zwei vorher von mir gestarteten, unbenutzten Spielmenüs; die Aussetzer bleiben trotzdem bestehen.

Im ersten isolierten nativen Lauf beträgt der maximale Frame 319,34 ms, p95 23,52 ms und die verworfene Aufholzeit 0,214 s. Im weiteren Lauf maximal 320,29 ms und 0,376 s verworfene Zeit. Der komplette Spiel-`_process`-Aufruf dauert maximal 16,07 bzw. 17,02 ms; der letzte Simulationstakt während der Aussetzer etwa 2,4–3,0 ms. Die Fenstertitel-Aktualisierung des Benchmarks braucht maximal 0,245 ms und erklärt diese Ausreißer ebenfalls nicht. Rendering/Präsentation, übrige Engine-Arbeit und Scheduling sind noch nicht voneinander isoliert; eine konkrete Treiber-/Windows-Ursache ist nicht nachgewiesen. Das ist noch keine vollständige Langzeit-/Multiplayer-Abnahme.

Die früheren Vorab-Grafikläufe sind ebenfalls als Rohdaten erhalten, aber wegen paralleler Menüs kein sauber isolierter Hauptvergleich: nativ bei 10.000 anfänglichen Kriegern 56,18 FPS / 19,56 Takte/s mit 60-FPS-Cap, sowie vor der Rendereroptimierung unlimitiert 1.201 FPS / 19,30 Takte/s. Der ursprüngliche Einheitenprototyp erreichte unlimitiert 1,87 FPS / 9,34 Takte/s. Verlässlich isoliert die Headless-Messung die Beschleunigung des Rechenkerns.

Ein zusätzlicher isolierter 2.000-Krieger-Lauf erreicht 50,97 FPS / 19,39 Takte/s, mit maximal 309,81 ms pro Frame bei höchstens 4,92 ms gemessenem Spielprozess und 0,155 ms Titelaktualisierung. Ähnliche Ausreißer treten also auch bei deutlich kleinerer Armee auf; ihre Ursache wird weiterhin offen gehalten.

## Nachgewiesener Engpass und Änderung

Eine ausdrücklich eingeschaltete Armee-Profilierung des Referenzpfads erfasste im 10.000er-Marschfall über 120 Takte rund 5,34 s für Kontaktabfragen, 3,52 s für Verteidigungs-/Zielwahl und 4,02 s für Wege/Bewegung. Profilierung verursacht zusätzliche Zeit und wird nicht mit den unprofilierten Laufzeiten vermischt.

`native/army_kernel.inc` erweitert den bestehenden optionalen Godot-4.3-C-Rechenkern um die sequentielle Armee-Arithmetik. Reihenfolge ist weiterhin nach stabilen Krieger-IDs; spätere Krieger sehen frühere Bewegungen desselben Takts. Die Suche verwendet dieselbe Zeilen-/Spalten- und Zielpriorität, die lokale Verteidigungs-BFS dieselbe Begrenzung und Nachbarreihenfolge. Eigene Arbeiterkorridore kosten dieselbe Bewegungszeit und erhalten ausschließlich freie Endpositionen. Treffer werden gesammelt und erst in GDScript angewendet; Produktion, HP, Tode, Bilanzen und Speicherzustand bleiben dort geführt.

Der Adapter liefert Ganzzahlparameter und gemeinsame Terrain-Wegfelder. Bis 16 verschiedene Marschziele nutzt er den neuen Rechenkern; bei mehr Zielen oder einer alten/fehlenden Bibliothek bleibt die ausführbare GDScript-Referenz zuständig. Diese Grenze ist eine Optimierungsgrenze, kein Befehlslimit. Sehr viele individuelle Ziele und große/oft geänderte Welten bleiben gesonderte Lastfälle. Keine Threads und keine Nodes je Dot.

Der Krieger-Renderer verwendet eine feste, pixelgleich geprüfte Farbpalette, vier direkte Löschzugriffe je belegter Zelle und eine gebündelte Kopie der gezeichneten Positionen. Wiederholte Farbkonvertierungen und kleine innere Schleifen entfallen. Der normale Spielbetrieb erhält durch diesen Auftrag keinen neuen FPS-Limiter; `--fps-cap=60` ist ein expliziter Diagnoseparameter des Armee-Grafikbenchmarks.

Windows-Bibliothek: `native/bin/dot_wars_native.windows.x86_64.v4.dll`. Die vorige v3-Datei wurde nicht überschrieben, damit bereits laufende Instanzen ihre geladene Bibliothek behalten. Zum Testen des neuen Standes das Spiel vollständig neu starten; die Bibliothek wird nicht im laufenden Spiel ausgetauscht. Die DLL bleibt wie bisher ein lokales, nicht versioniertes Buildprodukt. Linux-Quellen sind aktualisiert, aber auf diesem Windows-PC nicht gebaut oder ausgeführt.

## Prüfung

- Vollständige native Testsammlung: **226 Tests, 31.422 Prüfungen, 0 Fehler**.
- Vollständige Sammlung ohne Native-Backend: **226 Tests, 28.143 Prüfungen, 0 Fehler**. Native-spezifische Vergleiche entfallen dabei ausdrücklich, daher weniger Prüfungen.
- Neue direkte Vergleichsfälle: acht deterministische Zufallskarten über je 50 Takte, darunter Wände, Bündnisse, KI-Steuerung, Geländeänderung, Produktion und Todesfälle. Zusätzlich 2.500 Krieger über 15 Takte. Zustandshash und dynamische Belegung werden nach jedem Takt verglichen; Zähler bestätigen den tatsächlichen nativen Einsatz.
- Ungültige Arraylängen, doppelte IDs und ungültige Breite werden ohne Änderung der Eingaben abgelehnt. Mehr als 16 Marschziele nutzen den geprüften Referenz-Fallback. Renderer-Test prüft alle Fraktionsfarben, Löschen getöteter Krieger und unveränderten Simulationszustand.
- Die schon vor dieser Arbeit vorhandene Änderung in `swarm_mind.gd` wurde über identische SHA-256-Werte vor/nach der Phase als unverändert bestätigt. Der verschachtelte zweite Checkout bleibt unangetastet.

Die ERROR-Zeilen für absichtlich ungültige Startwelten/Konfigurationen gehören zu vorhandenen Negativtests, nicht zu Testfehlern. Es wurden keine Commits oder Veröffentlichungen vorgenommen.

## Messprotokoll

Godot 4.3, Ryzen 9 5950X, RTX 2070 SUPER, zwei Fraktionen, offene 256er-Welt. Headless: 120 Takte, davon 20 Warmup. Neue Mittelwerte, p95 und Maximum der vollständigen Simulation:

- 2.000 anfängliche Krieger im Marsch/Annähern: 0,730 / 0,872 / 1,392 ms; 1.600 am Ende.
- 10.000 anfängliche Krieger im Marsch/Annähern: 2,612 / 2,751 / 3,412 ms; 9.600 am Ende.
- 2.000 anfängliche Krieger im dichten Nahkampf: 0,765 / 1,371 / 3,589 ms; 45 am Ende.
- 10.000 anfängliche Krieger im dichten Nahkampf: 2,868 / 6,586 / 18,495 ms; 205 am Ende.

Die beiden letzten Fälle verlieren während des Laufs viele Krieger. Deshalb gibt es zusätzlich `--sustained-contact`: 40 Takte, davon 10 Warmup, mit dichtem Kontakt und **keinen Todesfällen während des gesamten Laufs**. Dabei verursachen und erhalten die Krieger regulär Schaden:

- 2.000 Krieger durchgehend lebend: Mittel 0,739 ms, p95 1,380 ms, Maximum 1,382 ms.
- 10.000 Krieger durchgehend lebend: Mittel 2,758 ms, p95 6,547 ms, Maximum 6,649 ms.

Diese kurze Kontaktprüfung ist ein belastbarer voller Populationsfall, aber kein Langzeittest. Die Werte sind keine Garantie für 10.000 unterschiedliche Ziele, dichten Abbau, Fog of War, endlose Welten oder Netzwerkbetrieb.

Grafikmessungen verwenden die echte Szene, HUD und vollständig sichtbare Armeen bei 1920×1080, deaktiviertem VSync, 3 s Warmup und 10 s Messzeit. `--fps-cap=60` begrenzt ausschließlich diesen expliziten Lauf. Rohdaten liegen lokal unter `bench/results/army-performance-2026-10-25/`.

```text
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --headless --path . -s bench/army_benchmark.gd -- --require-native
godot --headless --path . -s bench/army_benchmark.gd -- --sustained-contact
godot --headless --path . -s bench/army_benchmark.gd -- --sustained-contact --army-reference
godot --headless --path . -s bench/army_benchmark.gd -- --profile-army
godot --path . -s bench/army_live_benchmark.gd -- --warriors=10000 --fps-cap=60 --out=bench/results/army-10000-60.json
```

`--army-reference` deaktiviert nur den nativen Armee-Schritt; andere vorhandene native Operationen bleiben möglich. `--no-native` deaktiviert das gesamte Native-Backend. `--profile-army` misst ausdrücklich die GDScript-Armee-Unterphasen und aktiviert deshalb für die Armee die Referenz. Diagnose-/Profilzähler beeinflussen weder Zustandshash noch Saveformat. Nachfolgende Arbeit: die verbleibenden langen Frames isolieren, individuelle Marschziele und wechselndes Gelände vermessen, dann eine gemischte Langzeitabnahme festlegen.

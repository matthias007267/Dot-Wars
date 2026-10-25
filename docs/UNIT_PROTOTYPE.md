# Einheitenprototyp vom 25. Oktober 2026

**Aktueller Folgestand:** Die später ausdrücklich beauftragte Stabilitätsprüfung Punkte 1 bis 3 ist umgesetzt. [STABILITY_VALIDATION.md](STABILITY_VALIDATION.md) dokumentiert den Windows-Gerätemeldungs-Fix, exakte Viele-Ziele-Wege, gemischte Langtests und additives Resume. Die folgenden älteren Messungen und Bibliotheksgrenzen sind historischer Stand vor dieser Folgephase.

Lokale Umsetzung nach ausdrücklichem Folgeauftrag zur Planungspause. Verbindliche Entscheidungen D-051 bis D-053 in [DECISIONS.md](DECISIONS.md); keine Veröffentlichung oder Commit. Das Hauptprojekt liegt unter `C:/Users/matth/Documents/GitHub/Dot-Wars`. Der gleichnamige Unterordner `dot-wars/` ist ein anderer Checkout und wurde nicht verändert.

## Aktueller Performance-Nachtrag

Die nachfolgend ausdrücklich beauftragte Armee-Optimierung ist umgesetzt: 10.000 Krieger im bisherigen Headless-Marschfall benötigen im Mittel 2,61 statt 95,63 ms pro Takt. Der begrenzte Grafiklauf erreicht im isolierten Vergleich 53,84 FPS und 19,68 Takte/s (weiterer Lauf: 48,41 FPS / 19,26 Takte/s), mit einzelnen verbleibenden Aussetzern. [ARMY_PERFORMANCE.md](ARMY_PERFORMANCE.md) enthält die aktuellen Tests, Messungen, die v4-Bibliothek und die Grenzen. Die Messwerte und Testzahlen weiter unten dokumentieren den ursprünglichen Einheitenprototyp vor diesem Folgeschritt.

## Spielbare Änderungen

- Maximal 50 Arbeiter pro Spieler, lebende und bereits bezahlte wartende Käufe zusammen. Ein abgelehnter Kauf verbraucht keine Energie. Krieger zählen nicht dazu. Markierte Diagnosefixtures dürfen größere Populationen haben und keine regulären Spielstände schreiben.
- Fusion aus dem aktiven Spiel entfernt: kein Fusionssystem, keine Fusionskäufe, Größenbefehle oder Fusions-Testlaborsteuerung. Interne geometrische Hilfen bleiben für Altstände erhalten.
- Kriegerproduktion am vorhandenen Hauptkern, eigener Krieger-Kaufknopf, Einzel-/Rechteckauswahl und gemischte Marschbefehle. Eigene Krieger sind rot, gegnerische tragen die jeweilige Fraktionsfarbe.
- Alle Krieger blockieren einander. Eigene Arbeiter können durchquert werden; eine Endposition muss leer sein. Durchquerte Strecke wird vollständig in der anschließenden Bewegungspause berechnet. Arbeiterbewegung, KI-Käufe, reguläre Platzierung, Testlabor und Kernevakuierung respektieren die Kriegerbelegung.
- Krieger greifen feindliche Dots bei orthogonalem Kontakt an und reagieren im kleinen Verteidigungsradius. Angegriffene Arbeiter behalten ihren Arbeitsauftrag. Treffer einer Kampfrunde werden gesammelt, bevor Tote entfernt werden. Nur Krieger beschädigen gegnerische Kerne.
- Alte Solo-Siegziele vollständig deaktiviert; Anzeige „FREIES SPIEL“. Bestehende lokale Match-Siegoptionen wurden nicht als neuer Gesamtentwurf ersetzt.

## Ausdrücklich vorläufige Zahlen

Krieger kosten 20 Energie und sind frühestens nach 20 Takten fertig. Sie haben 12 HP, verursachen 1 Schaden alle 10 Takte und laufen mit 2 Takten je Zelle. Arbeiter haben 5 HP. Bei 1× entsprechen 20 Takte einer Sekunde. Der Verteidigungsradius beträgt 3 Manhattan-Zellen, mit gestaffelter Nachprüfung alle 5 Takte. Die lokale Verfolgung plant nur innerhalb dieses Radius; längere Umwege sind darin nicht enthalten. Mehrere Produktionsaufträge dürfen vorläufig parallel reifen; blockierte Platzierungen warten. Die KI kauft vorläufig höchstens 2.000 lebende/wartende Krieger, kein allgemeines Kriegerlimit für den Spieler.

Diese Werte sind ein testbarer Prototyp, kein beschlossener finaler Forschungs-, Wirtschafts- oder Produktionsbaum. Marschbefehle verwenden gemeinsame Terrain-Wegfelder. Dynamische Staus werden noch nicht durch Formationen oder ein ausgereiftes Umleitungssystem aufgelöst.

## Selbst testen

1. Im Hauptprojekt `project.godot` mit Godot 4.3 öffnen und das Projekt starten. Ein bereits laufendes Spiel muss neu gestartet werden, um den neuen Code zu laden.
2. Für Kampf im Startmenü eine Partie gegen KI wählen. Im bisherigen Solo-Modus gibt es keine gegnerische Armee, und die alten Siegziele sind deaktiviert.
3. Energie abbauen und den Eingang am Kern abwarten. „KRIEGER“ bestellt für 20 Energie einen Krieger. Nach mindestens einer Sekunde bei 1× erscheint er auf einer freien Zelle beim Kern; bei voller Umgebung wartet er.
4. Eigene Dots mit Linksklick oder Auswahlrechteck markieren und mit Rechtsklick auf freie Wege schicken. Ein Auswahlrechteck kann Arbeiter und Krieger gemeinsam erfassen. Kern-/Gebäudebau, Forschung und Fog of War sind noch nicht Teil dieses Prototyps.
5. Für große Lastfälle die untenstehenden Diagnosefixtures verwenden. Sie erzeugen gezielt Krieger statt die neue Arbeitergrenze im normalen Spiel zu umgehen.

## Speicherkompatibilität

Version 2 bleibt lesbar und erhält additive Kriegerdaten mit stabilen IDs, HP, Zielen, Abklingzeiten und Produktionsaufträgen. Alte Stände ohne Kriegerdaten laden eine leere Armee; alte Arbeiter erhalten 5 HP. Fusionierte Arbeiter werden beim Laden in die entsprechende Zahl einzelner 1×1-Arbeiter aufgeteilt, ohne Masse zu verlieren. Ihr konkreter alter Arbeitszustand wird dabei neu bestimmt. Bestehende Altpopulationen über 50 werden erhalten; neue Käufe bleiben bis unter 50 gesperrt. Alte Solo-Siege werden zurückgesetzt. Bloßes Laden schreibt den ursprünglichen Slot nicht um; späteres manuelles Speichern oder das normale Autosave kann den migrierten Zustand speichern.

## Prüfung und reproduzierbare Messungen

Die vollständige native Regression besteht mit **221 Tests, 30.145 Prüfungen, 0 Fehlern**. Zusätzlich bestehen 15 Einheitentests mit 144 Prüfungen ohne nativen Rechenkern. Abgedeckt sind unter anderem Limit und Zahlung, eigene Arbeiterdurchquerung, verbündete Kriegerblockade, weiterarbeitende angegriffene Arbeiter, gleichzeitige Tode, stabile Auswahl-IDs nach Slottausch, Speichern/Fortsetzen, beschädigte Armeedaten, Alt-Fusion, gemischte Auswahl, lokale Umwege, parallele Produktion, Kernevakuierung, KI-Nachkäufe und blockiertes Quellenwachstum unter Kriegern. Die wenigen ERROR-Ausgaben für absichtlich ungültige Startwelten/Konfigurationen gehören zu bestehenden Negativtests; der Runner meldet keine Testfehler.

```text
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- unit_phase --no-native
godot --headless --path . -s bench/army_benchmark.gd -- --require-native
godot --path . -s bench/army_live_benchmark.gd -- --warriors=2000 --out=bench/results/army-2000.json
godot --path . -s bench/army_live_benchmark.gd -- --warriors=10000 --out=bench/results/army-10000.json
```

Die Headless-Fixtures verwenden eine offene 256er-Karte und zwei Fraktionen, mit 2.000 bzw. 10.000 Kriegern insgesamt, 120 Takten und Messung der letzten 100 Takte. „contact=false“ bedeutet Marsch/Annäherung zweier Armeen und enthält später Kontakt; „contact=true“ startet in dicht durchmischtem Nahkampf. Im Kontaktfall sterben die meisten Krieger während des Laufs; der Durchschnitt ist daher **kein** Nachweis dauerhafter Last mit der Anfangspopulation.

Mit Godot 4.3, Ryzen 9 5950X und vorhandenem Native-Backend:

- 2.000 Krieger, Marsch/Annäherung: durchschnittlich 18,49 ms/Takt, p95 19,84 ms, Maximum 22,68 ms; am Ende 1.600 lebend.
- 10.000 Krieger, Marsch/Annäherung: durchschnittlich 95,63 ms/Takt, p95 101,40 ms, Maximum 110,37 ms; am Ende 9.600 lebend.
- Dicht durchmischter Nahkampf: bei 2.000 anfänglichen Kriegern 9,61 ms/Takt, am Ende 45 lebend; bei 10.000 anfänglichen Kriegern 48,89 ms/Takt, am Ende 205 lebend. Beide Ergebnisse werden wegen der Todesfälle nicht als stabile Maximalpopulation gewertet.

Eine lokale Verteidigungs-Wegsuche ersetzt den vorherigen weltweiten BFS je naher Zielzelle. Im identischen Marschfall sank der Durchschnitt von 54,76 auf 18,49 ms bei 2.000 und von 135,26 auf 95,63 ms bei 10.000. Alle vier Szenarien behielten ihre jeweiligen Endhashes gegenüber dem vorherigen Suchpfad.

Grafikprüfung mit echter Szene, HUD, beiden Armeen im Bild, 1920×1080, RTX 2070 SUPER, ohne VSync, 3 s Warmup und 10 s Messzeit:

- 2.000 anfängliche Krieger: 19,70 tatsächliche Takte/s, durchschnittlich 1.026,7 FPS; maximaler Frame 362,8 ms und 0,156 s verworfene Aufholzeit. Hoher Durchschnitt schließt einzelne Aussetzer nicht aus.
- 10.000 anfängliche Krieger: 9,34 tatsächliche Takte/s und 1,87 FPS; maximaler Frame 843,7 ms und 5,494 s verworfene Aufholzeit. Das 20-Hz-Ziel wird klar verfehlt.

Alle gemessenen Endzustände erfüllen die Belegungs- und Mengenbilanzen. Die vollständigen Rohdaten liegen lokal unter `bench/results/unit-prototype-2026-10-25/`. Der Grafiklauf ist eine synthetische offene Welt mit wenigen Arbeitern, kein Abbau-/Fog-/Netzwerk-Langzeittest. Die gesonderte Profilgruppe SPAWN enthält derzeit auch Energie und Armee, keine isolierte Spawnzeit.

## Bewusst offene Folgearbeit

Ursprünglicher Befund vor dem Folgeschritt: 10.000 aktive Krieger überschritten das Taktbudget. Dieser Armee-Engpass ist inzwischen gemäß ARMY_PERFORMANCE.md behoben. Einzelne lange Grafikframes sowie viele individuelle Marschziele und große/wechselnde Wegfelder bleiben zu untersuchen; die aktuellen Aussetzer werden nicht ungeprüft der inzwischen kurzen Simulation zugeschrieben. Die feste 20-Hz-Taktung und die Aufholgrenze wurden dafür nicht verändert.

Noch nicht umgesetzt: große nachladbare Welt, diagonale Wege und natürliche Höhlen; Außenposten, Arbeiterbaustellen und Überleben durch begonnenen Kernbau; vollständiger Energieraub/Neutralisierung/60-s-Verfall; Fog of War und geteiltes Bündniswissen; zeitbasierte Parallelforschung; echte Netzwerk-Lobby. Die interne Teamzuordnung ist nur eine Grundlage für Kampfprüfungen. Die Minimap bildet die Krieger noch nicht gesondert ab. Das alte sofortige Ausscheiden bei Kernverlust bleibt im Match-Prototyp bis zur Bau-/Überlebensphase bestehen.

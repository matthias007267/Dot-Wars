# Stabilitätsprüfung: Punkte 1 bis 3

25. Oktober 2026. Ausdrücklicher Auftrag: verbliebene Frame-Aussetzer eingrenzen, schwierige Armeewege prüfen und eine längere gemischte Partie testen. Lokal umgesetzt und geprüft; keine Commits oder Veröffentlichung. Regeln, feste 20 Hz, Angriffswerte und Aufholgrenze bleiben erhalten. Neue Bau-, Forschungs-, Sicht- und Netzwerksysteme wurden nicht begonnen.

## 1. Lange Frames: Ursache gefunden und gezielt korrigiert

Der Frame-Probe trennt Skriptphase, Render-Signale und Zeit bis zum nächsten Frame. Vor der Korrektur lagen die 150–450-ms-Aussetzer überwiegend nach dem gemeldeten Zeichenabschluss; die Skriptarbeit und gemessene CPU-/GPU-Zeichenzeit waren viel kürzer. Dieselben Aussetzer traten mit komplett abgeschaltetem Render-Loop sowie in einem leeren Fenster ohne Spielsimulation auf. Im identischen Kontrolllauf ohne Fenster gab es keine Aussetzer über 50 ms; auch ein unabhängiger Windows-Schlaftimer blieb darunter. Ein kurzes Vollbildexperiment entfernte die Aussetzer nicht.

Die anschließende Zeitmessung der originalen Fensterprozedur identifizierte `WM_DEVICECHANGE` (537 / 0x219), konkret `DBT_DEVNODES_CHANGED` (7), mit bis zu rund 149 ms je Aufruf. Godot 4.3 führt bei jeder solchen Nachricht synchron eine vollständige Joypad-Suche aus. Diese Zuordnung ist sowohl lokal gemessen als auch im [Godot-4.3-Fenstercode](https://github.com/godotengine/godot/blob/4.3-stable/platform/windows/display_server_windows.cpp#L4709) und der [Controller-Suche](https://github.com/godotengine/godot/blob/4.3-stable/platform/windows/joypad_windows.cpp#L286) nachvollziehbar. Welches Hintergrundgerät die wiederholten Meldungen erzeugt, wurde nicht bestimmt; kein Gerät und kein Treiber wurde deaktiviert.

`src/window_event_guard.gd` und `native/window_probe.inc` filtern ausschließlich allgemeine Gerätebaum-Meldungen, wenn die vollständig abgefragte Raw-Input-Geräteliste unverändert ist. Tatsächliche Ankunfts-/Entfernungsmeldungen und Abfragefehler werden immer an Godot weitergereicht. HID- und XInput-Schnittstellenmeldungen werden zusätzlich für das eigene Fenster angemeldet. Die Umsetzung nutzt [Windows-Gerätebenachrichtigungen](https://learn.microsoft.com/en-us/windows/win32/devio/registering-for-device-notification); die Registrierung und Fensterprozedur werden beim Abschalten wiederhergestellt. Die Prüfung betrifft ausschließlich das eigene Spielfenster, keine fremden Prozesse oder globalen Systemeinstellungen.

Die synthetische Fensterprüfung bestätigt: unveränderte allgemeine Meldung gefiltert, HID-Ankunftsmeldung weitergeleitet und originale Fensterprozedur wiederhergestellt (`[1, 1, 1]`). Ein physischer Controller-Stecktest wurde nicht durchgeführt. Der Filter kann mit `--no-device-change-guard` abgeschaltet werden; ohne unterstützte native Bibliothek bleibt der bisherige Fensterpfad aktiv. Diagnose-Tracing erfordert zusätzlich ausdrücklich `--trace-window`.

Ergebnisse nach der Korrektur, 1920×1080 und 60-FPS-Grenze:

- Leeres Kontrollfenster: 60,25 FPS, keine Frames über 50 ms; neun redundante Meldungen gefiltert.
- Offene Welt mit 10.000 Kriegern: 59,99 FPS und 20,03 Takte/s über 20 s Messzeit; maximaler Frame 27,79 ms, keine Frames über 50 ms; 30 redundante Meldungen gefiltert.
- Gemischte Partie mit 100 Arbeitern, anfangs 10.000 Kriegern und laufender Wirtschaft/Kampf: 60,00 FPS und 20,00 Takte/s über 60 s Messzeit; maximaler Frame 44,13 ms, p95 35,19 ms, keine Frames über 50 ms. Am Ende 9.832 Krieger; 68 redundante Meldungen gefiltert.

Die durchschnittliche Framerate ist damit stabil, aber nicht jeder Frame dauert exakt 16,67 ms. Das diskrete 20-Hz-Simulationsmodell wurde nicht durch Interpolation oder eine andere Spielgeschwindigkeit ersetzt.

## 2. Einzelziele, Labyrinth, Engstellen und Geländeänderungen

Der bisherige pauschale Rückfall auf die GDScript-Armee bei mehr als 16 verschiedenen Zielen ist für den neuen nativen Rechenpfad entfernt. Der Adapter erhält keine vollständig vorgebauten Felder je Einzelziel mehr. Stattdessen verwendet der Rechenkern:

- Einen Terrain-Cache mit exaktem Vergleich der Weltzellen, damit auch interleavte Welten mit gleicher Revisionsnummer nicht verwechselt werden.
- Einen Summenpuffer als exakten Nachweis freier Rechtecke bzw. geprüfter L-Wege. Ein Manhattan-Abstand wird nur verwendet, wenn ein entsprechend freier Weg nachgewiesen ist und die ursprüngliche Richtungsauswahl erhalten bleibt.
- Sofortiges Erkennen vollständig blockierter Einheiten, ohne dafür eine unnötige Wegsuche auszuführen.
- Bis zu 128 vollständige Terrain-Felder mit einem regulären Feldbudget von 32 MiB. Bei Karten, deren einzelnes Feld größer ist, bleibt mindestens ein Feld möglich; dies ist keine Speicherzusage für riesige Welten.
- Für seltene Ziele bei höchstens 256 Hindernisecken einen exakten rechtwinkligen Sichtgraphen. Jede Kante ist ein verifizierter freier Weg; Zielendpunkte werden in der ursprünglichen Richtungsfolge geprüft. Bei komplexerem Terrain bleibt die vollständige Raster-BFS zuständig.
- Höchstens acht neu vorgewärmte Vollfelder für seltene Ziele pro Takt, solange der exakte Graphpfad verfügbar ist. Bewegungen werden dabei nicht verschoben: Der Graph liefert sofort die korrekte Entscheidung. Häufige gemeinsame Ziele erhalten weiterhin vollständige Felder.

Die neue Suche bleibt terrainbasiert. Kriegerbelegung wird für jede Einheit in stabiler ID-Reihenfolge aktuell gelesen. Ein eigener Arbeiterkorridor darf nur bis zu einem freien Endpunkt durchquert werden; seine gesamte Länge zählt zur Bewegungspause. Unauflösbare Gegenströme im Ein-Zellen-Weg bleiben physisch blockiert. Es wurde kein Durchqueren verbündeter Krieger oder verstecktes Teleportieren eingeführt. Ein Regressionstest prüft das Weiterlaufen nach Entfernen eines Blockierers.

Gemessene vollständige Simulationstakte bei 10.000 lebenden Kriegern auf 256×256:

- 10.000 unterschiedliche Ziele in offener Welt, 120 Takte: 2,68 ms im Mittel, p95 2,79 ms, Maximum 3,32 ms. Der erste noch ungeeignete Cache-Ansatz benötigte 585 ms im Mittel; der Endhash bleibt exakt gleich (`615474782`).
- Labyrinth mit 64 Zielen, 240 Takte: 3,72 ms im Mittel, p95 4,27 ms, Maximum 21,63 ms.
- Zwei große Räume mit Ein-Zellen-Engstellen, 240 Takte: 2,78 ms im Mittel, p95 3,13 ms, Maximum 4,47 ms. Keine Belegungsfehler.
- Labyrinth mit kontrollierten Geländeöffnungen alle zehn Takte, 240 Takte: 5,27 ms im Mittel, p95 18,59 ms, Maximum 21,76 ms.
- Kombiniert 10.000 Einzelziele im Labyrinth: zunächst 301 ms im Mittel über 20 Takte. Der exakte Graphpfad erhält denselben Endhash (`3994949034`). Im längeren endgültigen Lauf über 240 Takte: 26,58 ms im Mittel, p95 30,75 ms, Maximum 32,11 ms; 10.000 Krieger bleiben lebend, Bilanzen und Belegung sind konsistent.

Der zusätzliche endgültige Grafiklauf dieses kombinierten Extremfalls erreicht 59,17 FPS und 19,99 Takte/s bei 60-FPS-Grenze. p95 liegt bei 48,01 ms, das Maximum bei 58,65 ms; acht Frames überschreiten 50 ms. Es wird keine Aufholzeit verworfen. Die starken Gerätebaum-Hänger sind auch hier herausgefiltert, einzelne Spitzen der tatsächlichen Weg-/Darstellungsarbeit bleiben aber bestehen.

Die Mittelwerte der einfachen Fälle wurden vor den letzten, zusätzlich verkürzten Adapter-Schleifen gemessen. Der kombinierte Fall ist ein eigener schwererer Lastfall; sein Wert wird nicht durch den kurzen günstigen Anfang ersetzt. Eine Garantie für beliebige zerklüftete Karten, 10.000 Einzelziele und gleichzeitig stark wechselndes Terrain ist daraus nicht ableitbar. Graph und Rasterpfad werden durch Zustandsvergleiche gegen vollständige BFS geprüft; Diagnosezähler bestätigen den tatsächlichen Graph-Einsatz.

## 3. Längere gemischte Partie

Die Headless-Fixtures verwenden eine prozedural gefüllte 256er-Welt mit einer diagnostisch geöffneten Arena, zwei Fraktionen und **50 Arbeitern je Spieler**. Beide Wirtschafts-KIs der Arbeiter stehen auf Intelligenz 4. Krieger bekommen reproduzierbare Marschbefehle; Nachproduktion wird über die echten Kauf- und Energiekonten bezahlt. Jeder Lauf prüft regelmäßig Belegung, Arbeiterlimit sowie Energie- und Einheitenbilanzen. Die Originalspielstände bleiben unangetastet.

**30 simulierte Minuten / 36.000 Takte mit voller Frontattrition:**

- Anfangs 10.000 Krieger, nach vielen Verlusten am Ende 1.117; durchgehend 100 Arbeiter.
- 14.388 Kriegerverluste einschließlich nachproduzierter Einheiten.
- 28.928 Pixel abgebaut; die endliche Testkarte ist danach erschöpft.
- 110.504 Energie erzeugt, davon 110.188 geliefert und 316 unterwegs: Bilanz exakt geschlossen.
- Durchschnittlich 5,51 ms/Takt, p95 16,33 ms, Maximum 72,92 ms; etwa 201 s reale Rechenzeit.
- Keine Invariantenfehler. Dies ist ein Attritions-/Wirtschaftstest und kein Test mit durchgehend 10.000 lebenden Kriegern.

**Zusätzlich 15 simulierte Minuten / 18.000 Takte mit Reservearmeen und aktiver Kampfgruppe:**

- Anfangs 10.000, mindestens 9.825 und am Ende 9.986 lebende Krieger; durchgehend 100 Arbeiter.
- 2.813 Kriegerverluste, reale Nachproduktion, 18.129 Pixel abgebaut.
- 73.154 Energie erzeugt, 67.013 geliefert und 6.141 unterwegs: Bilanz exakt geschlossen.
- Durchschnittlich 6,61 ms/Takt, p95 16,46 ms, Maximum 54,53 ms; etwa 121 s reale Rechenzeit.
- Keine Invariantenfehler. Die Reservearmeen stehen überwiegend außerhalb des direkten Nahkampfs; diese Last wird nicht als gleichzeitig kämpfende 10.000 Krieger ausgegeben.

Der zusätzliche oben genannte 60-s-Grafiklauf verwendet dieselbe gemischte Reservefixture im Echtzeitbetrieb. Die beiden langen Läufe sind beschleunigte Headless-Läufe mit unveränderten Ganzzahltakten, keine 30 bzw. 15 Minuten realer Grafik-Spielzeit. Einzelne Simulations-Takte der Langtests überschreiten 50 ms; die Ergebnisse sind keine Behauptung einer ausnahmslos eingehaltenen Deadline.

## Gefundener Speicherfehler und Kompatibilität

Der neue gemischte Fortsetzungstest zeigte nach dem Laden bei Takt 504 eine abweichende Arbeiterbewegung. Ein inkrementell aufgebautes Wegfeld war im geladenen Zustand noch im Aufbau, im Original bereits veröffentlicht. Hinzu kamen bisher nicht gespeicherte individuelle Wegschritte.

Version 2 erhält deshalb additive Resume-Daten: veröffentlichte und laufende Wegfelder einschließlich Arbeitsfortschritt, Weltrevision/Änderungsprotokoll und Reihenfolge der Abbaufronten, Energierouten mit ihrem bisherigen Neuaufbauzeitpunkt, automatische Arbeitsfront sowie individuelle Arbeiterschritte und Bewegungsreste. Die tatsächliche Chunkgröße wird ebenfalls mitgespeichert. Ungültige Größen, Typen, Zellen, Richtungen und unvollständige Frontzustände werden abgelehnt. Ein fehlender Resume-Block bleibt für Altstände zulässig; ein beschädigter vorhandener Block wird nicht still ignoriert.

Der neue 50-Takte-Fortsetzungstest bleibt nach dem Laden identisch. Zusätzlich wurde ein großer Zustand mit 9.886 Kriegern und 100 Arbeitern durch echte Binärserialisierung ohne geteilte Objektreferenzen übertragen und weitere 20 Takte identisch fortgesetzt. Dabei: 5.429.604 Bytes, rund 42 ms für Erzeugung/Serialisierung und 281 ms fürs Laden. Alte Version-2-Dateien bleiben lesbar; die exakte neue Fortsetzungsgarantie gilt für neu erzeugte Stände mit Resume-Daten.

**Messgrenze:** Die Grafikfixtures laufen als Diagnose und schreiben keine normalen Speicherdateien. Synchrones manuelles Speichern bzw. Autosave kann mit diesem großen Zustand weiterhin einen kurzen zusätzlichen Aussetzer verursachen; Datei-I/O ist nicht Bestandteil der gemeldeten Grafik-FPS. Eine asynchrone Speicherarchitektur wurde hier nicht eingeführt.

## Automatisierte Abschlussprüfung

- Nativer v7-Rechenkern: **233 Tests, 31.603 Prüfungen, 0 Fehler**.
- Vollständiger GDScript-Fallback: **233 Tests, 28.309 Prüfungen, 0 Fehler**. Native-spezifische Vergleiche werden dort ausdrücklich übersprungen, daher weniger Prüfungen.
- Neue Regressionen prüfen exakte Richtungsauswahl trotz unklarem L-Weg, hunderte Ziele mit Geländeänderung, getrennte Welten mit gleicher Revision, Blockadefreigabe, gemischte Speicherfortsetzung, beschädigte Resume-Blöcke und alte Version-2-Stände. Der tatsächliche Sichtgraph-Einsatz wird per Diagnosezähler geprüft.
- Die vorgefundene Änderung in swarm_mind.gd bleibt laut identischen SHA-256-Werten unverändert; der verschachtelte zweite Checkout bleibt unangetastet.

## Reproduzierbar prüfen

Windows 11, Godot 4.3, Ryzen 9 5950X, RTX 2070 SUPER. Native Bibliothek: `native/bin/dot_wars_native.windows.x86_64.v7.dll`. Vorhandene ältere DLLs wurden nicht gelöscht. Das Spiel für den neuen Stand vollständig neu starten. Linux wurde in dieser Windows-Sitzung nicht gebaut oder ausgeführt.

```text
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --headless --path . -s bench/stability_benchmark.gd -- --case=unique --ticks=120 --out=bench/results/unique.json
godot --headless --path . -s bench/stability_benchmark.gd -- --case=maze_unique --ticks=240 --out=bench/results/maze-unique.json
godot --headless --path . -s bench/stability_benchmark.gd -- --case=choke --ticks=240
godot --headless --path . -s bench/stability_benchmark.gd -- --case=changing --ticks=240
godot --headless --path . -s bench/stability_benchmark.gd -- --case=mixed --ticks=36000
godot --headless --path . -s bench/stability_benchmark.gd -- --case=mixed_reserve --ticks=18000
godot --path . -s bench/mixed_live_benchmark.gd -- --seconds=60 --trace-window --out=bench/results/mixed-live.json
godot --path . -s bench/mixed_live_benchmark.gd -- --case=maze_unique --seconds=20 --trace-window --out=bench/results/maze-live.json
```

Rohdaten und die endgültigen Testprotokolle liegen lokal unter `bench/results/stability-2026-10-25/`. Die Meldungen über absichtlich ungültige Startwelten in den Tests gehören zu bestehenden Negativtests. Es gibt keine neuen Commits, keinen Push und keinen Herunterfahrbefehl aus diesem Auftrag.

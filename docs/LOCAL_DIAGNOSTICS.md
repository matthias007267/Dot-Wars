# Lokale Diagnose unter Windows, 24. Oktober 2026

Ausgangspunkt: Commit `aa4eb09`, dazu bereits vorhandene lokale Änderungen an `project.godot` (Kommentare/Reihenfolge) und `scenes/main.tscn` (Szenen-UID). Diese Änderungen wurden erhalten. Keine Commits oder Uploads.

## Umgebung und Zugriff

- Godot 4.3-stable, Windows, AMD Ryzen 9 5950X mit 32 logischen Prozessoren.
- NVIDIA GeForce RTX 2070 SUPER, GL Compatibility, Grafikläufe mit tatsächlichem Viewport 1920 × 1080.
- GitHub und die lokalen Projektdateien sind lesbar; Godot und Spielfenster wurden über Computer Use geprüft.
- Tatsächlicher Projektordner: `C:\Users\matth\Documents\GitHub\Dot-Wars`. Der Chat-Arbeitsordner `Documents\ChatGPT\Dot-Wars` enthält die Diagnoseausgaben und Arbeitshilfen.
- Die bereits laufende Testlaborpartie wurde für die Grafikmessungen pausiert und nicht beendet oder neu gestartet. Editor und andere Desktop-Anwendungen blieben offen. Das ist kein vollständig isolierter Labor-PC.

## Bestätigte Fehler und Korrekturen

1. **Testlabor konnte Autosaves überschreiben.** Nach Deaktivierung blieb `debug_modified` gesetzt, der Autosave prüfte aber nur `debug_mode`. Zusätzlich gab es keine zentrale Dateisperre. `SaveGame.write_file` weist beide Fälle jetzt vor dem Öffnen zurück. Die Autosave-Bedingung beachtet ebenfalls beide Flags. In-Memory-Snapshots für Tests bleiben verfügbar.
2. **Die Tickzeit war unvollständig.** Sie endete vor KI, Kampf und abschließender Siegprüfung. Die letzte Tickzeit umfasst jetzt den gesamten Takt. Die vier bisherigen Stufen bleiben Teilmessungen; `spawn` enthält auch Fusion, Gebäude und Energietransport.
3. **Profiling-Mittelwerte nach Laden waren falsch.** Laufzeitmessungen wurden durch die gespeicherte gesamte Spieltaktzahl geteilt. Ein separater, nicht gespeicherter Zähler misst jetzt nur neue Takte.
4. **Overlay war missverständlich und verdeckt.** Letzter Tick und Stufenmittelwerte sind getrennt beschriftet. Arbeiterobjekte heißen Arbeiter, nicht Gesamtmasse oder Energie-Dots. Das Overlay liegt oben mittig, außerhalb der Zielkarte. Es wurde im Grafiklauf angesehen.
5. **Godots Frame-delta verlor reale Zeit.** Vor der Umstellung summierte es in einem 10,000124-s-Lauf nur 8,800124 s; die eigene Aufholgrenze wurde dabei nie erreicht. Der Spielbetrieb nutzt jetzt monotone Mikrosekunden. Die vorhandene Fünf-Takte-Grenze bleibt gleich und erfasst verworfene Zeit separat. Auch der ältere `--frames`-FPS-Lauf verwendet nun reale Messzeit.

Die beiden ersten Regressionstests scheiterten vor der Korrektur mit vier fehlgeschlagenen Prüfungen. Danach bestand die vollständige Suite: **195 Tests, 24.483 Prüfungen, 0 Fehler**. Die neuen Tests decken insbesondere unveränderte bestehende Speicherdateien, vollständige Tickmessung, Profiling nach Laden, Echtzeituhr, Pause, Neustart und 4×-Tempo ab.

## Headless-Messung

Welt 256 × 256, Seed 1337, Intelligenz 0, Bewegung alle acht Takte. Pro Population 100 Aufwärmtakte und 600 Messtakte. Drei strikt nacheinander ausgeführte Ausgangsläufe; die zuerst versehentlich parallel gestarteten Läufe sind ausgeschlossen. Die ursprüngliche Partie lief während dieser Ausgangsläufe noch mit; im Abschlusslauf war sie pausiert.

- **1.000 Arbeiter:** Ausgangsläufe Ø 1,923–1,962 ms/Takt, p95 5,409–5,458 ms. Kein Takt über 50 ms.
- **10.000 Arbeiter:** Ausgangsläufe Ø 21,809–22,130 ms/Takt, p95 47,279–48,656 ms. Je 25–27 von 600 Takten über 50 ms.
- **Abschlusslauf nach Korrekturen, 1.000 Arbeiter:** Ø 2,000 ms, p95 5,489 ms, Maximum 11,649 ms. Kein Takt über 50 ms.
- **Abschlusslauf nach Korrekturen, 10.000 Arbeiter:** Ø 22,358 ms, p95 49,040 ms, p99 65,769 ms, Maximum 82,074 ms. 27 von 600 Takten über 50 ms.
- Bei 10.000 Arbeitern im Abschlusslauf: Zielsuche Ø 15,986 ms, Bewegung Ø 4,318 ms, Abbau Ø 0,363 ms, übrige Entstehungsstufe Ø 1,488 ms.
- Alle genannten Läufe bestanden die Zustandsprüfungen. Der Hauptanteil liegt hier in der kombinierten Zielsuche, nicht in der Bewegung. Die genaue Aufteilung innerhalb der Zielsuche ist noch nicht profiliert.

Die Höhle wird künstlich vergrößert und zwei Gruppen erhalten je eine Kartenhälfte als Auftrag. Das ist ein reproduzierbarer Lastfall, keine ausgewachsene menschliche Partie. Die gemessenen Kosten sind keine garantierte Echtzeit-Taktrate. Windows-Prozess-CPU und RSS werden vom bestehenden `/proc`-basierten Headless-Skript nicht erfasst; `-1` bedeutet nicht verfügbar.

## Grafikmessung und verbleibende Hänger

VSync wurde nur in den separaten Benchmark-Prozessen deaktiviert, ohne dauerhaftes Projektsetting. Nach fünf Sekunden Aufwärmen wurden je zehn reale Sekunden gemessen. Kein Screenshot während der gewerteten Wiederholungen. Kamera, Eingaben und Aufträge waren fest; Testlabor war aktiv und Speichern gesperrt.

Nach der Echtzeitkorrektur, je drei Wiederholungen:

- **1.000 Arbeiter:** Ø 803,5–1.114,5 FPS und 18,20–19,50 tatsächliche Takte/s. Maximale einzelne Frame-Zeiten 440,0–658,1 ms; die eigene Aufholgrenze verwarf 0,255–0,918 s je Lauf.
- **10.000 Arbeiter:** Ø 271,5–412,1 FPS und 18,70–19,37 tatsächliche Takte/s. Maximale einzelne Frame-Zeiten 523,7–632,7 ms; verworfen wurden 0,317–0,646 s je Lauf.

Die hohen Durchschnitts-FPS verdecken einzelne lange Pausen. Stabile 20 Takte/s sind in diesen Läufen **nicht** erreicht. Die Uhr eliminiert den zusätzlichen Verlust durch Engine-delta; die bewusst begrenzte Aufholfunktion kann weiterhin Zeit verwerfen.

Zusätzliche Frame-Diagnose umschließt den unveränderten `_process`-Aufruf des Spiels:

- Bei 1.000 Arbeitern dauerte ein Frame 443,948 ms, der Spielcode darin nur 7,960 ms. Der längste Spielcode-Aufruf im gesamten Lauf war 10,979 ms. Der Hauptteil dieser Pause liegt außerhalb des gemessenen Spielcode-Callbacks.
- Bei 10.000 Arbeitern gab es auch hohe Spielcodekosten: längster Frame 704,347 ms, darin 278,410 ms Spielcode. Aufholtakte nach einem Hänger können die nächste Frame-Arbeit zusätzlich erhöhen.
- Diese Messung trennt den Spielcode von der übrigen Frame-Zeit. Sie identifiziert **nicht** eindeutig einen Treiber-, GPU-, Windows- oder Engine-Fehler. Für diese Unterscheidung fehlen System-/GPU-Traces.

Das ursprüngliche Spiel hatte im Testlabor 2.198 Masse und Intelligenz 4. Ein ergänzender Lauf mit 2.198 Arbeitern und Intelligenz 4 (`live-swarm4.json`) ergab Ø 215,0 FPS, 18,00 reale Takte/s und Ø 32,952 ms Zielsuche je Takt. Bewegung kostete Ø 0,940 ms. Die Stichproben erreichten regelmäßig die Grenzen von 24 Such- und 48 Pfadaufträgen je Takt. Der längste Frame dauerte 647,339 ms; die Aufholgrenze verwarf insgesamt 1,102 s. Die Zustandsprüfung war fehlerfrei. Andere Stufen und die Weltgeometrie sind Benchmark-Standard; es ist keine Wiedergabe des ursprünglichen Spielstands und kein kontrollierter Vergleich der Intelligenzstufen.

## Reproduzieren

Die Befehle werden im tatsächlichen Projektordner ausgeführt; `godot` steht hier für die installierte Godot-4.3-Programmdatei.

```text
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s bench/benchmark.gd -- --workers=1000,10000 --ticks=600 --warmup=100 --size=256 --seed=1337 --move-period=8 --out=bench/results/headless.json
godot --path . -s bench/live_benchmark.gd -- --workers=1000 --seconds=10 --warmup-seconds=5 --size=256 --seed=1337 --out=bench/results/live-1000.json
godot --path . -s bench/live_benchmark.gd -- --workers=10000 --seconds=10 --warmup-seconds=5 --size=256 --seed=1337 --out=bench/results/live-10000.json
godot --path . -s bench/live_benchmark.gd -- --workers=2198 --swarm=4 --seconds=10 --warmup-seconds=5 --size=256 --seed=1337 --out=bench/results/live-swarm4.json
```

Unter PowerShell mit der GUI-Programmdatei explizit auf Prozessende warten (`Start-Process ... -Wait`), damit Wiederholungen nicht überlappen. Während einer Messung keine Screenshots, UI-Steuerung oder weiteren Benchmarks ausführen.

Rohdaten dieser Sitzung liegen lokal unter `bench/results/local-2026-10-24/` (durch `.gitignore` ausgeschlossen). `benchmark-serial-*` sind die drei gültigen Ausgangsläufe, `benchmark-final` der Abschlusslauf, `live-clock-*` die Zeitquellen-Diagnose, `live-final-*` die drei Grafik-Wiederholungen nach Korrektur und `live-stalls-*` die zusätzliche Frame-Diagnose. `tests-final.log` enthält die vollständige Testsuite. Die alten `live-clean-*`-Dateien im Chat-Arbeitsordner stammen aus der Phase vor der Echtzeitkorrektur; ihre damaligen Frame-Perzentile basierten noch auf Engine-delta und sind nicht als reale Frame-Zeiten zu verwenden.

Nächste gezielte Untersuchungen: Unterstufen der Zielsuche getrennt messen; einzelne lange Pausen mit einem System-/GPU-Trace erfassen. Eine Änderung der Spielregeln oder der Aufholgrenze wurde nicht vorgenommen.

## Nachtrag: tatsächliche langsame Partie mit 595 Arbeitern

Der Nutzer meldete etwa 7 FPS bei Intelligenz 0 und 1 FPS bei Stufe 4. In der laufenden Partie wurden 595 Arbeiter, Stufe 4, Abbau 10 und Energie-Tempo 5 bestätigt. Beim ersten Blick stand das Spiel noch auf 4×. Nach Umschalten auf 1× blieb der Einbruch bestehen, zuletzt mit Taktzeiten im Bereich 130–267 ms. Der Zustand wurde pausiert und über den neuen F7-Diagnoseexport separat gesichert.

Die zuvor publizierten künstlichen Höhlen-Benchmarks bilden diese gewachsene Partie nicht ausreichend ab. Die folgenden Vergleiche verwenden dieselbe reale Diagnosekopie, je 60 Takte, ohne Grafik:

- Intelligenz 0: Ø 24,777 ms vorher, 21,783 ms danach; Endzustand `1681972684` identisch.
- Intelligenz 1: Ø 35,718 ms vorher, 30,190 ms danach; Endzustand `4092356388` identisch.
- Intelligenz 2: Ø 38,441 ms vorher, 32,657 ms danach; Endzustand `2910507436` identisch.
- Intelligenz 3: Ø 60,222 ms vorher, 39,504 ms danach; Endzustand `291369914` identisch.
- Intelligenz 4: Ø 139,261 ms vorher, 39,121 ms danach; Endzustand `392561479` identisch.

Alle Zustandsregeln wurden eingehalten. Die vollständige Testsuite besteht mit **197 Tests, 26.983 Prüfungen, 0 Fehlern**. Neue Tests sichern insbesondere Randbehandlung, gleiche Zellzahl bei anderer Kartenbreite und die Speichergrenze des Nachbarcaches ab.

Die Änderungen verringern die Kosten der BFS-Schleifen. Sie senken keine Suchbudgets und ändern keine Ziel- oder Kollisionsregeln. Eine feste geometrische Nachbartabelle ist auf maximal 4 MiB begrenzt; größere Karten verwenden die direkte Berechnung.

Zwei separate Grafikläufe aus derselben Diagnosekopie, je drei Sekunden Warmup und 15 Sekunden Messzeit, 1×, normales HUD, VSync aktiv:

- Ohne Editor-Debugger: Ø **11,56 FPS**, **17,34 Takte/s**, p95 Frame 332,381 ms, Maximum 675,445 ms; 1,980 s am bestehenden Aufhollimit verworfen.
- Mit Editor-Debugger: Ø **2,92 FPS**, **14,02 Takte/s**, p95 Frame 506,643 ms, Maximum 834,344 ms; 4,447 s verworfen.

Beide Läufe bestanden die Zustandsprüfung. Die ursprüngliche 1-FPS-Anzeige ist eine direkte Beobachtung; die beiden neuen Läufe sind reproduzierte Snapshot-Läufe und kein exakt identischer Vorher-/Nachher-Frame-Verlauf. Die Optimierung ist eine Teilverbesserung, kein bestandener 60-FPS-Nachweis. Der Rückstand führt weiterhin zu mehreren Simulationstakten pro Bild und langen Eingabepausen.

Die ursprüngliche Partie bleibt pausiert erhalten. Das direkte Nachladen von `swarm_mind.gd` im Godot-Editor wurde von der automatischen Freigabeprüfung abgelehnt, weil der Dialog potenziell ungespeicherte Editoränderungen verwerfen könnte. Dieser Klick wurde nicht ausgeführt; die getestete Version wurde separat direkt von den Dateien gestartet. Die Editorfassung muss nach ausdrücklicher Freigabe mit der geprüften Datei abgeglichen werden.

Reproduzierbare Befehle im Projektordner:

```text
godot --headless --path . -s bench/snapshot_probe.gd -- "bench/results/local-2026-10-24/user-595/repro.dw"
godot --path . -s bench/snapshot_benchmark.gd -- "bench/results/local-2026-10-24/user-595/repro.dw" "bench/results/snapshot-after.json"
```

Die Diagnosekopie und Rohdaten liegen nur lokal unter `bench/results/local-2026-10-24/user-595/` und sind von Git ausgeschlossen. Eine native oder inkrementelle Ausführung der weiterhin teuren Suche ist noch nicht umgesetzt. Die häufige Folge mehrerer teurer Aufholtakte bleibt ebenfalls zu untersuchen; ein niedrigerer Simulationstakt wurde nicht als vermeintliche FPS-Lösung eingeführt.

## Nachtrag: nativer Rechenkern und Ziel 10.000 Dots

Die Angaben im vorherigen Abschnitt sind der damalige Zwischenstand. Inzwischen sind die nativen Rasteroperationen aus D-041 umgesetzt. Der Benutzer hat Änderungen und den Wechsel auf die geprüften Dateien ausdrücklich freigegeben. Der alte Debugprozess wird beendet; eine separate interaktive Diagnosekopie kann mit `bench/play_snapshot.gd -- eingabe.dw` geöffnet werden. Sie startet pausiert mit 1× und gesperrten regulären Saves. Änderungen daran überschreiben keinen normalen Spielstand.

Windows-Bibliothek mit Zig 0.17.0, C11/O3 und x86_64-windows-gnu gebaut. Kein systemweiter Compiler/PATH-Eintrag wurde installiert. Bauanleitung und Plattformgrenzen: `native/README.md`.

Validierung:

- Vollständige native Suite: **203 Tests, 28.479 Prüfungen, 0 Fehler**.
- Vollständige GDScript-Referenz: **203 Tests, 27.479 Prüfungen, 0 Fehler**. Native Direkttests werden dort ausdrücklich übersprungen; die Taktvergleiche laufen mit der Referenz.
- Nach Ergänzung der expliziten Backend-Pflicht: alle vier nativen Regressionstests erneut bestanden, 1.488 Prüfungen, 0 Fehler. Fehlende Bibliotheken können den nativen CI-Lauf damit nicht unbemerkt auf den Fallback umstellen.
- Hauptszene startet headless ohne Skriptfehler. Linux-CI ist vorbereitet, hier jedoch nicht ausgeführt. Kein Release-/Steam-Export getestet.
- Reale Diagnosepartie, je 60 Takte: Stufe 0 Ø 17,834 ms, 1 Ø 20,893 ms, 2 Ø 23,370 ms, 3 Ø 25,502 ms, 4 Ø 27,265 ms. Alle fünf Endhashes entsprechen weiterhin exakt den oben dokumentierten Ausgangshashes; keine verletzte Zustandsregel. Das sind einzelne Läufe ohne Grafik, keine garantierte Echtzeit-Rate.

Abschluss-Grafiklauf aus derselben 595-Arbeiter-Kopie: 3 s Warmup + 15 s Messung, normales HUD, VSync aktiv, kein Editor-Debugger. **28,69 FPS, 17,57 tatsächliche Takte/s**, p95 Frame 67,004 ms, maximal 1.079,969 ms. Damit ist der gemeldete Fall deutlich schneller, aber weder stabile 60 FPS noch stabile 20 Takte/s sind erreicht.

Vier-Fraktionen-Test mit **10.000 Dots**, offener 256er-Karte, Bewegungsperiode 1, festen Marschaufträgen und tatsächlichen Angriffen auf alle Kerne, je 100 Takte:

- Intelligenz 0: Ø 18,510 ms, p95 43,009 ms, Maximum 47,512 ms.
- Intelligenz 1: Ø 25,927 ms, p95 51,605 ms, Maximum 54,819 ms.
- Intelligenz 2: Ø 26,244 ms, p95 48,667 ms, Maximum 54,316 ms.
- Intelligenz 3: Ø 25,761 ms, p95 50,938 ms, Maximum 65,682 ms.
- Intelligenz 4: Ø 25,833 ms, p95 50,195 ms, Maximum 54,605 ms.

Die Kern-HP sinken in allen Fällen auf [999968, 999967, 999865, 999969]; alle 10.000 Einheiten bleiben erhalten und alle Zustandsprüfungen bestehen. Die erhöhten Kern-HP sind ausschließlich Benchmark-Aufbau, keine neue Spielregel. Unterschiedliche Intelligenz-Upgrades sind Teil des Hashs; Hash-Unterschiede zwischen Stufen sind daher erwartet. Marschaufträge deaktivieren regelgemäß individuelle Bergbausuche. Die Wirtschafts-KI wird durch feste Befehle ersetzt; dieser Test ist kein Nachweis großer autonomer KI-Armeen.

Ein separater Abschluss-Grafiklauf dieses Marsch-/Kernkampfszenarios (3 s Warmup + 10 s Messung, 1920×1080, VSync nur hier aus) erreicht **200,18 FPS, aber nur 15,00 tatsächliche Takte/s**. Maximaler Frame 1.178,1 ms; 2,384 s am bestehenden Aufhollimit verworfen. Ein vorheriger Lauf ergab 217,2 FPS und 17,93 Takte/s, enthielt jedoch eine parallele Editor-Beobachtung und ist nicht der saubere Abschlusslauf. Hohe durchschnittliche FPS verdecken also weiterhin Hänger und Simulationseinbußen.

Der zusätzliche dichte Abbau-Lastfall mit **10.000 Arbeitern, Intelligenz 4, Bewegungsperiode 1** bleibt langsam: **2,59 FPS und 12,94 Takte/s**. Bewegung kostet Ø 38,100 ms/Takt, die Zielsuche zusätzlich 21,755 ms. Es ist ausdrücklich noch kein generell flüssiges 10.000-Dot-Spiel erreicht. Der nächste gemessene Engpass sind die vielen Kollisions-/Ausweichentscheidungen und die verbleibende GDScript-Arbeit der Suchphase; die feste Simulationsrate oder Suchbudgets wurden nicht reduziert, um die Zahlen zu verschönern.

Rohdaten, Logs und alle fünf Intelligenzläufe liegen lokal unter `bench/results/local-2026-10-24/native-scale/` und sind von Git ausgeschlossen. Keine Commits oder Uploads vorgenommen. Reguläre Spielstände bleiben unverändert.
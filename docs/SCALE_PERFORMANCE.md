# Etwa 10.000 Einheiten: Sicht und Darstellung, 26. Oktober 2026

D-072 erweitert den lokalen Branch `perf/fog-update` ausdrücklich um Skalierungstests und nötige Optimierungen. Der erste kleine reale Lastfall steht historisch in [FOG_PERFORMANCE.md](FOG_PERFORMANCE.md). Kein Commit, Push, Merge oder Release aus diesem Auftrag.

## Ergebnis und Umsetzung

Mit 10.000 Kriegern plus 100 Arbeitern war die GDScript-Sichtunion trotz D-071 zu teuer: 60 Takte des kontrollierten gemischten Falls dauerten durchschnittlich **189,585 ms**, p95 **213,456 ms**, Maximum beim ersten Takt **3.152,678 ms**. Derselbe Fall mit nativer Sichtunion benötigt **12,668 ms**, p95 **14,674 ms**, Maximum **18,024 ms**. Beide Endzustandshashes sind `2474950521`; alle Zustandsprüfungen bestanden.

Die Ergänzung in `native/fog_kernel.inc` berechnet dieselben Bresenham-Strahlen und ihre Vereinigung pro Fraktion gebündelt. Bereits durch eine andere eigene Quelle sichtbare Ziele benötigen keinen zweiten Strahl. Die Hindernisendpunkte bleiben sichtbar, alles dahinter bleibt verdeckt. Es gibt keine reduzierten Reichweiten, verzögerten Sichtaktualisierungen oder Einheitenbudgets. Bündnisse, Terrain-/Gebäudeerinnerung und Veröffentlichung des Wissens bleiben in GDScript. Die vollständige GDScript-Implementierung bleibt über `--fog-reference` verfügbar; `--no-native` deaktiviert weiterhin alle nativen Operationen.

Die native Operation prüft Formen, Fraktionen, Ursprünge, Radien, Dimensionen und Speichergrenzen, bevor sie Ergebnisse veröffentlicht. Fehlende Methode, fehlgeschlagene Allokation oder ungültige Ausgabe führen zur vollständigen Referenz. Weltzellen × Fraktionen sind im nativen Aufruf auf 16.777.216, Quellen auf 1.000.000 und Radien auf 64 begrenzt. Das ist eine Speicher-/Eingabegrenze, keine Freigabe solcher Spielgrößen.

In der Darstellung wurden weitere gemessene Kosten entfernt:

- Die Minimap verwendet einen gemeinsamen MultiMesh statt etwa 5.000 einzelner Kreis-Zeichenaufrufe. Kreismarker behalten Position, Radius, Farbe und die bisherigen Besitz-/Sichtfilter; ein kleiner gemeinsamer Kreis-Mesh ersetzt die einzelnen Kreise. Gebäude und Kamerarechteck bleiben erhalten. Transform und Farbe werden gemeinsam übertragen. Das öffentliche Bufferlayout wurde am [Godot-4.3-GLES3-Quellcode](https://github.com/godotengine/godot/blob/4.3/drivers/gles3/storage/mesh_storage.cpp#L1731) geprüft und mit echtem Grafikbackend zurückgelesen.
- Die Kriegerdarstellung berechnet die identische Atlaszeile einmal pro Aktualisierung. Texturleerung läuft gebündelt; unveränderte Aktivitätsregeln lesen die vorhandenen Bewegungs-/Angriffstakte direkt. Verborgene und gestorbene Einheiten hinterlassen keine Bild- oder Aktivitätsdaten.
- Der Fog-Renderer überspringt unveränderte Wissenszeilen mit Packed-Array-Vergleichen vor den GDScript-Pixelschleifen. Geänderte Zellen und Chunks werden weiterhin im selben Bild aktualisiert.
- Die dauerhaften Benchmarks protokollieren jetzt zusätzlich p99, Anzahl der Frames über 50 ms und tatsächlich verwendete native Fog-Aktualisierungen.

## Grafikmessung

Windows 11, AMD Ryzen 9 5950X, RTX 2070 SUPER, Godot 4.3, native v9. Zwei Fraktionen, 256×256, Seed 58191, 50 Arbeiter je Fraktion, Intelligenz 4, Start mit 10.000 Kriegern. Feste Marschbefehle, echter Nahkampf, Abbau, physischer Energieverkehr und Fog aktiv. Normale Szene mit HUD und Minimap, 1920×1080, 60-FPS-Limit, VSync für den Benchmark aus. Je fünf Sekunden Warmup und 30 Sekunden Messung. Keine parallelen Benchmarks oder UI-Aktionen während der Messfenster; vorhandene interaktive Partien bleiben pausiert. Kein Editor-Debugger an Messprozessen. Die letzte UI-Beobachtung zeigte einen gesperrten Windows-Desktop; diese automatischen Renderläufe sind keine visuelle Bedienabnahme auf einem entsperrten Vordergrundfenster.

Nach alleiniger nativer Sichtunion, vor den Darstellungsoptimierungen: **17,155 FPS**, **19,853 Takte/s**, p95 **78,650 ms**, Maximum **447,271 ms**, 0,204 Sekunden verworfene Simulationszeit. Die Simulation allein genügt somit nicht als Grafiknachweis.

Endgültiger Lauf (`scale-graphic-verified.json`):

- **57,605 FPS**, **19,990 tatsächliche Takte/s**.
- p95 Frame **49,765 ms**, p99 **52,335 ms**, Maximum **64,547 ms**.
- **75 Frames über 50 ms**, keine am Aufhollimit verworfene Zeit.
- 10.000 Krieger am Start, **9.410 am Ende**, **590 Kampfverluste**, 100 Arbeiter am Ende.
- Alle Zustandsprüfungen bestanden, keine Skript-/Parse-/Ladefehler.

Weitere gültige 30-Sekunden-Läufe nach den Darstellungsoptimierungen lagen zwischen **55,85 und 58,01 FPS**, jeweils rund 20 Takte/s und ohne verworfene Zeit. Ein früher Zwischenlauf mit einem Typfehler beim Laden der Minimap wurde ausdrücklich verworfen und zählt nicht als Nachweis. Der separate Zeitwrapper-Lauf erfasste **104 Zeichenaufrufe** statt etwa **5.050**; dessen Framerate ist wegen abweichender Messinstrumentierung kein direkter Ersatz für den normalen Abschlusslauf.

Die einzelnen Frames sind weiterhin ungleichmäßig. Durchschnittlich fast 60 FPS ist ausdrücklich kein Nachweis konstanter 16,7-ms-Frames. In der Grafikphase hängen Befehlszeitpunkte am Live-Takt; exakte Zustandsidentität wird deshalb separat mit identischen taktbasierten Befehlen geprüft.

## Längere und schwierige Simulationsfälle

- **Gemischter Reservefall, 1.800 Takte = 90 simulierte Sekunden:** Start 10.000 Krieger, durchgehend mindestens **9.829**, am Ende **9.841**, 100 Arbeiter. Bewegung in 1.799 Takten, **323 Kampfverluste** und regulär bezahlter Ersatz. Mittel **18,632 ms/Takt**, p95 **23,882 ms**, Maximum **29,520 ms**. 2.221 abgebaute Zellen. Energie: **5.321 erzeugt = 3.616 geliefert + 1.705 unterwegs**, nichts verfallen. Zustandsprüfungen fehlerfrei. Rund 9.000 Krieger sind hier zunächst Reserve; der vorherige Grafikfall beauftragt die gesamte Armee mit Bewegung.
- **Labyrinth mit individuellen Zielen, 120 Takte:** alle **10.000 Krieger** erhalten, Bewegung in jedem Takt, Mittel **37,848 ms**, p95 **43,276 ms**, Maximum **45,770 ms**, keine Zustandsfehler. Die Fraktionen sind hier zur Isolation der Wege verbündet; dieser Fall ersetzt den Kampfnachweis nicht.
- **Enge Verbindung zwischen zwei Kammern, 120 Takte:** alle **10.000 Krieger** erhalten, Bewegung in jedem Takt, Mittel **13,974 ms**, p95 **16,354 ms**, Maximum **22,428 ms**, keine Zustandsfehler. Ebenfalls isolierter Wegefall mit verbündeten Kriegern, die sich weiterhin blockieren.

Diese Zeitangaben stammen aus Headless-Läufen einschließlich des kalten Starts; sie sind keine FPS-Zahlen. Fraktionswissen, Kollisionen und Bilanzen bleiben aktiv.

## Gleichheit und Tests

Der gemischte 10.000er-Fall wurde **120 Takte** einmal mit nativer und einmal mit reiner GDScript-Sichtberechnung ausgeführt. In **jedem Takt** stimmen Spielzustandshash und SHA-256 des vollständigen Fog-Snapshots exakt überein. Beide Läufe enden ohne Zustandsfehler. Die GDScript-Referenz betrifft hier gezielt die Sicht; die unveränderte native Armee bleibt aktiv, um denselben Fall sinnvoll vergleichen zu können.

Neue Tests vergleichen native Vereinigungen mit unabhängigen frischen Strahlen bei überlappenden Quellen, mehreren Fraktionen, Kartenrändern, undurchsichtigen Ursprüngen und zufälligen Hindernissen. Weitere Tests prüfen ungültige Eingaben, vollständiges Fraktionswissen mit Bündniswechseln, Minimap-Besitz-/Sichtfilter, Markerkoordinaten/-farben sowie identische Kriegeraktivitäten und das Entfernen verborgener/gestorbener Pixel. Die Grafikprüfung liest MultiMesh-Koordinaten und Farben mit dem echten Windows-Backend zurück; der Dummy-Headless-Renderer unterstützt diese Rücklesung nicht.

Vollständige native Suite: **346 Tests, 53.038 Prüfungen, 0 Fehler**. Vollständige Referenzsuite: **346 Tests, 31.561 Prüfungen, 0 Fehler**. Separate Grafiktests der gebündelten Darstellung: **2 Tests, 14 Prüfungen, 0 Fehler**. Windows-v9-Build und zusätzliche Linux-x86-64-Querkompilierung erfolgreich. Ein Linux-Lauf wurde hier nicht ausgeführt.

## Wiederholen und verwenden

Das Spiel beziehungsweise den ausführenden Godot-Prozess vollständig neu starten, um die neue **v9-DLL** zu laden; der Descriptor und der GDScript-Ladepfad sind gemeinsam umgestellt. Bereits laufende v8-Instanzen wurden erhalten und verwenden die neue Bibliothek nicht automatisch. Native Bibliotheken sind weiterhin generierte, nicht versionierte Build-Ausgaben.

```text
godot --path . -s bench/mixed_live_benchmark.gd -- --case=mixed --seconds=30 --out=bench/results/scale-live.json
godot --headless --path . -s bench/stability_benchmark.gd -- --case=mixed_reserve --warriors=10000 --ticks=1800 --out=bench/results/scale-long.json
godot --headless --path . -s bench/stability_benchmark.gd -- --case=maze_unique --warriors=10000 --ticks=120 --out=bench/results/scale-maze.json
godot --headless --path . -s bench/stability_benchmark.gd -- --case=choke --warriors=10000 --ticks=120 --out=bench/results/scale-choke.json
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
```

Lokal steht `godot` für die installierte Godot-4.3-Datei. Native Buildanleitung in [native/README.md](../native/README.md). Rohdaten und Taktvergleiche liegen ausschließlich lokal unter `C:/Users/matth/Documents/ChatGPT/Dot-Wars/perf-2026-10-26/`. Originalpartien und reguläre Saves wurden nicht überschrieben.

Die kontrollierten Fälle beweisen keine echte Multiplayerpartie, nahezu endlose Welt, strategische Wirtschafts-KI oder 10.000 Arbeiter. Forschung, große Leitungsnetze und Abfangstationen wurden in diesen großen Fixtures nicht gezielt zugeschaltet; die bestehenden Funktions-/Referenztests bleiben zusätzlich erforderlich. Die vorherige echte kleine Partie enthält Forschungszentren, ersetzt aber keinen kombinierten Großnetzlasttest. Verbleibende lange Frames sowie größere aktive Flächen sind spätere, konkret zu vermessende Lastfälle.

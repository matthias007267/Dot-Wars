# Nativer Rechenkern (Godot 4.3)

Optionaler GDExtension-Rechenkern für deterministische Rasteroperationen:
individuelle BFS, Wegfeld-Ausbreitung, nächstmöglicher Marschstandpunkt und
gebündelte Nachbarschaftsprüfungen, Bewegung normaler Arbeiter und Energie-Dots.
GDScript bleibt die ausführbare Referenz; Budgets und Entscheidungsreihenfolgen
bleiben identisch. Zustandsführung und Taktsteuerung bleiben in GDScript. Es gibt keine Nodes pro Dot.

## Bauen

Windows x86-64, mit vorhandenem Zig-Compiler (lokal mit Zig 0.17.0 geprüft):

```powershell
.\native\build.ps1 -Compiler 'C:\Pfad\zu\zig.exe'
```

Linux x86-64 mit C11-Compiler:

```sh
bash native/build.sh
```

Vor dem Ersetzen einer geladenen Bibliothek Godot-Prozesse schließen. Die
GDExtension ist absichtlich nicht als live neu ladbar gekennzeichnet.
Compiler werden durch diese Skripte weder installiert noch heruntergeladen.
Die erzeugten Bibliotheken unter `native/bin/` werden nicht eingecheckt.

## Prüfen

```text
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --headless --path . -s bench/population_benchmark.gd -- --workers=10000 --swarm=4 --out=bench/results/match-10000.json
godot --path . -s bench/population_benchmark.gd -- --graphic --workers=10000 --swarm=4 --out=bench/results/match-10000-live.json
```

Ohne Bibliothek läuft das Spiel mit der GDScript-Referenz. `--no-native` erzwingt
diesen Fallback; `--require-native` lässt den Backend-Test bei fehlender
Bibliothek fehlschlagen. Vergleichstests prüfen Zustände nach jedem Takt,
Nachbarschaftssignaturen, Kartenränder, Marschziele und Eingabegrößen.

Der Populationsbenchmark verwendet vier durchmischte Fraktionen, eine offene
256er-Karte, gemeinsame Marschziele, Kernangriffe und erhöhte Kern-HP. Die
Fraktionen werden per festen Befehlen gesteuert, nicht durch Wirtschafts-KI.
Ein Marschziel deaktiviert regelgemäß individuelle Abbauzielsuche; dieser Test
belegt daher keine 10.000 individuellen Bergbauentscheidungen. Für den dichten
Abbau-Lastfall zusätzlich `bench/live_benchmark.gd -- --workers=10000 --swarm=4
--move-period=1` verwenden. Alle Benchmark-Simulationen sperren reguläre Saves.

## Export und Grenzen

Die zum Zielsystem passende Bibliothek muss vor Godot-Import und Export gebaut
sein. Das Manifest `dot_wars.gdextension` referenziert Windows und Linux x86-64.
Ein Steam-/Release-Export wurde in dieser lokalen Diagnose nicht erstellt oder
getestet. Andere Plattformen verwenden bislang den GDScript-Fallback.

10.000 Einheiten sind ein gemessenes Skalierungsziel, keine Garantie für
beliebige Karte, volle Intelligenz, Gedränge und 4×-Tempo. Insbesondere
verschmolzene Einheiten verwenden weiterhin die GDScript-Bewegung. Normale
Arbeiter werden als vollständiger Batch in unveränderter ID-Reihenfolge bewegt. Frame-Spitzen und
Zeitverlust an der bestehenden Aufholgrenze werden separat ausgewiesen.

## Herkunft und Lizenz

`gdextension_interface.h` ist unverändert aus Godot 4.3 übernommen:
https://github.com/godotengine/godot/blob/4.3/core/extension/gdextension_interface.h

Der MIT-Lizenz- und Copyright-Hinweis bleibt im Header erhalten. Die
Schnittstelle entspricht der offiziellen Godot-4.3-GDExtension-C-ABI. Es wird
kein godot-cpp und keine zusätzliche Laufzeitbibliothek installiert.

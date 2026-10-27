# Nativer Rechenkern (Godot 4.3)

Aktueller Windows-Stand: **v14**. Der Armee-Cache folgt geöffneten Zellen schrittweise, und `flow_job_begin/step/export/drop` halten einen budgetierten Arbeiter-Wegfeldaufbau zwischen Takten im nativen Speicher (D-086, [LARGE_MAPS.md](../docs/LARGE_MAPS.md)). Seit v13: `fog_merge` übernimmt nach der Sichtunion die Schreibvorgänge in Sicht-, Erkundungs-, Gelände- und Bodenerinnerung je Fraktion (D-085, [MATCH_PERFORMANCE.md](../docs/MATCH_PERFORMANCE.md)); ohne die Methode bleibt die GDScript-Schleife aktiv. Seit v12: `army_step_reachable` ergänzt gemeinsame Terrainfelder um einen nächsten Standpunkt je abgetrennter freier Komponente. `excavation_path` berechnet einmal pro Arbeiterauftrag die lexikografisch günstigste Route nach Blockzahl/Grundarbeit/Schritten mit einer identischen GDScript-Referenz. Sicht, Kampf und die vorhandenen exakten Freiraum-/Eckenpfade bleiben erhalten. Descriptor, Buildskript und Ladepfad gehören zusammen; ein vollständig neuer Godot-Prozess ist erforderlich. Alte Kerne ohne neue Armeemethode verwenden die aktuelle GDScript-Armee. Linux/Godot 4.3 wird geprüft; Windows-Ausführung ist damit nicht belegt. Regeln und Messgrenzen: [REACHABLE_ORDERS.md](../docs/REACHABLE_ORDERS.md).

Die seit v9 gebündelte exakte Sichtunion bleibt erhalten. `fog_visible_depth(blockers, source_records, factions, width)` gibt eine sichtbare Zellliste je Fraktion zurück. Jede Quelle hat sieben Ganzzahlen: Besitzer/Zelle/Radius/eigene Grundfläche x/y/Breite/Höhe; Einheiten verwenden eine leere Grundfläche. Nichtleeres Material startet die vier Rasterfelder tiefe Sichtgrenze, die eigene Quellgrundfläche wird ausgenommen. Positive Grundflächen müssen innerhalb der Karte liegen und die Quelle enthalten. Dieselbe Bresenham-Referenz bleibt über `--fog-reference` verfügbar. Ein alter Kern ohne die neue Methode verwendet hierfür die GDScript-Referenz. Speicherprüfung begrenzt Weltzellen × Fraktionen auf 16.777.216 und Radien auf 64; größere/ungültige Eingaben liefern keine Teilausgabe und der Adapter verwendet die Referenz. Alle aktuellen Spielradien liegen darunter. Frühere Performance-Nachweise: [SCALE_PERFORMANCE.md](../docs/SCALE_PERFORMANCE.md).

Optionaler GDExtension-Rechenkern für deterministische Rasteroperationen:
individuelle BFS, Wegfeld-Ausbreitung, nächstmöglicher Marschstandpunkt und
gebündelte Nachbarschaftsprüfungen, Bewegung normaler Arbeiter und Energie-Dots sowie sequentielle Armee-Arithmetik mit lokaler Zielsuche.
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


## Armee-Kern v4

Windows verwendet jetzt dot_wars_native.windows.x86_64.v4.dll. Bereits geladene v3-Bibliotheken bleiben erhalten; das Spiel für den neuen Kern vollständig neu starten. army_step validiert Eingabeformen, Belegung, stabile IDs, Parameter und Feldgrößen, verarbeitet stabile IDs sequentiell und gibt veränderte Packed-Arrays sowie gesammelte Treffer explizit zurück. Der GDScript-Adapter hält Zustandsführung und Produktion. Bei mehr als 16 verschiedenen Marschzielen oder fehlender Methode bleibt die Referenz aktiv. --army-reference schaltet nur die native Armee ab; --no-native alle nativen Operationen. --profile-army misst die Armee-Referenzunterphasen. Nachweise und reproduzierbare Befehle in [ARMY_PERFORMANCE.md](../docs/ARMY_PERFORMANCE.md). Linux wurde in dieser Windows-Phase nicht gebaut oder ausgeführt.


## Stabilitätsstand v7

Der Stabilitätslauf verwendete dot_wars_native.windows.x86_64.v7.dll. Vollständiger Neustart erforderlich. army_step_cached verarbeitet beliebig viele gültige Ziele über exakte Freiraum-Nachweise, begrenzte Terrain-Felder und bei kleinen Hinderniseckenmengen einen Sichtgraphen. Ohne passenden Graphen bleibt die volle BFS aktiv. Der auf das eigene Windows-Fenster begrenzte Gerätebaum-Filter umgeht die gemessene wiederholte Controller-Neusuche nur bei unveränderter Eingabegeräteliste; Ankunft/Entfernung und Fehler werden weitergereicht. --no-device-change-guard deaktiviert ihn, --trace-window aktiviert explizites Diagnose-Tracing, --validate-device-guard prüft synthetisch Weiterleitung und Wiederherstellung. Kein System-Hook für fremde Fenster, keine Treiberänderung. [STABILITY_VALIDATION.md](../docs/STABILITY_VALIDATION.md) enthält Testbefehle und Grenzen. Ein physischer Controller-Stecktest und ein Linux-Build wurden hier nicht ausgeführt.


## Bauphase v8

In der abgeschlossenen Bauphase baute Windows `dot_wars_native.windows.x86_64.v8.dll`; Descriptor und Fallbackpfad sind gemeinsam umgestellt. Neu ist der Arbeiterzustand 4 (Bau-/Reparaturauftrag): normale Bewegung und frontaler Arbeitertausch überspringen ihn genau wie die GDScript-Referenz. Native Armee-/Fensterstabilitätsfunktionen aus v7 bleiben erhalten. Ein vollständig neu gestarteter Godot-Prozess ist zum Laden der neuen DLL erforderlich. Bauvalidierung: [CONSTRUCTION_PHASE.md](../docs/CONSTRUCTION_PHASE.md).

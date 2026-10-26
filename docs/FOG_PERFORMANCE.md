# Fog-/Karten-Performance, 26. Oktober 2026

Dieser Bericht beschreibt den ersten, kleinen realen Lastfall nach D-071. Der ausdrücklich folgende 10.000er-Auftrag D-072 ergänzt native Sicht und weitere Darstellungsoptimierungen; aktueller Stand und Neustartanforderung v9 in [SCALE_PERFORMANCE.md](SCALE_PERFORMANCE.md). Die frühere Aussage „kein neuer nativer Build erforderlich“ gilt ausschließlich für den ersten D-071-Stand.

Auftrag D-071: CPU-Engpässe der echten langsamen Partie beheben, ohne Sichtregeln oder Simulationstakt zu verändern. Lokaler Branch `perf/fog-update`, Basis `ea1e521`. Kein automatischer Commit/Push/Merge.

## Änderung

- `fog_of_war.gd`: keine vollständige Rasterabfrage über `construction.at()` mehr. Rohmaterialien liefern bereits die Terrainblocker, aktive Gebäudeflächen werden ergänzt. Sichtquellen liefern kompakte sichtbare Zelllisten. Fraktionen und Verbündete vereinigen nur diese Zellen statt kompletter Maskenschleifen. Cacheeinträge enthalten exakte lokale Hindernisbytes und eine Zellliste; entfernte Abbauänderungen verwerfen keine unveränderten Sichtquellen. Bewegte/entfernte Quellen werden weiterhin aus dem Cache entfernt. Der Cache belegt keine volle Weltmaske pro Einheit mehr.
- `fog_overlay.gd`: nur veränderte Wissenszellen werden in Farben umgesetzt. Nur betroffene Fog-Chunks werden aufgebaut und übertragen; Zeilenkopien verwenden PackedByteArray-Slices statt vier GDScript-Schreibzugriffen je Pixel. Die Minimap aktualisiert weiterhin dieselben Sicht-/Wissensänderungen. Keine veralteten Sichtintervalle und kein Zugriff auf unbekanntes Terrain.
- `world_renderer.gd`: Marker vergleichen ihre tatsächlich gerenderten Werte. Sicht- oder HP-Änderungen malen nicht mehr die gesamte Terraintextur neu. Bei Markeränderungen werden nur alte/neue Markerzellen umgefärbt. Normale Terrainänderungen bleiben beim bestehenden Dirty-Chunk-Pfad.
- Diagnosewerkzeuge: Snapshot-Grafikbenchmark akzeptiert optional `--fps-cap=60`. Der gemeinsame Sampler unterstützt den Bau-/Reparaturzustand 4, sodass aktuelle Snapshots nicht an der alten Vier-Zustands-Auswertung scheitern.

Sichtreichweiten, Bresenham-Strahlen, sichtbare Hindernisendpunkte, sofortiges Verbergen gegnerischer Einheiten, zuletzt bekannte Gebäude und Terrainwissen bleiben erhalten. Forschung/Netz/Kampf/Bilanz/Saveformat/20-Hz-Takt sind unverändert. Neue Cachefelder sind ausschließlich Laufzeitdaten und werden nach Laden neu aufgebaut.

## Messaufbau

Echte F7-Diagnosekopie vom 26. Oktober, 256×256, Seed 1337, Starttakt 11684, 30 Arbeiter und etwa 135 Krieger. Godot 4.3, Windows 11, RTX 2070 SUPER, native v8 aktiv. Originalpartie während der Messung pausiert, keine parallelen Benchmarks oder UI-Eingriffe. Separate Diagnoseprojekte verwenden dieselben Quellen; nur identische Zeitmess-Wrapper wurden ergänzt. Kein Editor-Debugger an den Messprozessen. 1920×1080, 60-FPS-Limit, 3 s Warmup, mindestens 12 s Messung, normale Spielszene/HUD. Kamerazustand startet nach den normalen Attach-Vorgaben und ist nicht Teil des gespeicherten Originalzustands.

Der direkt beobachtete Editorlauf lag bei etwa 2 FPS. Die reproduzierte alte Version erreichte ohne Editor-Debugger 5,922 FPS und 17,272 echte Takte/s. p95 Frame 342,516 ms, Maximum 388,061 ms. Pro Bild kosteten Simulation 65,112 ms, Fog-/Minimap-Aufbereitung 54,073 ms, Welt-Abgleich 36,021 ms, HUD 4,020 ms. Bildkosten enthalten gegebenenfalls mehrere Aufholtakte.

Erster vollständiger Vergleich mit Update: **59,879 FPS und 19,987 Takte/s**, p95 Frame 27,943 ms, Maximum 46,570 ms, keine am Aufhollimit verworfene Zeit. Pro Bild: Simulation 1,142 ms, Fog-/Minimap 1,457 ms, Welt-Abgleich 0,018 ms, HUD 1,804 ms. Haupt-Callback insgesamt 4,634 ms statt 159,699 ms. Damit ist der konkrete Einbruch behoben; p95 oberhalb von 16,7 ms zeigt noch ungleichmäßige Bilder trotz durchschnittlich 60 FPS.

Abschlussmessung mit den endgültigen Dateien **direkt aus dem Hauptprojekt**, vorhandener `snapshot_benchmark.gd`, 3 s Warmup + 15 s Messung: **60,026 FPS, 19,986 Takte/s**, p95 Frame **42,291 ms**, Maximum **46,007 ms**, keine Aufholgrenzen-Treffer, keine verworfene Zeit, keine Zustandsfehler. Dieser Sampler erfasst nach dem Haupt-Callback; der erste Diagnose-Sampler erfasste am Frame-Signal. Daher werden die Frame-Perzentile der beiden Messmethoden getrennt genannt. Die Maximaldauer des Haupt-Callbacks und die Aufholtakte stehen in `final-project.json`; verbleibende ungleichmäßige Frames werden nicht als konstante 16,7-ms-Ausgabe ausgegeben.

Headless-Nachmessung derselben 120 Takte mit Zeitwrappern: **3,338 ms/Takt** statt 24,929 ms, p95 **5,420 ms** statt 69,969 ms, Maximum **40,565 ms** statt 79,361 ms. Fog darin **1,628 ms/Takt** statt 22,873 ms. Startzustand und Endpopulation entsprechen dem Ausgangslauf. Kalter Cache nach Laden ist enthalten. Alle Zustandsprüfungen bestanden.

## Zustandsnachweis

240 unveränderte Simulationstakte ab derselben Diagnosekopie wurden mit alter und neuer Version verglichen. Für **jeden Takt** stimmen der Spielzustandshash und SHA-256 des vollständigen Fog-Snapshots exakt überein. Der Fog-Nachweis umfasst alle Fraktionen, Sicht, Erkundung, bekanntes Terrain, Gebäudegedächtnis und Bündnisse. Beide Läufe enden ohne Zustandsfehler.

Neue Regressionstests prüfen gecachte Sicht gegen frische Strahlen mit Arbeitern/Kriegern, zufälligen Materialänderungen, wechselnden Bündnissen, Grenzzellen und unmittelbar geöffneten/geschlossenen Sichtwegen. Darstellungstests prüfen Fog-Chunk-Grenzen, sofortige Transparenz-/Deckungsänderung, eingefrorenes unbekanntes Terrain, Stilwechsel und inkrementelle Marker gegen vollständiges Neuzeichnen. Prüfstand: vollständige native Suite 337 Tests / 34.758 Prüfungen, vollständige Referenzsuite 340 Tests / 31.539 Prüfungen, jeweils 0 Fehler. Die unterschiedlichen Testzahlen entstehen durch die während des Durchlaufs ergänzten neuen Tests. Der endgültige Fog-Stand einschließlich zusätzlichem Sichtweg-/Stiltest wurde danach separat in beiden Backends mit 14 Tests / 111 Prüfungen geprüft, ebenfalls 0 Fehler. Betroffene Höhlen-/Lichttests (4 / 21) und Weltansicht (8 / 59) bestehen ebenfalls. Keine Skript-/Parse-/Ladefehler in den vollständigen Testlogs; erwartete negative Konfigurationsfälle erzeugen weiterhin ihre bekannten Engine-Fehlermeldungen.

## Wiederholen und Grenzen

Im Projektordner, `godot` durch die installierte Godot-4.3-Datei ersetzen:

```text
godot --path . -s bench/snapshot_benchmark.gd -- PFAD_ZUR_DIAGNOSE.dw bench/results/fog-after.json --fps-cap=60
godot --headless --path . -s tests/run_tests.gd -- fog
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
```

Die private Diagnosepartie und Rohdaten bleiben lokal unter `C:/Users/matth/Documents/ChatGPT/Dot-Wars/perf-2026-10-26/`; sie werden nicht eingecheckt. Die alte Vergleichsversion dort bleibt erhalten. Originalpartie und reguläre Spielstände werden nicht überschrieben. Kein neuer nativer Build erforderlich.

Die konkrete Partie ist kein Nachweis für 10.000 bewegte Krieger, sehr große Karten oder echte Netzwerkpartien. Neue Ursprünge benötigen weiterhin exakte Sichtstrahlen; bei großen bewegten Armeen bleibt deren Skalierung gesondert zu vermessen. Der noch vollständige Vergleich der Wissensarrays in der Darstellung skaliert mit Kartenfläche, die Minimap überträgt ihre gesamte kleine Textur. Keine grenzenlose Welt-/Armee-Garantie aus diesem Lauf ableiten.

## Testinstanz

Die zuletzt gesicherte Originalpartie (30 Arbeiter, etwa 160 Krieger) wurde mit der aktuellen Version separat über bench/play_snapshot.gd geöffnet und startet pausiert im Diagnosemenü. Reguläre Saves bleiben dort gesperrt. Die ursprüngliche Editorpartie bleibt pausiert erhalten. Die neue Instanz meldet keine Lade-/Skriptfehler. Bei der abschließenden Sichtprüfung war Windows inzwischen gesperrt; es wurden keine weiteren UI-Eingaben versucht. Eine visuelle Endkontrolle dieser interaktiven Instanz muss nach Entsperren erfolgen; der vorherige vollständige Grafikbenchmark ist erfolgreich abgeschlossen.

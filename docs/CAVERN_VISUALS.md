# Cavern-Optik – erste Grafikphase

**Fortsetzung:** Nach der ersten Übertragung hat der Nutzer ausdrücklich den austauschbaren Grafikkatalog und die ersten drei Sprite-Beispiele beauftragt. Die ursprünglichen Codezeichnungen für Gebäude/Icons und die einfachen Einheitenmerkmale sind inzwischen durch gemeinsame Atlasgrafiken ergänzt bzw. ersetzt; Nach Merge von #10 in den alten Feature-Branch übernimmt ein neuer PR auf `main` die Basis und den ausdrücklich bestätigten Quadratentwurf; aktueller Stand in [SPRITE_CATALOG.md](SPRITE_CATALOG.md). Die folgende Beschreibung dokumentiert die erste Übertragung.

Der Nutzer beauftragt auf Basis seiner Bildreferenz eine erste Übertragung der neuen Optik auf das aktuelle Spiel: dunkle Höhlen-/Steintexturen, warme und fraktionsbezogene Lichtakzente, eine gemeinsame untere Menü-/Bau-/Infoleiste mit Minimap sowie unterscheidbare Einheitenoberflächen.

Diese Phase baut auf `16231bc` / PR #9 auf. Sie liegt auf dem separaten Branch `feat/cavern-visual-foundation`; der neue Review-PR hat zunächst `feat/p6-playable-research` als Basis. PR #9 und die Grafikphase werden nicht automatisch gemergt. Das Referenzbild ist eine Stilrichtung, keine neue Freigabe für die darin abgebildeten Spielsysteme.

## Übernommene Gestaltung

- **Terrain:** Der bestehende Ein-Pixel-pro-Zelle-Datenbestand bleibt erhalten. Der GPU-Shader zeichnet darauf zwölfteilige Zelloberflächen mit Steinbevels, Fugen, Rissen, Materialtönung und seltenen grünen/orangen/blauen Mineralfacetten. Das sind die vorhandenen Härtestufen, keine neuen Ressourcenvorkommen oder Mehrerträge. Tunnel erhalten einen warmen, körnigen Boden und dunkle Wandkanten.
- **Beleuchtung:** Eine niedrig aufgelöste RGB-Lichtkarte mischt weiche goldene/rote bzw. Fraktionslichtfelder in Boden und Wände. Sie verwendet höchstens 64 Quellen und maximal 512×512 Texel, wird mit 5 Hz aktualisiert und bei unveränderten Quellen wiederverwendet. Keine Node/PointLight pro Dot. Quellen sind eigene oder aktuell sichtbare Gebäude und tatsächliche Sendungen. Forschungszentren erzeugen das Aktivitätslicht ausschließlich bei echtem Energieverbrauch.
- **Gebäude:** Originale prozedurale Pixelzeichnungen ersetzen farbige Füllrechtecke: Reaktorkern, kompakter Außenposten, Abfang-Antennen und Forschungsprisma. Fraktionsgehäuse, Metallstreben, Baustellengerüst sowie vorhandene HP-/Bauanzeigen und Auswahl bleiben erkennbar. Positionen und Kollisionsflächen bleiben unverändert.
- **Leitungen:** Dünne verbundene Leiterbahnen mit Knoten und kleinen physisch positionierten Energieimpulsen ersetzen vollflächige Overlay-Zellen. Freie Bergbauenergie und Sendungen bleiben getrennte reale Zustände.
- **Einheiten:** Worker-/Army-/Energy-Texturen bleiben gebündelt. Ein gemeinsamer Shader zeichnet Helm-/Visormerkmale für Arbeiter, Schild-/Kreuzmerkmale für Krieger und kompakte helle Energiedots. Eigene Kämpfer sind goldfarben, die erste Gegnerfraktion rot; weitere Fraktionsfarben bleiben erhalten. Eigene Arbeiter erhalten zusätzliche Markierungen bei tatsächlich vorhandenen eigenen Abbau-/Bewegungsupgrades. Es werden keine neuen Krieger-T1/T2/T3-Regeln oder unbekannte Gegnerforschung erfunden.
- **HUD:** Minimap links unten; daneben Auswahlporträts, Menü/Pause/Tempo, ein bebildertes Bau-/Befehlsraster sowie Versorgung/Standort und Missionsinformationen. Forschungszentrum, Abfangstation, Leitungen, Abriss und Forschungsbaum sind direkt erreichbar. Die bisherigen Kauf-, Forschungs-, Bau-, Speicher-, Pause- und Kamerafunktionen bleiben erhalten. Der HUD-Wurzelcontainer skaliert mit der tatsächlichen Viewportgröße; der Grafiktest prüft zusätzlich die Begrenzung bei 1280×720. Interne automatische Arbeitsregionen werden nicht mehr ständig umrandet; ausdrücklich beauftragte Gebiete und Auswahl bleiben sichtbar.

Die Icon-SVGs und Gebäudefiguren sind eigene, aus Code erzeugte Formen. Das Referenzbild wird nicht als Spielfeldhintergrund verwendet; es wurden keine fremden Bitmaps oder neuen Asset-/Runtime-Abhängigkeiten eingebaut.

## Wissensgrenzen und Simulation

- Lichtquellen lesen keine unbekannten Gegnergebäude. Bei mehrzelligen Gebäuden entscheidet aktuell sichtbarer Teil des tatsächlichen Grundrisses; der verborgene Kernmittelpunkt ist kein zulässiger Ersatz für die Sichtprüfung.
- Fog-Erinnerung verwendet denselben Terrainstil auf dem **gespeicherten** Materialzustand, gedimmt und ohne aktuelle Lichtkarte. Chunk-Ursprünge halten die Texturdetails an Weltkoordinaten gebunden. Die Minimap verwendet weiter Spielerwissen, nicht die ungefilterte Welttextur.
- Bekannte gegnerische Gebäude werden im Nebel gedimmt gezeichnet; ihr alter Snapshot bleibt maßgeblich. Keine Aktivitätsbeleuchtung aus verstecktem Live-Zustand.
- Die Materialpalette der Simulation, Härten, Forschung, Energiebilanzen, Belegung, Einheitentypen und Speicherregeln ändern sich nicht. Die Renderer behalten den GDScript-/Native-Vergleich und die bisherigen Datenformate.

## Dateien und APIs

- `src/render/shaders/terrain.gdshader`: GPU-Zelltexturen, Kanten, Lichtabtastung, Gedächtnisdimmung.
- `src/render/shaders/dot_glow.gdshader`: Artenmerkmale, eigene Upgrade-Markierungen, kompakte Silhouetten.
- `src/render/cavern_lighting.gd`: sichtgefilterte, begrenzte und zwischengespeicherte Lichtkarte.
- `src/render/tactical_art.gd`: wiederverwendbare Gebäudefiguren und gecachte Befehlsicons.
- `WorldRenderer`, `FogOverlay`, `OrderOverlay`, Worker-/Army-/Energy-Renderer: Anbindung der neuen Darstellung.
- `GameHud` / `UiTheme`: gemeinsame untere Leiste und Icons. Die eigenständig aufrufbaren HUD-Aufbaumethoden bleiben für bestehende Regressionen erhalten.

## Prüfungen

Die neuen Tests in `tests/test_cavern_visuals.gd` prüfen Sichtschutz der Lichtquellen, Ressourcenbegrenzung, Wiederverwendung, Simulationsidentität, getrennte Art-Icons, unteren HUD-Anker, weiter erreichbare Kaufaktionen und Aktivitätslicht nur bei tatsächlichem Verbrauch. Der alte HUD-Textvergleich wird auf die weiterhin reale Kaufaktion im neuen Raster migriert.

`bench/cavern_visual_check.gd` erzeugt eine **explizite Diagnose-Testszene** mit angelegten Korridoren und regulären Gebäudedaten. Diese Änderungen liegen nur im Benchmark und werden nicht in die Weltgenerierung übernommen. Diagnose-Speicherung bleibt gesperrt. Der Test prüft HUD-Platzierung, Auswahlbindung, Minimap/Kamera und unveränderten Simulationshash beim Zeichnen und erstellt Übersicht, Forschungsansicht, Detailaufnahme und eine kompakte 1280×720-Ansicht:

```sh
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1600x1000x24' \
  godot --audio-driver Dummy --path . -s bench/cavern_visual_check.gd
```

Zusätzlich wird `bench/p6_live_check.gd` mit der neuen Optik ausgeführt: Bau/Reparatur, E-Zug/Loslassen, Forschungsstart/-abschluss, reale Energie, Q-Abriss, Speicherung und Arbeiterabriss. Beide Grafikläufe wurden lokal unter Godot 4.3 / Xvfb / Mesa-Software-Rendering ausgeführt und ihre Screenshots visuell angesehen. CI erfasst Skript- **und Shader-Compilerfehler**, führt beide Grafiktests zusätzlich zu den vollständigen nativen und Referenzsuiten aus und lädt die Bilder als `cavern-visual-check` bzw. `p6-visual-check` hoch. Der endgültige Actions-Link und geprüfte Commit werden im PR-Abschlussprotokoll festgehalten.

## Grenzen dieser ersten Übertragung

Die Formen und Oberflächen sind eine erste spielbare Art-Grundlage. Handgezeichnete Sprites/Atlanten, komplexere Materialtexturen, echte Kriegerstufen und weitere Gebäudetypen sind nicht dadurch fertig. Die Lichtkarte ist eine weiche Farbbeleuchtung ohne physikalische Schatten oder Wand-Occlusion; Fog bleibt eine separate Informationsgrenze. Für die neue Darstellung gibt es noch keine Windows-Hardware-/10k-Armee-/große-Netz-Leistungsabnahme. CPU-/GPU-Leistung und Lesbarkeit bei sehr großer Entfernung benötigen eine eigene Messung. Es werden keine neuen Spielregeln, Gebäude, Weltgenerierungsregeln oder Releasezusagen aus der Referenz abgeleitet.

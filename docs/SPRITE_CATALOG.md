# Grafikkatalog und erste Sprite-Beispiele

Diese Fortsetzung von PR #10 setzt die bestätigte Empfehlung um: zuerst einen austauschbaren Grafikkatalog und daran Arbeiter, Krieger und Forschungszentrum ausarbeiten. Der bestehende Branch `feat/cavern-visual-foundation` bleibt auf PR #9 aufgebaut; kein automatischer Merge. Terrain, Spielregeln, Forschungswerte und gespeicherte Simulationsdaten bleiben erhalten.

## Tatsächlich integrierte Grafik

- **Arbeiter:** Helm mit Lichtreflex, neutraler Metallrand, cyanfarbenes Visier, Rucksack und Beine. Bereit, Bewegung, Abbau mit Werkzeug, Bau/Reparatur mit Werkzeugkasten sowie blockierter Weg haben eigene Zeilen. Zwei vorhandene eigene Forschungsmarkierungen bleiben sichtbar. Es werden keine unbekannten Gegnerverbesserungen oder neuen Einheitenstufen dargestellt.
- **Krieger:** Gepanzerter Helm, breitere Schultern, Schild mit Kreuz und Nahkampfwaffe. Bewegung folgt dem tatsächlichen Bewegungstimer; ein Angriff erscheint nur kurz nach einem vorhandenen Angriffstakt. Die Fraktionsfarbe kommt aus dem Besitzer, unabhängig von der alten Army-Farbpalette.
- **Forschungszentrum:** Fertig/bereit, laufende Forschung mit Scanlinie, fehlende Versorgung mit statischer Warnung, kurz sichtbarer beobachteter Abschluss und Baustellengerüst. Gehäuse sind fraktionsfarben, Prisma und Metall bleiben davon unabhängig.
- **Gemeinsame Grafiken:** Weltgebäude, Einheitenporträts und Bau-/Befehlsicons lesen denselben Katalog. Die anderen bestehenden Gebäude und Icons liegen ebenfalls im Atlas; die ersten detailliert angebundenen Zustandssätze sind die drei Beispiele oben.

Die 16×16-Pixel-Bilder sind eine erste eigene Pixelart-Fassung. Bei weniger als zehn Bildschirmpixeln pro Weltzelle verwendet der Einheiten-Shader kompakte Fraktionssymbole: quadratische Arbeiter, rautenförmige Krieger. Die Detailgrafik bleibt unabhängig vom Leuchten aktiv. Die vorherige Dot-Darstellung kann über `sprites_enabled` am Renderer bei dessen Aufbau verwendet werden; `glow_enabled` steuert separat den Halo. Das sind Renderer-Eigenschaften, noch kein neues Qualitätseinstellungsmenü.

## Dateien austauschen

`assets/pixel/tactical_atlas.tres` ist die tatsächlich geladene Godot-Resource. Sie enthält:

| Feld | Bedeutung |
| --- | --- |
| `body` | PNG mit neutralem Metall, Visieren, Prismen und transparentem Hintergrund |
| `team_mask` | Deckungsgleiche PNG mit weiß/grauen Fraktionsflächen und transparentem Rest |
| `cell_size` | Kantenlänge eines Bildes, aktuell 16 Pixel |
| `frames` | Spalten/Animationsbilder, aktuell vier |
| `frame_ticks` | Simulationstakte je Bild, aktuell vier bei 20 Takten/s |
| `rows` | Benannte Zustände und ihre Atlaszeilen |

Beide PNGs sind aktuell 64×336 Pixel groß. Ein statischer Zustand wiederholt sein Bild in allen vier Spalten. Fraktionsmasken übernehmen beim Zeichnen die jeweilige Teamfarbe; Grautöne erhalten Schattierungen. Metall-/Visierdetails müssen in der Maske transparent bleiben. Unbenutzte Pixel sind transparent. Beide Texturen werden verlustfrei, ohne Mipmaps und mit nächster Pixelabtastung verwendet.

Zum Überarbeiten bestehender Figuren genügen Änderungen an den beiden PNGs im gleichen Raster. Zeilen können in der Resource umgeordnet werden; die Renderer benutzen Namen wie `worker.mine` oder `research.waiting`. Rastergröße, Spalten und Taktabstand werden ebenfalls aus der Resource gelesen. Weltgrafik und daraus erzeugte 32×32-HUD-Porträts werden beim nächsten Spielstart gemeinsam aktualisiert. Terrain bleibt derzeit im vorhandenen Materialshader.

Die PNGs wurden mit dem eingecheckten Originalzeichenwerkzeug `tools/draw_tactical_atlas.py` erstellt. Es kann die Ausgangsgrafiken mit Python/Pillow erneut erzeugen, wird aber beim Spielstart, Export oder in CI nicht benötigt. Direkt bearbeitete PNGs werden vom Werkzeug beim erneuten Ausführen überschrieben. Es wurden keine Bildteile aus der Nutzerreferenz übernommen und keine fremden Assetpakete eingebaut.

## Zustände, Zeit und Wissen

`SpriteCatalog` bindet die Atlas-Resource an Shader, Weltzeichnungen und gecachte Porträts. `TacticalArt` behält seine bisherigen Aufrufstellen als kleine Fassade bei. Worker- und Army-Renderer verwenden zusätzlich zur bisherigen Farbtextur je eine gebündelte RGBA-Zustandstextur: Atlaszeile, Blickrichtung, Besitzer und eigene Forschungsmarkierung. Verlassene, tote und nicht sichtbare Einheiten werden aus Farb- und Zusatzdaten entfernt. Keine Node oder Szene pro Einheit.

Animationsbilder hängen ausschließlich vom übergebenen Simulationstakt ab. Pause stoppt sie, Spieltempo beschleunigt sie. Zeichenoperationen schreiben keine Simulations-, Zufalls- oder Speicherdaten. Die neuen Welt-Zustandstexturen benötigen vier zusätzliche CPU- und GPU-Bytes pro Weltzelle und Renderer; Laufzeit und Speicherbedarf bei großen Welten sind separat zu messen.

`ResearchVisualState` ist flüchtiger Darstellungszustand. Er liest nur eigene bzw. aktuell sichtbare Zentren. Echte Energielieferung schaltet den Betrieb ein; fehlende benötigte Lieferung zeigt Warten. Ist die gesamte Energie bereits bezahlt, läuft die vorhandene Restdauer weiterhin sichtbar weiter. Das Umgebungslicht bleibt wie bisher an tatsächlichen Verbrauch gebunden. Ein Abschlusszeichen erscheint nur, wenn ein zuvor beobachteter Auftrag tatsächlich eine Forschungsstufe erhöht hat; es endet nach 40 Simulationstakten. Ein neu gestarteter Auftrag hat Vorrang. Nach Laden/Wechsel der Simulation wird der Beobachtungszustand verworfen. Verborgene Zentren zeigen nur das gedimmte statische Erinnerungsbild; verborgene Abschlüsse werden nicht nachträglich gemeldet.

## Prüfungen und Reviewbilder

`tests/test_sprite_catalog.gd` prüft Atlasgrenzen, Ebenen und gemeinsame Icons; tatsächliche Arbeits-/Angriffszustände; Besitzer unabhängig von Farbgruppen; eigene Markierungen; Entfernen/Verbergen von Einheiten; echte Versorgung, bereits bezahlte Restdauer, Abschlussdauer sowie verborgene Forschung. Die bisherigen Army-Paletten- und Gameplayregressionen bleiben erhalten.

`bench/sprite_visual_check.gd` läuft zusätzlich im echten Godot-4.3-OpenGL-Renderer. Er erstellt eine beschriftete Atlasübersicht und prüft den gebündelten Einheiten-Shader ohne Leuchten, Fraktionsfarben anhand gerenderter Pixel, Bildidentität bei Pause, Bildänderung durch Simulationstakte, Entfernung toter Einheiten sowie das echte Forschungsgebäude bei Lieferung und Unterbrechung. Das ist eine ausdrücklich veränderte Diagnosewelt, keine neue Spielregel. Ausgabe: `SPRITE SUMMARY: 0 failures`.

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd -- sprite_catalog
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1600x1000x24' \
  godot --audio-driver Dummy --path . -s bench/sprite_visual_check.gd
```

CI führt zusätzlich weiterhin die vollständigen nativen und GDScript-Referenztests, Hauptszenenstart, P6-Bedienung und Cavern-HUD-Prüfung aus. Der neue Schritt erkennt auch Script-/Shaderfehler und lädt Protokoll und Screenshots als `sprite-visual-check` hoch. Der tatsächlich geprüfte Commit und Actions-Lauf werden im PR dokumentiert.

Die Beispielsprites sind integriert und austauschbar. Vollständig ausgearbeitete weitere Gebäudegrafiken, physikalische Schatten, große Partikeleffekte, ein Qualitätseinstellungsmenü, eine vollständige zweite HUD-Überarbeitung sowie Windows-/10k-Armee-Leistungsabnahme sind damit nicht abgeschlossen.

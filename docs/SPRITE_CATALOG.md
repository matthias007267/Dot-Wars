# Grafikkatalog und bestätigte Quadrat-Einheiten

Der Nutzer übernimmt ausdrücklich den generierten Entwurf einfacher quadratischer Arbeiter und Krieger. Diese Korrektur ersetzt die vorherigen Figuren mit Helm/Gliedmaßen. Neuer Branch `feat/square-unit-art` auf `main` (`d9fbadb`), kein automatischer Merge. Die Optik aus PR #10 wird mitgenommen: PR #9 wurde zuerst nach `main` gesquasht, PR #10 danach nur in dessen alten Feature-Branch gemergt. Details in D-070.

## Tatsächlich integrierte Grafik

- **Arbeiter:** Ein Teamquadrat mit dunklerem quadratischem Einsatz und kleinem hellem Kern. Keine Arme, Beine, Werkzeuge oder sichtbare Drehung. Beim tatsächlichen Abbau/Bauen pulsiert ausschließlich der Kern in Simulationstakten. Vorhandene eigene Forschungsmarkierungen erscheinen als symmetrischer Kernrand.
- **Krieger 1:** Derselbe quadratische Fußabdruck und durchgehende Teamrand, dunkler Panzerrahmen, vier Metallpunkte und farbiger Kern.
- **Krieger 2:** Dieselbe Grafikfamilie mit verstärkten L-Ecken.
- **Krieger 3:** Dieselben verstärkten Ecken plus zusätzlichem Innenrahmen.
- **Forschungszentrum:** Die vorhandenen Zustände bereit, Forschung, Versorgungswartezeit, beobachteter Abschluss und Baustelle bleiben erhalten. Andere Gebäude/Icons behalten ihre Bilder.

Die drei Kriegergrafiken sind vollständig im Katalog vorhanden. **Die Simulation besitzt weiterhin nur den bestehenden Basiskrieger; reguläre Partien verwenden Grafik 1.** `ArmyRenderer.visual_level` ermöglicht ausschließlich eine ausdrückliche Grafikvorschau der drei Varianten und wird im Grafikcheck benutzt. Es wurden keine Kampfwerte, Forschungsstufen, Speicherfelder, unbekannten Gegnerstufen oder Schere-Stein-Papier-Regeln ergänzt.

Weltansicht und HUD-Porträts lesen denselben zentralen `SpriteCatalog`. Die Teamfarbe kommt aus dem Besitzer und bleibt unabhängig von der internen Farbgruppe. Bei weniger als zehn Bildschirmpixeln je Zelle zeichnet der Shader ebenfalls Quadrate: Arbeiterkern und Kriegerpanzer bleiben als einfache Merkmale erhalten. Die Detaildarstellung bleibt ohne Halo aktiv. `sprites_enabled` und `glow_enabled` bleiben getrennte Renderer-Eigenschaften beim Aufbau; ein neues Qualitätseinstellungsmenü ist nicht Bestandteil.

## Assets und Austausch

| Resource | Bilder | Raster | Inhalt |
| --- | --- | --- | --- |
| `assets/pixel/square_units.tres` | `square_units_body.png`, `square_units_team.png` | 32×32, eine Spalte, vier Zeilen | Arbeiter und Kriegergrafiken 1–3 |
| `assets/pixel/tactical_atlas.tres` | `tactical_body.png`, `tactical_team.png` | 16×16, vier Spalten, 13 Zeilen | Bestehende Gebäudezustände und Befehlsicons |

Beide Resources sind tatsächlich geladen. Ein `SpriteAtlas` enthält `body`, `team_mask`, `cell_size`, `frames`, `frame_ticks` und benannte `rows`. Der Einheitenatlas ist 32×128 Pixel groß; seine Zustandsnamen verwenden dasselbe jeweilige Quadrat. Der Gebäudeatlas ist 64×208 Pixel groß. Seine bisherigen Bilder wurden nur umgeordnet, nicht neu gestaltet. Die Forschungsanimation behält vier Bilder mit vier Takten je Bild.

Die neutralen Körperbilder enthalten Metall, Kerne, Prismen und transparente Flächen. Deckungsgleiche weiß/graue Team-Masken werden beim Zeichnen mit der Fraktionsfarbe multipliziert und behalten ihre Schattierungen. Beide Ebenen nutzen verlustfreie PNGs, nächste Pixelabtastung und keine Mipmaps. Die 32×32-HUD-Porträts werden aus denselben Bildregionen erzeugt und gecacht. Der Körper-/Team-Dateitausch benötigt keine Änderung der Simulation. Raster und Zeilen stehen in den Resources; Terrain bleibt im vorhandenen Materialshader.

`assets/pixel/square_units_source.png` ist die mit dem Bildwerkzeug aus dem freigegebenen Konzept aufbereitete transparente Vierer-Spritequelle. `tools/import_square_units.gd` erledigt nur den technischen Import: vier getrennte Alpha-Fußabdrücke finden, auf 32 Pixel ausrichten und Goldflächen von neutralem Metall trennen. Der Quellstreifen ist keine Laufzeitabhängigkeit. Die Originalausgabe des Bildwerkzeugs bleibt außerhalb des Repositorys erhalten.

```sh
godot --headless --path . -s tools/import_square_units.gd
godot --headless --path . --import
```

Die bestehenden Gebäude/Icons lassen sich mit `tools/draw_tactical_atlas.py` (optional Python/Pillow) reproduzieren. Dieses Werkzeug schreibt ausschließlich den Gebäudeatlas und überschreibt die Quadrate nicht. Zum Spielen, Exportieren und in CI sind weder dieses Werkzeug noch Pillow erforderlich. Direkte Änderungen an den fertigen PNGs werden beim erneuten Aufruf des jeweiligen Import-/Zeichenwerkzeugs überschrieben.

## Zustände, Zeit und Wissen

`TacticalArt` bleibt eine kleine Fassade zum zentralen Katalog. Die Worker-/Army-Renderer behalten ihre gebündelten Farbtexturen und zusätzliche RGBA-Daten: Atlaszeile, tatsächliche Aktivität, Besitzer sowie eigene Arbeitermarkierung bzw. visuelle Krieger-Vorschauvariante. Blickrichtungen und Sprite-Rotation wurden entfernt. Der Arbeitskern und der kurze Angriffskern lesen reale Workerzustände bzw. `last_attack`; allein veränderte Ziele drehen und verändern die Figuren nicht. Es gibt keine Node oder Szene pro Einheit.

Kernakzente und Forschungsbilder folgen ausschließlich Simulationstakten. Pause stoppt sie; Spieltempo verändert deren Taktgeschwindigkeit. Zeichnen verändert keine Simulation, Zufallsquelle oder Speicherdatei. Tote, verlassene und nicht sichtbare Einheiten werden aus Farb- und Zusatzdaten entfernt. Die Zustandstexturen benötigen je vier zusätzliche CPU- und GPU-Bytes pro Weltzelle und Renderer; eine große Leistungsabnahme ist weiterhin gesondert zu messen.

`ResearchVisualState` bleibt flüchtiger Darstellungszustand: eigene/aktuell sichtbare Zentren, echte Versorgung, weiterlaufende bereits bezahlte Restdauer und nur tatsächlich beobachtete Abschlüsse. Das Umgebungslicht erfordert tatsächlichen Verbrauch. Abschlusszeichen enden nach 40 Simulationstakten; ein neuer Auftrag hat Vorrang. Nach Simulationstausch wird die Beobachtung verworfen. Verborgene Gegnerzentren verwenden ein statisches gedimmtes Erinnerungsbild; keine Live-Aktivität und keine nachträglichen Abschlussmeldungen.

## Prüfungen und Reviewbilder

`tests/test_sprite_catalog.gd` prüft beide Atlasgrenzen, Körper-/Maskenebenen, gemeinsame Icons, die vier unterscheidbaren Quadratgrafiken und den Teamrand an allen vier Seiten. Weiter geprüft werden echte Arbeits-/Angriffszustände, Besitzer unabhängig von Farbgruppen, eigene Markierungen, tote/verborgene Einheiten und die bisherigen Forschungszustände einschließlich Sichtverlust. Die gültigen Army-Paletten- und Gameplayregressionen bleiben erhalten.

`bench/sprite_visual_check.gd` rendert eine beschriftete Übersicht aller drei Teamfarben und Kriegergrafiken sowie Ansichten bei 32/16 Pixeln. Der echte gebündelte GPU-Renderer wird ohne Halo geprüft: Teamrand/Kernpixel, Pause, Arbeitskern, identische Bilder bei geänderten Zielen, sichtbare Panzerunterschiede, tote Einheiten und echtes Forschungsgebäude bei Versorgung/Unterbrechung. Die Stufen-Vorschau erzeugt keine spielmechanischen Stufen. Die Diagnosewelt wird ausdrücklich verändert und ist keine speicherbare normale Partie.

```sh
godot --headless --path . -s tests/run_tests.gd -- sprite_catalog
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1600x1000x24' \
  godot --audio-driver Dummy --path . -s bench/sprite_visual_check.gd
```

CI prüft weiterhin die vollständigen nativen und GDScript-Referenzsuiten, Hauptszenenstart, P6-Bedienung, Cavern-HUD und Sprite-Darstellung. Script-/Shaderfehler lassen die Grafikschritte fehlschlagen. Protokolle/Bilder werden als `p6-visual-check`, `cavern-visual-check` und `sprite-visual-check` hochgeladen. Tatsächlicher Commit und Actions-Ergebnis werden im neuen PR dokumentiert.

Physikalische Schatten, größere Partikeleffekte, weitere ausgearbeitete Gebäudegrafiken, das Qualitätseinstellungsmenü und Windows-/10k-Armee-Leistungsabnahme bleiben eigene Schritte.

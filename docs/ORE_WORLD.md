# Tunnel, Erzadern und kontinuierlicher Energieabbau

Auftrag vom 27. Oktober 2026, D-075/D-076. Der Nutzer bestätigt die Erzdesigns, die untenstehenden vorläufigen Werte, getrennte Start-Tunnelnetze und ausdrücklich **einen Energiepunkt pro Dot während des Abbaus**. Dieser Review-Stand liegt auf `feat/ore-veins-world`, aufbauend auf `00ab5a2` aus dem noch offenen Boden-PR #12. Der Folge-PR gegen `main` enthält dadurch auch dessen Bodenänderungen. Kein automatischer Merge oder Release.

## Bestätigte Spielregeln und vorläufige Werte

Jeder Spieler erhält ein Startgebiet und ein frei begehbares Tunnelnetz. Anfangs besteht keine freie Verbindung zu anderen Startnetzen. Abbaubare Zellen trennen sie; dauerhaftes Obsidian darf die Erreichbarkeit durch Abbau niemals verhindern. Freie Verzweigungen und Sackgassen sind möglich. Nach vollständigem Abbau aller Ressourcen bleiben die unzerstörbaren Wände als Kartenstruktur erhalten.

| Material | Härte | Basisdauer je Arbeiter | Energie je Block |
|---|---:|---:|---:|
| Gestein | 1 | 1 s | 1 |
| Kupfer | 1 | 1 s | 3 |
| Eisen | 2 | 2 s | 8 |
| Silber | 3 | 4 s | 25 |
| Gold | 4 | 8 s | 80 |
| Kobalt | 5 | 16 s | 250 |
| Chrom | 6 | 32 s | 800 |
| Titan | 7 | 64 s | 4.000 |
| Diamant | 8 | 128 s | 20.000 |
| Obsidian | unzerstörbar | — | 0 |

Die Dauer gilt bei 20 Takten/s, Basis-Abbauleistung 1 und ohne Forschung. Alle Erze sind grundsätzlich abbaubar. Bestehende Abbau-Forschung und mehrere Arbeiter beschleunigen die Arbeit, ohne den Gesamtertrag zu verändern. Bestehende Veredelung kann freigesetzte Energie weiterhin verdoppeln; die Tabelle nennt den unveredelten Ertrag.

## Neue Welten

`CavernGenerator` verwendet einen festen Ganzzahl-Zufallsstrom. Die Schritte sind: Gestein füllen, dauerhaftes Wandgerüst anlegen, getrennte freie Tunnel herausarbeiten, sparse Erzadern setzen. Gleiche Konfiguration und gleicher Seed erzeugen denselben Zustand. Neue Karten enthalten keine alten mittleren/harten Material-IDs 2/3.

Das Obsidian-Gerüst ist ein Baum aus rechtwinkligen Segmenten auf einem 12-Zellen-Raster mit Abstand zum Kartenrand. Ohne geschlossene Wandzyklen kann es keine Region einsperren. Startgebiete und zentrale Missionsflächen sind ausgespart; Tunnel können Segmente unterbrechen. Es entsteht ein verbleibendes Wandlabyrinth, keine geschlossene Arena.

Tunnel wachsen als verbundene, drei Zellen breite Äste innerhalb der nächstgelegenen Startregion. Eine Schutznaht aus abbaubarem Material verhindert Kontakte zwischen den Netzen, auch an Ecken. Bau-Startlichtungen beachten dieselbe Naht. Auf der kleinsten 32er-Mehrspielerkarte liegen drei/vier Starts in den Ecken, damit die Produktionsringe vollständig bleiben. Für mehr als 30 Startarbeiter werden größere, weiterhin getrennte Lichtungen angelegt.

Vorläufige Aderintervalle je Weltzellenzahl: 600 / 1.200 / 2.800 / 6.500 / 13.000 / 28.000 / 70.000 / 300.000; maximale Aderlängen: 8 / 7 / 6 / 5 / 4 / 3 / 2 / 1 für Kupfer bis Diamant. Der Bruchrest der Aderzahl entscheidet deterministisch über eine zusätzliche Ader. Jeder Ader-Schritt kann mit 20 % Wahrscheinlichkeit die nächstniedrigere Erzart enthalten. Nur gewöhnliches Gestein wird ersetzt. Dadurch sind wertvollere Ressourcen im Mittel seltener; einzelne Welten müssen nicht jede Art oder eine exakt geordnete Häufigkeit enthalten. Erzeugte Bereiche zählen nicht als Spielerabbau.

## Energie während der Arbeit

`MiningSystem` berechnet den kumulativen Anspruch als auf die nächste ganze Zahl gerundeten Anteil `Fortschritt × Ertrag / Gesamtdauer`. Es erzeugt ausschließlich die Differenz zum bereits ausgegebenen Zellzähler. Überarbeit wird auf die Haltbarkeit begrenzt. Mehrere Arbeiter und Forschung können so weder mehrfach bezahlen noch einen Abschlussbonus erzeugen.

Ein Gesteinsblock mit nur einem Energiepunkt gibt diesen bei halber Arbeit ab und bleibt bis zum vollständigen Abbau fest. Ein Basis-Arbeiter an Diamant gibt bei Standardwerten pro Takt sieben oder acht einzelne Dots ab. Dots entstehen auf der freien Arbeitszelle; ihr Herkunftsfeld bleibt der Erzblock. Damit können sie den Kern bereits erreichen, während der Block noch fest ist. Der jeweils beitragende Arbeiter bestimmt den Besitzer neu erzeugter Energie. Transport, Stau, Abfangen, Puffer, Neutralisierung, Routenverfall und Gutschrift bei Ankunft bleiben erhalten.

Der Mehrfraktionen-Transport verwendet den bestehenden nativen Bewegungsaufruf nun pro fälliger Fraktion gebündelt. Unveränderte Arrayfelder werden nicht erneut geschrieben; beim Entfernen eines Dots werden weiterhin sämtliche parallelen Felder gemeinsam kompaktiert. Ein 30-Takt-Vergleich mit 20.000 Dots, zwei Besitzern und unterschiedlichen Transportperioden prüft Gleichheit mit der GDScript-Referenz nach jedem Takt.

Ein lokaler isolierter 20.000-Dot-Transportprobe unter Linux/Godot 4.3 sank von 41,95 auf 30,17 ms im Mittel und von 91,38 auf 40,78 ms Spitze. Das ist keine Abnahme einer ganzen Partie, mehrerer Diamantströme, Windows oder 4×-Tempo. Es gibt weiterhin keine Node pro Energiedot.

Die Probe ist mit `godot --headless --path . -s bench/energy_stream_benchmark.gd` wiederholbar: 64er-Offenwelt, zwei Fraktionen, keine Arbeiter, 20.000 Dots einer Fraktion, 80 Transportaufrufe bei Periode 8; erster Topologieaufbau aus der Messung ausgeschlossen.

## Darstellung und Sichtwissen

`assets/pixel/ore_tiles_source.png` ist die mit dem Bildwerkzeug aus dem freigegebenen Entwurf aufbereitete Vorlage: zehn quadratische Kacheln in zwei Reihen. `tools/import_ore_tiles.gd` extrahiert sie anhand der Transparenz und skaliert technisch mit Nearest Neighbor auf den 32×320-Atlas `ore_tiles.png`. Reihenfolge: Gestein, Kupfer, Eisen, Silber, Gold, Kobalt, Chrom, Titan, Diamant, Obsidian. Jedes Erz hat ein eigenes Muster und eine eigene Farbe; Obsidian ist violett mit dunklen Facetten.

Eine zusätzliche R8-Materialtextur wählt die Kachel im Terrainshader; die vorhandene Zellpalette bleibt für Minimap und Legacy-Materialien erhalten. Lebende Baustellenfundamente erhalten nur im Renderer die Kennung 254, damit sie keine natürlichen Obsidianblöcke vortäuschen. Diese Daten stehen schon vor dem ersten Upload bereit. Simulation und Weltmaterial ändern sich dadurch nicht.

Der Fog-Renderer verwendet ausschließlich gemerktes Terrain, gemerkte Bodenhistorie und gemerkte Gebäude. Neue Erze und Abbau außerhalb der Sicht aktualisieren diese Darstellung nicht. Alte Bodenfarbunterschiede aus PR #12 bleiben erhalten. Diagnose-Kartenübersichten im Grafikcheck decken die Karte ausdrücklich nur in markierten, nicht speicherbaren Testzuständen auf.

## Speicherung und native Bibliothek

SaveGame-Version 2 erhält additiv `mining_released` sowie `work_per_hardness` und `dig_power`. Länge, Typ, Materialgrenzen, Fortschritt, maximaler Ertrag und bereits erreichter Auszahlungsanspruch werden validiert. Der Zellzähler wird erst nach dem Wiederherstellen der Materialien eingesetzt, damit `set_material` ihn nicht zurücksetzt. Ein Diamant mit laufendem Abbau kann exakt ohne doppelte oder fehlende Energie fortgesetzt werden. Welt-Hashes berücksichtigen die Auszahlungszähler.

Alte Welten werden nicht neu generiert. IDs 2/3 behalten Härte, alte Dauer und alten Ertrag; fehlende Auszahlungszähler bedeuten dort bisher nicht ausgezahlte Arbeit, die beim nächsten Beitrag anteilig nachgeholt wird. Neue Erz-IDs ohne Zähler werden als unvollständiger Speicherstand abgelehnt. Bereits vorhandene Dots und Bilanzen bleiben erhalten. Das ist eine additive Migration, keine Zusage, neue Speicherstände in alten Programmversionen öffnen zu können.

Native Zielsuche und Arbeiterbewegung akzeptieren jetzt alle gültigen Erz-IDs und schließen ID 4 aus. Windows-Build, Descriptor und Fallbackpfad wechseln gemeinsam auf **v10**. Das Spiel dafür vollständig neu starten; eine laufende v9-Partie lädt den neuen Kern nicht nach. Linux wurde gebaut und ausgeführt; Windows-v10-Ausführung ist hier nicht geprüft.

## Nachweise

Godot 4.3, Linux, nativer C11-Build und Software-OpenGL/Xvfb. Automatisierte Prüfungen enthalten Materialwerte, Forschung für sämtliche neuen Ressourcen, Bruchfortschritt mit Speicherfortsetzung, 20.000 Einzelpunkte, Überarbeit/mehrere Arbeiter, getrennte Netze für 32/64 und zwei bis vier Spieler über mehrere Seeds, Erreichbarkeit nach Komplettabbau, ausgeschlossene Obsidianziele und den nativen Transportvergleich. Bestehende Bau-, Wartungs-, Sicht- und Spielmechaniktests bleiben erhalten. Geänderte Fixtures trennen nun generiertes Obsidian von Kernfundamenten und isolieren Transporttests von zusätzlichem Abbau. Numerisch nahe Farben sind durch eigenständige Atlasmuster ergänzt.

Reproduzierbare Befehle:

```sh
bash native/build.sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --headless --path . --quit-after 8
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . -s bench/ore_world_check.gd
```

Der neue Grafikcheck prüft den ersten Fundament-Upload, unveränderten Simulationszustand beim Zeichnen und einen realen laufenden Diamantabbau mit bereits gelieferter Energie. Er erzeugt `/tmp/ore-catalog.png`, `/tmp/ore-map-overview.png`, `/tmp/ore-map-detail.png` und `/tmp/ore-diamond-flow.png`. CI veröffentlicht diese samt Log als `ore-visual-check` und führt zusätzlich die bisherigen P6-, Cavern-, Sprite- und Bodenchecks aus. Das tatsächliche GitHub-Actions-Ergebnis und der geprüfte Commit werden im PR festgehalten.

Lokaler Abschlussstand: **361 Tests / 54.808 Prüfungen / 0 Fehler** nativ und **361 Tests / 33.301 Prüfungen / 0 Fehler** mit `--no-native`; Hauptszene startet. Alle fünf Grafikchecks melden jeweils `0 failures`, ohne Skript-, Parse- oder Shaderfehler in den Abschlusslogs. Windows-v10-Lauf, manuelle Langpartie und endgültiges Ressourcenbalancing bleiben offen.

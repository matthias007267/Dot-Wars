# Bestätigte Energie-Dot-Grafik

Der Nutzer hat zunächst eine Vorschau verlangt und den gezeigten Entwurf anschließend ausdrücklich übernommen (27. Oktober 2026, D-077). Umsetzung auf `feat/ore-veins-world` im offenen Review-PR #13. Der freigegebene Bildentwurf liegt als `assets/pixel/energy_dot_concept.png` bei; er ist eine Konzeptzeichnung und kein Screenshot der damaligen Spielversion.

## Darstellung

Ein achsensymmetrisches Lichtquadrat ersetzt die bisherige kleine Farbfläche: weißer 2×2-Kern, cyanfarbenes Innenlicht, dunkler Zwischenraum, ein Pixel breiter Teamrand und zurückhaltendes Leuchten. Der Kernbereich umfasst acht logische Pixel innerhalb eines 16-Pixel-Zellrasters. Die eigentliche Form belegt damit die halbe Zellbreite und bleibt kleiner als die Arbeiter. Sie dreht sich nicht und erhält keine neue Spielanimation.

`src/render/shaders/energy_dot.gdshader` bildet diese einfache Geometrie direkt nach. Dadurch benötigt die Laufzeit weder die große Konzeptzeichnung noch eine Textur pro Energiepunkt. Alle Energiedots werden weiterhin mit einer gemeinsamen Welttextur und einem Drawcall gezeichnet. Die separate Shaderdatei verändert die bestehenden Arbeiter-/Krieger-Sprites nicht.

Ab zwölf Bildschirmpixeln pro Weltzelle zeigt der Renderer alle Details. Darunter bleibt eine kompakte, überwiegend teamfarbige Form lesbar. Zoom entscheidet anhand der gesamten Canvas-/Objekttransformation; auch vergrößerte Diagnoseansichten zeigen dieselbe Grafik. Der weiße Kern und die Teamkennung bleiben bei ausgeschaltetem Halo erhalten.

Der Rand nutzt immer die bestehende Fraktionspalette: Gold, Koralle/Rot, Blau, Grün. Eigene freie Energie war bisher cyan; sie trägt jetzt wie im Entwurf den goldenen Teamrand. Neutrale Energie bleibt grau. Gepufferte Energie erhält ein bernsteinfarbenes Innenlicht, behält aber den Rand ihres tatsächlichen Besitzers.

Die Welttextur speichert RGB = Randfarbe und A = Präsenz/Pufferstatus (0 leer, 128 gepuffert, 255 frei). Der Shader dekodiert den Status und zeichnet die Körperform deckend. Die Simulation verwendet diese Daten nicht.

## Sicht und große Ströme

`EnergyRenderer` filtert jeden physischen Punkt über die aktuelle Sicht des Betrachters. Nach Sichtverlust werden die alten Pixel beim nächsten Update gelöscht. Der neue Shader liest keine Nachbarzellen: Der Halo bleibt innerhalb der eigenen Zelle und kann aus verdeckten Punkten keine Helligkeit erzeugen.

Mehrere Energiedots auf derselben Rasterzelle teilen wie bisher eine sichtbare Markierung; bei gemischtem Besitz bestimmt weiterhin der letzte sichtbare Punkt im stabilen Array die Markierung. Die Liste zum Löschen alter Renderpixel enthält nun jede belegte Zelle nur einmal. Auch 20.000 übereinanderliegende Punkte werden einzeln transportiert, abgefangen und bilanziert. Es gibt keine Wertpakete, zusätzliche Gutschrift oder Node pro Dot. Regeln, Forschung, Abbau, native Bibliothek und Speicherformat bleiben unverändert.

## Prüfung

`tests/test_energy_renderer.gd` prüft Teamfarbe, neutrale und gepufferte Energie, sofortiges Entfernen bei Sichtverlust, Wiedererscheinen bei Sichtkontakt, unveränderten Simulationszustand und 20.000 physische Punkte bei nur einer Renderzelle.

Der grafische Check liest tatsächlich gerenderte Pixel und prüft weiße Kerne und exakte Teamränder für alle vier Besitzer, getrenntes bernsteinfarbenes Pufferlicht, unsichtbare Dots ohne Körper oder Halo sowie abschaltbaren Halo bei unverändertem Kern. Die kompakte Darstellung behält die Teamfarben. Zusätzlich wird ein laufender Diamantabbau in der echten Hauptszene gezeigt, ohne Kartenaufdeckung; der vollständige Simulationshash bleibt beim Zeichnen gleich.

```sh
godot --headless --path . -s tests/run_tests.gd -- energy_renderer
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . -s bench/energy_dot_visual_check.gd
```

Die Grafikprüfung erzeugt `/tmp/energy-dot-colors.png`, `/tmp/energy-dot-compact.png` und `/tmp/energy-dot-game.png`. CI führt sie zusätzlich zu den bisherigen fünf Grafikchecks aus und veröffentlicht Bilder samt Log als `energy-dot-visual-check`. Das tatsächliche CI-Ergebnis und der geprüfte Commit werden im PR dokumentiert. Die Szene ist eine markierte Diagnosefixture; sie schreibt keinen regulären Spielstand.

Lokaler Abschluss unter Linux/Godot 4.3: **363 Tests / 54.820 Prüfungen / 0 Fehler** nativ, **363 Tests / 33.313 Prüfungen / 0 Fehler** als GDScript-Referenz. Neuer Energie-Grafikcheck und bestehender Erz-/Abbau-Grafikcheck jeweils `0 failures`; Import und Abschlusslogs ohne Skript-, Parse- oder Shaderfehler. Keine neue Windows- oder Langpartie-Abnahme aus dieser Grafikprüfung ableiten.

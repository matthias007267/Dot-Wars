# Kampfimpulse und Pixelzerfall

Auftrag D-081, Umsetzung auf `feat/combat-pixel-effects` ab `main`/`0646fa0` nach Merge von PR #13. Reine Kampfoptik; Schaden, Reichweite, Produktion, Taktung, Bilanzen und gespeicherter Zustand bleiben erhalten.

## Darstellung

- Ein tatsächlicher Nahkampfangriff erzeugt einen kurzen Teamimpuls am Kriegerkern und einen kleinen Lichtstoß zum benachbarten Ziel (0,16 Sekunden bei 1×). Die Einheit dreht sich nicht. Der Lichtstoß ist eine Animation, kein neues Projektil mit eigener Spiellogik.
- Ein tatsächlich beschädigtes Dot blitzt innen weiß auf (0,13 Sekunden), mit vier kleinen Teamfunken. Der äußere Teamrand bleibt sichtbar. Mehrere gleichzeitige Treffer werden je beschädigter Einheit zu einem Blitz zusammengefasst.
- Besiegte Arbeiter zerfallen in acht kleine Quadrate über 0,38 Sekunden, Krieger in zwölf über 0,48 Sekunden. Drei Viertel der Splitter tragen die Teamfarbe, die übrigen sind weiß. Sie fliegen kurz auseinander und verblassen. Kein dauerhafter Schutt, keine zusätzlichen Energie-Dots, keine Node pro Partikel.
- Vorhandene Katalogstufen 1/2/3 behalten dasselbe Muster mit einer, zwei oder drei kurzen Spuren; Stufe 3 ergänzt einen quadratischen Leuchtring. Reguläre Partien verwenden weiterhin ausschließlich den vorhandenen Basiskrieger. Das Review-Bild von Stufe 3 führt keine neue Forschung oder Einheit ein.
- Pause friert Effekte ein, 2×/4× beschleunigt sie entsprechend. Szenenwechsel/Laden beginnt ohne nachträgliche Explosionen. Entfernung außerhalb des Kampfes, etwa Ausscheiden einer Fraktion, ist kein Kampftod und erzeugt keinen Burst.

## Ereignisse und Sichtschutz

Beide Armee-Rechenpfade treffen in `ArmyState._apply_damage` zusammen. Vor gleichzeitiger Schadensanwendung/Slotentfernung werden flüchtige Signale für Angriffe, aggregierte Treffer und tatsächliche Tode veröffentlicht. Bei unverbundener Angriffsbeobachtung entfällt die zusätzliche Angreiferschleife. Keine Änderung an der nativen Schnittstelle; v11 bleibt gültig, kein neuer nativer Build für diesen Grafikauftrag nötig. Spiel neu starten.

Der Renderer prüft Sicht, Kamera und Budget, bevor er für einen Angriff das Ziel mit dem vorhandenen Selektor rekonstruiert. Benachbarte Gegner bewegen sich in diesem Armeeschritt nicht; dadurch bleibt das tatsächliche Ziel erhalten. Treffer/Tode werden mit der bisherigen Zelle vor dem Slottausch gemeldet. Unabhängige aggregierte Treffer können nativ und in GDScript in anderer Reihenfolge eintreffen; die vollständige Ereignismenge und der Simulationszustand müssen übereinstimmen.

Ein Impuls erfordert Sicht auf beide Enden, ein Treffer/Burst auf sein sichtbares Ziel. Ein unbekannter Angreifer verrät weder Position noch Farbe durch einen Impuls. Während der Lebensdauer wird aktuelle Sicht erneut geprüft; Sichtverlust verwirft Effekte. Jedes Partikelrechteck einschließlich Halo wird zusätzlich an sichtbaren Rasterzellen zugeschnitten. Auch ein Burst direkt neben schwarzem oder erkundetem Nebel zeichnet nicht hinein. Ehemalige Sicht allein reicht nicht.

## Budgets und Messgrenzen

Ein einziges MultiMesh mit gemeinsamem Float-Puffer stellt maximal **64 Ereignisse / 2.048 zugeschnittene Quads** dar. Ein Kriegerburst enthält zwölf Splitter; Halos und Zuschnitte können weitere Quads benötigen. Bei voller Kapazität werden weitere Effekte ausgelassen; Todesereignisse verdrängen zuerst weniger wichtige Effekte. Neue Angriffsimpulse belegen höchstens die erste Hälfte des Ereignisbudgets, damit Platz für Treffer bleibt. Effekte außerhalb des Kamerabereichs werden gar nicht aufgenommen. Ohne aktive Effekte erfolgen keine laufenden Pufferuploads.

Lokale isolierte Linux-/Godot-4.3-Probe: 10.000 Krieger im Schachbrettkontakt, fünf native Kontaktschritte, HP vor jedem Sample außerhalb der Messung zurückgesetzt, damit alle 10.000 erhalten bleiben. Zustandsvergleich mit unbeobachteter Kopie nach jedem Schritt. Gemessen beim letzten Lauf: Armee ohne Beobachtung **7,29 ms**, mit Effektereignissen **12,45 ms** im Mittel. Getrennte Vorbereitung von 64 Kriegerbursts bei Alter 0,16 Sekunden und 2.048 Quads: **3,15 ms** im Mittel über 30 Durchläufe nach fünf Warmups. Das sind isolierte lokale CPU-Messungen, keine volle Partie, kein GPU-/FPS-Nachweis und keine Windows-Abnahme.

## Prüfung und Vorschau

```text
godot --headless --path . -s tests/run_tests.gd -- combat_effects --require-native
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --path . -s bench/combat_visual_check.gd
godot --headless --path . -s bench/combat_effects_benchmark.gd
```

Die vier neuen Regressionstests prüfen tatsächliche Angriffe/Arbeiter-/Kriegertode, Ereignisgleichheit und Zustandsvergleich mit Native/Referenz/unbeobachteter Simulation, Nebel samt Halozuschnitt, keine erneute Anzeige nach Sichtverlust, feste Budgets, Tod-Priorität, Pause/Tempo und unveränderte Bilanzen. Bestehende gleichzeitige Kampftode, Konstruktion, Wartung, Forschung, Speicherung und Sicht bleiben durch die vollständigen Suiten abgedeckt.

Der Grafikcheck verwendet die echte Hauptszene und einen tatsächlichen Kampftakt ohne globale Kartenaufdeckung: oben überlebende Krieger, mittig ein besiegter Arbeiter, unten gleichzeitige Kriegertode. Er prüft den weißen Trefferblitz anhand gerenderter Pixel, sichtbare Splitter, keine Pixeländerung im verdeckten Nachbarfeld und unveränderten Simulationshash beim Zeichnen. Er erzeugt `/tmp/combat-strike.png`, `/tmp/combat-burst.png` und `/tmp/combat-level-preview.png`. CI führt diesen neunten Grafikcheck aus und lädt sie samt Protokoll als `combat-visual-check` hoch.

Optional `-- --combat-record` speichert 24 Bilder der echten Ereignisse unter `/tmp/combat-frames/`. Die Simulation steht dabei für eine reproduzierbare Aufnahme; nur die bereits ausgelöste Animation läuft in 0,025-Sekunden-Schritten weiter. Beispiel für ein zugeschnittenes GIF in **halber Geschwindigkeit** (lokaler FFmpeg, nicht für CI erforderlich):

```text
ffmpeg -y -framerate 20 -i /tmp/combat-frames/%03d.png -filter_complex 'crop=640:660:640:160,split[a][b];[a]palettegen[p];[b][p]paletteuse' /tmp/combat-preview.gif
```

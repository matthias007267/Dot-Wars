# Normale KI-Partie: gemessene Engpässe, 27. Oktober 2026

D-085. Auftrag des Nutzers: Code analysieren, Konzeptverbesserungen vorschlagen und die Performance optimieren. Die Konzeptvorschläge sind **Vorschläge ohne Freigabe** und ändern keine Regel. Die Optimierungen ändern weder Spielregeln, Sichtweiten, Takt noch Bilanzen. Branch `perf/match-profile`, Commit und Review-PR auf ausdrücklichen Wunsch, kein automatischer Merge.

## Ausgangslage

Bisherige Messungen deckten Großfixtures (10.000 Krieger, Labyrinth, Engstelle) ab, aber keine gewöhnliche Partie mit KI, Bau, Forschung, Netz und HUD. Zwei neue dauerhafte Messläufe schließen diese Lücke:

- `bench/match_profile.gd` – headless, 256×256, Seed 1337, drei KI-Gegner plus untätige Fraktion 0, 15 Spielminuten. Teilzeiten je Systemschritt über das neue, standardmäßig ausgeschaltete `Simulation.profile_detail`; am Ende Zustandshash und SHA-256 des vollständigen Spielstands.
- `bench/match_live_profile.gd` – dieselbe Partie nach zehn vorgespulten Minuten mit echtem Fenster, HUD, Minimap, Fog und Einheitenansichten; 1920×1080, VSync aus. Teilzeiten der Bildaktualisierung pro Simulations-Frame.

Native Windows-Bibliothek war beim Start nicht gebaut: Descriptor verlangt v12, im Ordner lagen nur bis v9. Das Spiel lief also auf der GDScript-Referenz. v12 wurde zuerst gebaut und dient als Ausgangswert.

## Gefundene Engpässe und Änderungen

| Bereich | Vorher | Nachher | Änderung |
| --- | --- | --- | --- |
| HUD je Simulations-Frame | **5,86 ms** | **0,56 ms** | Forschungsbaum stylt Knöpfe nur noch bei Auswahlwechsel und setzt Text nur bei Änderung |
| Fog je Takt | 1,95 ms | 1,06 ms | Native `fog_merge` schreibt Sicht/Erkundung/Gelände-/Bodenerinnerung |
| Energie je Takt | 1,00 ms | 0,58 ms | Hot Loop mit lokalen Arrays und Takt-Cache je Besitzer |

**HUD:** `ResearchTreeView.refresh` lief bei jedem Takt auch bei verborgenem Baum und rief für jeden Technologieknopf `UiTheme.style_button` auf. Das erzeugte je Knopf drei neue StyleBoxen und acht Theme-Overrides und zwang Godot zu Theme-/Layout-Neuberechnungen. 95 % der HUD-Zeit lagen hier. Der sichtbare Endzustand ist identisch: Stil wird beim ersten Refresh und bei jedem Auswahlwechsel gesetzt.

**Fog:** Nach der nativen Strahlunion schrieb GDScript jede sichtbare Zelle einzeln in vier Wissensarrays, pro Fraktion und Takt mehrere zehntausend Zuweisungen. Native v13 ergänzt `fog_merge(cells, explored, terrain_memory, floor_memory, terrain, excavated)` mit denselben Schreibvorgängen. Bündnisse werden weiterhin in GDScript zu einer Zellliste je Fraktion vereinigt. Ohne Methode, bei ungültiger Eingabe oder mit `--fog-reference`/`--no-native` läuft die unveränderte Referenzschleife.

**Energie:** Je Dot und Takt wurden Objekteigenschaften, Terrain und `_pace_of` mehrfach gelesen. Die Schleife verwendet jetzt lokale Arrays, schreibt sie einmal zurück und berechnet die Fälligkeit je Besitzer einmal pro Takt. Die zuletzt zugewiesene `_dist`-Route gehört zum Resume-Zustand und wird in denselben Fällen gesetzt wie vorher.

## Ergebnisse

Windows 11, Ryzen 9 5950X, RTX 2070 SUPER, Godot 4.3, native v13.

Headless, 15 Spielminuten (18.000 Takte):

- Vorher (v12): Ø **4,626 ms/Takt**, p95 6,993, p99 16,188, Maximum 47,034 ms.
- Nach Fog: Ø **3,711 ms**, p95 5,922, p99 15,377, Maximum 46,220 ms.
- Energieänderung allein, 6 Minuten: Ø 3,208 → 2,883 ms, Energie 0,997 → 0,576 ms. Zustandshash `2802019333` und Snapshot-SHA-256 `ff912dcc44cf8fa8…` sind vorher und nachher identisch.

Abschluss headless, 15 Spielminuten, alle drei Änderungen: Ø **3,300 ms/Takt** (−29 %), p95 5,113, p99 15,142, Maximum 46,854 ms, kein Takt über 50 ms, Invarianten fehlerfrei.

Grafiklauf nach zehn vorgespulten Minuten, je 30 Sekunden Messung ohne Bildratenlimit:

| | Vorher (v12) | Nachher (v13) |
| --- | --- | --- |
| Arbeit je Simulations-Frame (Sim + Ansichten + HUD) | 12,8 ms | 5,6 ms |
| davon Simulation / HUD | 5,63 / 6,16 ms | 4,05 / 0,55 ms |
| p99 Frame | 23,3 ms | 15,4 ms |
| Frames über 33 ms | 10 | 0 |
| Takte/s | 20,03 | 20,00 |

Mittlere Bildrate ohne Limit (≈900 → ≈1.190 FPS) ist kein Spielgefühlnachweis; entscheidend sind die selteneren langen Frames bei 60 FPS mit VSync.

## Tests

Vollständige native Suite: **409 Tests, 59.718 Prüfungen, 0 Fehler**. Vollständige Referenzsuite `--no-native`: **409 Tests, 33.912 Prüfungen, 0 Fehler**. Keine Skript-/Parse-/Ladefehler. Neuer Test `test_native_merge_matches_reference_writes_and_rejects_invalid_input`; der vorhandene taktweise Native-/Referenzvergleich mit Bündniswechseln deckt `fog_merge` im Spielablauf ab.

## Grenzen

Fraktion 0 wird von der KI nicht gesteuert; die Messpartie ist daher drei aktive KI-Gegner plus ein untätiger Spieler. Keine Multiplayer-, 10.000-Krieger- oder Langzeitgrafikabnahme aus diesem Lauf. Verbleibende größere Posten je Takt: Armee ≈0,6 ms (bereits nativ), Wegfelder ≈0,5 ms, Strahlunion ≈0,57 ms. Das Maximum von ≈46 ms fällt in die erste Spielminute (Kaltstart); danach liegen die Minutenmaxima bei etwa 18–33 ms. p99 um 15 ms bleibt; diese Einzelspitzen sind ein eigener Messfall.

Nach dem Ersetzen der DLL Godot/das Spiel vollständig neu starten; v12-Prozesse laden v13 nicht automatisch.

## Konzeptvorschläge aus der Analyse (ohne Freigabe)

Diese Punkte sind **Vorschläge**. Sie ändern keine beschlossene Regel und werden nur nach ausdrücklichem Auftrag umgesetzt.

1. **KI-Wirtschaft an das Spielerlimit anpassen.** `MatchRules.AI_CAP = 8` begrenzt KI-Arbeiter, während Spieler 50 haben und die KI bis zu 2.000 Krieger kauft. In der Messpartie hatten drei KI-Gegner plus Startarbeiter zusammen 29 Arbeiter, aber bis zu ~590 Krieger. Vorschlag: Arbeiterziel je Schwierigkeit (z. B. leicht 8, normal 20, schwer 35) und Außenposten als Expansionsziel.
2. **Armeegröße an etwas binden.** Krieger kosten nur einmal; danach gibt es weder Unterhalt noch Kapazität. Das belohnt Horten. Mögliche Varianten: Kapazität je Kern/Außenposten oder geringer Energieunterhalt ab einer Schwelle, analog zum bereits bestätigten Waffenunterhalt (D-083).
3. **Mittelfristiges Ziel vor der Vernichtung.** Ohne neue Reliquienregeln ist Vernichtung das einzige aktive Matchziel. Das bereits vorgesehene Reliquienpaket (ein Typ, Transport/Diebstahl, Netzanschluss, Countdown) würde Kämpfe um feste Punkte erzwingen.
4. **Geplante Gebäude Mauern und Aufklärungssensor priorisieren.** Vier-Felder-Sichttiefe, Abbau und Engstellen machen genau diese beiden Gebäude (G02/G04) taktisch wertvoll; Energiefarmen dagegen erst nach Klärung von Frage 11.
5. **Altlasten aus Oberfläche und Regeln entfernen.** Das HUD aktualisiert weiter deaktivierte Sofortkauf-Knöpfe (Kern, Verschmelzung 2×2/3×3), Quelle und Veredler bleiben unentschieden (Fragen 11/15). Eine Entscheidung „entfernen oder in Energiefarm überführen“ würde Bedienung und Code vereinfachen.
6. **Energieverluste sichtbar machen.** Energie ohne Route verfällt nach 60 s. Eine HUD-Warnung „x Energie ohne Route, verfällt in y s“ würde die Regel verständlich machen, ohne sie zu ändern.

Beobachteter Darstellungsfehler, nicht still korrigiert: `ResearchTreeView` setzt beim Aufbau Zweigfarben als Schriftfarbe, `UiTheme.style_button` überschreibt sie danach. Auf den Knöpfen sind die vier Zweigfarben daher nicht zu sehen, nur in den Zweigtiteln. Das Verhalten ist vor und nach D-085 identisch.

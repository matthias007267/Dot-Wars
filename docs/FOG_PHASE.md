# P5 Fog of War – aktueller Implementierungsstand

Branch: `feat/p5-fog-visibility-foundation`, Draft PR #7.

## Implementiert
- Getrennte aktuelle Sicht, permanente Erkundung und gespeicherter letzter Terrain-/Gebäudezustand pro Fraktion.
- Sichtlinien mit Hindernissen; eigene Arbeiter, Krieger und fertige Standorte als Sichtquellen; Allianzsicht.
- Sichtzustand im Match-Tick, additive Speicherung in V2-Saves.
- `FogOverlay` über dem Terrain: unerforschte Zellen vollständig verdeckt; außerhalb aktueller Sicht nur zuletzt bekannte Terrainfarbe.
- Sichtfilter für Arbeiter-, Krieger- und Energietexturen.
- Minimap in Matches wieder aktiviert, mit separater Textur aus erkundetem Terrain statt der unzensierten Welttextur.
- Rechtsklick auf nicht sichtbare Standorte nutzt keine geheimen Gebäudedaten mehr.
- OrderOverlay zeichnet bekannte Gebäude aus eingefrorenen Spieler-Snapshots; unbekannte feindliche Gruppenbefehle und Kernbeschriftungen sind ausgeblendet.
- HUD unterdrückt exakte gegnerische Population und alte Annäherungshinweise; Auswahl unsichtbarer Einheiten wird verhindert.
- Headless-Tests für Sichtblockaden, Erinnerungszustand, Allianz und Snapshot.

## Offene Punkte vor Merge/Abnahme
1. **Wichtig:** Fog-Overlay überdeckt Terrain, aber der ursprüngliche WorldRenderer nutzt weiterhin echte Daten. Auch Marker, HUD, Auswahl-/Order-Overlay und andere Ausgabekanäle müssen vollständig auf Informationslecks geprüft werden. Sichtgefilterte Terrain- und Minimap-Texturen statt nur Overlay sind das Ziel.
2. Gebäude-Snapshots und Zeichnung gegen Bau-/Zerstörungs- und Sichtwechsel testen. Unbekannte Gebäude dürfen niemals in anderen Overlays/Markern erscheinen.
3. Fog-Minimap zeigt Terrainwissen, bekannte Gebäude, sichtbare eigene Einheiten und Kamerafenster. Minimap-Texturupload und Markerzahl auf sehr großen Karten weiter profilieren.
4. **Performance:** Unveränderte Fog-Frames, identische Sichtquellen und vollständig unveränderte Simulations-Sichtzustände werden übersprungen. Die Signaturprüfung scannt weiterhin Terrain/Quellen; bei Sichtwechseln bleiben volle Sichtarrays und zwei volle Texturuploads. Dirty-Regionen/Chunks und reale Profiling-Messwerte fehlen.
5. Sicherstellen, dass **keine** unbekannten Gegner-/Ressourcen-/Gebäudedaten über Interaktionen, HUD, KI oder späteren Netzwerkverkehr offengelegt werden. Serverautoritatives Sichtfilter-Protokoll separat designen.
6. Godot-Parser, alle Tests, Match-Screenshot, Save/Load-Regressionen und Windows/Linux-CI ausführen. Der zuvor geprüfte Actions-Job war abgebrochen; für die jüngsten Commits war noch kein Lauf abrufbar. Lokal ist keine Godot-Binärdatei verfügbar.
7. Sichtquellen/Reichweiten sind vorläufig. Sensorgebäude und Forschung bleiben außerhalb dieses Teil-PRs.

## Work-Prüfauftrag
PR #7 auschecken; Godot headless import und komplette Tests ausführen; Fehler beheben; mindestens zwei Fraktionen mit Mauern/Terrain-Sichtblockern, beweglichen Dots, zerstörten Gebäuden und Save/Load visuell testen; prüfen, ob gegnerische Informationen im sichtbaren Client erscheinen; CPU-Zeit und Upload-Kosten bei 128², 512² und 1024² mit wachsenden Dot-Zahlen messen; vor Merge alle Sicherheits- und Performance-Blocker beheben.

## Ergänzung: weitere Arbeiten im PR
- Sichtzustandssignatur überspringt die gesamte LOS-Berechnung bei unverändertem Terrain, Einheitenpositionen, Gebäudestatus und Allianzen; Geländeänderungen invalidieren sie.
- Mehrzellige Worker werden pro Pixel an Sicht und Kartengrenzen abgeschnitten.
- Neue Tests für unveränderte Updates und Sichtcache-Invalidierung.
- Chunk-basiertes Fog-Rendering, positionsbasiertes LOS-Quellen-Caching, sichtgefilterte Minimap-Marker und ein reproduzierbarer Headless-Benchmark (`bench/fog_benchmark.gd`) sind implementiert, jedoch nicht ausgeführt.
- **Nicht als erledigt markieren:** belastbare 1k/10k-Dot-Benchmarks, vollständiger Audit aller HUD/AI/Netzwerk-Ausgabekanäle, visuelle Godot-Abnahme und grüner CI-Lauf.

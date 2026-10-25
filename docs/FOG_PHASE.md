# P5 Fog of War – aktueller Implementierungsstand

Branch: `feat/p5-fog-visibility-foundation`, Draft PR #7.

## Implementiert
- Getrennte aktuelle Sicht, permanente Erkundung und gespeicherter letzter Terrain-/Gebäudezustand pro Fraktion.
- Sichtlinien mit Hindernissen; eigene Arbeiter, Krieger und fertige Standorte als Sichtquellen; Allianzsicht.
- Sichtzustand im Match-Tick, additive Speicherung in V2-Saves.
- `FogOverlay` über dem Terrain: unerforschte Zellen vollständig verdeckt; außerhalb aktueller Sicht nur zuletzt bekannte Terrainfarbe.
- Sichtfilter für Arbeiter-, Krieger- und Energietexturen.
- Bestehende Minimap in Matches vorläufig deaktiviert, da sie ansonsten die unzensierte Welttextur offenlegt.
- Rechtsklick auf nicht sichtbare Standorte nutzt keine geheimen Gebäudedaten mehr.
- Headless-Tests für Sichtblockaden, Erinnerungszustand, Allianz und Snapshot.

## Offene Punkte vor Merge/Abnahme
1. **Wichtig:** Fog-Overlay überdeckt Terrain, aber der ursprüngliche WorldRenderer nutzt weiterhin echte Daten. Auch Marker, HUD, Auswahl-/Order-Overlay und andere Ausgabekanäle müssen vollständig auf Informationslecks geprüft werden. Sichtgefilterte Terrain- und Minimap-Texturen statt nur Overlay sind das Ziel.
2. Sichtgefilterte Gebäudezeichnung: zuletzt bekannte gegnerische Gebäude als eingefrorene Snapshots, nicht live aktualisieren; Bauzustand und Zerstörung nur bei Sichtkontakt aktualisieren.
3. Fog-aware Minimap statt der vorläufigen Abschaltung; Sicht- und Erkundungszustände korrekt visualisieren.
4. **Performance:** Aktuell dichte Arrays, Sichtlinien je Quelle und voller Texture-Upload pro Tick; auf großen Karten nicht geeignet. Chunkbasierte Änderungen, sparsame Updates und Profiling nötig.
5. Sicherstellen, dass **keine** unbekannten Gegner-/Ressourcen-/Gebäudedaten über Interaktionen, HUD, KI oder späteren Netzwerkverkehr offengelegt werden. Serverautoritatives Sichtfilter-Protokoll separat designen.
6. Godot-Parser, alle Tests, Match-Screenshot, Save/Load-Regressionen und Windows/Linux-CI ausführen; bisher keine Laufzeitausführung durch den Assistenten.
7. Sichtquellen/Reichweiten sind vorläufig. Sensorgebäude und Forschung bleiben außerhalb dieses Teil-PRs.

## Work-Prüfauftrag
PR #7 auschecken; Godot headless import und komplette Tests ausführen; Fehler beheben; mindestens zwei Fraktionen mit Mauern/Terrain-Sichtblockern, beweglichen Dots, zerstörten Gebäuden und Save/Load visuell testen; prüfen, ob gegnerische Informationen im sichtbaren Client erscheinen; CPU-Zeit und Upload-Kosten bei 128², 512² und 1024² mit wachsenden Dot-Zahlen messen; vor Merge alle Sicherheits- und Performance-Blocker beheben.

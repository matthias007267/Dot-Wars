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
3. Fog-Minimap zeigt Terrainwissen; bekannte Gebäudemarker, eigene Einheiten und Kamerafenster sinnvoll ergänzen. Große Textur-Uploads reduzieren.
4. **Performance:** Unveränderte Fog-Frames und doppelte Sichtquellen werden übersprungen. Bei Sichtwechseln bleiben dichte Arrays, Sichtlinien je unterschiedlicher Quelle und zwei volle Texturuploads bestehen; Dirty-Regionen/Chunks und Profiling sind noch nicht implementiert.
5. Sicherstellen, dass **keine** unbekannten Gegner-/Ressourcen-/Gebäudedaten über Interaktionen, HUD, KI oder späteren Netzwerkverkehr offengelegt werden. Serverautoritatives Sichtfilter-Protokoll separat designen.
6. Godot-Parser, alle Tests, Match-Screenshot, Save/Load-Regressionen und Windows/Linux-CI ausführen. GitHub Actions läuft automatisch; noch keine lokale Godot-Ausführung durch den Assistenten.
7. Sichtquellen/Reichweiten sind vorläufig. Sensorgebäude und Forschung bleiben außerhalb dieses Teil-PRs.

## Work-Prüfauftrag
PR #7 auschecken; Godot headless import und komplette Tests ausführen; Fehler beheben; mindestens zwei Fraktionen mit Mauern/Terrain-Sichtblockern, beweglichen Dots, zerstörten Gebäuden und Save/Load visuell testen; prüfen, ob gegnerische Informationen im sichtbaren Client erscheinen; CPU-Zeit und Upload-Kosten bei 128², 512² und 1024² mit wachsenden Dot-Zahlen messen; vor Merge alle Sicherheits- und Performance-Blocker beheben.

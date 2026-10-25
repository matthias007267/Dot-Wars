# P5 Fog of War – Implementierungsstand (Teil 1)

Stand: Branch `feat/p5-fog-visibility-foundation`. Dieses Paket implementiert **nur den headless Wissenskern** und ist ausdrücklich noch keine abgeschlossene P5-Abnahme.

## Enthalten
- `src/sim/fog_of_war.gd`: getrennte aktuelle Sicht, dauerhafte Erkundung, letzte bekannte Terrainpixel und Gebäude-Snapshots je Fraktion.
- Deterministische Sichtlinien mit Blockade durch solide Terrainpixel und Bauflächen. Das blockierende Zielpixel selbst ist sichtbar.
- Sichtquellen: Arbeiter, Krieger und fertige eigene Produktions-/Abfanggebäude (vorläufige Testreichweiten 7/9/12 Zellen).
- Gemeinsame Sicht über eine explizite Allianzkennung; getrennte Energiekonten bleiben unangetastet.
- Aktualisierung nach Match-Simulationstakten und additive Speicherung in Version-2-Spielständen; ältere V2-Stände ohne Fog-Daten erhalten einen neuen Erkundungszustand.
- Neue Tests für Sichtblockade, Terrain-Gedächtnis, Allianzsicht und Snapshot.

## Nicht enthalten / keine falsche Abnahme
- Welt-, Minimap-, Arbeiter-, Krieger- und Energie-Renderer lesen bislang **weiterhin den echten Weltzustand**. Es gibt deshalb **noch keine sichere visuelle Nebeldarstellung**.
- Auswahl, Zielbefehle, HUD, KI-Ausgaben und Netzwerkschnittstellen sind noch nicht auf einen gefilterten Spielerwissenszustand umgestellt. F01–F04 und W05–W06 sind damit **nicht vollständig erfüllt**.
- Keine fertigen Aufklärungssensoren, keine Bündnisverwaltung in der UI, keine abschließenden Sichtreichweiten.
- Das aktuelle Sichtfeld wird noch über dichte Arrays pro Fraktion berechnet. Vor einer Abnahme auf großen Karten sind Dirty-Regionen, Sparse-Sichtlisten, Aktualisierungsintervalle und Profiling nötig.
- Godot-Tests und Windows-Grafiktests müssen durch CI/Work bestätigt werden; diese GitHub-Codeänderungen wurden nicht lokal ausgeführt.

## Folgearbeiten innerhalb P5
1. Sichtgefilterte, möglichst chunkbasierte Terraintextur und Minimap, einschließlich letzter bekannter Terrainfarben.
2. Sichtgefilterte Dot-/Gebäudedarstellung und Interaktions-/Befehlsvalidierung.
3. Informationsfluss-Audit einschließlich KI/Netzwerkgrenzen.
4. Sichtalgorithmus für große Karten optimieren; Tests/Benchmarks und Save/Load-Regressionen.
5. Danach erst P5 als abgeschlossen markieren.

# Commitvorbereitung des gesammelten Entwicklungsstands

Stand: 25. Oktober 2026. Ausdrücklicher Auftrag zum gemeinsamen Commit und Push nach `origin/main` (D-064).

## Inhalt

Der Hauptprojektstand umfasst die vorbestehende Nutzeränderung in SwarmMind, das 50-Arbeiter-Limit und entfernte Fusion, skalierbare Nahkampfkrieger, native Armee-/Fensterstabilität, Bau und Überleben, manuelle Reparatur/Abbruch/KI-Bauplanung sowie Energieverfall, Abfangstationen und vollständige Transportbilanz. Vorläufige und bestätigte Regeln bleiben in den jeweiligen Phasendokumenten getrennt.

Der lokale Unterordner `dot-wars/` ist ein eigenständiger Checkout. Er wird nicht als Quellcode oder Submodul übernommen. Godot-Caches, native Binärdateien und lokale Diagnoseausgaben bleiben ebenfalls außerhalb des Commits. Die Buildskripte und alle benötigten `.inc`-Quellen sind Bestandteil des Projekts.

## Prüfung des Commitinhalts

Der vorgesehene Git-Index wird in einen neuen, sauberen Prüfexport ohne bestehende `.godot`-Daten und ohne vorherige native Bibliotheken ausgecheckt. Dort werden Windows-Native-Bibliothek, Godot-Import, beide vollständigen Testsuiten und der Start der Hauptszene geprüft. Ein Linux-Cross-Build prüft zusätzlich die Plattformabgrenzung; eine Linux-Laufzeit wird dadurch nicht behauptet. Ergebnisse im sauberen Export des vorgesehenen Commitinhalts:

- Windows-Native-Build aus den vorgemerkten Quellen: erfolgreich; die vorherige lokale DLL wurde nicht verwendet.
- Linux-x86-64-Cross-Build derselben Quellen: erfolgreich. ABI-Funktionszeiger-Castwarnungen des GDExtension-Loaders sind keine Buildfehler; die tatsächliche Linux-Ausführung ist erst durch GitHub Actions abgedeckt.
- Frischer Godot-Import ohne vorherige `.godot`-Daten: erfolgreich, keine Skript-/Parsefehler. Ein Windows-PDB-Pfadkürzungshinweis im langen Diagnosepfad war nicht funktional relevant.
- Native Suite: **290 Tests / 33.900 Prüfungen / 0 Fehler**, 24,58 Sekunden.
- GDScript-Referenzsuite: **290 Tests / 30.606 Prüfungen / 0 Fehler**, 107,13 Sekunden.
- Hauptszene: startet erfolgreich in die Simulation (256×256, Seed 1337, fünf Arbeiter).
- Indexprüfung: alle benötigten Quell-/Include-Dateien vorhanden, kein verschachtelter Gitlink, keine generierten Bibliotheken/Caches/Diagnoseausgaben im Commit. Scan der hinzugefügten/geänderten Dateien ohne Zugangsdatenmuster; `git diff --cached --check` ohne Formatfehler.

Die vier erwarteten Engine-Fehlermeldungen für absichtlich ungültige Konfigurationen/Startwelten sind bestehende Negativtests. In den erfolgreichen Testläufen gibt es keine Skript-/Parsefehler. Das Ergebnis ist eine lokale Quellstandsprüfung; GitHub Actions wird nach dem Push gesondert kontrolliert.


Die CI führt weiterhin Linux-Native-Build, Import, native Suite, GDScript-Referenz und Szenenstart aus. Die vergrößerte Suite erhält begrenzte, längere Timeouts (Import 120 s, native Tests 300 s, Referenz 600 s, Job 20 min). Skript-/Parsefehler werden auch dann erkannt, wenn ein Test vor dem Fehler bereits einzelne erfolgreiche Prüfungen ausgeführt hatte. Absichtliche Negativtests ungültiger Konfigurationen bleiben zulässig.

Aktuelle Phasenmessungen und Grenzen: [UNIT_PROTOTYPE.md](UNIT_PROTOTYPE.md), [STABILITY_VALIDATION.md](STABILITY_VALIDATION.md), [CONSTRUCTION_PHASE.md](CONSTRUCTION_PHASE.md), [MAINTENANCE_PHASE.md](MAINTENANCE_PHASE.md) und [ENERGY_PHASE.md](ENERGY_PHASE.md). Dieser Commit ist kein Steam-/Release-Build und keine neue Freigabe für Welt, Fog of War, Forschungsbaum oder Netzwerk.

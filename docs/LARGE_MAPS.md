# Große Karten: gemessene Optimierung an einer echten Partie, 27. Oktober 2026

D-086. Auftrag des Nutzers nach der Analyse seiner laufenden Partie: „Ja, setze die Optimierungen 1 bis 4 für große Karten um, gemessen an der Kopie meiner Partie, ohne Regeländerung.“ Branch `perf/large-maps`; der Nutzer beauftragt ausdrücklich Commit, Fast-Forward nach `main` und normalen Push, kein Force-Push oder Release.

## Ausgangslage

Die laufende Partie des Nutzers (aus dem Editor gestartet, native v13 geladen) nutzt eine **1000×1000-Karte** mit vier Fraktionen, 40 Arbeitern und rund 20 Kriegern. Gemessen wurde ausschließlich eine Kopie ihres Autosaves (Takt 1.202); die laufende Instanz und der Originalstand wurden nicht verändert.

Die Kosten hingen an der Kartengröße, nicht an der Einheitenzahl: Mehrere Systeme rechneten bei jeder abgebauten Zelle oder in jedem Takt über alle 1 Mio. Zellen. In 197 von 400 Takten veränderte Abbau die Welt.

Neuer dauerhafter Messlauf: `bench/save_profile.gd --save=<Kopie> --ticks=400 [--write-test=<Pfad>]` misst Teilzeiten, schreibt pro Takt den Zustandshash und am Ende den SHA-256 des vollständigen Spielstands. Alt und neu werden damit taktgleich verglichen.

## Änderungen

1. **Energie-Routen schrittweise** (`EnergyStore._update_routed`). Abbau öffnet nur Zellen; Breitensuchdistanzen können dadurch nur kürzer werden. Ab den geöffneten Zellen wird mit dem vorhandenen nativen Verbesserungsmodus von `flow_spread` (GDScript-Schleife als Rückfall) entspannt; das ergibt exakt den vollständigen Neuaufbau. Geschlossene Zellen, andere Empfänger, ein verworfenes Änderungsprotokoll oder ein geladener Stand bauen wie bisher vollständig neu. Der gespeicherte Fortsetzungswert `_dist` bleibt identisch.
2. **Armee-Wegfelder schrittweise** (native v14, `army_cache.inc`). Jedes gecachte Feld führt eine Maske seiner Zielhöhle. Eine geöffnete Zelle entspannt die Zielhöhle, angeschlossene bisher getrennte Höhlen erhalten echte Distanzen, und eine nur unter sich verbundene Höhle berechnet ihre nächsten Standpunkte neu – wie beim Vollaufbau. Ändern sich die Zielstartpunkte, wird eine Zelle geschlossen oder öffnen sich mehr als 64 Zellen, wird wie bisher verworfen. Zusätzlich bleibt die Slot-Belegung über Aufrufe bestehen (statt pro Takt 4 MB anzulegen), Zielzähler werden nur an benutzten Zielen zurückgesetzt und zwei Kartenprüfungen laufen in einem Durchgang.
3. **Kopien pro Takt vermeiden.**
   - Sicht: Gelände wird durch direkten Vergleich mit der zuletzt gesehenen Kopie erkannt statt durch Hashen von 2 MB pro Takt (direkte Schreibzugriffe bleiben erkannt, Test `test_cached_visibility…`). Die Blockerkarte wird nur bei geändertem Gelände oder geänderten Gebäuden neu gebaut. `fog_merge` kopiert ein Wissensarray nur noch, wenn sich darin tatsächlich etwas ändert; ein Merge mit identischen Zellen über unverändertem Gelände entfällt.
   - Blockerkarte der Armee: einmal pro Takt für Bewegung, Spawn und Wachstum (alle drei lesen nur; Krieger bewegen sich erst danach). Die Kriegerwarteschlange baut ihre Maske erst, wenn ein Eintrag fällig ist.
   - Arbeiter-Wegfelder: Ein laufender, über viele Takte budgetierter Aufbau bleibt im nativen Speicher der jeweiligen `FlowField` (`flow_job_*`). Bisher kopierte jeder Teilschritt wegen Copy-on-Write das ganze Feld (5 MB je Gruppe und Takt). Gleiche Ausbreitungsschleife, gleiches Budget; vor dem Speichern synchronisiert `sync_job()` die Arrays.
4. **Autosave im Hintergrund** (`SaveGame.write_file_background`). Im Bildtakt wird nur eine tiefe Kopie des Snapshots angelegt (Packed-Arrays copy-on-write); Serialisierung und Schreiben laufen in einem Worker. Gleiches Dateiformat. Geschrieben wird in eine Temporärdatei, danach umbenannt: Ein Abbruch beschädigt den alten Autosave nicht mehr. Manuelles Speichern bleibt synchron; Laden und Beenden warten auf einen laufenden Schreibvorgang.

## Ergebnisse auf der Partiekopie

Windows 11, Ryzen 9 5950X, Godot 4.3, native v14, headless, 400 Takte ab Takt 1.202, ohne parallele Last.

| | Vorher (v13) | Nachher (v14) |
| --- | --- | --- |
| Ø Takt | **32,44 ms** | **17,60 ms** (−46 %) |
| p95 / Maximum | 65,3 / 101,7 ms | 46,0 / 71,5 ms |
| Arbeiter-Wegfelder | 9,78 | 7,02 |
| Armee | 7,46 | 3,66 |
| Energie | 6,53 | 1,32 |
| Sicht | 5,34 | 2,90 |
| Bewegung | 1,90 | 1,61 |

Autosave im Bildtakt: **~150 ms → 3,6–6,0 ms**; das Schreiben (~150 ms) läuft im Worker, die Datei lädt denselben Zustand. Datei unverändert 127,5 MB; Laden ~8,8 s (unverändert).

Tests: native Suite **413 Tests, 60.927 Prüfungen, 0 Fehler**; Referenzsuite `--no-native` **413 Tests, 34.161 Prüfungen, 0 Fehler**; keine Skript-/Parse-Fehler.

Alle Takthashes, der Endhash und der SHA-256 des vollständigen Spielstands sind nach jeder einzelnen Änderung identisch mit dem Ausgangsstand.

## Grenzen und offene Befunde

- Die Arbeiter-Wegfelder bleiben der größte Posten. Die Vorbereitung lokaler Korrekturen (`_begin_patch`, Abräumen abhängiger Zellen in GDScript) kostet etwa 3,6 ms pro Takt; ein exakter nativer Port muss die Reihenfolge erhalten und ist ein eigener Schritt.
- Die Armee-Präfixsummen werden bei jeder Änderung weiter vollständig neu gebaut; die Eckengraphen werden wie bisher verworfen.
- Wenn in einem Armeeaufruf mehr als acht neue Ziele ein Feld bräuchten, kann ein zwischengespeichertes Feld eine Eckenroute ersetzen, die nach einem Verwerfen gewählt worden wäre. Beides sind kürzeste Wege; in den gemessenen Fällen trat das nicht auf.
- Vorbestehender Befund, nicht geändert: Eine frisch erzeugte Simulation und ihre unmittelbar aus dem Snapshot geladene Kopie verhalten sich im ersten Takt unterschiedlich (96er-Karte, Wegfeld-Budget 64). Die neuen Tests vergleichen deshalb zwei geladene Kopien.
- Laden großer Stände dauert weiter rund 9 s (Validierung je Zelle in GDScript).
- Gespielt aus dem Editor läuft GDScript mit Debugger langsamer; für das Spielgefühl außerhalb des Editors starten.
- Native **v14**: `native/build.ps1` neu bauen, Godot vollständig neu starten.

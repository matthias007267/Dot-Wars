# DOT WARS – Architekturplan (Phase 1)

Engine: Godot 4.3 (GDScript, Renderer `gl_compatibility`), Ziel Windows, später Steam.

## Leitprinzipien

1. **Simulation kennt keine Szene.** Alles unter `src/sim/` besteht aus `RefCounted`-Klassen ohne
   Abhängigkeit zu Nodes, Input oder Rendering. Sie ist headless lauffähig (Tests, Benchmark).
2. **Datenorientiert.** Welt und Arbeiter liegen in flachen Packed-Arrays (Struct-of-Arrays).
   Es gibt keine Nodes pro Zelle oder pro Arbeiter.
3. **Systeme sind zustandslose Funktionen über Daten.** `MovementSystem` und `MiningSystem`
   haben nur `static`-Funktionen mit expliziten Datenargumenten. Dadurch kann ein System später
   1:1 durch eine GDExtension (C++/Rust) mit gleicher Signatur ersetzt werden.
4. **Feste, deterministische Takte.** 20 Hz (`SimConfig.TICKS_PER_SECOND`), Ganzzahl-Arithmetik
   in allen Spielregeln, keine Zufallszahlen und keine Echtzeit in der Simulation. Gleicher Seed +
   gleiche Befehlsfolge ⇒ identischer Zustand (`Simulation.state_hash()`).
5. **Darstellung liest nur.** Renderer und HUD lesen Welt und Statistik; schreibende Eingriffe
   laufen ausschließlich über die API der `Simulation` (`assign_area`, `clear_area`, `set_quotas`).

## Schichten und Module

```
src/
  sim/                       Simulation (headless, deterministisch)
    sim_config.gd            Konfiguration + Validierung (Weltgröße, Seed, Quoten, Tuning)
    materials.gd             Materialtabelle: Härte 1 / 3 / 8, Farben
    world_state.gd           Weltzustand: Zellen, Abbaufortschritt, Chunk-Dirty-Tracking
    world_generator.gd       Reproduzierbare Weltgenerierung + Starttunnel
    worker_store.gd          Arbeiter als Struct-of-Arrays + Zellbelegung
    dig_areas.gd             Abbaugebiete (Rechtecke + Masken) je Gruppe
    flow_field.gd            Gemeinsame Zielsuche (budgetierte Multi-Source-BFS je Gruppe)
    movement_system.gd       Orthogonale Bewegung entlang des Flow-Fields
    mining_system.gd         Zielwahl und Abbaufortschritt
    spawn_system.gd          Entstehung neuer Arbeiter, Platzierung, Warteschlange
    group_quotas.gd          Quotenvalidierung und Gruppenwahl (Defizitverfahren)
    tick_clock.gd            Fester Zeitschritt-Akkumulator mit Pause
    simulation.gd            Orchestrierung, Statistik, Invariantenprüfung
  render/                    Darstellung (nur lesend)
    world_renderer.gd        Chunk-Texturen, Arbeiter-Layer, Raster
    area_overlay.gd          Abbaugebiete und Auswahlrechteck
    camera_controller.gd     Zoom, Verschiebung
  ui/
    hud.gd                   Statistik, Buttons
    selection_controller.gd  Rechteckauswahl mit der Maus
  main.gd                    Verdrahtung, Eingabe, Pause/Neustart
tests/                       Eigener, abhängigkeitsfreier Test-Runner + Tests
bench/benchmark.gd           Headless-Benchmark
```

### Weltzustand

* `cells: PackedByteArray` – ein Byte pro Zelle (0 = leer, 1/2/3 = Material).
* `progress: PackedInt32Array` – Abbaufortschritt je Zelle (Arbeitspunkte).
* Chunk-Einteilung (Standard 32 × 32). Jede Änderung markiert genau einen Chunk als „dirty“
  (Flag-Array + Liste, jeder Chunk höchstens einmal). Der Renderer holt per
  `consume_dirty_chunks()` nur diese Chunks und aktualisiert deren Texturen.
* `revision` zählt Weltänderungen; abgeleitete Strukturen (Flow-Fields) erkennen damit Veralterung.

### Arbeiter

Struct-of-Arrays: `cell`, `group`, `state`, `target`, `last_move_tick` plus
`occupant` (Zelle → Arbeiter-ID, −1 = frei). Eine Zelle fasst höchstens einen Arbeiter.
IDs sind in Phase 1 dicht und stabil (Arbeiter verschwinden nicht). Die spätere Verschmelzung
muss Arbeiter entfernen (Swap-Remove + Umbuchung von `occupant`) – das ist bewusst noch nicht
implementiert.

### Takt (`Simulation.tick_once`)

1. **Zielsuche** – je Gruppe `FlowField.step(budget)`
2. **Bewegung** – `MovementSystem.step`
3. **Abbau** – `MiningSystem.step`
4. **Entstehung** – `SpawnSystem.process`

Innerhalb eines Systems werden Arbeiter in aufsteigender ID-Reihenfolge verarbeitet. Das ist die
einzige „Konfliktauflösung“ und macht jedes Ergebnis deterministisch.

### Gemeinsame Zielsuche (Flow-Field)

Pro Gruppe existiert ein Flow-Field, das **einmal** für alle Arbeiter der Gruppe berechnet wird:

* Quellen: leere Zellen, die orthogonal an markiertes, noch festes Material der Gruppe grenzen
  („Abbauposition“).
* Multi-Source-BFS über leere Zellen liefert je Zelle Distanz und nächste Richtung
  (`PackedInt32Array dist`, `PackedByteArray dir`).
* Die Berechnung ist **in Phasen mit festem Budget** pro Tick zerlegt (Zellbesuche, nicht Zeit ⇒
  deterministisch). Gebaut wird in einen Hintergrundpuffer, nach Abschluss wird getauscht.
  Arbeiter sehen nie ein halbfertiges Feld.
* Ein Feld wird nur neu aufgebaut, wenn sich `World.revision` oder `DigAreas.revision` geändert hat.
* Das Feld ist ein **Hinweis**: Bewegung und Abbau prüfen vor jeder Aktion den aktuellen Weltzustand.
  Ein veraltetes Feld kann also nur zu Verzögerung, nie zu regelwidrigem Verhalten führen.
* Unerreichbare Gebiete: Zellen ohne Verbindung zu einer Quelle behalten `DIR_NONE`; Arbeiter dort
  warten (`STATE_WAITING`). Es wird nie ein Weg „erfunden“.

### Bewegung

* Ein Schritt pro `move_period_ticks` (gestaffelt über `(tick + id) % period`), nur orthogonal,
  nur auf leere, freie Zellen innerhalb der Welt.
* Blockiert ein anderer Arbeiter: (1) Tausch bei frontalem Gegenverkehr, (2) Ausweichen auf eine
  andere Nachbarzelle mit kleinerer Distanz, sonst (3) Warten (`STATE_BLOCKED`).

### Abbau

* Haltbarkeit einer Zelle = `Härte × work_per_hardness`. Jeder abbauende Arbeiter fügt pro Tick
  `dig_power` Fortschritt hinzu (Zusammenarbeit möglich).
* Der Fortschritt liegt an der **Zelle**, nicht am Arbeiter. Abgeschlossen wird eine Zelle
  genau dann, wenn sie noch fest ist und der Fortschritt die Haltbarkeit erreicht. Spätere
  Arbeiter im selben Tick sehen eine leere Zelle und tragen nichts mehr bei ⇒ kein Doppelabbau.

### Entstehung und Massenbilanz

* Jede abgebaute Zelle wird in eine FIFO-Warteschlange gestellt (Entstehungsort = abgebaute Zelle).
* Ist der Ort belegt, wählt eine deterministische BFS (Reihenfolge N, O, S, W) die nächste freie
  Zelle in der zusammenhängenden leeren Fläche (Begrenzung `spawn_search_limit`).
  Findet sich keine, bleibt der Eintrag in der Warteschlange (Head-of-Line, FIFO bleibt erhalten).
* Gruppenwahl: `GroupQuotas.pick_group` – kleinster Quotient `Anzahl / Quote` (= größtes relatives
  Defizit). Gleichstand: größere Quote, danach kleinerer Gruppenindex. Quote 0 wird nie gewählt.
  Reine Ganzzahlarithmetik (Kreuzmultiplikation).
* **Invariante:** `Arbeiter + wartende Entstehungen == Startarbeiter + abgebaute Zellen`.
  `Simulation.check_invariants()` prüft das (plus Belegungskonsistenz) und wird in Tests und
  Benchmark verwendet. Die spätere Verschmelzung muss diese Summe erhalten (Masse wird addiert,
  nicht verworfen).

### Darstellung

* `WorldRenderer` ist ein einzelner `Node2D` und zeichnet per `_draw()` nur sichtbare Chunks
  (ein `ImageTexture` je Chunk, nur bei Änderung aktualisiert).
* Arbeiter werden in eine weltgroße RGBA-Textur (1 Pixel = 1 Zelle) geschrieben, nur wenn ein neuer
  Takt vorliegt. Kosten wachsen mit Weltfläche, nicht mit Zoom.
* Raster: Linien ab ausreichendem Zoom, nur im sichtbaren Bereich, ein Draw-Call.
* Kamera: Mausrad-Zoom zum Cursor, Verschieben mit rechter/mittlerer Maustaste oder WASD/Pfeile.

## Vorbereitete, aber noch nicht implementierte Module

Folgende Module sind **nicht Teil von Phase 1** und existieren bewusst nicht als Platzhalterdateien.
Die Schnittstellen dafür sind vorbereitet:

| Modul | Anknüpfungspunkt |
|---|---|
| Verschmelzung | `WorkerStore` (Swap-Remove), Massenbilanz in `check_invariants`, Gruppenzähler |
| Opferloch | `SpawnSystem`/`DigAreas`-Muster: eigenes System mit Daten + `step` in `Simulation.tick_once` |
| Upgrades | `SimConfig` (`dig_power`, `move_period_ticks`) als zentrale Parameter |
| Speicherstände | Zustand liegt vollständig in Packed-Arrays + Ganzzahlen; `state_hash()` listet bereits alle relevanten Felder |
| GDExtension | `MovementSystem`, `MiningSystem`, `FlowField` haben datenorientierte Signaturen |

## Implementierungsschritte (Phase 1)

1. [x] Repository prüfen (leer) und Projektgerüst anlegen (`project.godot`, Szene, `.gitignore`)
2. [x] Architekturplan (dieses Dokument)
3. [x] `SimConfig`, `Materials`, `WorldState` (Dirty-Chunks)
4. [x] `WorldGenerator` (Seed, drei Materialien, Starttunnel)
5. [x] `WorkerStore`, `GroupQuotas`, `DigAreas`
6. [x] `FlowField` (budgetierte, gemeinsame Zielsuche)
7. [x] `MovementSystem`, `MiningSystem`, `SpawnSystem`
8. [x] `Simulation`, `TickClock` (20 Hz, Pause, Neustart)
9. [x] Rendering: Chunk-Texturen, Arbeiter-Layer, Raster, Kamera
10. [x] UI: Rechteckauswahl, Gruppenzuweisung, HUD, Pause/Neustart
11. [x] Tests + eigener Test-Runner
12. [x] Headless-Benchmark (1.000 / 10.000 Arbeiter)
13. [x] GitHub Actions (Tests + Benchmark-Smoke)
14. [x] Dokumentation der Ergebnisse (`docs/benchmarks.md`) und Pull Request

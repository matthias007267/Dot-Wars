# Messungen

Zielwerte aus der Spezifikation sind Vorgaben, keine bereits bestandenen Nachweise. Diese Seite enthält nur Läufe, die auf dieser Maschine ausgeführt wurden.

Rendering-FPS sind nicht gemessen. Es gibt noch keinen Welt-Renderer. Die Hauptszene zeichnet nur Text.

## Headless-Benchmark vom 22. Oktober 2026

Befehl:

```bash
godot --headless --path . -s bench/benchmark.gd -- --workers=1000,10000 --ticks=200
```

Umgebung:

* Godot 4.3-stable
* CPU laut Engine: Intel Xeon, 4 Threads
* Welt 256 × 256, Seed 1337, Bewegungsperiode 2 Takte
* 200 gemessene Takte, kein Warmup
* Abbauzeit nach Entscheidung D-001: Härte 1 dauert eine Sekunde

Die Maschine ist die Entwicklungsumgebung dieses Laufs, nicht ein Ziel-Windows-PC. 200 Takte sind 10 Simulationssekunden. In dieser kurzen Spanne bleibt der Schwarm dicht, und die meisten Arbeiter sind blockiert. Der Lauf belegt die Taktkosten, nicht eine ausgewachsene Partie.

| Arbeiter am Start | Ø Tick | p95 | Maximum | nachhaltig | Zielsuche Ø | Bewegung Ø | Abbau Ø | Entstehung Ø |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1.000 | 3,97 ms | 5,25 ms | 5,55 ms | 252 Takte/s | 2,46 ms | 1,49 ms | 0,03 ms | 0,00 ms |
| 10.000 | 15,92 ms | 19,54 ms | 24,58 ms | 63 Takte/s | 2,61 ms | 13,13 ms | 0,17 ms | 0,01 ms |

Kein Takt lag über 50 ms. 20 Simulationstakte pro Sekunde wären auf dieser Hardware rechnerisch möglich, weil ein Takt dafür bis zu 50 ms dauern darf. Das engere Ziel von höchstens 10 ms im Durchschnitt ist bei 10.000 Arbeitern nicht erreicht.

Eine vollständige Neuberechnung eines Flow-Fields dauerte im Median 27 ms bei 1.000 Arbeitern und 37 ms bei 10.000. Im Takt selbst ist die Zielsuche auf ein Budget begrenzt und kostet etwa 2,6 ms. Der Neuaufbau betrifft trotzdem die ganze erreichbare Fläche, nicht nur die geänderte Stelle.

Speicher nach dem Aufbau der 10.000-Arbeiter-Simulation: etwa 19 MB statisch in Godot, 88 MB RSS. Die Vorgabe unter 1 GB ist in diesem Kurzlauf eingehalten. Ein Langzeittest fehlt.

Am Ende des 10.000er-Laufs: 10.178 Arbeiter, 178 abgebaute Zellen, 81 wartend, 179 in Bewegung, 54 am Abbauen, 9.864 blockiert. Die Invariantenprüfung war in beiden Läufen ohne Fehler. Weltgenerierung etwa 138 ms, Anlegen der Simulation 14 ms.

## Einordnung

Der Engpass ist die Bewegung, nicht der Abbau. Fast alle Arbeiter stehen sich im engen Startbereich im Weg. Jeder fällige Arbeiter wird trotzdem geprüft.

Mögliche spätere Hebel, ohne die Spielregeln zu ändern:

* Blockierte Arbeiter seltener anfassen.
* Das Flow-Field nur in der betroffenen Region neu berechnen.
* Die Bewegungsschleife in eine GDExtension verlegen, wenn das Profiling das nach den strukturellen Änderungen noch zeigt.

Diese Hebel gehören nicht zu Phase 1 und sind hier nicht umgesetzt.


## Darstellung vom 22. Oktober 2026

Dieselbe Maschine, Godot 4.3, OpenGL über llvmpipe (Mesa 25.2). Kein dedizierter Grafikchip. VSync wurde abgeschaltet, der Treiber meldet dabei einen Fehler und fällt nicht sichtbar aus. Gemessen wurden 120 Frames nach 30 Frames Warmup. Die Ansicht ist statisch: keine Arbeiter, eine Textur.

| Welt | Fenster | Erzeugung | FPS |
|---:|---|---:|---:|
| 256 × 256 | 1920 × 1080 | 143 ms | 65,1 |
| 500 × 500 | 1920 × 1080 | 563 ms | 67,9 |
| 1.000 × 1.000 | 1920 × 1080 | 2.144 ms | 63,7 |
| 500 × 500 | 1280 × 720 | — | 133,0 |

60 FPS bei 1080p sind auf dieser Maschine für die statische Welt erreicht. Der Wert liegt knapp über 60. Ob der Treiber die Rate noch dämpft, ist nicht getrennt gemessen. Sobald Arbeiter gezeichnet werden, gilt diese Zahl nicht mehr.

Die Erzeugung von 1.000 × 1.000 dauert etwa 2,1 Sekunden. Der Kopf des Laufs bleibt unter 100 MB RSS, wie im Simulationsbenchmark.

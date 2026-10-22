# Messungen

Zielwerte aus der Spezifikation sind Vorgaben, keine bereits bestandenen Nachweise. Diese Seite enthält nur Läufe, die auf dieser Maschine ausgeführt wurden.

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

## Simulation vom 22. Oktober 2026, mit Laufziel im Flow-Field

Derselbe Befehl und dieselbe Maschine wie im ersten Headless-Lauf. Der Benchmark weist weiterhin Abbaugebiete zu. Neu ist nur die Prüfung, ob sich das Laufziel geändert hat. Die Ansicht selbst vergibt kein Abbaugebiet; dieser Lauf misst die Simulation, nicht das Fenster.

| Arbeiter am Start | Ø Tick | p95 | Maximum | nachhaltig | Zielsuche Ø | Bewegung Ø | Abbau Ø | Entstehung Ø |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1.000 | 4,23 ms | 5,43 ms | 5,57 ms | 236 Takte/s | 2,72 ms | 1,48 ms | 0,03 ms | 0,00 ms |
| 10.000 | 16,09 ms | 19,60 ms | 21,19 ms | 62 Takte/s | 2,73 ms | 13,17 ms | 0,18 ms | 0,00 ms |

Kein Takt lag über 50 ms. Das Ziel von höchstens 10 ms im Durchschnitt ist bei 10.000 Arbeitern weiterhin nicht erreicht.

Eine vollständige Neuberechnung eines Flow-Fields dauerte im Median 30,6 ms bei 1.000 Arbeitern und 39,6 ms bei 10.000. Im Takt bleibt die Zielsuche budgetiert und kostet etwa 2,7 ms.

Speicher nach dem Aufbau der 10.000-Arbeiter-Simulation: etwa 18,7 MB statisch in Godot, 88 MB RSS. Am Ende: 10.178 Arbeiter, 178 abgebaute Zellen, 81 wartend, 179 in Bewegung, 54 am Abbauen, 9.864 blockiert. Die Invariantenprüfung war in beiden Läufen ohne Fehler. Weltgenerierung 138 ms, Anlegen der Simulation 14 ms.

## Darstellung mit Arbeitern vom 22. Oktober 2026

Dieselbe Maschine und dasselbe Fensterverfahren wie bei der statischen Welt. Fünf Arbeiter, die Simulation läuft, kein gesetztes Laufziel, die Arbeiter bleiben auf dem Tunnel. Die Arbeitertextur wird bei jedem neuen Takt für die ganze Welt neu gefüllt. 120 Frames nach 30 Frames Warmup. VSync lässt sich auf diesem Treiber nicht abschalten.

| Welt | Fenster | Erzeugung | FPS |
|---:|---|---:|---:|
| 256 × 256 | 1920 × 1080 | 139 ms | 51,5 |
| 500 × 500 | 1920 × 1080 | 533 ms | 50,3 |
| 1.000 × 1.000 | 1920 × 1080 | 2.214 ms | 59,1 |
| 500 × 500 | 1280 × 720 | 532 ms | 110,7 |

60 FPS bei 1080p sind auf dieser Maschine nicht mehr erreicht, sobald die Simulation läuft. Die statische Welt lag bei 64 bis 68 FPS. Bei 1280 × 720 bleiben 110 FPS. Die Arbeitertextur wurde in diesem Lauf je neuem Takt vollständig geleert. Der folgende Lauf ändert das.

## Nach den Phasen 4 bis 10, 22. Oktober 2026

Dieselbe Maschine. Die Arbeitertextur löscht und zeichnet nur noch die belegten Zellen. Fünf Arbeiter, Simulation läuft, HUD ist sichtbar. 120 Frames nach 30 Frames Warmup, Fenster 1920 × 1080, Welt 256.

| Welt | Fenster | FPS |
|---:|---|---:|
| 256 × 256 | 1920 × 1080 | 70,3 |

60 FPS bei 1080p sind in diesem kurzen Lauf mit fünf Arbeitern erreicht. Das gilt nicht für einen großen Schwarm und nicht für die 1.000er-Welt; die wurde hier nicht erneut im Fenster gemessen.

Headless, 200 Takte, Welt 256:

| Arbeiter am Start | Ø Tick | p95 | Maximum | nachhaltig | Zielsuche Ø | Bewegung Ø | Abbau Ø | Entstehung Ø |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1.000 | 4,45 ms | 5,59 ms | 5,71 ms | 225 Takte/s | 2,71 ms | 1,53 ms | 0,04 ms | 0,17 ms |
| 10.000 | 18,07 ms | 21,72 ms | 22,72 ms | 55 Takte/s | 2,76 ms | 13,50 ms | 0,19 ms | 1,62 ms |

Kein Takt über 50 ms. Das 10-ms-Ziel bei 10.000 Arbeitern ist nicht erreicht. Der Engpass bleibt die Bewegung, vor allem blockierte Arbeiter. Daran wurde nichts geändert, weil eine seltenere Prüfung Blockierter die Kollisionsregeln verändern könnte und nicht gemessen als korrekt belegt ist.

Stresstest, 40 Takte, 50.000 Arbeiter, Welt 256: Ø 87,4 ms, p95 91,0 ms, Maximum 97,0 ms, alle 40 Takte über 50 ms. Bewegung 77,6 ms. Am Ende 50.061 Einheiten, Invarianten ohne Fehler, RSS 94 MB. 50.000 Einheiten laufen, aber nicht mit 20 Takten pro Sekunde.

Welt 1.000 × 1.000, 1.000 Arbeiter, 20 Takte: Ø 1,36 ms, weil in diesem kurzen Fenster kein Tunnel entstand und die Zielsuche ihr Budget kaum anrührte. Eine vollständige Feldberechnung dauerte 458 ms. Erzeugung der Welt 2,2 s, statischer Speicher am Ende 56 MB, RSS 126 MB. Invarianten ohne Fehler. Abgebaut wurde in den 20 Takten nichts, weil der Benchmark auf dieser Größe das Gebiet nicht rechtzeitig in Reichweite hatte. Der Lauf belegt das Anlegen und die leeren Takte, nicht eine wachsende Million-Zellen-Partie.

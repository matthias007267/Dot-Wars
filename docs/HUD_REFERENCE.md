# HUD nach der markierten Referenz

Auftrag vom 27. Oktober 2026, D-078: Aus dem vom Nutzer beschrifteten RTS-Bild werden **ausschließlich die HUD-Vorschläge** übernommen. Landschaft, Grafikstil, Ressourcen, Gebäude, Einheiten, Kampfsystem und Wirtschaft dieser Bildvorlage gehören nicht zum Auftrag. Umsetzung auf `feat/ore-veins-world` als Ergänzung des offenen PR #13; kein automatischer Merge.

## Anordnung und Bedienung

| Bereich | Inhalt |
|---|---|
| Oben links | Verfügbare gesammelte Energie, Arbeiter im Feld, Krieger im Feld. Tooltips trennen Transportenergie und bezahlte Warteschlangen vom aktuellen Bestand. |
| Darunter | Eigene laufende Forschung, Bau, Abriss und Produktion als Icons mit Fortschrittslinie und bei Bedarf Anzahl. Ein Klick wählt den Standort und zentriert die Kamera. |
| Oben rechts | Menü/Einstellungen, Aufträge, Ziele, Forschungsübersicht, Pause und Spieltempo. Escape sowie Speichern/Laden bleiben erhalten. |
| Unten links | Aktionen, die zur gewählten eigenen Einheit oder zum gewählten eigenen Gebäude passen. |
| Daneben | Auswahl/Standort, laufende Produktion und ein Infofeld für die Erklärung der überfahrenen bzw. fokussierten Aktion. Hinweise zu Befehlen und Fehlern bleiben separat lesbar. |
| Unten rechts | Minimap mit bisheriger Navigation und darüber eigene bzw. verbündete Spieler mit ihren bestehenden Zielständen. |

Fertige Kerne und Außenposten zeigen Arbeiter-/Kriegerproduktion. Arbeiter zeigen Bauaktionen, Leitung und Abriss. Fertige Forschungszentren zeigen den Forschungsbaum; eigene unfertige Gebäude den Bauabbruch. Reparatur erscheint bei beschädigtem Gebäude und mitgewählten Arbeitern. Krieger behalten die bestehenden Mausbefehle; sie erhalten keine erfundenen Bau-/Produktionsaktionen. Beim Auswählen neuer Einheiten wird der alte Gebäude-Kontext verlassen. Beim Auswählen eines Gebäudes bleiben zuvor gewählte Arbeiter für Bau und Reparatur erhalten und werden als mitgewählte Einheiten ausgewiesen.

Maus-Hover und Tastaturfokus erklären eine Aktion im Infofeld. Die Erklärung verwendet dieselben aktuellen Angaben wie der Button, einschließlich Kosten und Voraussetzungen. Nach Kontextwechsel bleibt kein Hinweis auf eine ausgeblendete Aktion stehen. E/Q für Leitung und Abriss sowie die bisherigen Auswahl-, Marsch-, Kampf- und Abbaumarkierungen funktionieren weiter.

„Aufträge“ öffnet eine scrollbare Gesamtübersicht der eigenen laufenden Arbeit. „Ziele“ zeigt die bisherigen aktivierten Siegziele. „Technik“ erlaubt die Forschungsübersicht; zum tatsächlichen Start einer Forschung ist weiterhin ein geeignetes eigenes Zentrum erforderlich. Menüpunkte rufen die vorhandenen Spielaktionen auf; es werden keine neuen Kauf- oder Forschungsregeln eingeführt.

## Daten, Sichtschutz und Kosten

`HudOverview` bereitet ausschließlich vorhandene Zustände auf: eigene Forschungsaufträge, eigene Baustellen und Abrisse, bezahlte Arbeiter, eigene Kriegerwarteschlangen und bestehende Team-Zielstände. Produzierte Einheiten werden je Standort und Art gezählt, nicht in der Simulation zusammengelegt. Es gibt keine zweite Auftrags- oder Produktionslogik. Fortschritt und Zählwerte stammen aus der Simulation; vorbereitete Arbeiter warten auf einen freien Entstehungsplatz. Forschung mit bereits vollständig verbrauchter Energie wird nicht fälschlich als wartend dargestellt, wenn nur noch Forschungsdauer übrig ist.

Die obere Reihe zeigt höchstens zehn Positionen; die letzte öffnet bei Bedarf weitere Aufträge. Die lokale Produktionsreihe zeigt bis zu vier Positionen. Weitere Gruppen öffnen über die letzte Position die vollständige Übersicht. `HudTaskIcon` zeichnet Icon, Fortschrittslinie und optionalen Zahlenbadge. Bestehende Icons werden aktualisiert; die Auftragsliste baut ihre Buttons nur bei veränderten Auftragsgruppen neu auf, damit fortlaufender Fortschritt nicht den Fokus entfernt. Es entstehen keine Nodes pro wartender Einheit.

Der Energie-Hauptzähler zeigt ausschließlich das ausgebbare Konto. Der Tooltip nennt nur eigene Transportenergie; globale Energiebilanzen anderer Spieler werden nicht mehr im normalen HUD ausgelesen. Die Teamübersicht verwendet die vorhandenen Bündnisse und nur die aktivierten Zielgrößen: **F** = Siegforschungsstufe, **R** = gehaltene Relikte, **H** = Hügelfortschritt. Ohne entsprechende Ziele erscheint freies Spiel bzw. Überleben. Es wird keine neue Gesamtpunktzahl berechnet. Feindliche Forschungs-/Produktionsaufträge und nicht verbündete Teamzeilen werden nicht angezeigt. Minimap und Forschung behalten ihre bisherigen Sicht- und Wissensgrenzen.

Eigene platzierte Baupläne sind auswählbar, auch wenn seit dem Platzieren noch kein Sichttakt lief: Der Spieler kennt seine eigene Platzierung bereits. Fremde Standorte passieren weiterhin die Sichtprüfung. Dies erhält insbesondere den bestehenden Bauabbruch mit korrekter Erstattung. Es entsteht keine zusätzliche Sicht auf das Gelände.

## Prüfung

`tests/test_hud_reference.gd` prüft eigene gegenüber gegnerischen Aufträgen, gruppierte Produktionsanzahlen, verbündete Zielstände, passende Auswahlaktionen, aktuelle Hoverinformationen, eigene Pläne vor dem nächsten Sichttakt, verborgene Gegnergebäude, Energie-/Einheitenzähler und unveränderte Simulationszustände. Bestehende HUD-, Bau-, Wartungs-, Forschungs- und Sichttests bleiben erhalten.

`bench/hud_reference_check.gd` öffnet die echte Hauptszene mit markierten Diagnoseaufbauten und echten Forschungs-/Kaufwarteschlangen. Der Check prüft reine Icon-Aufträge, Arbeiter-/Kern-/Forschungszentrum-Kontexte, Hover-Erklärungen, Auftragsliste, eigene/verbündete Teamzeilen, unveränderten Simulationshash und überlappungsfreie Panels bei 1280×720. Die normale Nebeldarstellung bleibt aktiv; es wird kein regulärer Spielstand geschrieben. Die vorhandene Cavern-Grafikprüfung prüft die mitgewählten Einheiten nun im passenden Standort-Infofeld statt im alten Einheiten-Header.

```sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . -s bench/hud_reference_check.gd
```

Der grafische Check erzeugt `/tmp/hud-workers.png`, `/tmp/hud-hover.png`, `/tmp/hud-core.png`, `/tmp/hud-research.png`, `/tmp/hud-orders.png` und `/tmp/hud-compact.png`. CI veröffentlicht die Bilder samt Log als `hud-reference-check` und führt weiterhin die sechs bisherigen Grafikchecks aus. Das tatsächliche CI-Ergebnis und der geprüfte Commit werden im PR festgehalten. Die lokale Prüfung verwendet Linux, Godot 4.3 und Software-OpenGL; eine neue Windows- oder Langpartie-Abnahme folgt daraus nicht.

Lokaler Abschlussstand unter Linux/Godot 4.3: **367 Tests / 54.852 Prüfungen / 0 Fehler** nativ und **367 Tests / 33.345 Prüfungen / 0 Fehler** als GDScript-Referenz. Alle sieben Grafikchecks melden `0 failures`; Hauptszene und Import erfolgreich, Abschlusslogs ohne Skript-, Parse- oder Shaderfehler. Der bestehende Wartungs-/Bauabbruchtest bleibt unverändert und besteht wieder.

# Gebäudelicht und Vier-Felder-Nebel

Auftrag vom 27. Oktober 2026, D-079. Der Nutzer verlangt eigene Gebäudelichtquellen, helleren erkundeten Nebel und Sicht, die an Gebäuden/Ressourcen nicht schon am ersten Block endet, sondern vier Felder tief reicht. Umsetzung auf `feat/ore-veins-world` im offenen PR #13; kein automatischer Merge.

## Sichtgrenze

Die erste solide Rasterzelle außerhalb des eigenen Quellgebäudes zählt als Feld 1. Felder 1–4 sind innerhalb der normalen Sichtweite sichtbar, Feld 5 ist außerhalb der aktuellen Sicht. Nach der ersten Barriere zählen auch freie Lücken weiter; eine dünne Wand eröffnet keinen unbeschränkten Blick in einen dahinterliegenden Tunnel. Die Zählung folgt den ganzzahligen Bresenham-Schritten, einschließlich diagonaler Schritte. Gestein, sämtliche Erze, Obsidian und Gebäude verwenden dieselbe Begrenzung. Begehbarkeit, Abbaubarkeit und Rohstoffe ändern sich dadurch nicht.

Die vorläufigen Radien bleiben 7 für Arbeiter, 9 für Krieger und 12 ab Gebäudezentrum. Ein Gebäude ignoriert beim Ausstrahlen ausschließlich seine eigene rechteckige Grundfläche. Das Fundament eines anderen, auch benachbarten Gebäudes ist weiterhin eine Barriere. Damit wird die bisher im eigenen Fundament abgeschnittene Quelle wirksam, ohne ihren Radius zu erhöhen.

Fertige Gebäude und tatsächlich begonnene Baustellen liefern eigene Sicht. Ein bloßer unbegonnener Bauplan ist keine kostenlose Aufklärungsquelle. Zerstörung entfernt die Quelle; bereits erkundetes Wissen bleibt gespeichert. Bündnisse teilen weiterhin die aktuelle Sicht und Erkundung. Die neue Regel gilt symmetrisch für alle Fraktionen.

Auch Dots verwenden die neue Sichtgrenze. Außerhalb davon verschwinden sie weiterhin sofort, einschließlich Halo und Minimapmarker. Innerhalb der vier Felder ist die Sicht tatsächlich vorhanden, nicht nur ein optischer Umriss über unverändert gesperrten Sichtdaten. Feindliche Gebäude außerhalb der Sicht bleiben im letzten bekannten Zustand, verborgene Geländeänderungen aktualisieren das Spielerwissen nicht.

## Helligkeit und Lichtquellen

`FogOverlay.MEMORY_SHADE` steigt von 0,38 auf **0,55**. Das macht bereits erkundetes, aktuell nicht sichtbares Gelände heller. Die Darstellung verwendet weiterhin ausschließlich gespeichertes Terrain und gespeicherte Gebäude. Unbekanntes Gebiet wird mit RGB **0/0/0** schwarz gezeichnet; die höhere Erinnerungshelligkeit hebt diesen Schwarzbereich nicht an. Bereits früher erkundete Felder hinter der neuen Sichtgrenze bleiben als Erinnerung erhalten, statt das Wissen wieder zu löschen.

Jedes fertige bzw. begonnene Gebäude ist eine mögliche Grundlichtquelle, auch ein gerade nicht versorgtes Forschungszentrum. Hauptkerne behalten Stärke 0,95 bei Licht-Radius 9; andere fertige Gebäude nutzen 0,55 bei Radius 5, begonnene Baustellen 0,25. Ein tatsächlich verbrauchender Forschungsauftrag verstärkt sein Licht auf 0,95. Ohne neue Lieferung bleibt das Grundlicht bestehen, nicht die Aktivitätsverstärkung. Licht erzeugt oder verbraucht keine Simulationsenergie.

Die vorhandene niedrige Lichtkartenauflösung, Aktualisierung alle 0,2 Sekunden und Begrenzung auf 64 visuelle Quellen bleiben erhalten; die eigentliche Gebäude-Sicht hat diese Begrenzung nicht. Sichtbare fremde Quellen sind weiterhin an tatsächlichen Sichtkontakt mit ihrem Gebäude gebunden. Es gibt keine Licht-Node pro Gebäude oder Einheit.

## Native Referenz und Speicherung

Die GDScript-Referenz und der native Rechenkern verwenden exakt dieselbe Vier-Felder-Regel. `fog_visible_depth(blockers, source_records, factions, width)` verarbeitet pro Quelle sieben Ganzzahlen: Besitzer, Ursprungszelle, Radius, eigene Grundfläche x/y/Breite/Höhe. Einheiten haben eine leere Grundfläche. Die native Validierung prüft Kartengrenzen, Radius, Eingabeform und dass eine positive Grundfläche ihre Quelle enthält. Es ist nicht möglich, eine entfernte fremde Grundfläche als Ausnahme einzutragen.

Der native Pfad behält seine gebündelte Sichtunion mit frühzeitigem Überspringen bereits sichtbarer Ziele. Die Referenz behält ihren lokalen Cache; neben exakten Blockerbytes wird jetzt auch die Grundflächen-Ausnahme verglichen. Bauen, Abriss, Rohstoffabbau und ein geänderter Quelltyp können dadurch keine veraltete Sicht aus dem Cache übernehmen. Ein alter Kern ohne die neue Methode verwendet die GDScript-Referenz für Sicht.

Windows-Build, Descriptor und GDScript-Ladepfad wechseln gemeinsam auf **v11**. Neu bauen und das Spiel vollständig neu starten; laufende v10-Prozesse laden den neuen Kern nicht nach. Der Linux-Kern wurde gebaut und ausgeführt. Ein Windows-v11-Lauf und eine neue große Langpartie wurden hier nicht geprüft.

Das Speicherformat bleibt Version 2. Gespeichertes Spielerwissen und bestehende Felder bleiben erhalten. Nach dem Laden wird die Sicht bei der nächsten normalen Aktualisierung nach der neuen Regel berechnet; es wird keine ganze Karte aufgedeckt und keine unbekannte Vergangenheit erfunden.

## Nachweise

Die Tests prüfen vier gegen fünf Felder in mehreren Richtungen und Materialtypen, freie Lücken hinter einer dünnen Wand, Ausschluss nur des eigenen Fundaments, Cachewechsel zwischen Einheits- und Gebäudequelle, Bauzustände, unabhängiges Licht/Sicht eines entfernten Forschungszentrums, Quellenverlust bei Zerstörung und erhaltenes Erinnerungswissen. Native und Referenz vergleichen zufällige Karten, überlappende Quellen, Randzellen und sämtliche Fraktionsdaten über mehrere Simulationstakte. Native ungültige Grundflächen werden verworfen.

Die bisherigen Tests für sofortige Blockierung wurden auf die ausdrücklich neue Grenze angepasst. Der Gebäudelichttest prüft jetzt dauerhaftes Grundlicht und eine weiterhin nur durch echten Verbrauch ausgelöste Verstärkung. Seine unbekannte Gegner-Fiktur liegt auf einer 64er-Karte, damit der Gegner auch mit wirksamer Gebäudesicht außerhalb der Reichweite bleibt. Die Sichtschutz-, Speicher-, Bau-, Wartungs- und Forschungsregressionen bleiben erhalten.

`bench/fog_depth_check.gd` verwendet die echte Hauptszene: ein eigenes inaktives Zentrum, vier sichtbare Blockschichten, eine versteckte freie fünfte Zelle mit gegnerischem Dot und durch tatsächliche Erkundung entstandenes Terrain-Gedächtnis. Er prüft gerenderte Pixel für die Sichtgrenze und vergleicht die frühere Erinnerungshelligkeit 0,38 mit 0,55 bei identischer Szene. Der Simulationshash bleibt beim Zeichnen unverändert. Die markierte Diagnosefixture schreibt keinen regulären Spielstand und verwendet keine globale Kartenaufdeckung.

```sh
bash native/build.sh
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . -s bench/fog_depth_check.gd
```

CI führt zusätzlich zu beiden Testsuiten und dem Hauptszenenstart jetzt acht Grafikchecks aus. Der Artifact `fog-depth-check` enthält `/tmp/fog-four-cells.png`, `/tmp/fog-memory-before.png`, `/tmp/fog-memory-after.png` und das Prüfprotokoll. Das tatsächliche CI-Ergebnis und der geprüfte Commit werden im PR dokumentiert.

Lokaler Abschluss unter Linux/Godot 4.3: **371 Tests / 59.226 Prüfungen / 0 Fehler** nativ, **371 Tests / 33.470 Prüfungen / 0 Fehler** als GDScript-Referenz. Alle acht Grafikchecks melden `0 failures`; Hauptszene und Import erfolgreich, Abschlusslogs ohne Skript-, Parse- oder Shaderfehler. Die größere native Prüfungszahl entsteht insbesondere durch die größere sichtbare Vereinigung der zufälligen Vergleichskarten.

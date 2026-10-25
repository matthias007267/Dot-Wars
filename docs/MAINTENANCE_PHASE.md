# Reparatur, Baustellenabbruch und KI-Bauplanung

Nachfolgender Auftrag: P4 Energie wurde später ausdrücklich als Punkte 1–3 beauftragt und lokal integriert. [ENERGY_PHASE.md](ENERGY_PHASE.md) ist der aktuelle Stand für Abfangstationen, Verfall und Energiebilanz. Die folgenden Abgrenzungen beschreiben die ursprüngliche Reparatur-/KI-Phase.

Stand: 25. Oktober 2026, Folgeauftrag „Dann arbeite Punkte 1–3 ab“ zur direkt vorher genannten Liste: manuelle Reparaturen, Baustellenabbruch und KI-Bauplanung. Diese Phase ergänzt die zuvor abgeschlossene [Bauphase](CONSTRUCTION_PHASE.md); sie ist kein Auftrag für Forschung, Energieraub, neue Welt oder Netzwerk.

## Verbindlicher Umfang und vorläufige Ausführung

Verbindlich aus dem Konzept: Reparaturen benötigen manuell zugewiesene Arbeiter und verbrauchen Energie. Der Folgeauftrag gibt außerdem den Baustellenabbruch und die KI-Bauplanung frei. Die bestätigten Bauwerte und die Überlebensregeln aus D-059 bleiben erhalten.

Die folgenden Reparaturwerte und Erstattungsregeln sind mit der nachgereichten Antwort „Diese Testregeln verwenden“ **ausdrücklich bestätigte vorläufige Testregeln** (D-061). Sie entsprechen bereits der geprüften Umsetzung; endgültiges Balancing bleibt offen. Die weiter unten beschriebene KI-Ausbaupolitik bleibt eine gesonderte vorläufige Implementierungsannahme:

- Je zugewiesenem Arbeiter alle vier Simulationstakte bis zu zwei HP Reparatur für eine Energie. Bei 20 Takten/s sind das bei freiem Arbeitsplatz zehn HP/s. Auch der letzte Beitrag von nur einem fehlenden HP kostet eine Energie; bei voller Gesundheit wird nichts mehr abgebucht.
- Mehrere Arbeiter reparieren gemeinsam. Ohne Energie wartet der Auftrag am Gebäude, ohne Schaden zu heilen oder Schulden zu erzeugen. Ein neuer Befehl oder die Fertigstellung beendet ihn. Ein Angriff löst keine Flucht oder automatische Arbeitsunterbrechung aus; der Tod entfernt den Arbeiter regulär.
- Reparierbar sind die vorhandenen fertigen eigenen Hauptkerne und Außenposten. Unfertige Baustellen werden in dieser Phase nicht repariert. Keine automatische Reparaturzuweisung, auch nicht durch die KI.
- Unbegonnene und unbeschädigte Baustelle: beim manuellen Abbruch den tatsächlich gezahlten Baupreis vollständig zurückgeben. Nach dem ersten Beitrag oder erlittenem Schaden gibt es keine Erstattung. Fertige Gebäude werden mit diesem Befehl nicht abgerissen. Keine Erstattung bereits verlorener Einheitenwarteschlangen.
- Der Abbruch entfernt den Bauplatz sofort, gibt Boden und zugewiesene Arbeiter frei und senkt die aktuelle Außenpostenanzahl. Wird der letzte schützende begonnene Kern abgebrochen, folgt nach der nächsten regulären Schutzprüfung die Niederlage; der bestehende Schutz wird nicht still verlängert.

## Bedienung

Eigene Arbeiter auswählen und anschließend ein beschädigtes eigenes fertiges Gebäude anklicken. „REPARIEREN“ weist die ausgewählten Arbeiter zu. Alternativ führt ein Rechtsklick der ausgewählten Arbeiter auf ein beschädigtes fertiges eigenes Gebäude denselben manuellen Auftrag aus. Bei unfertigen Baustellen bleibt der Rechtsklick ein Bauauftrag.

Eine eigene Baustelle anklicken: „ABBRUCH +…“ zeigt die aktuelle Rückzahlung und führt den Abbruch aus. Der Tooltip erläutert Erstattung und den möglichen Verlust des letzten Schutzes. Fertige und fremde Gebäude sind dafür gesperrt. Die Anzeige des Standorts zeigt weiterhin HP bzw. Baufortschritt.

Außenposten bleiben im normalen Spiel für Spieler **und KI** gesperrt. Escape → Testlabor → „Außenposten freischalten (Test)“ gilt für den laufenden Test. Es ist weiterhin keine reguläre Forschung und sperrt reguläre Saves des veränderten Testlaufs.

## KI-Verhalten

Die Planung läuft ausschließlich für echte KI-Fraktionen; menschliche und als remote markierte Spieler bleiben unangetastet. Sie benutzt dieselbe Platzierungsprüfung, Baupreise, Reservierung und tatsächlichen Arbeiterbeiträge. Sie räumt keinen Fels kostenlos frei und umgeht die Außenpostensperre nicht.

- Nach Hauptkernverlust spart die KI zuerst auf den festen Ersatzkernpreis. Ein fertiger Außenposten erhält dabei Produktion und Energieempfang. Fehlen Arbeiter, wird bei vorhandenem fertigem Standort regulär Nachwuchs gekauft. Ohne fertigen Empfänger und ohne Arbeiter werden keine Einheiten oder Energie erfunden; die beschlossene Stillstands-/Schutzregel gilt weiter.
- Geplante oder begonnene eigene Kernbauten haben Vorrang. Vorhandene Baustellen erhalten bei Arbeiterausfällen neue erreichbare Arbeiter. Manuell zugewiesene Reparaturarbeiter werden nicht dafür abgezogen.
- Vorläufige Ausbaupolitik: leicht/mittel/schwer höchstens ein/zwei/drei aktuelle Außenposten, frühestens mit drei/vier/sechs Arbeitern und mit 50 Energie Reserve über dem Baupreis. Zugewiesene Baugruppe höchstens zwei/drei/vier Arbeiter, zusätzlich auf etwa die Hälfte vorhandener Arbeiter begrenzt (mindestens einer). Das ist eine testbare Anfangsstrategie, keine neue endgültige Spielgrenze für menschliche Spieler.
- Bauplanung alle 100 Takte, über Fraktionen versetzt. Pro Platzierungsversuch höchstens 384 Kandidaten auf freien Flächen nahe eigenen fertigen Standorten. Ein gemeinsames Wegfeld prüft die Erreichbarkeit; die Auswahl der Bauarbeiter richtet sich nach tatsächlicher Wegdistanz. Aktuelle gegnerische Positionen werden für diese Standortwahl nicht abgefragt.
- Ungültige oder unerreichbare Plätze verbrauchen keine Energie. Die KI wählt keinen Standort im HUD des Spielers aus. Abbruch, Forschungsfreischaltung oder Reparatur werden von ihr nicht automatisch ausgeführt.

Die bisherige Kampf-KI kennt weiterhin globale Ziele; die neue Bauplanung implementiert keine Erkundung oder Fog of War. Strategische Bauplatzoptimierung, Gefahrbewertung und Logistikplanung bleiben spätere Verbesserungen.

## Zustände und Speicherkompatibilität

`WorkerStore.build_mode` ergänzt die vorhandene stabile Bauplatzzuweisung: Bau oder Reparatur. Beide Aufträge verwenden denselben nativen Arbeiterzustand 4, sodass normale Bewegung, Arbeitertausch und Schwarm-Intelligenz sie nicht überschreiben. Slottausch, Tod, neue Befehle und Speicherung berücksichtigen den Modus.

Der tatsächliche Baupreis steht als `paid` im Gebäude-Datensatz und wird gespeichert; Preissteigerungen nach dem ursprünglichen Kauf verändern die Rückzahlung nicht. Ältere Bau-Saves ohne diesen Wert bleiben lesbar und erhalten mangels nachgewiesenem Kaufpreis keine Rückzahlung. Bestehende Bauten, HP und Fortschritte bleiben erhalten.

Reparaturtakte sind aus dem gespeicherten Simulationstakt ableitbar; es gibt keinen ungespeicherten Reparaturtimer. Die KI-Planung ist ebenso aus Takt, Schwierigkeit und Zustand ableitbar. Ein bei der Anreise oder Reparatur gespeicherter Lauf setzt taktgleich fort.

Alte Ein-Zellen-Kerne mit historischem Flächenausbau werden von außerhalb der reservierten Energiefläche repariert. Neue Bauplätze dürfen diese Fläche nicht überbauen. Das stellt den alten Kernmechanismus nicht auf das neue Gebäudemodell um.

## Validierung

Lokal mit Godot 4.3 unter Windows ausgeführt:

- Vollständige native Suite: **274 Tests / 33.622 Prüfungen / 0 Fehler**.
- Vollständige GDScript-Referenzsuite (`--no-native`): **274 Tests / 30.328 Prüfungen / 0 Fehler**. Unterschiedliche Prüfzahlen ergeben sich aus optionalen nativen Vergleichsfällen.
- Darin enthalten: **20 neue Folgephasen-Tests / 449 Prüfungen**, zusätzlich gezielt in beiden Rechenwegen ausgeführt, jeweils fehlerfrei. Keine Script-/Parsefehler in den erfolgreichen Läufen. Die vier erwarteten Fehlermeldungen absichtlich ungültiger Konfigurations-/Startwelten bleiben Teil der bestehenden Negativtests.
- Kontrollierter Grafiklauf mit echtem HUD bei 1280×720 und geprüften Screenshots: Hauptkern von 400 auf 600 HP durch zugewiesene Arbeiter repariert; unbegonnene 200-Energie-Baustelle über HUD mit korrekter Erstattung abgebrochen; ein KI-Außenposten im vollständigen Simulationslauf durch Arbeiter fertiggestellt. Bei Takt 555 alle drei Ziele erfüllt, keine Invariantenfehler. Alle neuen Buttons waren sichtbar und bedienbar.
- Mischlast: 1.200 Takte mit anfänglich 10.000 Kriegern und 100 Arbeitern, zusätzlich 500 HP Hauptkernreparatur. Mittel **5,88 ms/Takt**, p95 **13,84 ms**, Maximum **38,26 ms**. Reparatur bei Takt 249 fertig; während dieser 249 Takte Mittel **2,88 ms**, Maximum **6,79 ms**. Am Ende 9.854 Krieger und konstant 100 Arbeiter, keine Invariantenfehler. Kurze Regressionsmessung, keine neue allgemeine Leistungs- oder Langzeitabnahme.
- `git diff --check` ohne Formatfehler. Bestehende Nutzeränderungen in SwarmMind und die zuvor abgeschlossenen nativen Armee-/Fenster-/Resume-Fixes wurden in dieser Folgephase nicht verändert.
 Die gezielten automatisierten Fälle prüfen manuelle Zuweisung, Kosten und Takt, gemeinsame Reparatur und HP-Kappung, Energiemangel und Wiederaufnahme, Eigentümerkonten, Weiterarbeiten unter Angriff/Tod, neue Befehle, Slottausch, exakt fortgesetzte Anreise mit Intelligenz 4, Abbruch-/Erstattungsregeln, doppelte Rückzahlung, Schutzverlust, Altstände, Forschungs-/Remote-Sperre, KI-Schwierigkeitsstufen, begrenzten Ausbau, Ersatzkern und -arbeiter, unerreichbare Plätze und einen vollständigen KI-Baulauf.

Diagnosen sind als `bench/maintenance_live_check.gd` (mit optionalem `--capture-dir=<Ordner>`) und `bench/maintenance_benchmark.gd` reproduzierbar. Sie benutzen ausdrücklich veränderte Testläufe ohne reguläre Autosaves. Screenshots und Messwerte ersetzen keine allgemeine Release-/Mehrspielerabnahme.

## Noch offen

Endgültiges Reparaturbalancing und Erstattungsregeln; Reparaturen an weiteren erst später eingeführten Gebäudetypen; weitergehende KI-Strategie; der eigentliche Forschungsbaum. Als nächstes großes Paket bleibt P4 Energie: 60-Sekunden-Verfall ohne Route, Abfangstationen, wiederholter Eigentumswechsel und vollständige Bilanz. Dafür ist ein eigener Auftrag nötig. Keine Commits, PRs, Veröffentlichung oder Abschaltung aus dieser Phase.

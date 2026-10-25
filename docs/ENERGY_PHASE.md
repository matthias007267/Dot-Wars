# Energiephase: Routenverfall, Abfangen und vollständige Transportbilanz

Stand: 25. Oktober 2026. Ausdrücklicher Auftrag „Arbeite Punkte 1–3 ab“ zur unmittelbar vorher genannten Energieliste: fehlende Routen/60-Sekunden-Verfall, Abfangstationen und Zerstörung/Energiebilanz (D-062). Die vorherigen Bau-, Reparatur- und Abbruchentscheidungen bleiben erhalten.

## Verbindliche Regeln und vorläufige Testfestlegungen

Verbindlich aus E01–E07: Energie bewegt sich physisch zu einem eigenen fertigen Kern/Außenposten und wird erst bei Ankunft gutgeschrieben. Nur Abfanggebäude stehlen gegnerische Energie. Erneutes Abfangen ist ohne Lebenszeitlimit möglich. Gestohlene Energie muss anschließend zum Empfänger ihres neuen Besitzers gelangen. Bei Stationszerstörung wird nur ihre noch gepufferte Energie neutral. Eigentumswechsel und Neutralisierung erzeugen keine zusätzliche Energie.

Die angebotenen Timer-, Stations- und Neutralenergietestregeln sind mit der nachgereichten Antwort „Diese Testregeln verwenden“ **ausdrücklich als vorläufige Testregeln bestätigt** (D-063). Sie entsprechen bereits der geprüften Umsetzung. Endgültiges Balancing bleibt offen; ergänzende Ausführungsdetails wie die Konkurrenzpriorität über stabile IDs bleiben vorläufige Implementierungsfestlegungen:

- Die 60 Sekunden sind **1.200 aufeinanderfolgende Simulationstakte bei 20 Takten/s**. Spielpause hält den Timer an; 4× Spielgeschwindigkeit durchläuft ihn entsprechend schneller in Echtzeit.
- „Ohne Route“ bedeutet: Vom tatsächlichen Energieort existiert kein Weg durch leeres Terrain zu einem freien Empfangsrand eines fertigen eigenen Kerns/Außenpostens. Die Wegprüfung ignoriert Arbeiter und Krieger. Warten vor einem Arbeiter ist deshalb kein Routenverlust. Die eigentliche Bewegung respektiert weiterhin die bestehende Arbeiterblockade.
- Eine tatsächlich wieder verfügbare eigene Route setzt den Timer auf null. Eigentumswechsel allein setzt ihn nicht zurück. Bei Abfangen wird die Route des neuen Besitzers geprüft; ohne Route bleibt die bereits angesammelte Frist erhalten. Gelände- und Empfängeränderungen werden ohne den früheren Zehn-Takte-Aufschub berücksichtigt.
- Abfangstation: **3×3 Zellen, 150 HP, 250 Energie, 300 Arbeiter-Takte**. Wie andere Gebäude auf freiem Boden durch eigene Arbeiter gebaut, beschädigbar und manuell reparierbar. Kein Produktionsort, kein Energieempfänger für Bankgutschriften und kein Schutz vor Niederlage.
- Abfangkontakt nur am direkt angrenzenden freien orthogonalen Rand. Kein Fernabfangen durch Felsen. Bis zu **acht Punkte je Station/Takt**, Pufferkapazität **256**, Weitergabe nach **20 Takten**. Der Punkt bleibt beim Abfangen an seiner tatsächlichen Randzelle; es gibt keinen Teleport in den Baukörper oder zum Kern.
- Eigene und verbündete Energie wird nicht gestohlen. Neutrale Energie kann jede fertige Station abfangen. Bei konkurrierenden geeigneten Stationen gewinnt die kleinste stabile Gebäude-ID mit verfügbarer Kapazität. Pro Energiepunkt höchstens ein Abfangen je Takt. Nach Ende der Pufferzeit ist erneutes Abfangen sofort möglich; die zwanzig Takte verhindern eine Endlosschleife innerhalb eines einzelnen Taktes, ohne die Zahl der Eigentumswechsel zu begrenzen.
- Neutrale Energie bleibt am Ort, wird nicht von gewöhnlichen Gebäuden gutgeschrieben und verfällt ebenfalls nach 1.200 Takten ohne erneutes Abfangen mit anschließender gültiger Route. Eine Zerstörung setzt den bisherigen Routenverlusttimer nicht künstlich zurück.

## Spielbarer Ablauf

1. Escape → Testlabor aktivieren → **„Abfangstationen freischalten (Test)“**. Das markiert den Lauf als verändert; reguläre Saves bleiben gesperrt. Eine echte Forschung wird damit nicht erfunden.
2. Eigene Arbeiter auswählen, **FÄHIGKEITEN → ENERGIETRANSPORT → ABFANGSTATION BAUEN** wählen und die linke obere Ecke eines freien 3×3-Platzes anklicken. Bau, neue Arbeiterzuweisung per Rechtsklick und Abbruch folgen den vorhandenen Regeln.
3. Eine fertige Station so platzieren, dass gegnerische Energie ihren freien Rand passiert. Abfangen ändert den Besitzer und puffert, ohne Bankgutschrift. Nach Freigabe läuft die Energie über reale freie Wege zum eigenen Kern/Außenposten.
4. Zerstörung gibt den Baugrund frei und macht noch gepufferte Punkte sofort neutral. Bereits freigegebene Punkte behalten ihren Besitzer. Auch die Entfernung einer Fraktion zerstört ihre Stationen regulär und neutralisiert deren Puffer, statt Energie still zu löschen.

Energie ist im freien eigenen Transport blau, im freien Transport anderer Fraktionen in deren Farbe, gepuffert orange und neutral grau. Die Stationsfläche trägt ein eigenes Kreuzsymbol. Der Tooltip der Energieanzeige und das Testlabor zeigen geliefert, verfallen, gepuffert, neutral und Abfangvorgänge. Die Bankanzeige zeigt weiterhin ausschließlich gutgeschriebene Energie; „unterwegs“ schließt den eigenen Puffer ein.

Der bestehende KI-Bauplan errichtet weiterhin Hauptkerne/Außenposten; eine strategische automatische Stationsplatzierung ist kein Teil dieses Durchlaufs. Gegnerische Stationen und Konkurrenzfälle sind in automatisierten und grafischen Diagnosen ausdrücklich als Fixtures angelegt. Gegnerische laufende Energie kann im Testspiel bereits durch eigene Stationen abgefangen werden.

## Bilanz und technische Umsetzung

Die verbindliche Transportbilanz lautet jetzt:

`erzeugt = geliefert + verfallen + unterwegs`

`unterwegs = frei mit Besitzer + gepuffert + frei neutral`

Ein gepufferter Punkt zählt genau einmal als unterwegs. Abfangen und Neutralisieren ändern nur Kategorien/Besitzer; ihre kumulierten Ereigniszähler sind keine Energiequellen und dürfen durch wiederholtes Abfangen größer als die erzeugte Menge werden. „Erzeugt“ umfasst regulären Abbau, die ausdrücklich beibehaltene alte Veredler-Erzeugung sowie markierte Diagnosequellen. „Geliefert“ ist der kumulierte Abfluss in die Bank, nicht der aktuelle Kontostand nach Bau-/Einheitenkäufen oder Reparaturen. Bestehende Kosten und beschlossene Abbrucherstattungen bleiben separate Kontotransaktionen. Bereits eingelagerte gegnerische Energie wird nicht vom Konto gestohlen.

`EnergyStore` hält zusätzliche parallele Arrays für Routenverlusttakte, Puffergebäude-ID und Freigabetakt sowie kumulierte Verfalls-/Transferzähler. `energy_transport.gd` verarbeitet die Punkte in deterministischer Reihenfolge und kompaktiert alle Arrays gemeinsam. Gemeinsame Distanzfelder werden bei relevanten Topologieänderungen exakt erneuert, Kontaktzellen der Stationen zwischengespeichert. Kein Node und keine Wegsuche pro Energiepunkt; keine neuen Threads. Der bisherige native Ein-Fraktions-Bewegungspfad und die native gemeinsame BFS bleiben erhalten; GDScript bleibt Referenz.

Das Gebäudeformat erhält Typ 2 für Abfangstationen. Produktions-, Empfangs- und Schutzprüfungen schließen diesen Typ ausdrücklich aus. Die Bau-/Reparaturlogik wird wiederverwendet. Der Stationskontakt wird vor der Bankgutschrift am betreffenden Ort geprüft; ein Punkt kann daher nicht gleichzeitig gestohlen und seinem früheren Besitzer gutgeschrieben werden.

## Speichern und Altstände

Version 2 wird additiv um `energy_transport` erweitert. Gespeichert werden Besitzer, verbleibende Routenverlust-/Pufferzeit, Stationbindung und Bilanzzähler. Geladene Daten werden gegen Punktzahl, Besitzer, fertige Station, tatsächlichen freien Rand, Pufferkapazität und Zeitgrenzen geprüft. Ableitbare Kontaktcaches werden neu aufgebaut; die Testlaborfreigabe wird nicht als erforschte Technologie gespeichert.

Alte Version-2-Stände ohne Transportabschnitt bleiben lesbar: vorhandene Energie und Konten bleiben erhalten, unbekannte historische Verfallszeiten starten bei null, Verfall/Abfangzähler ebenfalls bei null. Ein aus der aktuellen Fassung entfernter Bilanzabschnitt ist nicht automatisch ein gültiger Altstand, wenn dadurch bereits verfallene Energie aus der Erhaltungsgleichung verschwände. Die neue Fassung verspricht keine Vorwärtskompatibilität mit älteren Spielversionen.

## Validierung

Lokal mit Godot 4.3 unter Windows ausgeführt:

- Vollständige native Suite: **290 Tests / 33.900 Prüfungen / 0 Fehler**.
- Vollständige GDScript-Referenzsuite (`--no-native`): **290 Tests / 30.606 Prüfungen / 0 Fehler**. Optionale native Vergleichsfälle erklären die unterschiedliche Prüfzahl.
- Darin enthalten: **16 neue Energiephasen-Tests / 278 Prüfungen**. Keine Script-/Parsefehler in den erfolgreichen Läufen. Die vier erwarteten Fehlermeldungen absichtlich ungültiger Startwelten/Konfigurationen bleiben bestehende Negativtests.
- Grafischer Stationslauf bei 1280×720: eigene Station tatsächlich durch Arbeiter gebaut, Stationsbauknopf unter Fähigkeiten geprüft, sechzehn Punkte wiederholt abgefangen. Vor Zerstörung 48 Abfangvorgänge, anschließend sechzehn gepufferte Punkte neutralisiert und erneut abgefangen. Am Ende **16 erzeugt = 0 geliefert + 0 verfallen + 16 unterwegs**, insgesamt 64 Abfangvorgänge und sechzehn Neutralisierungen, keine Invariantenfehler. Screenshots von Puffer, Steuerung, neutralem Zustand und erneutem Transport visuell geprüft. Die gegnerische Station ist eine ausdrücklich vorgefertigte Diagnoseeinrichtung.
- Fünf simulierte Minuten kombinierte Last: **6.000 Takte**, anfänglich 10.000 Krieger, mindestens 9.920 und am Ende 9.971, konstant 100 Arbeiter. Aktive Stationspuffer, wiederholtes Abfangen, gezielte Stationszerstörung, Neutralisierung und Verfall. Mittel **9,86 ms/Takt**, p95 **15,38 ms**, Maximum **42,85 ms**. **23.680 erzeugt = 20.021 geliefert + 256 verfallen + 3.403 unterwegs**; 6.960 Abfangvorgänge, 80 Neutralisierungen, keine Invariantenfehler. Die Fixture enthält explizite anfängliche Energiequellen und einen zerstörten Stationspuffer; es ist kein regulärer Spielstand.
- Separater Grafik-Regressionslauf mit anfänglich 10.000 Kriegern und 100 Arbeitern bei **1920×1080**: nach fünf Sekunden Aufwärmen zwanzig Sekunden Messzeit, **59,99 FPS / 20,00 Simulationstakte/s**, maximal **38,53 ms/Frame**, p95 **29,24 ms**, keine Frames über 50 ms, kein verworfenes Simulationszeitbudget, keine Invariantenfehler. Am Ende 9.890 Krieger und 253 Energiepunkte. Dieser Grafiklauf prüft den normalen gemischten Transport ohne Stationen; die kombinierte Stationslast wurde separat headless gemessen. Keine Gleichsetzung mit einer Grafikabnahme beliebig großer Abfangschlachten.
- `git diff --check` ohne Formatfehler. Vorherige Nutzeränderungen in SwarmMind sowie die Armee-, Resume-, Fenster- und nativen Adapterdateien wurden in dieser Phase nicht verändert.
 Gezielte Tests prüfen exakt 1.200 Takte, Stau ohne Verfall, Wiederherstellung im letzten Moment, erneuten Routenverlust, Forschungssperre, echte Bauarbeit, Ausschluss von Produktion/Empfang/Schutz, Besitzerkonten, Gutschrift erst nach Ankunft, wiederholtes Abfangen, Neutralisierung nur des Puffers, erneutes Abfangen neutraler Punkte, Verbündete, Randkontakt, stabile Konkurrenzpriorität, Durchsatz/Kapazität, Fristerhalt bei Diebstahl ohne Route, Speicherfortsetzung, ungültige Daten und alte Saves.

Reproduzierbare Einstiegspunkte: `tests/run_tests.gd -- test_energy_phase`, jeweils mit `--require-native` bzw. `--no-native`; `bench/energy_live_check.gd -- --capture-dir=<Ordner>` und `bench/energy_benchmark.gd -- --ticks=6000`. Diagnosen verwenden veränderte Testläufe und schreiben keine regulären Autosaves.

## Verbleibende Grenzen

Endgültige Stationswerte, Wirkbereich, Durchsatz, Pufferzeit, Konkurrenzpriorität und neutrales Verhalten bleiben Balancingthemen. Forschungseinbindung und strategischer KI-Stationsbau fehlen. Fog of War/Erkundungswissen, nahezu endlose Welt, diagonale Wege und Netzwerk bleiben eigene Folgephasen. Leistungswerte gelten nur für die beschriebenen Szenarien, nicht für beliebige Welt-/Stationsgrößen. Keine Commits, PRs, Veröffentlichung oder Abschaltung aus dieser Phase.

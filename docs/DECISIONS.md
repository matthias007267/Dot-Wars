# Entscheidungen

Beschlossene Punkte stehen fest, bis sie ausdrücklich geändert werden. Offene Punkte werden nicht still entschieden.

## Beschlossen

### D-001 Abbauzeit

Datum: 22. Oktober 2026.

Eine Arbeitseinheit ist eine Simulationssekunde. Ein Basis-Arbeiter leistet eine Arbeitseinheit pro Sekunde. Härte 8 dauert damit 8 Sekunden, Härte 3 dauert 3 Sekunden, Härte 1 dauert 1 Sekunde.

Umsetzung: 20 Simulationstakte sind eine Sekunde. `work_per_hardness` ist 20 Fortschrittspunkte. `dig_power` ist 1 Punkt pro Tick. Haltbarkeit = Härte × 20. Mehrere Arbeiter addieren ihre Punkte im selben Tick. Die Werte bleiben in `SimConfig` zentral änderbar. Der ausgelieferte Standard erfüllt diese Regel.

Der vorherige Prototyp nutzte 10 Punkte je Härtestufe und damit 4 Sekunden für Härte 8. Diese Tests sind auf die beschlossene Dauer umgestellt.

### D-002 Vorhandener Prototyp bleibt

Datum: 22. Oktober 2026.

Phase 1 ersetzt den Simulationsprototyp nicht und baut ihn nicht zur spielbaren Partie aus. Dokumentation, CI, Test-Runner und die minimale Hauptszene liegen darüber. Phasen 2 bis 5 gelten trotzdem als nicht begonnen, weil ihre Abnahme (Darstellung, Bedienung, drei Gruppen) nicht erfüllt ist.

### D-003 Test-Runner ohne externe Bibliothek

Datum: 22. Oktober 2026.

Der Runner unter `tests/run_tests.gd` bleibt. Eine zweite Testbibliothek würde dieselbe Prüfung doppelt abbilden.

### D-004 Engine

Datum: 22. Oktober 2026.

Godot 4.3, GDScript, Renderer `gl_compatibility`. Dieselbe Version nutzt die CI.

### D-005 Quoten mit Summe ungleich 100 % werden abgelehnt

Datum: 22. Oktober 2026, Bestand des Prototyps, nicht neu entschieden.

`GroupQuotas.validate` verlangt eine Summe von genau 100 %. Es gibt keine stille Normalisierung. Phase 5 darf das nur mit einer neuen Entscheidung ändern.

### D-006 Gleichstand bei der Gruppenwahl

Datum: 22. Oktober 2026, Bestand des Prototyps.

Gewonnen hat die Gruppe mit dem kleinsten Quotienten Anzahl/Quote. Bei Gleichstand gewinnt die größere Quote, danach der kleinere Gruppenindex. Der Vergleich ist eine Kreuzmultiplikation ohne Gleitkommazahlen.

### D-007 Farben und unzerstörbares Material

Datum: 22. Oktober 2026.

Weich ist Grün, mittel Orange, hart Blau, unzerstörbar Dunkelgrau. Leer ist der Tunnel und dunkler als die Materialien, aber heller als der Hintergrund hinter der Welt. Die Farben stehen in `Materials.COLORS`. Das Opferloch bleibt unzerstörbares Material und wird nur in der Darstellung magenta gezeichnet.

Stand 22. Oktober 2026, Variante „Premium Pixel Tactics“: Hintergrund `#0D1015`, Tunnel `#161C24`, weich `#57C96D`, mittel `#D3822C`, hart `#5C86DB`, unzerstörbar `#393F49`, Opferloch `#C77AFF`. Gruppen 1 bis 4 sind `#FFE45E`, `#53C7FF`, `#FF6A76`, `#7EFF93`. Die Gruppen 5 bis 8 sind `#F4F7FB`, `#FF9AD5`, `#3EE0C7`, `#D6F26A`, damit acht Gruppen hell und voneinander getrennt bleiben.

Unzerstörbare Zellen haben keine Haltbarkeit. `WorldState.mine_cell` lehnt sie ab. Sie zählen nicht zum abbaubaren Bestand der Massen- und Fortschrittsquote.

### D-008 Reservierte Opferlochzelle

Datum: 22. Oktober 2026.

`WorldGenerator.sacrifice_cell` liegt bei `(width / 2 + 1, height / 2 + 1)`. Die Zelle ist unzerstörbar und orthogonal an den Starttunnel angrenzend. Ein Feld von 4×4 Zellen nordwestlich des Tunnels ist ebenfalls unzerstörbar, damit der Typ in der Ansicht sichtbar ist. Einlieferungsregeln, Energie und der Schutz vor vollständiger Opferung bleiben Phase 7.

### D-009 Darstellung

Datum: 22. Oktober 2026.

Eine Zelle ist eine Welteinheit und ein Pixel in einer gemeinsamen Textur. Geändert wird nur der betroffene Chunk, gezeichnet wird ein Rechteck. Es gibt keine Node pro Zelle. Der Zoom startet bei 10 Pixeln je Zelle, geht bis 40 hinauf und bis zur ganzen Welt im Fenster hinunter. Das Mausrad zoomt zur Cursorposition.

### D-010 Laufziel ohne Abbau in der Ansicht

Datum: 22. Oktober 2026.

Phase 3 zeigt die Arbeiter und lässt sie laufen. Ein Linksklick auf eine leere Zelle setzt dasselbe Laufziel für jede Gruppe. Ein Klick auf Material wird verworfen. Das Flow-Field der Gruppe erhält diese Zelle als zusätzliche Quelle. Zellen ohne Verbindung behalten keine Richtung, der Arbeiter wartet. Steht ein Arbeiter auf dem Ziel und hat die Gruppe keinen Abbauauftrag, bleibt er stehen.

Die Abbaulogik bleibt in der Simulation und in den Tests. Die Hauptszene weist kein Abbaugebiet zu, deshalb steigt die abgebaute Masse im Fenster nicht.

Die Leertaste schaltet `TickClock.paused`. In der Pause wird keine Zeit gesammelt.

Arbeiter liegen weiter in `WorkerStore`. `faction` ist ein zusätzliches Byte und steht beim Anlegen auf 0. Gezeichnet werden sie in einer zweiten Textur, ein Pixel pro Zelle. Es gibt keine Node pro Arbeiter.

### D-011 Aufträge je gewählter Gruppe

Datum: 22. Oktober 2026.

Ein kurzer Linksklick setzt das Laufziel nur für die gewählte Gruppe. Ein Zug mit der linken Taste markiert ihr Abbaugebiet. Die Tasten 1 bis 8 wählen die Gruppe. Rechte und mittlere Taste verschieben weiterhin die Kamera. D-010 gilt für den Stand von Phase 3; die spätere Bedienung ersetzt das gemeinsame Ziel.

### D-012 Gruppen anlegen und schließen

Datum: 22. Oktober 2026.

Eine neue Gruppe beginnt mit Quote 0 %, damit die Summe 100 % bleibt. Schließen ist nur möglich, solange eine andere Gruppe offen bleibt. Ihre Arbeiter und ihre Quote gehen an die offene Gruppe mit dem kleinsten Index. Die Gesamtmasse ändert sich nicht.

### D-013 Quoteneingabe

Datum: 22. Oktober 2026. Schließt O-006.

Die Oberfläche normalisiert eine Summe ungleich 100 % nicht. Der Versuch wird abgelehnt und der bisherige Stand bleibt.

### D-014 Schutzregel am Opferloch

Datum: 22. Oktober 2026. Schließt O-005.

Eine Einheit wird nur geopfert, wenn danach mindestens Masse 1 im Spiel bleibt. Wartende Entstehungen zählen mit. Würde die Opferung die letzte Masse entfernen, unterbleibt sie und der Opferauftrag dieser Gruppe endet. Energie ist gleich der geopferten Masse.

### D-015 Bewegungs-Upgrade

Datum: 22. Oktober 2026.

Der Grundtakt ist ein Schritt alle `move_period_ticks` Takte, versetzt nach Arbeiter-ID. Die Stufenleiter, die diesen Takt verkürzt, steht in D-028. Die frühere Punkterechnung mit dem Faktor 6/5 gilt nicht mehr.

### D-016 Abbau-Upgrade

Datum: 22. Oktober 2026. Schließt O-003.

Die Haltbarkeit aus D-001 bleibt. Jede Stufe multipliziert die Leistung mit 5/4, als Bruch ohne Rundungsverlust. Eine Stufe macht aus einem Punkt je Takt 5/4 Punkte. Härte 1 dauert dann 16 Takte statt 20. Große Einheiten nutzen dieselbe Bruchrechnung auf ihrer eigenen Grundleistung.

Kosten: 50 × (gekaufte Stufe + 1).

### D-017 Verschmelzungs-Upgrades

Datum: 22. Oktober 2026.

2×2 kostet einmalig 100 Energie und schaltet die Wunschgröße 2 frei. 3×3 kostet einmalig 250, setzt 2×2 voraus und schaltet die Wunschgröße 3 frei. 250 ist ein vorläufiger Balancingwert. Ohne diese Käufe bleibt die Wunschgröße 1.

### D-018 Verschmelzung

Datum: 22. Oktober 2026.

Größe 1 hat Masse 1 und Leistung 1, Größe 2 hat Masse 4 und Leistung 6, Größe 3 hat Masse 9 und Leistung 15. Verschmolzen wird nur innerhalb derselben Gruppe und Fraktion, auf ein freies Quadrat, höchstens vier Mal je Gruppe und Takt. Eine andere Wunschgröße zerlegt die Einheit zuerst in Basis-Arbeiter auf ihrer eigenen Fläche. Enge Lücken, die das Quadrat nicht fassen, sind nicht passierbar.

### D-019 Speicherstand

Datum: 22. Oktober 2026.

Formatversion 1, geschrieben mit `var_to_bytes`. Manuell unter `user://slot.dw` (F5, F9), automatisch alle 600 Simulationstakte unter `user://autosave.dw`. Eine falsche Version oder ein verletzter Zustand wird abgelehnt. Nach dem Laden setzt dieselbe Befehlsfolge die Simulation gleich fort.

### D-020 Lokale Korrektur der Zielsuche

Datum: 22. Oktober 2026.

Bis zu 32 Materialänderungen seit dem letzten veröffentlichten Feld korrigieren dieses Feld an Ort und Stelle. Verlorene Abbaupositionen nehmen die Zellen mit, deren nächster Schritt auf sie zulief. Geöffnete Zellen und diese Nachbarschaft werden neu angesetzt; ein kürzerer Weg ersetzt einen längeren. Das Ergebnis bleibt unsichtbar, bis die budgetierte Ausbreitung fertig ist. Öffnet sich währenddessen eine weitere Zelle, beginnt die Korrektur erneut beim letzten veröffentlichten Feld, solange zusammen höchstens 32 Änderungen betroffen sind.

Vollständig neu aufgebaut wird das Feld beim ersten Mal, bei einem neuen Gebiet, bei einem neuen Laufziel, ab 33 Änderungen, wenn das Änderungsprotokoll verworfen wird, und wenn der Abhängigkeitskegel 8192 Zellen überschreitet. Der letzte Fall begrenzt die Arbeit in einem Takt. Ein leeres Abbaurechteck wird beim Veröffentlichen entfernt und löst keinen Neuaufbau aus.

Gemessen am 22. Oktober 2026, Seed 1337, markierte linke Hälfte, eine abgebaute Randzelle neben einer leeren Zelle: 0,08 ms auf der 256er-Welt und 0,72 ms auf der 1.000er-Welt. Dieselbe vollständige Berechnung dauerte im Median 29,8 ms bzw. 455 ms. Geändert haben sich zwei Distanzen. Der Lauf nahm die lokale Korrektur, nicht den Neuaufbau.

## Offen

### O-002 Weitere Fraktionen

Die Fraktions-ID liegt neben der Gruppe. Neue Arbeiter bekommen Fraktion 0, und die Ansicht verwendet nur diese Fraktion. Mehrere Fraktionen, Besitz und getrennte Aufträge je Fraktion sind nicht umgesetzt.


### D-021 Premium Pixel Tactics – grafischer Feinschliff

Datum: 22. Oktober 2026.

Die beschlossene Palette D-007 bleibt unverändert. Abbaubare Materialien erhalten deterministische Helligkeitsvariationen von höchstens sechs RGB-Stufen pro Zelle; der Abbau-Fortschritt blendet weiter Richtung Tunnel. Das Opferloch erhält bei Zoom mindestens 3 einen schwachen Lichtschein. Es gibt keine Umrandungen pro Dot, keine zusätzlichen Nodes pro Dot und keine Änderungen an der Simulation oder Speicherständen. Der vorgeschlagene Lichtakzent je Arbeiter entfällt mit D-023, weil er bei jedem Bild alle Einheiten abläuft und die Pixelpunkte weichzeichnet.


### D-022 Reduziertes Spiel-HUD ohne Gruppenverwaltung

Datum: 22. Oktober 2026.

Die Farbgruppen und Gruppenquoten bleiben vollständig in der Simulation, werden aber nicht mehr als sichtbare Verwaltungsoberfläche angeboten. Das HUD erhält drei Statuswerte (Masse, Energie, Abbau), drei Missionsziele, eine kompakte Aktionsleiste (Abbauen, Bewegen, Opfern, Dot-Größe, Upgrades, Pause, Speichern) und eine anklickbare Minimap. Die Upgrade-Käufe befinden sich in einem ausblendbaren Panel. Debug-Informationen wie Simulations-Tick, Materiallegende, Gruppenlisten und Quotenregler sind nicht Teil des Standard-HUD.

Abbau- und Bewegungsaufträge gelten für alle aktiven internen Gruppen außer der opfernden Gruppe. Der jeweils neue Auftrag ersetzt den vorherigen Auftrag derselben Gruppe. Die letzte aktive Gruppe mit positiver Quote beziehungsweise vorhandener Arbeitermasse übernimmt bei aktiviertem Opfern die interne Einlieferung. Die übrigen Gruppen bleiben im Abbau. Wird Opfern deaktiviert, erhält diese Gruppe wieder das zuletzt per HUD markierte Abbaugebiet, sofern vorhanden.

Die Wunschgröße wird gemeinsam für alle arbeitenden Gruppen gesetzt. Gruppen-IDs sind nicht mehr per Zifferntasten auswählbar. Die Spielmechanik, Quotenverteilung, Massenerhaltung und das Speicherformat bleiben unverändert; vorhandene Speicherstände mit individuellen Gruppenaufträgen können weiter geladen werden. Neue globale Befehle überschreiben die bisherigen Aufträge der arbeitenden Gruppen.

### D-023 Test-Beta 0.2.0

Datum: 22. Oktober 2026.

Die reduzierte Leiste aus D-022 bleibt die Spieloberfläche. Die Quotenregler kommen nicht zurück. Sichtbar werden die drei Schwarmfarben mit ihrer Masse und dem Hinweis, welche Farbe opfert. Abbaugebiete und Sammelpunkte werden auf der Welt gezeichnet. Die Wunschgröße gilt auch für die opfernde Gruppe. Tempo 1×, 2× und 4× sowie Laden des Speicherstands `user://slot.dw` liegen in der Leiste. Kampf, KI und weitere Fraktionen gehören nicht zu dieser Beta.


### D-024 Zwei Dot-Arten und Energie-Kreislauf

Datum: 22. Oktober 2026.

Es gibt vorerst ausschließlich gelbe Arbeiter-Dots und cyanfarbene Energie-Dots. Rote Krieger-Dots sind ausdrücklich für eine spätere Entwicklungsphase reserviert. Abbau erzeugt keine Arbeiter mehr, sondern genau so viele Energie-Dots wie die Materialhärte (1, 3, 8). Energie bewegt sich autonom durch Tunnel zum zentralen Energiekern, dem umbenannten Opferloch, und wird erst bei Ankunft verfügbar. Arbeiter werden für zunächst 10 Energie am Kern gekauft und über die vorhandene Spawn-Warteschlange im Zentrum erzeugt. Opferung von Arbeitern ist deaktiviert. Transportierte Energie und Arbeiter haben getrennte Belegungsdaten; Energie wartet bei Arbeiterbelegung, Arbeiter werden nie durch Energie blockiert. Die Darstellung zeichnet Energie unter den Arbeitern.

Die Massenbilanz lautet Startmasse plus gekaufte Masse. Die Energieerzeugungsbilanz lautet erzeugt gleich geliefert plus unterwegs. Speichern und Laden verwenden Version 2; Version 1 wird bewusst nicht automatisch migriert.


### D-025 Energie teilt Zellen, Arbeiter halten den Gang

Datum: 22. Oktober 2026.

Energie-Dots blockieren einander nicht. Beliebig viele liegen auf derselben leeren Zelle und rücken gemeinsam vor, auch in einem Gang von einer Zelle Breite. Die nächste Zelle ist diejenige mit kürzerer Distanz zum Kern, in der Reihenfolge Nord, Ost, Süd, West. Ist diese Zelle von einem Arbeiter belegt, bleibt der Dot liegen. Arbeiter werden von Energie nicht verschoben. Die Kosten von 10 Energie je Arbeiter und 250 für 3×3 bleiben vorläufig. Die Siegbedingungen bleiben unverändert.


### D-026 Kernfläche als Fähigkeit

Datum: 22. Oktober 2026.

Der Energiekern bleibt auf Stufe 0 so, wie er ist: zwei leere Nachbarzellen auf dem Startkreuz nehmen Energie an, und Arbeiter dürfen dort stehen. Jeder Kauf der Fähigkeit Kern vergrößert die Fläche um eine Chebyshev-Stufe, höchstens bis Radius 4. Die Fläche selbst, ohne die unzerstörbare Kernzelle, nimmt Energie an und ist für Arbeiter gesperrt, sowohl in der Zielsuche als auch in der Bewegung. Der Ring direkt außerhalb wird leer gelegt, damit die Tunnelarme verbunden bleiben. Diese Zellen zählen nicht als Abbau und erzeugen keine Energie. `opened_count` hält den Abbauanteil stabil. Die Kosten sind vorläufig 40, 80, 120 und 160 Energie. Steht ein Arbeiter in der neuen Fläche, wird er vorher auf eine freie Zelle außerhalb gesetzt. Gelingt das nicht für jeden betroffenen Arbeiter, passiert nichts: kein Aushub, keine Kosten. Neue Arbeiter entstehen neben der Fläche, nicht darauf.

Weitere Fähigkeiten kommen in dasselbe Fenster, nicht als eigene Knöpfe in die Leiste. Die Leiste hat einen Knopf „Fähigkeiten“. Darin liegen die Zweige Kern und Schwarm. Der Zweig Bewegung folgt in D-028. Speicherstände bleiben Version 2. `core_level`, `opened` und der letzte Bewegungstakt eines Arbeiters sind optionale Felder und fehlen in älteren Ständen als 0 beziehungsweise -1.


### D-027 Kernfläche ist sichtbar, die Partiedauer ist einmal gemessen

Datum: 22. Oktober 2026.

Die freie Kernfläche wird dunkelmagenta `#5A3D78` gezeichnet. Der Energiekern selbst bleibt `#C77AFF`. Die Farbe ist nur Darstellung; die Zelle bleibt leer. Die Kernstufe steht in der Statuskarte als „Kern“ mit Balken bis 4. Der Kauf bleibt im Fähigkeiten-Fenster.

Ein skriptierter Lauf mit Seed 1337 markiert die ganze Welt, kauft einmal den Kern, viermal Abbau, einmal Tempo und Arbeiter bis Masse 100. Auf der 64er-Welt sind die drei Siegziele nach 2:16 Simulationszeit erreicht, auf der Standardwelt 256 nach 37:28. Wandzeit auf dieser Maschine: 2,8 s und 283 s. Invarianten ohne Fehler. Das liegt am oberen Rand des Ziels von 20 bis 40 Minuten und ist ein Lauf, kein menschliches Spiel. Die Siegbedingungen bleiben unverändert. Dieser Lauf nutzte noch einen Schritt alle zwei Takte, vor der langsameren Startgeschwindigkeit aus D-028.


### D-028 Tempo von Arbeitern und Energie

Datum: 22. Oktober 2026.

Arbeiter und Energie-Dots starten langsam: ein Schritt alle 8 Takte, also zweieinhalb Zellen je Simulationssekunde. Jede Fähigkeit verkürzt das in festen Stufen auf 6, 4, 3, 2 und schließlich 1 Takt. Ein Takt je Schritt ist der Anschlag. Die Stufen sind getrennt. Arbeiter kosten vorläufig 25, 50, 75, 100 und 125 Energie. Energie-Dots kosten vorläufig 30, 60, 90, 120 und 150. Beide Käufe liegen im Fähigkeiten-Fenster unter Bewegung, nicht in der Leiste. Rote Krieger haben keine Geschwindigkeit, weil es sie noch nicht gibt.

Stufe 0 der Arbeiter folgt weiterhin `move_period_ticks`. Neue Spiele stehen auf 8. Ein älterer Speicherstand ohne eigene Periode bleibt bei 2. `energy_speed` fehlt in älteren Ständen und ist dann 0, also der langsame Start. Die Kosten 10 und 250 bleiben unverändert. Die drei Prüfungen der Räumung bleiben; weitere Modi stehen in D-029.


### D-029 Modi, Quelle und Veredler

Datum: 22. Oktober 2026.

Die endgültigen Siege sind nicht festgelegt. Sie hängen am Modus. Drei Modi sind im Spiel, ihre Zielzahlen sind vorläufig.

Räumung behält Masse 100, zwei Käufe und 90 % des ursprünglichen Materials. Förderung endet bei 1.000 gelieferten Energieeinheiten. Veredelung endet bei 400 veredelten Einheiten am Kern. Roh angekommene Energie füllt in jedem Modus das Guthaben. Nur die Veredelung zählt sie ins Ziel, und nur wenn ein Veredler den Dot verdoppelt hat.

Die Quelle gibt es nur in der Förderung. Sie steht auf einer leeren Tunnelzelle, kostet vorläufig 80, 160 und 240 und es gibt höchstens drei. Alle 8 Sekunden, nach der ersten Stufe alle 6, wächst eine Nachbarzelle zu echtem Material nach, höchstens 4 gleichzeitig und ab Stufe 1 höchstens 6. Ist die Grenze voll oder keine Zelle frei, wartet der Takt. Stufe 2 macht jede dritte neue Zelle mittel, Stufe 3 jede sechste hart. Die Stufen kosten 40, 80 und 120 und gelten für alle Quellen. Abgebautes Nachwuchs-Material liefert seine Härte als Energie-Dots. Es zählt in der Förderung nicht als Siegbalken, weil dieser Modus keinen Abbauanteil hat.

Der Veredler gibt es in Räumung und Veredelung. Er kostet vorläufig 120 und 240, höchstens zwei. Ein Dot wird einmal verdoppelt, auch am zweiten Veredler nicht noch einmal. Der Umkreis ist Chebyshev, Stufe 0 bis 2 reicht 16, 24 und 32 Zellen um die Herkunft des Dots. Der Durchsatz ist ein Dot je Sekunde, dann zwei, dann vier. Die Stufen kosten 60 und 120. Dots ohne gespeicherte Herkunft, wie in älteren Speicherständen, werden nicht veredelt.

Beide Gebäude bleiben leer und begehbar. Arbeiter und Energie dürfen die Zelle betreten. Der Kern und die Kernfläche bleiben frei. Der Kauf und die Stufe zählen als Fähigkeit, damit die Räumung sie wie die anderen Käufe sieht. Die veredelten Dots ändern den Räumungssieg nicht. Die Leiste bekommt keinen weiteren Knopf. Setzen und Stufen liegen unter Bauen im Fähigkeiten-Fenster. Der Modus wird im Startmenü gewählt. Speicherstände bleiben Version 2. `mode`, `buildings`, `source_level`, `refinery_level`, `energy_birth`, `energy_refined` und `refined_delivered` fehlen in älteren Ständen und gelten dann als Räumung ohne Gebäude und ohne Herkunft.

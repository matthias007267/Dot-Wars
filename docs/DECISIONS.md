# Entscheidungen

Beschlossene Punkte stehen fest, bis sie ausdrücklich geändert werden. Offene Punkte werden nicht still entschieden.

## Quellenvorrang ab 25. Oktober 2026

Die Nutzerentscheidungen D-043 bis D-050 und [GAME_DESIGN.md](GAME_DESIGN.md) bestimmen das neue Zielkonzept. Widersprechende Aussagen älterer Einträge sind historischer Prototypstand, nicht aktuelle Zielregeln. Unberührte bestehende Regeln werden nicht still geändert. Offene Balancingwerte werden nicht durch historische Preislisten als neue Forschungswerte festgelegt. Dokumentation ist keine Implementierungsfreigabe.

## Bisherige Entscheidungen und Prototypgeschichte

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


### D-030 Mehrspieler gegen KI

Datum: 22. Oktober 2026.

Mehrspieler ist ein vierter Modus. Er spielt vorläufig nur gegen KI. Ein ferner menschlicher Slot existiert als Steuerung `REMOTE` und wird nicht angeboten und nicht bewegt. Ein Netz gibt es nicht. Rote Krieger gibt es weiter nicht. Auslöschen trifft den Kern, nicht eine neue Einheit.

Bis zu drei KI-Gegner. Zusammen mit dem Spieler sind das zwei bis vier Fraktionen. Jede Fraktion hat einen eigenen Kern auf einem Ring um das bestehende Mittelkreuz. Der Hügel ist die leere Mitte des Kreuzes. Das magenta Opferloch bleibt daneben. Auf der 32er-Welt verbinden sich die Basistunnel mit dem Kreuz. Auf der 256er-Welt muss man graben. Die Farben sind Gelb für den Spieler, dann Koralle, Himmel und Minze.

Die Ziele sind eine Maske. Mindestens eines ist an. Standard sind alle vier. Auslöschen gewinnt die letzte lebende Fraktion. Der Kern hat vorläufig 160 Trefferpunkte. Ein orthogonal benachbarter gegnerischer Arbeiter nimmt einen Punkt je Takt. Bei null verschwinden die Arbeiter dieser Fraktion, ihre Reliquien werden neutral, der Kern bleibt unzerstörbar. Forschungssieg ist Stufe 5. Die Stufe kostet vorläufig 50, 100, 150, 200 und 250 und liegt unter Forschung, nur wenn das Ziel an ist. Reliquien sind fünf leere Zellen auf dem Mittelkreuz. Drei davon gehören einer Fraktion, nachdem ein Arbeiter 100 Takte unbestritten darauf steht. Streit oder eine leere Zelle setzt nur den Fortschritt zurück. König des Hügels zählt unbestrittene Belegung der Mitte. Streit oder Leere pausiert den Zähler. 600 Takte, also 30 Sekunden, gewinnen. Das erste erfüllte Ziel in der Reihenfolge Auslöschen, Forschung, Reliquien, Hügel beendet die Runde.

Die KI gräbt die ganze Karte, sobald sie kein Gebiet hat. Unter vier Arbeitern kauft sie einen Arbeiter für 10, sonst Forschung, wenn das Ziel an ist und sie sie bezahlen kann, sonst weitere Arbeiter bis acht. Sie nutzt nicht die gemeinsame Warteschlange, damit die Fraktion stimmt. Tempo und Abbau bleiben je Fraktion. Ein Kauf des Spielers beschleunigt die KI nicht. Die Kernfläche blockiert im Match die Bewegung nicht, damit ein Gegner neben dem Kern stehen kann. Quelle und Veredler gibt es in diesem Modus nicht. Die Räumungsziele feuern nicht.

Menschliche Käufe zählen weiter als `purchased_workers`. KI-Käufe zählen als `match_bought`. Entfernte Arbeiter zählen als `removed_mass`. Die Masse bleibt `Anfang + Käufe des Spielers + Käufe der KI − entfernte Masse`. Energie-Dots tragen einen Besitzer. Sie liefern nur am eigenen Kern. Fehlender Besitzer in älteren Ständen ist 0. Speicherstände bleiben Version 2. `ai_count`, `victory_mask`, `energy_owner`, `research_level` und der Match-Block fehlen in älteren Ständen und gelten dann als Einzelspieler ohne Forschung.


### D-031 Menü und KI-Schwierigkeit

Datum: 23. Oktober 2026.

Das Startmenü fragt zuerst Einzelspieler oder Mehrspieler. Danach stehen nur die Einstellungen dieser Wahl. Einzelspieler zeigt Räumung, Förderung und Veredelung. Mehrspieler zeigt die vier Ziele, die Schwierigkeit und die Zahl der KI. Weltgröße und Seed bleiben darunter. Der Spieler ist fest einer. Weitere menschliche Spieler sind weiter nicht verbunden. Eine KI auf Gemischt gilt als Mittel.

Die Schwierigkeit ändert den Plan. Leicht gräbt ein Feld von 9×9 um die eigene Basis, setzt kein Laufziel und kauft einen Arbeiter nur unter drei, ab 30 Energie und nur alle 40 Takte. Mittel bleibt der Plan aus D-030: die ganze Karte, unter vier Arbeitern ein Kauf, sonst Forschung, sonst Arbeiter bis acht. Schwer gräbt einen Korridor von der Basis zum Ziel, um zwei Zellen erweitert. Das Ziel ist der nächste lebende gegnerische Kern, sonst die nächste fremde Reliquie, sonst der Hügel, sonst die ganze Karte. Schwer kauft ab vier Arbeitern Forschung, sonst Arbeiter bis sechs, sonst zweimal Abbau, sonst einmal Tempo, sonst Arbeiter bis zehn. Ein Laufziel setzt sie nur auf eine freie Angriffszelle, den Hügel oder eine Reliquie. Gemischt gibt bei zwei KI Leicht und Schwer, bei drei KI Leicht, Mittel und Schwer.

Der Standard ist Mittel, damit bestehende Partien gleich bleiben. Die Stufe liegt in der Konfiguration und je KI im Match. Fehlt sie in einem Stand der Version 2, gilt Mittel. Die Speicherversion bleibt 2.


### D-032 Basis, Abbau, Wegfeld und Pausenmenü

Datum: 23. Oktober 2026.

Mehrspieler legt den alten Mittelkern nicht mehr an. `WorldGenerator.generate` lässt im Match das Mittelkreuz, den Starttunnel und das unzerstörbare Feld aus. Hügel und die fünf Reliquien werden einzeln geöffnet. Die Basen bleiben auf dem Ring, jede mit demselben Kreuz und einem unzerstörbaren Kern. Einzelspieler erzeugt die Welt unverändert, gleiche Seeds bleiben gleich. Der magenta Kern wird im Match nicht gezeichnet.

Die eigene Basis bekommt einen gelben Rahmen. Jede Fraktion trägt „Du“ oder „KI“ auf einer dunklen Platte über dem Kern, in ihrer Farbe und in fester Bildschirmgröße. Die Kamera startet auf dem eigenen Kern. Ein Abbaugebiet über die ganze Karte wird nicht eingerahmt, damit Mittel die Ansicht nicht zudeckt.

Ein Abbauauftrag prüft, ob markiertes Material an die freie Fläche der Gruppe grenzt. Fehlt die Verbindung, steht der Hinweis „Das Gebiet ist nicht erreichbar. Der Schwarm gräbt sich dorthin.“ und die Gruppe markiert den kürzesten Weg aus leeren und abbaubaren Zellen. Ist kein Auftrag da, oder ist im Auftrag nichts mehr abbaubar, markiert sie die nächste Ressource. Ein Laufziel unterdrückt das. So bleiben Hügel, Reliquie und eine gehaltene Nische stehen, solange der Sammelpunkt dort liegt.

Eine laufende vollständige Wegsuche setzt eine geöffnete Zelle nicht zurück. Sie liest die aktuelle Welt. Ein neues Gebiet oder ein neues Laufziel startet sie weiter neu. Nach dem Veröffentlichen folgt höchstens eine Korrektur, wenn die Welt sich während des Aufbaus geändert hat.

Im Mehrspieler zeigt die Statuskarte die eigene Masse und die eigenen Energie-Dots unterwegs. Die gegnerische Masse steht in einer eigenen Zeile. Der weltweite Abbauanteil bleibt, weil die Räumung ihn braucht. Abbaurahmen und Sammelpunkte tragen die Farbe der Fraktion.

Escape öffnet das Pausenmenü: Weiter, Speichern, Laden, Neu starten, Lautstärke und Beenden. Neu starten verwendet dieselbe Konfiguration. Beenden kehrt ins Startmenü zurück. Die Speicherversion bleibt 2. Die drei Prüfungen der Räumung bleiben.


### D-033 Gemeinsamer Marsch

Datum: 23. Oktober 2026.

Abbau und Bewegen sind ein Befehl. Die linke Taste wählt Arbeiter. Ein Zug markiert ein Rechteck, ein Klick einen Arbeiter, ein Klick ins Leere hebt die Auswahl auf. Liegen mehrere Dot-Fraktionen im Rechteck, bleibt nur die mit der höchsten Priorität. Krieger stehen über Arbeitern. Energie-Dots sind nicht wählbar. Krieger gibt es noch nicht, die Priorität ist schon festgelegt.

Die rechte Taste setzt das Ziel. Die Auswahl geht dorthin und baut die Ressourcen auf dem kürzesten Weg ab. Ein Rechtszug markiert ein Gebiet. Dieselbe Auswahl erobert es und baut alles darin ab. Kämpfen in diesem Gebiet kommt mit den Kriegern. Strg und Rechtsklick schickt dann alle Krieger. Solange keine da sind, bleibt der Schwarm stehen und ein Hinweis sagt das.

Ohne Auswahl gehen etwa zehn Prozent der eigenen Arbeiter, mindestens einer. Es sind die, die dem Ziel am nächsten stehen. Bei gleichem Abstand gewinnt die kleinere ID. Die Abordnung liegt in einer eigenen Gruppe mit Quote 0. Die übrigen Gruppen behalten ihren Auftrag. Ein Laufziel unterdrückt den Abbau der nächsten beliebigen Ressource. Felsen auf dem Weg zum Marschziel werden markiert. Ist das Ziel noch fest, wird es zum Laufziel, sobald es leer ist.

Gruppen über Strg und die Tasten 0 bis 9 kommen später. Zehn Kontrollgruppen sind vorgesehen und noch nicht belegt. Die Kamera verschiebt sich mit der mittleren Taste, WASD und den Pfeiltasten. Die Speicherversion bleibt 2. Fehlt die Befehlsgruppe in einem älteren Stand, gibt es keinen offenen Marsch. Die drei Prüfungen der Räumung bleiben.

### D-034 Hohe Abbaustufen

Datum: 23. Oktober 2026.

Die Abbauleistung bleibt der Bruch 5/4 je Stufe aus D-016, ohne Rundungsverlust. Zähler und Nenner liefen bisher über 32 Bit. Ab Stufe 14 wurde der Zähler falsch, ab Stufe 16 war der Nenner 0, und der Abbau blieb stehen. Große Einheiten treffen das früher, weil ihre Leistung den Zähler noch multipliziert.

Die Rechnung nutzt jetzt breite Ganzzahlen. Der Restbruch steht weiter in `progress_frac`, solange er in 31 Bit passt. Darüber kommen weitere Glieder dazu. Ein älterer Speicherstand ohne diese Glieder lädt wie bisher. Die Version bleibt 2. Stufe 0 dauert 20 Takte, Stufe 1 dauert 16 Takte. Die drei Prüfungen der Räumung bleiben.

### D-035 Nächstmöglicher Punkt

Datum: 23. Oktober 2026.

Ein Laufziel, ein Marsch und später ein Kriegerbefehl merken sich den gewünschten Punkt. Die Wegsuche läuft nicht auf diesen Punkt zu, wenn die Gruppe ihn nicht betreten kann. Sie sucht in der erreichbaren leeren Fläche die Zelle mit dem kleinsten Manhattan-Abstand und läuft dorthin. Ist der Punkt selbst erreichbar, bleibt er der Standpunkt. Mehrere Arbeiter sammeln sich dort und reihen sich davor auf. Eine feste oder abgeschnittene Zelle ist trotzdem ein gültiger Wunsch: der Schwarm geht so nah heran, wie die Fläche es erlaubt, und gräbt nur, wenn auf dem Weg abbaubares Material liegt.

Abbaugebiete bleiben bei der nächsten Arbeitszelle. Ein unerreichbares Gebiet wird weiter angebaggert. Die Speicherversion bleibt 2. Die drei Prüfungen der Räumung bleiben.

### D-036 Auswahl, eigene Arbeit und Karte

Datum: 23. Oktober 2026.

Ein Handbefehl überschreibt nur die Aufträge der ausgewählten Arbeiter. Ohne Auswahl bleibt der Schwarm, wo er ist, und ein Hinweis sagt „Wähle zuerst Arbeiter.“ Die Abordnung von etwa zehn Prozent aus D-033 gilt für Marsch und Eroberung nicht mehr.

Die anderen Gruppen graben weiter. Ein neues Gebiet rechnet nur das Wegfeld dieser Gruppe neu. So bleibt ein Befehl an ein paar Arbeiter stehen, ohne die übrigen anzuhalten.

Ist in der Befehlsgruppe nichts Markiertes mehr übrig und läuft niemand mehr auf das Ziel zu, fallen Laufziel, Marschzelle und Gebiet weg. Dieselben Arbeiter suchen sich danach wieder selbst die nächste Arbeitsfront, höchstens 32 angrenzende Felszellen auf einmal. Steht jemand noch auf dem Weg, bleibt der Befehl. Laufziele von Hügel, Reliquie und KI bleiben davon unberührt.

Gedrückt gehaltene rechte Taste verschiebt die Karte. Zusammen mit Strg markiert derselbe Zug ein Gebiet. Ein kurzer Rechtsklick schickt die Auswahl, Strg und ein kurzer Rechtsklick bleibt der spätere Kriegerbefehl. Mittlere Taste, WASD und Pfeiltasten verschieben wie bisher. Die Speicherversion bleibt 2. Die drei Prüfungen der Räumung bleiben.

### D-037 Schwarm-Intelligenz

Datum: 23. Oktober 2026.

Die Fähigkeit Intelligenz liegt im Fähigkeiten-Fenster unter Schwarm, neben Abbau. Sie ändert nicht die Abbaugeschwindigkeit. Sie ändert, wie die Dots ihre Felsen wählen.

Stufe 0 ist der Start. Die Gruppe teilt sich ein Wegfeld. Die Dots laufen zum selben nahen Fels und stellen sich dahinter an, wenn die Zelle belegt ist.

Jede gekaufte Stufe gibt jedem Dot ein eigenes Ziel: den nächsten markierten Fels, den noch kein Arbeiter derselben Fraktion hat. Der Weg dorthin ist sein eigener. Stufe 1 sucht 64 Zellen weit und wechselt nach 80 Takten auf derselben Zelle ohne Abbau. Stufe 2 sucht 192 Zellen und wartet 40 Takte, Stufe 3 sucht 768 und wartet 20, Stufe 4 sucht 3072 und wartet 10. Die Kosten sind vorläufig 40, 80, 120 und 160 Energie. Danach ist die Stufe voll.

Stehen auf allen Nachbarzellen eigene Arbeiter, beginnt diese neue Suche nicht. Sie wartet, bis eine Nachbarzelle frei ist. Ein Laufziel, ein Marsch und die Ziele der KI bleiben beim gemeinsamen Wegfeld. Große Einheiten ebenfalls. Speicherstände bleiben Version 2. Fehlt `swarm_level`, gilt Stufe 0. Die drei Prüfungen der Räumung bleiben.

### D-038 Reichweite der Zielsuche

Datum: 23. Oktober 2026.

Die Flächenliste einer Welt enthält nur abbaubare Zellen mit einer leeren Nachbarzelle. Sie ändert sich, wenn eine Zelle das Material wechselt, nicht bei jedem Abbaufortschritt.

Die automatische Front markiert höchstens 32 dieser Flächen, und zuerst nur solche, die höchstens 16 orthogonale Schritte von einem Arbeiter der Gruppe entfernt sind. Ist der Umkreis leer, bleibt das Ergebnis liegen. Der nächste Versuch sucht 32, dann 64, dann die ganze erreichbare Höhle, jeweils einmal. Bewegt sich ein Arbeiter um mindestens 8 Zellen oder öffnet sich in dem durchsuchten Bereich eine Zelle, beginnt die Suche wieder bei 16. Ein gesetztes Gebiet, das noch nicht erreichbar ist, wird weiter angebaggert.

Die Samen des Wegfelds sind diese Flächen, nicht jede Zelle des Rechtecks. Eine Materialänderung außerhalb von 16 Zellen um die Arbeiter, ohne Markierung der Gruppe und ohne Anschluss an das veröffentlichte Feld, lässt die Richtungen dieser Gruppe stehen. Ein neues Gebiet, ein neues Laufziel und der Kernausbau rechnen das Feld der betroffenen Gruppe weiter neu.

Ab Intelligenz-Stufe 1 merkt sich ein Dot den nächsten Schritt, solange dasselbe Ziel gilt, er stehen bleibt und sich auf den Nachbarzellen weder Material noch Belegung ändert. Eine neue Suche gibt es, wenn die Geduld abläuft, das Ziel wegfällt oder der Schritt blockiert ist. Eingekreist wartet er wie bisher.

Speicherstände bleiben Version 2. Die drei Prüfungen der Räumung bleiben. Abbaugeschwindigkeit, Auswahlbefehle und der nächstmögliche Standpunkt eines Marsches bleiben.


### D-033 Kompakte Startlichtungen und fairer Kartenrand

Datum: 24. Oktober 2026.

Die kreuzförmigen Starttunnel werden im Einzelspieler und im Mehrspieler durch eine kompakte, abgerundete 5×5-Lichtung ersetzt (Reihenbreiten 3/5/5/5/3). Der jeweilige unzerstörbare Energiekern liegt in ihrer Mitte. Pro Basis bleiben 20 zusammenhängende, begehbare Zellen. Der Aushub ist keine Abbauleistung und erzeugt keine Energie. Die bisherige `tunnel_arm_length`-Einstellung bleibt für alte Konfigurationen lesbar, steuert aber nicht mehr die Startlichtung.

Im Mehrspieler liegen die Kernzentren symmetrisch auf den vier Himmelsrichtungen. Ihr Abstand zum jeweiligen Kartenrand beträgt mindestens `max(9, floor(Weltgröße / 5))` Zellen; dadurch bleiben die Basen auch auf kleinen Karten von den Rändern und den mittigen Spielzielen getrennt. Anzahl und Zuordnung der Fraktionen bleiben unverändert. Dies ersetzt nur die Startgeometrie und Positionierung aus D-032, nicht KI, Wirtschaft, Siegbedingungen, HUD oder Minimap. Die Einzelspieler-Kartengeometrie ändert sich absichtlich auch bei gleichen Seeds; bestehende Speicherstände behalten ihre gespeicherte Welt.

### D-039 Sichere lokale Performance-Diagnostik

Datum: 24. Oktober 2026.

Dateibasiertes Speichern weist aktive oder zuvor veränderte Testlabor-Simulationen zentral vor dem Öffnen der Datei ab. Dies gilt auch nach Deaktivierung des Testlabors; bestehende reguläre Speicherstände bleiben erhalten. Technische In-Memory-Snapshots für Tests bleiben möglich.

Die vollständige Taktzeit enthält auch die abschließende Mehrspieler- und Sieglogik. Die vier bisherigen Stufenmessungen bleiben Teilmessungen: insbesondere enthält Entstehung auch Fusion, Gebäude und Energietransport, aber nicht die abschließende Match-Logik. Das Overlay kennzeichnet den letzten Tick und Stufenmittelwerte getrennt. Die Mittelwerte verwenden nur seit Erzeugung beziehungsweise Laden gemessene Takte, nicht die gespeicherte Spielzeit. Arbeiterobjekte werden als Arbeiter bezeichnet; sie sind weder Gesamtmasse noch Energie-Dots. Such- und Pfadaufträge sind Aufrufzähler, keine Zahl besuchter Zellen.

Der feste Solltakt bleibt 20 Hz mit höchstens fünf Aufholtakt-Schritten je Frame. Überschüssige Zeit wird weiterhin verworfen. Spielregeln und Speicherformat ändern sich nicht.

Der grafische Spielbetrieb speist die Taktuhr aus monotonen Mikrosekunden (`Time.get_ticks_usec`) statt aus Godots Frame-delta. Gemessen wurden bei einem 10-Sekunden-Lauf nur 8,8 Sekunden aufsummiertes Engine-delta, ohne dass die eigene Aufholgrenze erreicht wurde. Pause aktualisiert die Zeitbasis ohne Takte; Erzeugung und Laden setzen sie zurück. Nur die eigene Fünf-Takte-Grenze darf Zeit verwerfen. Diagnosezähler erfassen solche Ereignisse und den verworfenen Überhang. Der ältere `--frames`-FPS-Lauf verwendet ebenfalls reale Zeit statt Engine-delta.

`bench/live_benchmark.gd` erzeugt einen separaten Testlaborlauf mit denselben Höhlen- und Auftragsparametern wie der Headless-Benchmark. Er zeichnet FPS, reale Takte/s, reale Frame-Zeiten, Engine-delta-Summe, Aufholverluste, Stufenmittelwerte, Arbeiterzustände, Energie-Dots und Zustandsregeln auf. Eingaben sind für den Lauf gesperrt, VSync ist nur in diesem separaten Prozess deaktiviert. Reguläre Speicherstände werden nicht geschrieben.

### D-040 Diagnosekopien und semantisch identische Suchoptimierung

Datum: 24. Oktober 2026.

Eine reale Testlaborpartie mit 595 Arbeitern, Welt 256 und Intelligenz 4 reproduzierte etwa 1 FPS. Auch nach Umschalten von 4× auf 1× blieb sie langsam. Die bisherige künstliche Benchmark-Höhle ist kein ausreichender Nachweis für diese Spielsituation.

F7 exportiert nur im aktiven Testlabor eine neue, eindeutig benannte Diagnosekopie unter `user://diagnostics/`. Reguläre Slots und Autosave werden nicht verwendet. Dies ist ein expliziter Diagnoseexport, keine Freigabe regulärer Testlabor-Saves. `bench/snapshot_probe.gd` vergleicht alle Intelligenzstufen über je 60 Takte am identischen gespeicherten Ausgangszustand; `bench/snapshot_benchmark.gd` misst diesen Zustand mit normaler Darstellung und gesperrten Eingaben.

Die inneren BFS-Schleifen der individuellen Suche und gemeinsamen Wegfelder verwenden lokale Arrayreferenzen und direkte Kantenprüfungen statt vieler Hilfsaufrufe. Für Welten bis 262.144 Zellen wird die unveränderliche Nachbarschaft in höchstens 4 MiB gespeichert; größere Welten bleiben bei direkten Randprüfungen. Suchbudgets, Nachbarreihenfolge, Zielwahl und Kollisionsregeln bleiben gleich. Der reale Diagnosefall ergibt für jede Intelligenzstufe nach der Optimierung exakt dieselbe Zustandsprüfsumme wie davor.

Die Optimierung verbessert den konkreten Fall, erreicht aber keine flüssigen 60 FPS. Mit Editor-Debugger sind in einem separaten Snapshot-Grafiklauf weiterhin nur etwa 3 FPS gemessen. Änderungen an Simulationsrate, Aufholgrenze oder Spielregeln wurden nicht vorgenommen.

### D-041 Nativer Rechenkern und räumliche Kampfprüfung für große Populationen

Datum: 24. Oktober 2026. Vom Nutzer ausdrücklich als Performance-Arbeit mit Ziel 10.000 Dots freigegeben.

Die gemessenen Raster-Kernschleifen erhalten einen optionalen Godot-4.3-GDExtension-C-Rechenkern. Individuelle BFS, gemeinsame Wegfeldausbreitung, Suche nach dem nächstmöglichen Marschstandpunkt und gebündelte Nachbarschaftssignaturen verwenden dieselben Budgets, Richtungsreihenfolgen und Auswahlregeln. Frühes Ende der Marschsuche ist nur bei Distanz null erlaubt, da ausschließlich die Zielzelle selbst diesen Abstand hat. Zustand, Spielregeln und feste 20-Hz-Taktung bleiben in GDScript. Die Referenz bleibt mit --no-native ausführbar; der Adapter fällt bei fehlender Bibliothek auf sie zurück. Weder Threading noch eine neue Kampfeinheitenart werden eingeführt.

Kernschaden prüft die vier Belegungszellen neben jedem Kern statt sämtliche Arbeiter gegen sämtliche Kerne. Einheiten-IDs werden pro Kern dedupliziert; Schaden aller Kerne wird weiterhin vor Auslöschungen ermittelt. Reliquien und Hügel verwenden die bestehende eindeutige Zellbelegung. Das Entfernen einer Fraktion erhält die ursprüngliche Swap-Reihenfolge in einem linearen Durchlauf und berechnet die maximale Einheitengröße einmal nach dem Batch neu.

Native und Referenz werden pro Takt verglichen; die reale 595-Arbeiter-Diagnosekopie behält auf Intelligenz 0 bis 4 dieselben Endhashes. Zusätzliche Regressionen vergleichen Kernschaden und Massenauslöschung bei 10.000 Einheiten mit der ursprünglichen vollständigen Suche. Ein reproduzierbarer Vier-Fraktionen-Benchmark erfasst Marsch und tatsächlichen Kernschaden mit 10.000 Dots. Da Marschaufträge individuelle Bergbauzielsuche deaktivieren, ist zusätzlich der deutlich schwerere dichte Abbaulastfall verpflichtend auszuweisen. Ein hoher FPS-Wert allein gilt nicht als Nachweis stabiler 20 Takte/s.

Der Quelltext und plattformspezifische Buildskripte werden versioniert, erzeugte Bibliotheken nicht. Linux-CI baut vor dem Import und prüft native sowie Referenzausführung. Der Windows-Build wurde lokal ausgeführt; Linux-CI und Release-Export gelten erst nach tatsächlichem Lauf als geprüft. Details, Bauanleitung und Grenzen stehen in native/README.md und docs/LOCAL_DIAGNOSTICS.md.
### D-042 Identische native Bewegung und Energietransport im dichten Schwarm

Datum: 24. Oktober 2026. Gezielte Fortsetzung der vom Nutzer freigegebenen Performance-Optimierung.

Die reale Folgepartie mit 8.700 Arbeitern erreicht bei 1× nur 2,62 FPS und 13,12 tatsächliche Takte/s. Je 60 Takte ohne Grafik benötigt Intelligenz 4 etwa 74,14 ms pro Takt; Bewegung/Ausweichen macht 39,37 ms aus. Dieser gewachsene Abbauzustand ist die primäre Reproduktion, der offene Marschbenchmark kein Ersatz.

Für ausschließlich normale 1×1-Einheiten führt die GDExtension die vollständige Bewegungsphase aus. ID-Reihenfolge, Fraktionstempo, Beschleunigungsrest, persönlicher Schritt, Abbauzielwahl, frontaler Tausch und seitliches Ausweichen bleiben identisch. Der native Aufruf liefert veränderte Arrays ausdrücklich zurück. Eingabeformen und Indizes werden geprüft; verschmolzene Einheiten oder nicht unterstützte Eingaben verwenden die ausführbare GDScript-Referenz. Es wird keine parallele oder spekulative Reihenfolge eingeführt. Der temporäre Rechenkern speichert keine eigene laufende Kopie der Einheiten.

Energie-Dots im Einzelspieler erhalten eine gebündelte native Schrittsuche. Reihenfolge N/O/S/W, Blockade durch Arbeiter und Lieferung anhand der Position vor dem Schritt bleiben erhalten. Energiebilanz, Herkunft, Veredelung und Besitzer bleiben in GDScript. Die Distanzfelder nutzen die vorhandene native Multi-Source-BFS; deren Kantenreihenfolge ist für reine kürzeste Distanzen unerheblich und wird gegen die ursprünglichen Felder geprüft. Fraktionsgebundener Energietransport bleibt bei der bisherigen Schrittauswahl, verwendet aber ebenfalls die schnelle Distanzberechnung.

SwarmMind verwendet lokale Referenzen auf dieselben gepackten Arbeiterdaten und einmal pro Takt gelesene Gruppenziele. Weder Such-/Pfadbudgets noch Zustandsaktualisierungen werden ausgelassen. Alle fünf 60-Takte-Endhashes der 8.700-Arbeiter-Kopie bleiben identisch. Vollständige Tests laufen mit nativer Bibliothek und mit --no-native; zusätzliche Vergleichstests prüfen Bewegung bei Fraktionstempi und Beschleunigung, Energiebewegung, ungültige Positionen und Distanzfelder nach Weltänderungen.

Zusätzliche nicht gespeicherte Profilzähler teilen die Zielsuche in Führung, Anker, Wegfelder und Schwarmverwaltung auf. Die feste 20-Hz-Taktung und die bestehende Aufholgrenze bleiben unverändert. Die Optimierung löst damit noch keine außerhalb des Spielcallbacks gemessenen langen Frame-Pausen. Einbau oder Freigabe einer anderen Takt-/Thread-Architektur ist nicht Bestandteil dieser Änderung.
## Neue Konzeptentscheidungen vom 25. Oktober 2026

Die folgenden Einträge dokumentieren Nutzerentscheidungen. Ihr Status ist Zielkonzept, nicht Implementierungsnachweis. Der vollständige Wortlaut und die offenen Präzisierungen stehen in [GAME_DESIGN.md](GAME_DESIGN.md), die Abweichungen in [CONCEPT_SYNC.md](CONCEPT_SYNC.md).

### D-043 Welt, Erkundung und Lobby

Die prozedurale Welt soll nahezu endlos sein; die Multiplayer-Kartengröße ist in der Lobby frei einstellbar. Pixelweiser Abbau einschließlich diagonaler Abbauwege, unzerstörbare Felsen und natürliche Höhlen gehören zum Ziel. Versteckte gegnerische Außenposten werden ausschließlich durch Erkundung gefunden. Weltgrenzen, Lobbygrenzen, Kartenform, Höhlengenerierung und diagonale Eck-/Bewegungsregeln sind noch zu präzisieren. Die heutige endliche quadratische Karte und ihre vier Nachbarn sind Implementierungsbestand, keine Beschränkung dieses neuen Ziels.

### D-044 Arbeiter, Krieger und Kollision

Vorläufig maximal 50 Arbeiter pro Spieler; mehrere Tausend Krieger pro Spieler sind das Skalierungsziel. Einzelne Dots und Gruppen bleiben frei auswählbar. Arbeiter blockieren sich gegenseitig. Alle Krieger blockieren sich gegenseitig, einschließlich verbündeter Krieger. Eigene Krieger dürfen eigene Arbeiter durchqueren. Weitere Durchquerungs- oder gemeinsame Endpositionsregeln werden nicht hinzuinterpretiert.

Feindliche Krieger greifen Arbeiter bei Kontakt automatisch an. Krieger reagieren selbstständig auf Gegner in einem kleinen Verteidigungsradius und kämpfen ausschließlich im Nahkampf. Angegriffene Arbeiter arbeiten bis zu ihrem Tod oder einem neuen Befehl weiter. Kampfwerte und die noch fehlenden Randregeln sind offen. Die genaue Limitzählung einschließlich Produktion und Verschmelzung ist noch nicht entschieden. Alte Arbeiter-Massenbenchmarks weisen Kriegerskalierung nicht nach.

### D-045 Produktionsgebäude, Kernbau und Überleben

Nur Hauptkerne und Außenposten produzieren Arbeiter und Krieger. Der Hauptkern ist größer und widerstandsfähiger, ansonsten besitzen beide dieselben Grundfunktionen. Außenposten sind kleiner und von fester Größe; ihre Baukosten steigen mit ihrer Anzahl. Ein Hauptkern kann auf einem normalen Bauplatz für einen festen Energiepreis neu gebaut werden.

Ein Kernbau zählt ab dem ersten tatsächlichen Arbeiterbeitrag als begonnen. Er verhindert die Niederlage auch ohne Arbeiter und ohne fertigen Kern. Ein bloßer Baubefehl reicht nicht. Größen, Preise, Bau- und Produktionszeiten, Zählweise der Außenposten und die vollständige Niederlagebedingung einschließlich fertiger Außenposten bleiben zu klären. Es wird kein automatischer Ablauf verlassener Kernbaustellen erfunden. Die heutige sofortige Fraktionsauslöschung bei Kernzerstörung erfüllt die neue Regel nicht.

### D-046 Physische Energie, Verfall und Abfangen

Energie bewegt sich physisch über freie Wege zu einem eigenen Kern; erst die Ankunft schreibt Guthaben gut. Ohne erreichbaren Empfänger verschwindet Energie nach 60 Sekunden ohne Route. Routenbegriff, Timerunterbrechung, Zeitbasis und Auswahl unter mehreren eigenen Empfängern sind noch festzulegen.

Nur Abfanggebäude können gegnerische Energie stehlen. Sie kann unbegrenzt oft erneut abgefangen werden und muss jeweils physisch zu einem Kern des neuen Besitzers gelangen. Bei Zerstörung einer Abfangstation wird nur die noch nicht weitertransportierte Energie neutral und wieder abfangbar. Bereits weitertransportierte Energie bleibt davon unberührt. Die Detailmechanik von Puffern, neutraler Energie und konkurrierenden Stationen ist offen; Besitzwechsel darf nicht als zusätzliche Energieerzeugung verbucht werden.

### D-047 Sichtwissen und Verbündete

Solide Pixel und Gebäude blockieren die Sicht. Gegnerische Dots verschwinden unmittelbar bei Sichtverlust. Entdeckte gegnerische Gebäude bleiben im zuletzt bekannten Zustand sichtbar; Veränderungen außerhalb der Sicht werden erst bei erneuter Erkundung bekannt. Verbündete teilen Sicht und Erkundung vollständig, behalten jedoch getrennte Energiekonten.

Weltzustand und Spielerwissen sind deshalb getrennt zu betrachten. Die Regel gilt auch für Minimap, Auswahl und sonstige Rückmeldungen. Algorithmus, Sichtweiten, Aktualisierung und Wissen bei Bündniswechseln sind noch nicht entschieden. Der heutige Zugriff der Minimap auf die unfiltrierte Welttextur ist lediglich Prototypbestand.

### D-048 Gebäude, Forschungspflicht und manuelle Reparatur

Am Spielbeginn ist als Gebäude nur der Hauptkern verfügbar. Alle anderen Gebäude müssen erforscht werden. Geplant sind Außenposten, Mauern, Energiefarmen, Energie-Abfangstationen und Aufklärungssensoren mit größerem Sichtbereich. Es gibt keine separaten Dot-Fabriken, Forschungslabore oder automatischen Verteidigungstürme; Verteidigung erfolgt durch Mauern und Krieger.

Mauerlinien werden beim Ziehen in einzelne Segmente aufgeteilt. Gebäude brauchen freien Baugrund und werden von Arbeitern errichtet. Reparaturen kosten Energie und benötigen manuell zugewiesene Arbeiter; automatische Reparaturzuweisung ist nicht beschlossen. Mechanik und Zahlen der neuen Gebäude sind offen. Quelle/Veredler aus dem Prototyp werden weder still gelöscht noch ohne Entscheidung umbenannt.

### D-049 Globale zeitbasierte Parallelforschung

Forschung läuft global je Spieler ohne Forschungsgebäude. Beim Start wird der gesamte Energiepreis bezahlt; anschließend läuft die Forschungszeit. Mehrere Technologien können gleichzeitig erforscht werden. Forschung schaltet Gebäude und Verbesserungen frei. Mehrstufige Upgrades erhalten steigende Kosten und feste Maximallevel.

Die Zweige Wirtschaft, Militär, Infrastruktur und Energietechnik sind Vorschläge. Konkrete Technologien, Level, Kosten, Zeiten, Abhängigkeiten und Abbruchregeln sind nicht beschlossen. Der heutige sofortige Upgrade-Kauf und der alte Forschungssieg sind kein implementiertes Parallelforschungssystem. Historische Preislisten werden nicht als neuer Forschungsbaum bestätigt.

### D-050 Planungspause, Bestandsschutz und Prioritäten

Der Auftrag vom 25. Oktober 2026 erlaubt den Abgleich und die Dokumentation, keine neuen Spielsysteme oder größeren Architekturänderungen. Frühere Performance-Aufträge sind keine fortdauernde Freigabe zur Umsetzung des neuen Konzepts. [ROADMAP.md](ROADMAP.md) und [CONCEPT_SYNC.md](CONCEPT_SYNC.md) enthalten nur vorgeschlagene spätere Pakete; jedes braucht einen ausdrücklichen Implementierungsauftrag.

Bestehender Code, Native-Backend, Tests und Speicherstände bleiben in dieser Synchronisierung unverändert. Alte Modi, Verschmelzung, Quoten und Version-2-Spielstände werden nicht ohne Folgeentscheidung entfernt oder migriert. Historische Entscheidungen bleiben lesbar, widersprechende Zielregeln werden aber nicht mehr als aktuelles Konzept ausgegeben. Die Zielgrößen verschieben sich von Massenarbeitern zu wenigen Arbeitern und großen Kriegerarmeen. Endlose Welt, Sichtwissen, Kampf und Netzwerk gelten nicht aufgrund vorhandener Worker-Benchmarks als umgesetzt.


### D-051 Einheitenphase und drei ausdrückliche Folgeentscheidungen

25. Oktober 2026, nach der Planungspause ausdrücklich beauftragt. Fusion wird vollständig aus dem aktiven Spiel entfernt. Eigene Krieger dürfen eigene Arbeiter ausschließlich durchqueren; jede Endposition muss frei sein. Alle Krieger blockieren sich, auch Verbündete. Die alten Solo-Siegziele werden auf ausdrücklichen Wunsch ganz deaktiviert, nicht auf das neue Arbeiterlimit angepasst. Das vorläufige Limit von 50 Arbeitern pro Spieler reserviert bereits bezahlte Warteschlangenplätze; Krieger zählen nicht dazu.

Die Phase liefert einen spielbaren Nahkampf-Prototyp mit ausdrücklich erlaubten vorläufigen Werten. Außenposten, Forschung und Weltumbau folgen später. Keine automatische Fortsetzung auf sämtliche neuen Konzeptpakete; kein Commit oder Shutdown aus der alten unbeaufsichtigten Planungssitzung.

### D-052 Vorläufige Kampf-/Produktionsparameter und deterministischer Ablauf

Krieger: 20 Energie bei Bestellung, 20 Takte bis frühester Platzierung, 12 HP, 1 Schaden, 10 Takte Angriffspause, 2 Takte je durchlaufener Zelle; Arbeiter 5 HP. 20 Takte entsprechen bei 1× einer Sekunde. Werte dienen dem Testen und sind kein endgültiges Balancing. Fällige Bestellungen warten bei fehlendem freien Platz. Mehrere Bestellungen dürfen parallel reifen; ein endgültiges Warteschlangen-/Kapazitätsmodell je Gebäude ist nicht beschlossen. Produktion erfolgt derzeit allein am vorhandenen Kern.

Nach Arbeiterbewegung, Abbau und Energie folgen Kriegerproduktion, Bewegung, Kontaktangriffe und gemeinsame Trefferauswertung. Krieger handeln nach stabilen IDs; Treffer werden gesammelt, bevor Tote entfernt werden. Gegner im Manhattan-Radius 3 lösen gestaffelt alle fünf Takte eine lokale Verfolgung aus. Nahkampf gilt bei orthogonalem Kontakt; bei Gleichstand Krieger vor Arbeitern, dann Zeilen-/Spaltenfolge. Keine automatische Flucht angegriffener Arbeiter. Ein eigener Arbeiterkorridor kann in einem diskreten Schritt bis zur nächsten freien Zelle passiert werden; die Bewegungspause wächst um die gesamte Strecke. Eine gemeinsame stehende Belegung entsteht nie.

Marschwege teilen deterministische Terrain-Wegfelder (bis 16 Zielzellen, Invalidierung bei Weltänderung). Die kurze Verteidigungssuche bleibt im Radius 3 um die aktuelle Zelle, statt pro Gegner die ganze Welt zu durchsuchen. Lange Umwege bei defensiver Verfolgung sind damit nicht abgedeckt. Dynamische Blockaden führen derzeit zum Warten; kein ausgereiftes Armee-Stau-/Formationssystem. Die bestehenden Match-Modi einschließlich Kernverlust bleiben Prototypbestand bis zur separaten Bau-/Überlebensphase. Interne Teamzuordnung ist keine fertige Bündnis-/Sichtfunktion.

### D-053 Einheitenreferenzen und additive Version-2-Kompatibilität

Krieger verwenden dichte Datenarrays und dauerhaft stabile, getrennt markierte Auswahl-IDs; ein Renderer zeichnet alle Krieger. Keine Node je Krieger. Speicherformat 2 erhält additive Kriegerdaten einschließlich Produktionswarteschlange, Lebenspunkten, Zielen und Abklingzeiten. Fehlende Kriegerdaten bedeuten eine leere Armee; alte Arbeiter erhalten 5 HP. Fusionierte Altarbeiter werden beim Laden entsprechend ihrem Fußabdruck in einzelne Arbeiter aufgeteilt, ohne Massenverlust; die aktiven Fusions-Upgrades bleiben gesperrt. Alte Populationen über 50 werden erhalten, aber weitere Käufe blockiert. Alte Solo-Siege werden zurückgesetzt. Reguläre Speicherdateien werden durch Diagnosefixtures nicht verändert.

Gesonderte Bilanzen: Arbeitermasse einschließlich wartender Käufe = Anfangsmasse + Käufe − Fraktionsentfernung − Kampftode; Krieger bezahlt − verloren = lebend + wartend. Ungültige Armee-Daten, Belegungsüberlappungen und nicht vorhandene Besitzer werden beim Laden abgelehnt. Die ausführbaren Nachweise und verbleibende Leistungsgrenze stehen in UNIT_PROTOTYPE.md.

### D-054 Gemessene Armee-Arithmetik nativ, Regeln unverändert

25. Oktober 2026. Nach Abschluss des Einheitenprototyps mit „gehe jetzt den nächsten Schritt vor“ als nächster gemessener Engpass freigegeben. Kontaktabfragen, lokale Verteidigungs-BFS und sequentielle Bewegung erhalten einen optionalen nativen Ganzzahl-Rechenpfad. Parameter stammen aus dem bestehenden GDScript-Modell, Reihenfolge bleibt nach stabilen IDs und dynamische Belegung wird innerhalb des Takts weitergegeben. Gemeinsame Terrain-Felder bleiben im Adapter; bei mehr als 16 verschiedenen Marschzielen, alter/fehlender Bibliothek oder expliziter Referenzwahl läuft die GDScript-Armee. Das ist kein Befehlslimit. Treffer werden gesammelt zurückgegeben, HP/Tode/Bilanzen und Produktion bleiben in GDScript.

Windows baut eine separate v4-Bibliothek; bereits geladene v3-Dateien werden nicht überschrieben. Keine Threads, keine Änderung an 20 Hz, Aufholgrenze, Geschwindigkeit, Angriffswerten, Saveformat oder Spielregeln. Die Farbpalette der gemeinsamen Kriegertextur wird pixelgleich effizienter geschrieben. Der Grafikbenchmark erhält einen expliziten FPS-Cap-Parameter, der normale Spielbetrieb keinen neuen Limiter.

Taktweise Gleichheitstests, ungültige Eingaben, Renderer und beide vollständigen Test-Backends bestehen. 10.000 Krieger benötigen im bisherigen Marschfall im Mittel 2,61 statt 95,63 ms pro Takt; ein zusätzlicher Kontaktfall hält 10.000 tatsächlich lebende Krieger während aller 40 Takte. Grafisch werden bei 60-FPS-Grenze im isolierten Vergleich 53,84 FPS und 19,68 Takte/s (weiterer Lauf: 48,41 FPS / 19,26 Takte/s) erreicht, einzelne lange Frames sind noch nicht nach Ursache isoliert. Dies ist keine Gesamtfreigabe für Welt/Bau/Forschung/Sicht/Netzwerk und keine vollständige Langzeit-Skalierungsabnahme. Messungen und Grenzen in ARMY_PERFORMANCE.md.

### D-055 Stabilitätsauftrag 1–3 und nachgewiesene Windows-Frame-Ursache

25. Oktober 2026. Der Nutzer beauftragt ausdrücklich die drei vorgeschlagenen Prüfungen: lange Frames, schwierige Marsch-/Blockadesituationen und eine längere gemischte Partie. Dabei gefundene Fehler werden gezielt behoben. Keine Freigabe für Welt-/Bau-/Sicht-/Forschungs-/Netzwerk-Folgephasen oder Veröffentlichung.

Die gemessenen 150–450-ms-Frames entstehen auch im leeren Windows-Fenster ohne Simulation/Render-Loop, nicht im identischen Headless-Lauf. Fensterprozedur-Tracing weist wiederholte WM_DEVICECHANGE / DBT_DEVNODES_CHANGED mit rund 149 ms je Aufruf nach; Godot 4.3 startet dabei synchron seine Controller-Suche. Ein auf das eigene Fenster beschränkter Filter überspringt ausschließlich allgemeine Meldungen bei identischer Raw-Input-Geräteliste. Ankunft/Entfernung, Eingabegeräteänderungen und Fehler werden weitergeleitet. HID-/XInput-Schnittstellenbenachrichtigungen bleiben angemeldet; die ursprüngliche Fensterprozedur wird beim Abschalten wiederhergestellt. Keine Geräte oder Treiber werden deaktiviert. Die Quelle der wiederholten Gerätebaumänderungen ist nicht bestimmt. Opt-out: --no-device-change-guard. Synthetische Weiterleitungs-/Wiederherstellungsprüfung und reale Grafikläufe bestehen; ein physischer Controller-Stecktest bleibt offen. Nachweise in STABILITY_VALIDATION.md.

### D-056 Exakte Viele-Ziele-Wege mit begrenztem Cache

Der v7-Rechenpfad ersetzt den alten Rückfall ab 17 Zielen durch Terrain-Cache, freie Rechteck-/L-Nachweise, sofortige Blockadeprüfung und vollständige BFS-Felder. Seltene Ziele nutzen bei bis zu 256 Hindernisecken einen exakten rechtwinkligen Sichtgraphen; andernfalls bleibt die vollständige BFS zuständig. Für seltene Ziele werden bei verfügbarem Graphpfad höchstens acht neue Vollfelder je Takt vorgewärmt, ohne Bewegung zu verschieben: Der Graph entscheidet sofort. Häufige gemeinsame Ziele erhalten weiterhin gemeinsame Vollfelder. Reguläres Feldbudget 32 MiB, höchstens 128 Felder; mindestens ein Feld auch bei größerer Einzelkarte. Keine Zusage für beliebige Weltgrößen.

Jede Graphkante ist ein überprüfter freier Weg. Zielendpunkte und eigene Arbeiterkorridore werden in der bisherigen Richtungsfolge mit derselben Zeitbelastung geprüft. Keine Näherungswege, Stau-Teleports, neuen Durchquerungsrechte oder geänderten Kampfwerte. Cache-Kohärenz vergleicht tatsächliche Terrainbytes auch zwischen Welten mit gleicher Revision. Taktweise Referenztests und Graph-Einsatzzähler sichern den neuen Pfad ab. 10.000 Einzelziele in offener Welt erreichen rund 2,68 ms/Takt; der kombinierte Labyrinthfall im längeren Test 26,58 ms/Takt, p95 30,75 ms. Grenzen und Rohdaten im Prüfbericht.

### D-057 Additiver Resume-Zustand für exaktes Fortsetzen

Die gemischte Prüfung fand bei Takt 504 nach dem Laden einen anderen Arbeiterschritt, weil laufende/veröffentlichte Wegfelder sowie individuelle Wegschritte bisher neu aufgebaut wurden. Neue Version-2-Stände enthalten deshalb additive, streng validierte Resume-Daten für die inkrementellen Wegfelder, Weltänderungslog und Frontreihenfolge, Energierouten/Neuaufbautakt, Arbeitsfront, tatsächliche Chunkgröße und individuelle Arbeiterschritte/Bewegungsreste. Alte Stände ohne Resume-Block bleiben lesbar; ein ungültiger vorhandener Block wird abgelehnt.

Snapshot- und Binär-Fortsetzungstests bleiben identisch. Normale Spielstände werden nicht durch Diagnosefixtures überschrieben. Synchrones Speichern eines großen Zustands kostet in der lokalen Messung rund 42 ms zuzüglich Datei-I/O; dies wird nicht durch speicherfreie Grafikfixtures als gelöst ausgegeben. Keine asynchrone Speicherarchitektur, kein Versionssprung und keine Übertragung des nativen Cache-Speichers als Spielzustand. Details in STABILITY_VALIDATION.md.

### D-058 Bauphase beauftragt, Detailentscheidungen offen

25. Oktober 2026. Nach der Empfehlung für Gebäude-/Baustellendaten, Arbeiterbau, Ersatzkern und Außenposten lautet der ausdrückliche Folgeauftrag: „Dann starte den Durchlauf“. Die Bauphase ist damit beauftragt. Bauwerte, Forschungsfreigabe und vollständige Niederlage-/Außenposten-Empfängerregel sind als strukturierte Rückfragen gestellt; eine unbeantwortete Vorauswahl gilt nicht als Zustimmung. Die unabhängige gemeinsame Datenhaltung in settlement_store.gd mit stabilen IDs, Besitzer, Fläche, HP und geplant/begonnen/fertig/zerstört ist erstellt und durch 4 Tests / 31 Prüfungen abgesichert. Sie ist noch nicht an die spielbare Produktion angeschlossen. Keine neuen Balancingkonstanten oder Forschungsausnahmen festgeschrieben. Umfang, Vorschläge und Integrationsplan in CONSTRUCTION_PHASE.md. Bestehende Spielstände und laufende Partien bleiben in diesem vorbereitenden Schritt unverändert.

## D-059 – Bauwerte, Testfreigabe und Überleben ausdrücklich bestätigt (25. Oktober 2026)

Die drei strukturierten Antworten sind eingetroffen: „Diese Testwerte verwenden“, „Im normalen Spiel gesperrt; zum Testen im Testlabor freischalten“ und „Diesen Vorschlag verwenden“. Damit gelten vorläufig Hauptkern 5×5/600 HP/500 Energie/600 Arbeiter-Takte und Außenposten 3×3/200 HP/(200 + 100 je vorhandenem oder begonnenem Außenposten)/300 Arbeiter-Takte; mehrere Arbeiter bauen gemeinsam. Außenposten bleiben bis zum künftigen Forschungsbaum im normalen Spiel gesperrt, im Testlabor freischaltbar. Fertige Außenposten erhalten das Weiterspielen nach Hauptkernverlust und empfangen Energie. Niederlage erst ohne fertigen eigenen Kern/Außenposten und ohne tatsächlich begonnenen Hauptkernbau; vorläufig höchstens ein fertiger oder geplanter/begonnener eigener Hauptkern. Ein bloß bezahlter Plan schützt nicht.

Die zuvor offenen Rückfragen in D-058 sind damit beantwortet. Lokal integriert: authoritative stabile Gebäudedaten, Bauflächenreservierung, manuell zugewiesene Arbeiter mit gemeinsamer Randarbeit, Produktionsauswahl und gemeinsame 50er-Grenze, Gebäudenahkampf und Ersatzkern-/Niederlageprüfung, physischer Energieempfang an allen fertigen eigenen Standorten und additive Version-2-Speicherung mit Altstand-Import. Zusätzliche ausdrücklich vorläufige Ausführungsdetails (Bau-HP, reservierte Außenposten zählen zum Preis, Warteschlangenverlust ohne Erstattung, alte Kernflächen-Upgrades nur für Altkerne) stehen in CONSTRUCTION_PHASE.md und bleiben von genehmigten Zahlen getrennt. Welt/Fog/Forschung/Netzwerk werden nicht als mitumgesetzt ausgegeben. Keine Commits/PRs oder Abschaltung aus diesem Auftrag.


## D-060 – Folgeauftrag Reparatur, Abbruch und KI-Bauplanung (25. Oktober 2026)

Nach der abgeschlossenen Bauphase nennt die unmittelbar vorangehende To-do-Antwort drei konkrete Aufgaben: manuelle Reparaturen, Baustellenabbruch und KI-Bauplanung für Außenposten/Ersatzkerne. Der Nutzer beauftragt „Dann arbeite Punkte 1-3 ab“. Das ist diese Folgephase, nicht eine neue Freigabe der älteren Leistungs-Punkte oder anderer großer Systeme.

Lokal umgesetzt: explizite eigene Arbeiterzuweisung zur Reparatur fertiger eigener Standorte mit Energiezahlung, Pausieren ohne Energie und Beenden durch neuen Auftrag/Tod/Fertigstellung; Baustellenabbruch mit freier Fläche, korrektem Schutzverlust und gespeicherter Rückzahlung; deterministische KI-Bauplanung mit bezahlten erreichbaren Standorten, Forschungs-/Remote-Sperre, Ersatzkernpriorität und Ersatz ausgefallener Bauarbeiter. Die KI führt keine automatische Reparaturzuweisung aus.

Neue Reparatur-/Erstattungszahlen wurden als konkrete vorläufige Implementierungsannahmen zur Änderung angeboten: pro Arbeiter alle vier Takte bis zu zwei HP für eine Energie; voller tatsächlich bezahlter Baupreis nur vor dem ersten Beitrag und ohne Schaden, danach keine Erstattung. Diese Zahlen sind kein ausdrücklich bestätigtes endgültiges Balancing. Vorläufige KI-Ausbaupolitik, Grenzen und vollständiger Prüfstand stehen in MAINTENANCE_PHASE.md. D-059 zu Bauwerten, Forschungsfreigabe und Überleben bleibt gültig; außerhalb der Testlabor-Freigabe baut auch die KI keine Außenposten. Welt/Fog/Forschung/Netzwerk/Energieraub und 60-Sekunden-Verfall sind nicht mitbeauftragt. Keine Commits/PRs/Abschaltung aus diesem Auftrag.


## D-061 – Reparatur- und Abbruchtestregeln ausdrücklich bestätigt (25. Oktober 2026)

Die nachgereichte strukturierte Antwort lautet „Diese Testregeln verwenden“. Damit sind folgende bereits implementierte Regeln ausdrücklich für die Testfassung bestätigt: je manuell zugewiesenem Arbeiter alle vier Takte bis zu zwei HP Reparatur für eine Energie (bei 20 Takten/s zehn HP/s); ohne Energie wartet der Auftrag. Baustellenabbruch vor dem ersten Arbeitsbeitrag erstattet den vollen tatsächlich gezahlten Baupreis, sofern kein Schaden vorliegt. Nach Baubeginn oder Schaden erfolgt keine Erstattung.

Die Regeln bleiben vorläufiges Balancing. Diese Bestätigung präzisiert den Status der Reparatur-/Erstattungsannahmen aus D-060; sie bestätigt nicht automatisch die separat dokumentierten KI-Ausbauwerte oder weitere Phasen. Keine Codeänderung erforderlich: Die geprüfte Umsetzung entspricht der Antwort bereits.


## D-062 – Energiephase ausdrücklich beauftragt (25. Oktober 2026)

Der Nutzer beauftragt „Arbeite Punkte 1-3 ab“ zur unmittelbar zuvor genannten Energieliste: 60-Sekunden-Verfall ohne Route, Abfangstationen und Zerstörung/Neutralisierung mit vollständiger Transportbilanz. Diese Phase umfasst die dafür notwendigen Gebäude-, Speicher-, UI- und Diagnoseanschlüsse. D-059/D-061 bleiben erhalten; keine neue Freigabe für Fog, Forschungsbaum, Welt oder Netzwerk.

Für den testbaren Durchlauf wurden offene Einzelheiten als vorläufige Testfestlegungen zur Änderung angeboten: 1.200 aufeinanderfolgende Simulationstakte ohne eigene Terrainroute, Stau durch Einheiten zählt nicht, gültige Route setzt zurück; Station 3×3/150 HP/250 Energie/300 Arbeitertakte, zunächst nur im Testlabor; Randkontakt, acht Punkte/Takt, 256 Plätze, zwanzig Takte Puffer; neutrale Energie wartet am Ort und unterliegt ebenfalls dem Routenverfall. Diese Werte sind bis zu einer ausdrücklichen Bestätigung keine endgültigen Balancingentscheidungen. Eigentumswechsel ohne neue gültige Route startet die Frist nicht neu. Konkurrenz wird über stabile Stations-IDs aufgelöst; verbündete und eigene Energie werden nicht gestohlen.

Die Bilanz lautet erzeugt = geliefert + verfallen + unterwegs, mit unterwegs = frei mit Besitzer + gepuffert + frei neutral. Abfangen/Neutralisierung sind reine Übergänge; Kontoausgaben und genehmigte Bauabbrüche bleiben separate Banktransaktionen. Geliefert wird genau einmal bei tatsächlicher Ankunft am Empfänger des aktuellen Besitzers gutgeschrieben. Stationszerstörung neutralisiert nur noch gepufferte Punkte und lässt bereits freigegebene Transporte unverändert. Die Station ist weder Produktionsort noch Bankempfänger noch Niederlageschutz. Additive Version-2-Persistenz hält Fristen und Pufferbindungen; Altstände starten ohne erfundene historische Verfallszeiten. Details, Tests und Grenzen in ENERGY_PHASE.md. Keine Commits/PRs oder Abschaltung aus diesem Auftrag.


## D-063 – Energie-Testregeln ausdrücklich bestätigt (25. Oktober 2026)

Die nachgereichte strukturierte Antwort lautet „Diese Testregeln verwenden“. Damit sind die angebotenen Regeln ausdrücklich für die Testfassung bestätigt: Verfall nach 1.200 aufeinanderfolgenden Simulationstakten ohne freien Terrainweg zum eigenen fertigen Kern/Außenposten; Einheitenblockaden zählen nicht, eine wieder verfügbare Route setzt den Timer zurück. Abfangstation 3×3, 150 HP, 250 Energie, 300 Arbeiter-Takte; zunächst nur im Testlabor freischaltbar. Abfangen am direkt angrenzenden freien Rand, bis zu acht Energiepunkte je Takt, maximal 256 Pufferplätze und Weitergabe nach zwanzig Takten. Neutrale Energie bleibt am Ort und unterliegt ebenfalls dem 60-Sekunden-Verfall ohne erneutes Abfangen mit gültiger eigener Route.

Diese Bestätigung präzisiert den Status der angebotenen Testregeln aus D-062; endgültiges Balancing bleibt offen. Ergänzende Ausführungsdetails wie die Konkurrenzpriorität nach stabiler Stations-ID sind gesonderte vorläufige Implementierungsfestlegungen und werden nicht als ausdrücklich mitbestätigt ausgegeben. Keine neue Phase ist daraus freigegeben. Die geprüfte Umsetzung entspricht den angebotenen Regeln bereits; keine Codeänderung erforderlich.


## D-064 – Gesammelten geprüften Stand committen und nach Main pushen (25. Oktober 2026)

Nach Abschluss der lokalen Phasen und Bestätigung D-063 beauftragt der Nutzer ausdrücklich: „Dann mach jetzt alles für ein Commit fertig und push es nach Main“. Damit ist ein gemeinsamer Commit des vollständigen Hauptprojektstands und ein normaler Push nach origin/main freigegeben. Dazu gehören die vorbestehende Nutzeränderung in SwarmMind, Einheiten-/Armeephase, native Performance-/Fensterstabilität, Bau/Überleben, Reparatur/Abbruch/KI und Energiephase einschließlich Tests, Diagnoseskripten und Dokumentation. Die älteren Aussagen „kein Commit aus diesem Auftrag“ beschreiben die früheren Implementierungsaufträge und stehen dieser neuen ausdrücklichen Freigabe nicht entgegen.

Der eigenständige Untercheckout dot-wars/ bleibt separat und wird ignoriert. Generierte Bibliotheken, Godot-Caches und Diagnoseausgaben werden nicht versioniert. Native Bibliotheken bleiben reproduzierbare Build-Ausgaben. Vor Commit/Push werden alle vorgesehenen Dateien aus dem Git-Index in einen sauberen Prüfexport übernommen und dort Import, Windows-Native-Build, native und Referenzsuite sowie Hauptszene geprüft. Die Linux-Zielbibliothek wird zusätzlich aus denselben Quellen querkompiliert; die tatsächliche Linux-Ausführung übernimmt GitHub Actions. CI erhält angemessene Laufzeitgrenzen und prüft zusätzlich Skript-/Parsefehler in den Testlogs. Keine neue Spielregel, Versionserhöhung, Veröffentlichung als Release oder Abschaltung aus dem Commitauftrag.


## D-065 – P6-Folgeauftrag 1–6 auf neuem PR (26. Oktober 2026)

Nach Merge von PR #8 beauftragt der Nutzer ausdrücklich zunächst KI-Netzversorgung und danach Transportausfälle/Abriss, grafische Bedienprüfung, Sichtschutz, reguläre Freischaltungen/Effizienz und grafischen Forschungsbaum. Basis `20a5059`, neuer Branch/PR statt Wiederverwendung von PR #8; kein automatischer Merge oder Release. Umfang und Grenzen in P6_PLAYABLE_RESEARCH.md. Historische Planungspausen gelten nicht als Sperre für diesen neuen ausdrücklichen Auftrag.

## D-066 – Vorläufige Transportausfallregeln bestätigt (26. Oktober 2026)

Die Antwort „Diese vorläufigen Regeln verwenden“ bestätigt Pause bezahlter Sendungen an Leitungsunterbrechungen, Fortsetzung beim Wiederanschluss, Verlust von Puffer/Sendungen bei Zentrumszerstörung ohne Erstattung sowie neue eigene Ersatzversorgung nach Quellkernverlust. Bezahlte Energie wird nicht dupliziert oder teleportiert; Verluste sind getrennt gespeichert. Neuversand nutzt einen verbundenen eigenen Hauptkern, sonst Außenposten. Bisherige physische Sendungen laufen von ihrem tatsächlichen Ort weiter.

## D-067 – Vorläufige Forschungsfreischaltungen und Effizienz bestätigt (26. Oktober 2026)

Die Antwort „Diese vorläufigen Werte verwenden“ bestätigt Außenposten nach Arbeiterbewegung, Abfangstation nach Energietransport, je 90 Energie/260 Takte; Energieeffizienz nach Energietransport mit drei Stufen, 80 Energie/240 Takte mal Zielstufe und 10/20/30 % weniger Forschungsenergie bei gleicher Dauer. Prototypwerte, kein finales Balancing. Kosten werden je Auftrag beim Start eingefroren, mit dem damaligen Effizienzstand gespeichert und auf ganze Energie nach oben gerundet (mindestens 1). Dauerbuffs, weitere Gebäudetypen und neue Kriegerwerte sind kein Bestandteil.

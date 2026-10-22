# Spielregeln

Verbindliche Regeln stehen im Präsens. Vorläufige Balancingwerte und offene Punkte sind als solche markiert. Was der Code heute noch nicht kann, steht am Ende.

## Spielidee

DOT WARS ist ein minimalistisches Echtzeit-Strategiespiel. Die Welt ist ein quadratisches Raster aus farbigen Punkten. Der Spieler steuert keine einzelnen Arbeiter, sondern Farbgruppen und deren Aufträge. Arbeiter bewegen sich selbst, bauen angrenzendes Material ab, und jedes vollständig abgebaute Feld erzeugt genau einen neuen Basis-Arbeiter.

Zielplattform ist Windows über Steam. Der erste verbindliche Umfang ist Singleplayer mit einer Fraktion und einer prozeduralen Welt pro Durchlauf. KI-Gegner, Kampf und Multiplayer gehören nicht zu den zehn Phasen, solange sie nicht ausdrücklich Teil einer Phase sind.

## Spielfeld

Die Welt ist quadratisch und die Kantenlänge ist konfigurierbar.

| Profil | Kantenlänge | Rolle |
|---|---:|---|
| Entwicklung | 256 | Standard im aktuellen Projekt |
| Standard | 500 | vorgesehene Spielwelt |
| Ziel | 1.000 | eine Million Zellen |

Jede Zelle ist leer, weiches Material, mittleres Material, hartes Material, unzerstörbar oder ein Sonderobjekt wie das Opferloch. Unzerstörbare Objekte dürfen getrennt von der Materialkarte liegen.

## Materialien

Härte ist der Arbeitsaufwand in Arbeitseinheiten. Ein Basis-Arbeiter leistet eine Arbeitseinheit pro Simulationssekunde. Mehrere Arbeiter an gültigen Nachbarzellen addieren ihre Leistung. Ein Feld verschwindet erst, wenn der Aufwand vollständig geleistet ist. Härteres Material erzeugt nicht mehr Arbeiter als weiches.

| Material | Härte | Farbe | Arbeitseinheiten | Dauer, ein Basis-Arbeiter |
|---|---:|---|---:|---:|
| Weich | 1 | Grün | 1 | 1 Sekunde |
| Mittel | 3 | Braun/Orange | 3 | 3 Sekunden |
| Hart | 8 | Blau/Grau | 8 | 8 Sekunden |
| Unzerstörbar | — | Dunkelgrau | nicht abbaubar | — |

Die Farben liegen später in einer zentralen Konfiguration. Die Dauer ist beschlossen (`docs/DECISIONS.md`). Im Code entsprechen 20 Fortschrittspunkte einer Arbeitseinheit, bei 20 Simulationstakten pro Sekunde und einem Punkt pro Tick.

## Weltgenerierung

Dieselbe Konfiguration und derselbe Seed erzeugen dieselbe Welt. Ein anderer Seed erzeugt eine andere Welt. Die abbaubare Masse hängt zusammen. Es gibt einen erkennbaren Startbereich mit Platz für die ersten Arbeiter. Es gibt keine unerreichbaren Pflichtgebiete. Leerer Raum um einen Materialkörper ist zulässig.

## Arbeiter

Ein Basis-Arbeiter hat eine ID, eine Fraktion, eine Farbgruppe, eine Position, Masse 1, Größe 1×1, eine Abbauleistung, eine Bewegungsgeschwindigkeit und einen Auftrag. Fraktion und Farbgruppe sind unabhängig: die Fraktion ist der Besitzer, die Gruppe ist der Auftrag.

Zustände bleiben wenige und klar, zum Beispiel Warten, Bewegen, Abbauen, Blockiert. Die Simulation ist deterministisch.

## Bewegung und Abbau

* Bewegung nur orthogonal durch leere Zellen innerhalb der Welt.
* Kein Weg durch Material. Tunnel entstehen durch Abbau.
* Abbau nur von einer orthogonal benachbarten, begehbaren Zelle.
* Größere Dots brauchen entsprechend breite, freie Durchgänge.
* Neue Arbeiter entstehen nie auf einer ungültigen Zelle.
* Der Spieler setzt nur Auftrag und Zielgebiet.

Die Wegfindung gilt für den Schwarm gemeinsam: Distanzfelder oder Flow-Fields, zwischengespeichert, bei Tunneländerungen gezielt aktualisiert, über mehrere Takte verteilt. Eine einzelne Zellenänderung löst keine vollständige Neuberechnung der ganzen Welt aus, sobald die Zielphase das umsetzt. Der jetzige Prototyp baut das Feld einer Gruppe bei einer Weltänderung noch neu auf. Das ist eine bekannte Abweichung, kein Soll.

Unerreichbare Ziele lassen die Arbeiter warten. Es wird kein Weg durch Material erfunden. Ein Feld wird nur einmal abgebaut. Gleichzeitige Versuche erzeugen die Ressource nicht doppelt. Fortschritt liegt an der Zelle. Abgebaute Zellen werden begehbar.

## Wachstum und Masse

Jedes vollständig abgebaute Materialfeld erzeugt genau einen Basis-Arbeiter. Ist die Zelle belegt, wartet die Entstehung in einer deterministischen Warteschlange. Wartende Arbeiter zählen zur Masse und handeln erst nach der Platzierung.

Zu jedem Zeitpunkt:

**Gesamtmasse = Anfangsmasse + vollständig abgebaute Felder − geopferte Masse**

Zur Gesamtmasse gehören aktive Arbeiter, die Masse verschmolzener Einheiten und noch nicht platzierte Arbeiter. Verschmelzung, Aufteilung, Gruppenwechsel, Weltgenerierung und das Laden eines Spielstands ändern diese Bilanz nicht unbeabsichtigt.

## Farbgruppen

Eine Gruppe hat ID, Farbe, optionalen Namen, Zielquote, Auftrag, optionales Zielgebiet, Verschmelzungseinstellung und aktuelle Masse. Neue Arbeiter gehen an die Gruppe mit dem größten relativen Defizit gegenüber ihrer Zielquote. Das Verfahren ist deterministisch. Gleichstände haben eine feste Reihenfolge. Gruppen mit 0 % bekommen keine neuen Arbeiter. Die Summe der Quoten ist 100 %. Bestehende Arbeiter wechseln bei einer Quotenänderung nicht die Gruppe. Verschmolzene Einheiten zählen mit ihrer vollen Masse. Opferung senkt die Gruppenmasse.

Im Prototyp gilt bei Gleichstand: die größere Quote gewinnt, danach der kleinere Gruppenindex. Eine Summe ungleich 100 % wird abgelehnt und nicht normalisiert. Ob eine Eingabe später auf 100 % normalisiert werden darf, ist offen.

## Verschmelzung, Opferloch, Upgrades, Sieg

Diese Regeln sind verbindlich für ihre Phasen. Sie sind im Prototyp nicht implementiert.

| Stufe | Größe | Masse | Abbauleistung | Stand der Werte |
|---|---|---:|---:|---|
| 1 | 1×1 | 1 | 1 | vorläufig |
| 2 | 2×2 | 4 | 6 | vorläufig |
| 3 | 3×3 | 9 | 15 | vorläufig |

Verschmelzung erhält die Masse, bleibt in Fraktion und Gruppe und braucht den Platz. Große Dots können mehrere erreichbare Felder gleichzeitig bearbeiten, erzeugen aber nie mehr Arbeiter, als Felder entfernt wurden. Sie lassen sich wieder zerlegen. Der Spieler setzt pro Gruppe eine Wunschgröße.

Das Opferloch steht im Startbereich, ist unzerstörbar, und eine Einlieferung opfert die Einheit genau einmal. Energie ist gleich der geopferten Masse. Das Spiel verhindert, dass eine versehentliche Opferung aller Arbeiter die Runde unspielbar macht. Die konkrete Schutzregel wird in Phase 7 festgelegt und getestet.

| Upgrade | Startkosten | Effekt | Wiederholung |
|---|---:|---|---|
| Bewegungsgeschwindigkeit | 25 | +20 % | ja, Kosten steigen |
| Abbauleistung | 50 | +25 % | ja, Kosten steigen |
| Verschmelzung | 100 | schaltet 2×2 frei | einmal |
| Erweiterte Verschmelzung | später | schaltet 3×3 frei | einmal |

Kostenformeln sind zentral und testbar. Effekte gelten global und konsistent. Die Abbildung von +25 % auf den Ganzzahl-Takt ist noch offen.

Die Runde ist gewonnen, wenn alle drei Ziele erreicht sind: mindestens 100 Gesamtmasse, mindestens zwei gekaufte Upgrades, mindestens 90 % des ursprünglich abbaubaren Materials. Leer und unzerstörbar zählen nicht zur Bezugsmenge. Nach dem Sieg kann weiter abgebaut werden. Die Statistik zeigt Spielzeit, abgebaute Zellen, höchste Masse, geopferte Masse, gekaufte Upgrades und die maximale Zahl Einheiten. 20 bis 40 Minuten auf der Standardwelt sind ein Balancingziel, kein belegtes Ergebnis.

## Simulation

20 Simulationstakte sind eine Simulationssekunde. Die Bildrate ändert die Abbaugeschwindigkeit nicht. Pause, Fortsetzen, die Stufen 1×, 2× und 4× und reproduzierbare Läufe gehören zum Spiel.

## Was der Stand heute bereits tut

* Quadratische Welt in 256, 500 und 1.000, gleicher Seed, drei abbaubare Materialien mit Härte 1, 3 und 8.
* Farben Grün, Braun/Orange, Blau/Grau. Unzerstörbares Material ist dunkelgrau und wird nicht abgebaut.
* Das Opferloch liegt auf der reservierten Zelle im Startbereich. Eine Einlieferung opfert die Einheit einmal. Die letzte Masse bleibt.
* Die Welt wird als eine Textur gezeichnet. Teilweise abgebaute Zellen dunkeln ab. Kamera, Zoom und Debug-Raster sind im Fenster.
* Arbeiter werden als zweite Textur gezeichnet, große Einheiten über ihr Quadrat.
* Das Startmenü startet ein Spiel mit drei Gruppen (40/30/30) oder lädt einen Speicherstand.
* Ein Zug mit der linken Taste markiert das Abbaugebiet der gewählten Gruppe. Ein kurzer Klick setzt ihr Laufziel.
* Gruppen lassen sich benennen, anlegen und schließen. Die Quote muss 100 % ergeben, sonst bleibt der alte Stand.
* Verschmelzung auf 2×2 und 3×3 ist nach dem passenden Upgrade die Wunschgröße der Gruppe. Masse bleibt erhalten, enge Tunnel sind nicht passierbar.
* Energie kauft Tempo, Abbauleistung und die beiden Verschmelzungsstufen. Die Kosten stehen in `docs/DECISIONS.md`.
* Gewonnen ist, wenn Masse, zwei Upgrades und 90 % Abbau zusammen erreicht sind. Danach läuft das Spiel weiter, die Statistik bleibt sichtbar.
* Pause, Spielgeschwindigkeit 1×, 2× und 4×, Speichern und Laden.
* Die Fraktions-ID liegt am Arbeiter und ist beim Start 0. Nur diese eine Fraktion wird verwendet.

## Was noch nicht da ist

* Mehrere Fraktionen mit eigenem Besitz.
* Eine Zielsuche, die nach einem einzelnen Abbau nur die betroffene Tunnelumgebung neu rechnet.
* Ein geprüfter Windows-Release-Build und eine Steam-Veröffentlichung. Die Vorbereitung steht in `docs/RELEASE.md` und `docs/STEAM.md`.
* Hintergrundmusik. Es liegt kein lizenziertes Stück bei. Abgeschlossener Abbau spielt einen kurzen erzeugten Ton, wenn ein Audiogerät vorhanden ist.

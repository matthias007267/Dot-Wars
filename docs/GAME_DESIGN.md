# Spielregeln

Verbindliche Regeln stehen im Präsens. Vorläufige Balancingwerte und offene Punkte sind als solche markiert. Was der Code heute noch nicht kann, steht am Ende.

## Spielidee

DOT WARS ist ein minimalistisches Echtzeit-Strategiespiel. Die Welt ist ein quadratisches Raster aus farbigen Punkten. Der Spieler steuert keine einzelnen Arbeiter. Er vergibt globale Abbau- und Bewegungsaufträge; Farbgruppen und ihre Quoten bleiben interne Simulationsmechanismen. Arbeiter bewegen sich selbst und bauen angrenzendes Material ab. Jedes vollständig abgebaute Feld erzeugt Energie-Dots in Höhe seiner Härte. Neue Arbeiter entstehen ausschließlich durch Kauf am Energiekern.

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

Härte ist der Arbeitsaufwand in Arbeitseinheiten und zugleich die Zahl der Energie-Dots, die das Feld beim Abbau erzeugt. Ein Basis-Arbeiter leistet eine Arbeitseinheit pro Simulationssekunde. Mehrere Arbeiter an gültigen Nachbarzellen addieren ihre Leistung. Ein Feld verschwindet erst, wenn der Aufwand vollständig geleistet ist. Abbau erzeugt keine Arbeiter.

| Material | Härte | Farbe | Arbeitseinheiten | Dauer, ein Basis-Arbeiter |
|---|---:|---|---:|---:|
| Weich | 1 | `#57C96D` | 1 | 1 Sekunde |
| Mittel | 3 | `#D3822C` | 3 | 3 Sekunden |
| Hart | 8 | `#5C86DB` | 8 | 8 Sekunden |
| Unzerstörbar | — | `#393F49` | nicht abbaubar | — |
| Tunnel | — | `#161C24` | — | — |
| Energiekern | — | `#C77AFF`, nur gezeichnet | nicht abbaubar | — |

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
* Gekaufte Arbeiter entstehen nur auf freien Tunnelzellen in der Nähe des Energiekerns.
* Der Spieler setzt nur Auftrag und Zielgebiet.

Die Wegfindung gilt für den Schwarm gemeinsam: Distanzfelder oder Flow-Fields, zwischengespeichert, bei Tunneländerungen gezielt aktualisiert, über mehrere Takte verteilt. Bis zu 32 geänderte Zellen korrigieren das bestehende Feld. Ein neues Gebiet, ein neues Laufziel oder eine größere Änderung berechnet es neu. Die Grenzen stehen in D-020.

Unerreichbare Ziele lassen die Arbeiter warten. Es wird kein Weg durch Material erfunden. Ein Feld wird nur einmal abgebaut. Gleichzeitige Versuche erzeugen die Ressource nicht doppelt. Fortschritt liegt an der Zelle. Abgebaute Zellen werden begehbar.

## Energie, Transport und Wachstum

Es gibt vorerst genau zwei bewegliche Dot-Arten: **gelbe Arbeiter-Dots** und **cyanfarbene Energie-Dots**. Rote Krieger-Dots sind eine spätere Erweiterung und derzeit nicht Bestandteil der Simulation.

Ein vollständig abgebautes Feld der Härte 1, 3 oder 8 erzeugt genau 1, 3 oder 8 Energie-Dots. Sie bewegen sich orthogonal durch bestehende Tunnel zum zentralen **Energiekern** (vormals Opferloch). Erst bei Ankunft zählt ihre Energie als verfügbares Guthaben. Der Energiekern erzeugt für **10 Energie** einen neuen Basis-Arbeiter im Starttunnel; wenn dort kein Platz ist, wartet der gekaufte Arbeiter in der Spawn-Warteschlange. Arbeiter werden niemals durch Abbau automatisch erzeugt.

Arbeiter haben bei Bewegungskonflikten Vorrang. Energie-Dots teilen eine Tunnelzelle und blockieren einander nicht. Steht ein Arbeiter auf der nächsten Zelle zum Kern, warten sie, bis die Zelle frei ist. Sie werden als separate Texturebene unter den Arbeitern gezeichnet. Transport erfolgt deterministisch über ein gemeinsames Distanzfeld.

**Arbeitermasse = Startmasse + gekaufte Arbeiter**. Noch nicht platzierte, aber bezahlte Arbeiter zählen mit. **Erzeugte Energie = zugestellte Energie + unterwegs befindliche Energie**. Guthaben und für Upgrades/Arbeiter ausgegebene Energie sind getrennt zu bilanzieren.


## Farbgruppen

Eine interne Gruppe hat ID, Farbe, optionalen Namen, Zielquote, Auftrag, optionales Zielgebiet, Verschmelzungseinstellung und aktuelle Masse. Gruppen werden im Standard-HUD nicht angezeigt und nicht einzeln verwaltet. Sichtbar sind alle Arbeiter gelb. Die Aktionsleiste bedient den arbeitenden Schwarm gemeinsam. Gekaufte Arbeiter gehen an die interne Gruppe mit dem größten relativen Defizit gegenüber ihrer Zielquote. Das Verfahren ist deterministisch. Gleichstände haben eine feste Reihenfolge. Gruppen mit 0 % bekommen keine neuen Arbeiter. Die Summe der Quoten ist 100 %. Bestehende Arbeiter wechseln bei einer Quotenänderung nicht die Gruppe. Verschmolzene Einheiten zählen mit ihrer vollen Masse.

Im Prototyp gilt bei Gleichstand: die größere Quote gewinnt, danach der kleinere Gruppenindex. Eine Summe ungleich 100 % wird abgelehnt und nicht normalisiert. Ob eine Eingabe später auf 100 % normalisiert werden darf, ist offen.

## Verschmelzung, Energiekern, Upgrades, Sieg

Verschmelzung, der Energiekern, Upgrades und die Siegbedingungen sind im Spiel. Arbeiter können nicht geopfert werden.

| Stufe | Größe | Masse | Abbauleistung | Stand der Werte |
|---|---|---:|---:|---|
| 1 | 1×1 | 1 | 1 | vorläufig |
| 2 | 2×2 | 4 | 6 | vorläufig |
| 3 | 3×3 | 9 | 15 | vorläufig |

Verschmelzung erhält die Masse, bleibt in Fraktion und Gruppe und braucht den Platz. Große Dots können mehrere erreichbare Felder gleichzeitig bearbeiten, erzeugen beim Abbau nur Energie entsprechend der Härte der entfernten Felder. Sie lassen sich wieder zerlegen. Der Spieler setzt pro Gruppe eine Wunschgröße.

Der Energiekern steht im Startbereich und ist unzerstörbar. Ankommende Energie-Dots werden eingelagert. Arbeiter können nicht mehr geopfert werden. Ohne die Fähigkeit Kern dürfen Arbeiter auf den beiden Zugängen stehen. Jede Stufe räumt eine größere Fläche um den Kern, die Arbeiter nicht betreten und auf der Energie ankommt. Der Außenring bleibt begehbar, damit die Tunnel verbunden bleiben. Die Fläche wächst bis Radius 4.

| Fähigkeit | Startkosten | Effekt | Wiederholung |
|---|---:|---|---|
| Kern | 40 | Fläche um den Kern, Radius +1 bis 4 | ja, Kosten steigen |
| Arbeiter-Tempo | 25 | Schritt alle 8, 6, 4, 3, 2, dann 1 Takt | ja, fünf Stufen, Kosten steigen |
| Energie-Tempo | 30 | dieselbe Stufenleiter für Energie-Dots | ja, fünf Stufen, Kosten steigen |
| Abbauleistung | 50 | +25 % | ja, Kosten steigen |
| Verschmelzung | 100 | schaltet 2×2 frei | einmal |
| Erweiterte Verschmelzung | 250 | schaltet 3×3 frei | einmal |

Kostenformeln sind zentral und testbar. Effekte gelten global und konsistent. Die Abbildung von +25 % auf den Ganzzahl-Takt ist noch offen.

Die Ziele hängen am Modus und sind vorläufig. In der Räumung ist die Runde gewonnen, wenn alle drei Prüfungen erfüllt sind: mindestens 100 gekaufte und vorhandene Arbeitermasse, mindestens zwei Käufe, mindestens 90 % des ursprünglich abbaubaren Materials. Leer und unzerstörbar zählen nicht zur Bezugsmenge. Förderung endet bei 1.000 gelieferten Energieeinheiten. Veredelung endet bei 400 veredelten Einheiten am Kern. Nach dem Sieg kann weitergespielt werden. Die Statistik zeigt Spielzeit, abgebaute Zellen, höchste Masse, gekaufte Arbeiter, gelieferte Energie, Upgrades, die maximale Zahl Einheiten und die veredelte Menge. 20 bis 40 Minuten auf der Standardwelt sind das Balancingziel der Räumung. Ein skriptierter Lauf mit Seed 1337 hat die drei Räumungsziele auf der 256er-Welt nach 37:28 erreicht, noch mit dem alten Zwei-Takt-Tempo. Ein menschliches Spiel ist damit nicht gemessen.

## Modi und Gebäude

Der Modus wird vor dem Start gewählt.

| Modus | Ziel | Gebäude |
|---|---|---|
| Räumung | Masse 100, zwei Käufe, 90 % Abbau | Veredler, nur als Wirtschaft |
| Förderung | 1.000 gelieferte Energie | Quelle |
| Veredelung | 400 veredelte Energie am Kern | Veredler |
| Mehrspieler | Auslöschen, Forschungssieg, Reliquien, König des Hügels, jedes Ziel einzeln schaltbar | keines |

Eine Quelle oder ein Veredler ist eine leere, begehbare Zelle. Der Kauf liegt unter Bauen im Fähigkeiten-Fenster. Der nächste Klick auf einen freien Tunnel setzt das Gebäude. Kern und Kernfläche bleiben frei.

Die Quelle lässt orthogonal benachbartes, leeres Gelände wieder zu echtem Material werden. Stufe 0: alle 8 Sekunden eine weiche Zelle, höchstens 4. Stufe 1: alle 6 Sekunden, höchstens 6. Stufe 2: jede dritte neue Zelle ist mittel. Stufe 3: jede sechste ist hart. Die erste Quelle kostet 80, die zweite 160, die dritte 240. Die Stufen kosten 40, 80 und 120.

Der Veredler verdoppelt einen Energie-Dot aus seinem Umkreis, einmal je Dot. Stufe 0 schafft einen Dot je Sekunde im Umkreis von 16 Zellen, Stufe 1 zwei Dots und 24 Zellen, Stufe 2 vier Dots und 32 Zellen. Der erste kostet 120, der zweite 240. Die Stufen kosten 60 und 120. Das Guthaben zählt weiterhin eine Einheit je ankommendem Dot.

Mehrspieler startet mit einer bis drei KI. Andere Spieler sind vorgesehen und noch nicht verbunden. Der Spieler bleibt gelb. Die KI ist koralle, himmelblau oder minze. Jede Basis liegt auf einem Ring und trägt ihren Namen. Die eigene Basis hat einen gelben Rahmen, die Kamera startet dort. Einen gemeinsamen Mittelkern gibt es in diesem Modus nicht. Der Hügel ist die einzelne freie Zelle in der Mitte, die fünf Reliquien liegen darum. Auslöschen räumt den gegnerischen Kern. Forschungssieg ist Stufe 5. Drei von fünf Reliquien oder 30 Sekunden allein auf dem Hügel gewinnen ebenfalls. Die Zahlen sind vorläufig. Die Einzelspieler-Ziele gelten in diesem Modus nicht.

Das Menü trennt zuerst Einzelspieler und Mehrspieler. Im Einzelspieler folgt der Modus. Im Mehrspieler folgen Ziele, Schwierigkeit und die Zahl der KI. Leicht bleibt an der Basis und spart. Mittel gräbt die ganze Karte und kauft Arbeiter und Forschung. Schwer gräbt auf das gewählte Ziel zu und kauft Abbau und Tempo. Gemischt gibt jeder KI einen anderen Plan. Eine einzelne KI auf Gemischt spielt Mittel.

## Simulation

20 Simulationstakte sind eine Simulationssekunde. Die Bildrate ändert die Abbaugeschwindigkeit nicht. Pause, Fortsetzen, die Stufen 1×, 2× und 4× und reproduzierbare Läufe gehören zum Spiel.

## Was der Stand heute bereits tut

* Quadratische Welt in 256, 500 und 1.000, gleicher Seed, drei abbaubare Materialien mit Härte 1, 3 und 8.
* Premium-Pixel-Farben: Grün, Orange, Blau, dunkles Grau. Der Tunnel ist `#161C24`, der Hintergrund `#0D1015`. Der Energiekern wird magenta `#C77AFF` gezeichnet und bleibt unzerstörbar. Die freie Kernfläche ist dunkelmagenta `#5A3D78`. Die Statuskarte zeigt die Kernstufe.
* Gelbe Dots sind Arbeiter. Cyanfarbene Dots sind Energie auf dem Weg zum Kern. Rote Dots sind für spätere Krieger reserviert und nicht im Spiel.
* Die Welt wird als eine Textur gezeichnet. Teilweise abgebaute Zellen dunkeln ab. Kamera, Zoom und Debug-Raster sind im Fenster.
* Arbeiter werden als zweite Textur gezeichnet, große Einheiten über ihr Quadrat.
* Das Startmenü fragt zuerst Einzelspieler oder Mehrspieler und zeigt danach nur die passenden Einstellungen. Ein neues Spiel startet mit drei Gruppen (40/30/30) oder lädt einen Speicherstand.
* Das HUD bietet zwei Modi: „Abbau“ markiert ein Gebiet per Ziehen, „Bewegen“ setzt einen gemeinsamen Sammelpunkt im Tunnel. Gebiete und Sammelpunkte tragen die Farbe der Fraktion. Ein Gebiet über die ganze Karte bleibt unsichtbar. Ein unerreichbares Gebiet nennt den Hinweis und der Schwarm gräbt sich dorthin. Ohne Auftrag, oder wenn im Auftrag nichts mehr liegt, nimmt er die nächste Ressource. Ein Sammelpunkt hält ihn davon ab. „Arbeiter +10“ kauft einen Arbeiter für 10 gelieferte Energie. Die Energiezeile nennt das eigene Guthaben und die eigenen Dots unterwegs. Im Mehrspieler steht die gegnerische Masse in einer eigenen Zeile. Quotenregler gibt es nicht.
* Die Gruppenverwaltung existiert weiterhin als interne API. Die Quoten bleiben in der Simulation exakt 100 %, aber die Standardoberfläche zeigt keine Quotenregler und keine Gruppenliste.
* Verschmelzung auf 2×2 und 3×3 ist nach dem passenden Upgrade die Wunschgröße der Gruppe. Masse bleibt erhalten, enge Tunnel sind nicht passierbar.
* Die Leiste öffnet ein Fähigkeiten-Fenster. Darin liegen Kern, Bewegung (Arbeiter- und Energie-Tempo), Schwarm (Abbau, 2×2, 3×3) und Bauen. Der Modus entscheidet, ob dort die Quelle oder der Veredler steht. Weitere Zweige kommen in dieses Fenster, nicht in die Leiste. Die Kosten stehen in `docs/DECISIONS.md`.
* Der Modus steht im Einzelspieler. Räumung gewinnt mit Arbeitermasse, zwei Käufen und 90 % Abbau. Förderung gewinnt mit 1.000 gelieferter Energie, Veredelung mit 400 veredelter Energie. Mehrspieler gewinnt über die gewählten Ziele gegen KI. Die Schwierigkeit steht nur dort und ändert den Plan der KI. Danach läuft das Spiel weiter. Die Auswertung nennt Spielzeit, abgebaute Zellen, höchste Masse, gekaufte Arbeiter, gelieferte Energie, Upgrades, die höchste Zahl gleichzeitiger Einheiten und die veredelte Menge. Die Masse wächst durch Käufe. Im Mehrspieler zieht das Entfernen einer Fraktion die entfernte Masse wieder ab.
* Escape öffnet das Pausenmenü mit Weiter, Speichern, Laden, Neu starten, Lautstärke und Beenden. Die untere Leiste behält Abbau, Bewegen, Arbeiter, Größe, Fähigkeiten und die Stufen 1×, 2× und 4×.
* Kleine Tunneländerungen korrigieren die Zielsuche lokal. Ab 33 Zellen, bei einem neuen Gebiet oder einem neuen Laufziel wird das Feld neu aufgebaut. Eine geöffnete Zelle setzt eine laufende vollständige Berechnung nicht zurück.
* Die Fraktions-ID liegt am Arbeiter. Einzelspieler bleibt bei 0. Mehrspieler vergibt je KI eine eigene Fraktion, ein eigenes Guthaben und einen eigenen Kern.

## Was noch nicht da ist

* Rote Krieger-Dots.
* Eine Verbindung zu anderen menschlichen Spielern. Der Platz dafür ist da, das Netz nicht.
* Ein geprüfter Windows-Release-Build und eine Steam-Veröffentlichung. Die Vorbereitung steht in `docs/RELEASE.md` und `docs/STEAM.md`.
* Hintergrundmusik. Es liegt kein lizenziertes Stück bei. Abgeschlossener Abbau spielt einen kurzen erzeugten Ton, wenn ein Audiogerät vorhanden ist.

Speicherstände der Version 1 passen nicht zur neuen Massen- und Energiebilanz und werden abgelehnt. Gültig ist Version 2.

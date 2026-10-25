# DOT WARS – verbindliches Zielkonzept

Stand: 25. Oktober 2026. **Einheitenphase ausdrücklich freigegeben; Detailstand in [UNIT_PROTOTYPE.md](UNIT_PROTOTYPE.md). Weitere große Systeme bleiben Folgearbeit.**

Dieses Dokument beschreibt das beschlossene Zielspiel. Es behauptet nicht, dass die Regeln bereits implementiert sind. Den geprüften Prototypstand, Abweichungen und die vorgeschlagene Reihenfolge späterer Arbeiten beschreibt [CONCEPT_SYNC.md](CONCEPT_SYNC.md). Die technische Einordnung steht in [ARCHITECTURE.md](ARCHITECTURE.md).

Die aktuelle Zusammenfassung des Nutzers und seine abrufbaren Entscheidungen im Chat „Abbausystem überdenken“ sind die Grundlage. Neuere ausdrückliche Nutzerentscheidungen gehen widersprechenden älteren Prototypregeln vor. Die alten Regeln bleiben als [historischer Prototypentwurf](archive/GAME_DESIGN_PRE_2026-10-25.md) und in [DECISIONS.md](DECISIONS.md) nachvollziehbar. Widersprüche werden dokumentiert, nicht durch stille Codeänderungen aufgelöst.

## Statusbegriffe

- **Verbindlich:** beschlossenes Verhalten des Zielspiels.
- **Vorläufig:** ausdrücklich veränderbarer Balancingwert.
- **Skalierungsziel:** gewünschte Größenordnung, kein bestandener Leistungsnachweis.
- **Vorschlag:** Diskussionsgrundlage ohne Freigabe.
- **Offen:** noch nicht entschiedene Einzelheit; keine stillschweigende Standardregel.

## Spielidee

DOT WARS ist ein minimalistisches Echtzeit-Strategiespiel in einer prozeduralen Pixelwelt. Wenige Arbeiter erschließen Ressourcen, errichten und reparieren Gebäude. Große Kriegerarmeen kämpfen im Nahkampf. Spieler können einzelne Dots und frei gebildete Gruppen auswählen und befehligen. Energie wird physisch transportiert und steht erst nach Ankunft zum Ausgeben bereit. Erkundung bestimmt das Wissen über Gegner.

Zielplattform bleibt Windows/Steam. Deterministische Simulation, Trennung von Simulation und Darstellung sowie datenorientierte Speicherung bleiben bestehende technische Projektgrundsätze. Die neue Konzeption ist keine automatische Freigabe von Netzwerkcode, einer neuen Weltarchitektur oder einem Release.

## Welt und Multiplayer

- **W01 – Verbindlich:** Die Welt wird prozedural erzeugt und soll nahezu endlos sein. Das ist keine Zusage mathematischer Unendlichkeit oder unbegrenzten Arbeitsspeichers. Konkrete räumliche Grenzen und eine technische Realisierung sind offen.
- **W02 – Verbindlich:** Die Multiplayer-Kartengröße ist in der Lobby frei einstellbar. Konkrete Eingabeform, erlaubte Grenzen, Kartenform und Zusammenspiel mit der nahezu endlosen Welt sind offen. Die heutige 4096er-Codegrenze ist keine neue Konzeptentscheidung.
- **W03 – Verbindlich:** Ressourcen werden pixelweise abgebaut. Diagonale Abbauwege sind möglich. Das frühere ausschließlich orthogonale Abbaumodell wird dadurch als Zielregel abgelöst. Details zur diagonalen Bewegung und zu geschlossenen Ecken sind offen.
- **W04 – Verbindlich:** Es gibt unzerstörbare Felsen und natürliche Höhlen.
- **W05 – Verbindlich:** Versteckte gegnerische Außenposten werden ausschließlich durch Erkundung gefunden. Eine globale Gegner- oder Gebäudeliste darf ihren Standort nicht vorweg verraten.
- **W06 – Verbindlich:** Verbündete teilen aktuelle Sicht und Erkundung vollständig. Ihre Energiekonten bleiben getrennt. Kontozusammenlegung folgt nicht aus geteilter Sicht.

## Dots und Kampf

- **D01 – Vorläufig:** Maximal **50 Arbeiter pro Spieler**. Im Einheitenprototyp umgesetzt: lebende Arbeiter plus bezahlte wartende Käufe je Spieler. Fusion ist auf ausdrücklichen Wunsch entfernt. Alte größere Populationen dürfen weitergeladen werden; neue Käufe warten bis unter 50. Markierte Diagnosefixtures sind ausgenommen und dürfen keine regulären Spielstände schreiben.
- **D02 – Skalierungsziel:** Mehrere Tausend **Krieger pro Spieler**. Die bisherigen 10.000-Arbeiter-Benchmarks sind keine Nachweise für diese neue Mischpopulation oder deren Kampfverhalten.
- **D03 – Verbindlich:** Einzelne Dots und Gruppen sind frei auswählbar. Eine Auswahl darf nicht zwangsläufig die übrigen Einheiten umbefehlen.
- **D04 – Verbindlich:** Arbeiter blockieren sich gegenseitig.
- **D05 – Verbindlich:** Alle Krieger blockieren sich gegenseitig, auch verbündete Krieger.
- **D06 – Verbindlich:** Eigene Krieger dürfen eigene Arbeiter durchqueren. Eine gemeinsame Endposition ist ausdrücklich verboten; das Ziel muss frei sein. Arbeiter dürfen Krieger nicht durchqueren. Für verbündete Krieger gegenüber fremden verbündeten Arbeitern ist keine zusätzliche Durchquerungserlaubnis beschlossen.
- **D07 – Verbindlich:** Feindliche Krieger greifen Arbeiter bei Kontakt automatisch an.
- **D08 – Verbindlich:** Krieger greifen Gegner innerhalb eines kleinen Verteidigungsradius selbstständig an. Radius, Zielpriorität, Verfolgungsweite und Rückkehrverhalten sind offen.
- **D09 – Verbindlich:** Angegriffene Arbeiter arbeiten weiter, bis sie sterben oder einen neuen Befehl erhalten. Automatische Flucht oder automatische Arbeitsunterbrechung ist nicht beschlossen.
- **D10 – Verbindlich:** Krieger kämpfen ausschließlich im Nahkampf. Fernkampf wird nicht als zusätzliche Variante eingeführt.

Endgültige Kampf- und Produktionswerte bleiben offen. Der ausdrücklich genehmigte spielbare Prototyp nutzt vorläufige Werte und gleichzeitige Trefferauswertung gemäß D-052. Kernschaden kommt nun von Kriegern, nicht von Arbeitern.

## Hauptkern und Außenposten

- **K01 – Verbindlich:** Ausschließlich Hauptkerne und Außenposten produzieren Arbeiter und Krieger. Separate Dot-Fabriken gibt es nicht.
- **K02 – Verbindlich:** Der Hauptkern ist größer und widerstandsfähiger als ein Außenposten. Beide haben ansonsten dieselben Grundfunktionen; daraus folgen noch keine identischen Produktionsraten oder konkreten Zahlenwerte.
- **K03 – Verbindlich:** Außenposten sind kleiner und haben eine feste Größe. Ihre Baukosten steigen mit ihrer Anzahl. Im genehmigten Bauprototyp zählen aktuelle eigene Außenposten einschließlich bezahlter reservierter Baustellen; zerstörte zählen nicht (D-059).
- **K04 – Verbindlich:** Ein Hauptkern kann auf einem normalen Bauplatz für einen festen Energiepreis neu gebaut werden. Genehmigte vorläufige Testwerte: 500 Energie, 600 Arbeiter-Takte, 5×5 Zellen und 600 HP; höchstens ein eigener fertiger oder reservierter/begonnener Kern (D-059).
- **K05 – Verbindlich:** Ein Kernbau zählt als begonnen, sobald mindestens ein Arbeiter daran gearbeitet hat. Ein bloßer Plan, ein Baubefehl oder eine Zahlungsreservierung genügt dafür nicht.
- **K06 – Verbindlich:** Ein begonnener Kernbau verhindert die Niederlage auch dann, wenn der Spieler keine Arbeiter und keinen fertigen Kern mehr besitzt.

Es wird weder ein automatischer Ablauf unfertiger Kernbauten noch eine automatische Niederlage bei Stillstand erfunden. Beschlossen ist jetzt: Niederlage erst, wenn kein fertiger eigener Kern/Außenposten und kein tatsächlich begonnener Hauptkernbau mehr existiert. Ein fertiger Außenposten erhält die Fraktion nach Kernverlust; ein unbegonnener Plan oder unfertiger Außenposten nicht. Abbruch-/Erstattungsdetails bleiben offen. Die frühere sofortige Fraktionsentfernung bei Kernverlust ist abgelöst (D-059).

## Energie

- **E01 – Verbindlich:** Abgebaute Energie bewegt sich physisch über freie Wege zu einem eigenen Kern. Fertige eigene Außenposten sind ausdrücklich ebenfalls Empfänger (D-059). Der Bauprototyp routet über freie Wege zu einem nächstgelegenen erreichbaren eigenen Empfangsrand. Endgültige Routingprioritäten bleiben offen.
- **E02 – Verbindlich:** Gutschrift erfolgt erst bei Ankunft. Abbau oder Abfangen schreibt nicht unmittelbar auf das Energiekonto gut.
- **E03 – Verbindlich:** Ohne erreichbaren Empfänger verschwindet Energie nach **60 Sekunden ohne Route**. Der Prototyp nach D-062 konkretisiert dies vorläufig als 1.200 aufeinanderfolgende Simulationstakte ohne Terrainroute zum eigenen Empfänger. Einheitenstau zählt nicht; wieder verfügbare Route setzt zurück. Die angebotenen Timerregeln sind durch D-063 ausdrücklich für die Testfassung bestätigt; endgültiges Balancing bleibt offen. Details in ENERGY_PHASE.md.
- **E04 – Verbindlich:** Nur Abfanggebäude können gegnerische Energie stehlen. Kontakt mit Dots oder gewöhnlichen Gebäuden genügt nicht.
- **E05 – Verbindlich:** Energie kann unbegrenzt oft erneut abgefangen werden. Ein einmaliger Diebstahlschutz oder ein maximales Abfanglimit ist nicht beschlossen.
- **E06 – Verbindlich:** Gestohlene Energie muss physisch zu einem Kern ihres neuen Besitzers gelangen, bevor sie gutgeschrieben wird.
- **E07 – Verbindlich:** Wird ein Abfanggebäude zerstört, wird seine noch nicht weitertransportierte Energie neutral und kann erneut abgefangen werden. Bereits weitertransportierte Energie wird dadurch nicht rückwirkend freigegeben.

Neutralisierung, Eigentumswechsel und Pufferung erzeugen keine zusätzliche Energie. Die implementierte Bilanz nach D-062 lautet erzeugt = geliefert + verfallen + unterwegs; gepufferte und neutrale Punkte sind Teil von unterwegs. Neutrale Position, Routenfrist und die angebotenen Stationswerte sind durch D-063 für die Testfassung bestätigt. Die ergänzende Konkurrenzpriorität ist in ENERGY_PHASE.md als vorläufige Implementierungsfestlegung dokumentiert; endgültige Werte bleiben offen.

## Fog of War

- **F01 – Verbindlich:** Solide Pixel und Gebäude blockieren die Sicht.
- **F02 – Verbindlich:** Gegnerische Dots verschwinden sofort aus der Darstellung, sobald sie außerhalb der aktuellen Sicht liegen. Sie bleiben nicht als letzte bekannte Einheitenposition stehen.
- **F03 – Verbindlich:** Entdeckte gegnerische Gebäude bleiben im zuletzt bekannten Zustand sichtbar.
- **F04 – Verbindlich:** Veränderungen außerhalb der Sicht werden erst bei erneuter Erkundung aktualisiert. Dazu gehören insbesondere Gebäudeänderungen und Veränderungen des bekannten Geländes.

Der aktuelle vollständige Weltzustand und das Wissen eines Spielers sind daher getrennte Begriffe. Auch Minimap, Auswahl, Auftragsvorschau, Meldungen und Gegneranzeigen dürfen außerhalb der Sicht kein neues Wissen verraten. Sichtweiten, genaue Sichtlinien, Aktualisierungstakte und Bündniswechsel sind offen.

## Gebäude, Bau und Reparatur

- **G01 – Verbindlich:** Zu Spielbeginn ist ausschließlich der Hauptkern als Gebäude verfügbar. Alle weiteren Gebäude müssen erforscht werden.
- **G02 – Verbindlicher Planungskatalog:** Außenposten, Mauern, Energiefarmen, Energie-Abfangstationen und Aufklärungssensoren sind vorgesehen. Konkrete Werte und noch nicht beschriebene Funktionsdetails dieses Katalogs sind offen. Aufklärungssensoren besitzen einen größeren Sichtbereich.
- **G03 – Verbindliche Ausschlüsse:** Keine separaten Dot-Fabriken, keine Forschungslabore und keine automatischen Verteidigungstürme. Verteidigung erfolgt durch Mauern und Krieger.
- **G04 – Verbindlich:** Mauern werden durch Ziehen einer Linie angelegt und in einzelne Segmente aufgeteilt. Kosten, Baustellen und Reparaturverhalten je Segment sind zu konkretisieren.
- **G05 – Verbindlich:** Gebäude benötigen freien Baugrund und werden von Arbeitern errichtet. Sofortige Platzierung eines fertigen Gebäudes genügt dem Zielkonzept nicht.
- **G06 – Verbindlich:** Reparaturen kosten Energie und erfordern manuell zugewiesene Arbeiter. Es gibt keine automatische Reparaturzuweisung. Die Folgephase D-060 setzt dies für fertige Kerne/Außenposten um; die Reparatur-/Abbruchwerte sind durch D-061 ausdrücklich als vorläufige Testregeln bestätigt und in MAINTENANCE_PHASE.md beschrieben.

Die heutigen Prototypgebäude „Quelle“ und „Veredler“ sind nicht automatisch mit Energiefarmen oder Abfangstationen gleichzusetzen. Ihre Übernahme, Umgestaltung oder Ablösung ist nicht entschieden. Die Arbeiter-Fusion ist dagegen ausdrücklich entfernt; alte Solo-Siegziele sind vollständig deaktiviert. Diese beiden Fragen sind entschieden.

## Forschung

- **R01 – Verbindlich:** Forschung erfolgt global pro Spieler ohne Forschungsgebäude.
- **R02 – Verbindlich:** Beim Forschungsstart wird der vollständige Energiepreis bezahlt. Danach läuft die Forschungszeit; die Wirkung wird nicht als sofortiger Kauf vorausgesetzt.
- **R03 – Verbindlich:** Mehrere Technologien können parallel erforscht werden.
- **R04 – Verbindlich:** Forschung schaltet Gebäude und Verbesserungen frei.
- **R05 – Verbindlich:** Mehrstufige Upgrades haben steigende Kosten und feste Maximallevel. Die konkreten Levelgrenzen sind noch nicht festgelegt.

**Vorschlag, nicht beschlossen:** Forschungszweige Wirtschaft, Militär, Infrastruktur und Energietechnik.

**Offen:** Einzeltechnologien, Forschungsstufen, Kosten, Zeiten, Abhängigkeiten, Freischaltungsreihenfolge, Abbruch/Rückzahlung, Wiederaufnahme sowie Forschungszustand bei Kernverlust. Es wird in der Planungspause kein ausformulierter Forschungsbaum mit vermeintlich verbindlichen Zahlen erfunden.

## Noch nicht beschlossene Anschlussfragen

Die folgenden Fragen blockieren spätere Detailimplementierungen, nicht die Dokumentation dieser Entscheidungen:

1. Wie hängen nahezu endlose Welt, Lobbygröße, Kartenrand und Siegbedingungen zusammen? Welche Spielerzahl und Bündniswechsel sind vorgesehen?
2. Sind diagonale Bewegung und diagonales Abbauen beide erlaubt? Welche Regeln gelten an geschlossenen Ecken, für Wegkosten und für Sichtlinien?
3. Entschieden: maximal 50 einzelne Arbeiter einschließlich bezahlter Warteschlange; keine Fusion. Künftige Bau-/Produktionsorte müssen dasselbe Spielerlimit einhalten.
4. Eigene Krieger dürfen eigene Arbeiter passieren, niemals auf ihnen stoppen. Arbeiter passieren keine Krieger. Offen bleiben weitergehende Bündnisdetails. Bleibt der heutige frontale Arbeitertausch unter der Blockaderegel erlaubt?
5. Welche Kampfwerte, Zielprioritäten, Befehlsprioritäten und Regeln gleichzeitiger Treffer gelten?
6. Baugrößen, HP, Kosten und Arbeit sind vorläufig nach D-059 bestätigt; endgültiges Balancing und endgültige Produktions-/Warteschlangenregeln bleiben offen.
7. Vorläufig entschieden nach D-059: aktuelle eigene Außenposten samt Reservierungen zählen; höchstens ein eigener Hauptkern samt reserviertem Bau.
8. Niederlagebedingung nach D-059 entschieden; Abbruchsteuerung, Erstattungen und Baustellen-HP-Kurve bleiben offen.
9. Fertige Außenposten empfangen Energie. Routenverfall ist nach D-062 testweise umgesetzt; endgültige Routing-/Timerpolitik bleibt Balancing-/Konzeptthema.
10. Abfangen, Puffer, Neutralisierung und erneutes Abfangen sind nach D-062 mit vorläufigen Kontakt-/Durchsatzwerten umgesetzt. Endgültiges Balancing und Forschungsintegration bleiben offen.
11. Wie funktionieren Energiefarmen, und was geschieht mit Quelle und Veredler aus dem Prototyp?
12. Welche Sichtweiten und welche Kenntnisregeln gelten bei Bündniswechseln oder gemeinsam entdeckten, später getrennten Gebäudeständen?
13. Bau, manuelle Reparatur und Baustellenabbruch sind im Prototyp nach D-059/D-060 konkretisiert. Endgültiges Reparaturbalancing und Erstattungen sowie lineare/diagonale Mauerregeln bleiben offen.
14. Wie sieht der Forschungsbaum aus? Welche Maximallevel, Kosten, Zeiten, Abhängigkeiten und Abbruchregeln gelten?
15. Entschieden: alte Solo-Siegziele ganz deaktivieren. Weitere Altmechaniken wie Quelle/Veredler und endgültiges Balancing bleiben offen.
16. Version 2 bleibt lesbar; Kriegerdaten und Arbeiter-Lebenspunkte werden additiv gespeichert. Alte fusionierte Arbeiter werden massenerhaltend vereinzelt, alte Solo-Siege zurückgesetzt. Der ursprüngliche Dateislot wird beim bloßen Laden nicht überschrieben.

## Umsetzung und Freigabe

Die priorisierte Abweichungsliste steht in [CONCEPT_SYNC.md](CONCEPT_SYNC.md) und [ROADMAP.md](ROADMAP.md). Nach der Planungspause wurde die oben abgegrenzte Einheitenphase ausdrücklich beauftragt. [UNIT_PROTOTYPE.md](UNIT_PROTOTYPE.md) trennt implementierte Regeln, vorläufige Werte, Messungen und verbleibende Grenzen. Weitere Pakete beginnen nicht automatisch; Commits und Veröffentlichung wurden nicht beauftragt.

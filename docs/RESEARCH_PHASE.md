# P6 – Globale Forschung: Bestandsanalyse und Implementierungsplan

Status: Planung auf eigenem Branch. **Keine neuen Technologie- oder Balancingwerte freigegeben.**

## Beschlossene Regeln (D-048)
- Forschung gilt global pro Fraktion, ohne Forschungsgebäude.
- Der vollständige Energiepreis wird beim Start abgebucht.
- Mehrere Technologien laufen unabhängig und parallel über Simulations-Takte.
- Abschluss schaltet Gebäude oder Verbesserungen frei.
- Mehrstufige Verbesserungen haben steigende Kosten und feste Maximallevel.
- Keine Dot-Fabriken, Forschungslabore oder automatischen Verteidigungstürme.

## Bestand (Codeprüfung)
- `Upgrades.try_buy` kauft sofortige Effekte; `research_level` ist **nur** der alte Forschungssieg bis Stufe 5. Beides nicht mit P6-Forschung vermischen.
- `MatchRules.wallet(sim, faction)` liefert die fraktionsgebundene Energie und Upgrades, auch für KI.
- `ConstructionSystem` kennt `outposts_unlocked` und `interceptors_unlocked`, derzeit Laufzeit-/Testlaborflags statt regulärer Forschung.
- `GameHud` hat ein Fähigkeitenfenster und einen Forschungssieg-Knopf, aber keine parallelen Forschungsaufträge.
- `MatchRules` serialisiert KI-Wallets; das bestehende Save/Load-System muss neue laufende Forschung separat und rückwärtsverträglich speichern.
- P5-Sichtwissen ist beim Anzeigen gegnerischer Forschung und Gebäude zu berücksichtigen.

## Implementierungsreihenfolge
1. **Datenmodell:** stabile Technologie-IDs, Definitionen (Voraussetzungen, Kosten, Dauer, Maximallevel, Effekte), per-Fraktion freigeschaltete Stufen und aktive Jobs. Keine konkreten Werte bis zur Entscheidung.
2. **Deterministische Simulations-API:** `can_start`, `start`, `step`, `is_unlocked`; atomare volle Vorauszahlung, mehrere unabhängige Jobs, Abschluss genau einmal. Kein Echtgeld-/Echtzeit-Timer.
3. **Integration:** eine fraktionsgebundene ResearchState-Instanz in Simulation, Bau-Freischaltungen statt Testlaborflags; alte Forschungssieg-Logik bleibt getrennt.
4. **Save/Load:** versionierte additive Daten, Validierung unbekannter IDs, laufender Restzeiten und alter Spielstände.
5. **UI:** Forschungsbaum und Warteschlangen/Fortschritt, verständliche Sperrgründe, keine versteckten Gegnerinformationen.
6. **KI:** Technologieauswahl anhand derselben API und Kostenregeln.
7. **Tests/Performance:** parallele Aufträge, Preisabbuchung, Voraussetzungen, Levelgrenzen, Abschluss, Save/Load, deterministische Fortsetzung, 1k/10k-Dot-Simulation.

## Vor Implementierung des Katalogs zu entscheiden
- Konkrete Technologien und Abhängigkeiten pro Zweig; vorgeschlagen sind Wirtschaft, Militär, Infrastruktur, Energietechnik.
- Kosten, Laufzeiten, Maximallevel und Skalierungsformeln.
- Abbruchregel (Erstattung oder Verlust), wenn ein Auftrag abgebrochen wird.
- Freischaltungen für Außenposten, Mauern, Energiefarmen, Abfangstationen und Sensoren sowie deren Einordnung.

**Abgrenzung:** P6 ersetzt weder den bestehenden Forschungssieg noch führt es ungefragt neue Gebäude oder Kampfmechaniken ein. P5-Livetests bleiben ein separater Abnahmepunkt.

## Entscheidung 2026-10-26: Bestehende Sofort-Upgrades ersetzen

Der Nutzer bestätigt die vier Forschungszweige **Wirtschaft, Militär, Infrastruktur, Energietechnik** und verlangt ausdrücklich, dass die bisherigen Upgrades/Forschungen durch das neue zeitbasierte System **ersetzt** werden, nicht daneben bestehen bleiben. Zunächst vorhandene Fähigkeiten in einen erweiterbaren Baum einordnen, danach weitere Technologien gemeinsam brainstormen und erst nach Freigabe vollständig implementieren.

### Migrationsinventar (vorläufige Zweigzuordnung, noch nicht freigegeben)
| Bestehender Code | Vorschlag für Forschungsbaum | Bestehende Grenzen |
| --- | --- | --- |
| KIND_DIG / dig_level | Wirtschaft: Abbaueffizienz | aktuell kein festes Maximum |
| KIND_SWARM / swarm_level | Wirtschaft: Schwarmkoordination | 4 Stufen |
| KIND_SPEED / speed_level | Infrastruktur: Arbeiterbewegung | 5 Stufen |
| KIND_FUSION2 / fusion2 | Infrastruktur: Verschmelzung II | einmalig; aktuell nicht über try_buy kaufbar |
| KIND_FUSION3 / fusion3 | Infrastruktur: Verschmelzung III | einmalig, erfordert II |
| KIND_CORE / core_level | Infrastruktur: Kerntechnologie | 4 Stufen; Legacy-Kernmechanik gesondert prüfen |
| KIND_ENERGY_SPEED / energy_speed_level | Energietechnik: Energietransport | 5 Stufen |
| KIND_RESEARCH / research_level | Forschungssieg als Technologie-/Siegpfad neu definieren | bisher 5 sofort gekaufte Stufen; nicht unverändert übernehmen |

**Migrationsanforderung:** Alle bisherigen Upgrade-Knöpfe und unmittelbaren Käufe im normalen Spiel durch Forschungsaufträge ersetzen; bestehende Effekte dürfen intern vorübergehend dieselben Upgrade-Felder nutzen, solange nur das Forschungssystem diese verändert. KI, UI, Simulation, Save/Load und Forschungssieg müssen konsistent migriert werden. Debug/Testlabor-Funktionen gesondert erhalten, sofern sie nicht normale Forschung umgehen. Altspielstände explizit migrieren oder nachvollziehbar zurückweisen.

### Erweiterbarkeit
Technologien datengetrieben durch stabile String-IDs und Definitionen (Zweig, Name, Voraussetzungen, Stufen, Kostenformel, Dauerformel, Effekt-ID, Zielgebäude) modellieren. Ein generischer, fraktionsbezogener Scheduler übernimmt Start, Vorauszahlung, parallele Ausführung und Abschluss. Effekt-Handler bleiben explizit registriert und validiert; keine dynamische Ausführung aus Daten. UI und KI lesen denselben Katalog. Neue Technologien sollen ohne Änderung an Scheduler, Save-Schema oder Forschungsbaum-UI ergänzbar sein.

### Noch offen
Die Zweigzuordnung, neue Technologien, konkrete Kosten, Dauer, Voraussetzungen, Abbruch-/Erstattungsregeln und der neue Forschungssieg sind vor Gameplay-Implementierung gemeinsam festzulegen.

## Entscheidung: Verschmelzung entfernen; visuelle Forschung in P6

- Die 2×2-/3×3-Verschmelzung und ihre Freischaltungen sollen vollständig aus dem Spiel verschwinden; **nicht** in den Forschungsbaum migrieren.
- Entfernung muss Simulationslogik, Einheitensteuerung, UI, KI, Tests und Save/Load-Kompatibilität einschließen. Vor dem Entfernen Abhängigkeiten und bestehende Altstand-Migrationsregeln prüfen.
- Der Forschungsbaum soll bereits innerhalb P6 als spielbare, zum DOT-WARS-Pixel-Art-Stil passende interaktive Oberfläche entstehen. Vorgesehen: vier visuell unterscheidbare Zweige, Verbindungslinien/Voraussetzungen, Technologie-Details, Kosten/Dauer/Fortschritt, Zoom/Pan und spätere Erweiterbarkeit.
- Spätere Work-Abnahme: Live-/Performance-Tests und visueller Feinschliff, nicht grundlegende Nachimplementierung.

## Brainstorming: Energieversorgung und Late-Game-Gebäudeverstärkung (noch keine implementierten Regeln)

Nutzeridee: Jedes Gebäude kann optional kontinuierlich mit Energie versorgt werden und zeigt im verstärkten Zustand einen sichtbaren Glow. Je nach Gebäudetyp entstehen passende Buffs: schnellere Forschung/Produktion, erhöhte Lebenspunkte, Selbstheilung, zusätzliche Sichtweite, stärkerer Abbau oder Energieertrag. Auch Mauern sowie durch ein geeignetes Fahrzeug versorgte mobile Mauern sind Kandidaten. Abbau- und Energieerzeugungsgebäude dürfen ebenfalls verstärkt werden, aber positive Rückkopplungen müssen gegen unbegrenztes Skalieren abgesichert sein. Das ist eine Late-Game-Basisstrategie, keine kostenlose Standardwirkung.

Wird ein Gebäude versetzt, muss es am neuen Standort neu ans Energienetz angeschlossen werden; die bisherige Verbindung bleibt nicht erhalten. Bei mobilen Mauern kann die Versorgung durch das Transport-/Versorgungsfahrzeug erfolgen. Vorschlag: Energie-Dots sichtbar physisch transportieren, Routen optional als Netz-Overlay; Buff nur bei tatsächlicher fortlaufender Energiezufuhr. Verfügbarkeit, Verbrauch, genaue Effekte, Stufen, Unterbrechungsregeln und Balance noch entscheiden.

**Konzeptkonflikt:** D-048 sah globale Forschung *ohne* Forschungslabore vor; der neue Vorschlag nennt forschende Gebäude und Kriegerproduktion. Vor Umsetzung ausdrücklich klären, ob die frühere Regel ersetzt wird und welche Gebäude tatsächlich Forschung bzw. Produktion durchführen.

## Beschlossen: Forschungsgebäude und bedarfsabhängiger Glow (2026-10-26)

Die frühere Vorgabe D-048 „globale Forschung ohne Forschungsgebäude“ ist **durch die neue Nutzerentscheidung ersetzt**: Forschung wird in Forschungsgebäuden durchgeführt. Forschung dauert abhängig von der Stärke/Komplexität der Technologie unterschiedlich lange und benötigt währenddessen Energie. Die Forschungsergebnisse gelten weiterhin global pro Fraktion; mehrere Forschungsgebäude sollen parallele Forschungsaufträge ermöglichen (konkrete Kapazität noch festlegen).

**Energie und Visualisierung:** Ein Gebäude leuchtet nur während tatsächlicher energieverbrauchender Tätigkeit oder bei aktiver dauerhaft versorgter Verstärkung; bloße Netzverbindung bzw. abgeschlossene Forschung/inaktives Gebäude erzeugt keinen Glow. Dauerhafte Buffs kosten kontinuierlich Energie. Auch Forschung und Produktion ziehen Energie bedarfsbezogen über sichtbare Energie-Dots an. Energieeffizienz kann durch eine zusätzliche mehrstufige Forschung optimiert werden; Verbrauchswerte, Effizienzgrenzen und Buff-Balancing erst durch spätere Tests festlegen.

**Technische Anforderungen:** Forschungsgebäude, deren Bau-Freischaltung und Produktions-/Forschungszuordnung in den Gebäudekatalog aufnehmen; Energiebedarf pro laufendem Auftrag, Versorgung und Pausen bei Unterversorgung sowie Save/Load deterministisch modellieren. Forschungsdauer und Energieverbrauch unabhängig konfigurierbar, keine ungefragten festen Zahlen. Ein ruhendes Gebäude hat keine Aktivitätsglow. Zu klären: Anfangsverfügbarkeit des ersten Forschungsgebäudes, Kosten und Bauablauf; Stromversorgung beim Start einer Forschung; genaue Regeln für Unterbrechung/Abbruch und Rückerstattung.

## Beschlossenes Konzept: transportierbare Energie-Reliquien (2026-10-26)

- Auf jeder Karte ist eine begrenzte Anzahl Reliquien verteilt; genaue Anzahl und Verteilungsregeln sind offen.
- Reliquien erzeugen **dauerhaft Energie, solange sie an das Energienetz angeschlossen sind**. Ohne Anschluss keine Einspeisung.
- Spezielle Transportfahrzeuge können Reliquien aufnehmen und in die eigene Basis bringen. Gegner können sie wieder stehlen und abtransportieren.
- Beim Aufnehmen, Transport oder sonstiger Trennung vom Netz endet die Energieeinspeisung unmittelbar; nach erneutem Anschluss am neuen Standort kann sie wieder beginnen.
- Damit entstehen umkämpfte externe Versorgungsorte und transportierbare strategische Ressourcen.

**Abgrenzung/Prüfpunkte:** Die vorhandenen Reliquien sind bisher auch Teil eines Siegmodus (Gebietskontrolle); dessen genaue zukünftige Beziehung zu transportierbaren Energie-Reliquien ist noch zu entscheiden. Energieertrag, Verbindung/Anschluss, Transportkapazität, Abladen, Diebstahl, Neutralität/Besitz und Save/Load müssen vor Implementierung präzisiert werden. Keine Zahlen oder automatische Umdeutung der bisherigen Siegmechanik annehmen.

## Beschlossen: Forschungsgebäude ab Start; ein Reliquientyp und neuer Siegmodus (2026-10-26)

- **Forschungsgebäude ist ab Spielbeginn baubar**, ohne vorgelagerte Technologie. Übliche Baukosten/-dauer bleiben zu bestimmen.
- Es gibt **genau einen Reliquientyp**: transportierbare, stehlbare Energiequelle und zugleich Siegobjekt. Der bisherige Gebietskontroll-Reliquiensieg wird durch den neuen Mechanismus ersetzt.
- Sobald **alle** auf der Karte vorhandenen Reliquien **innerhalb der eigenen Basis** einer Fraktion liegen, beginnt ein Countdown von **ca. 10 Minuten** (vorläufig 600 Sekunden Spielzeit). Bleibt die Bedingung bis zum Ende bestehen, gewinnt diese Fraktion.
- **Während des Countdowns sind alle Reliquien für alle Spieler sichtbar**, trotz Fog of War, damit gegnerische Spieler den Sieg noch verhindern können. Eine eindeutige globale Sieg-Warnung mit verbleibender Zeit ist vorzusehen.
- Ein Wegtransport/Diebstahl einer Reliquie lässt die Bedingung entfallen. **Noch offen:** Countdown bei Unterbrechung zurücksetzen oder pausieren? Was genau zählt als Basisfläche (Kern, Außenposten, Mauereinfassung)? Was bedeutet Sichtbarkeit (Positionen immer live oder nur aktuelle Sicht)? Timer bei Spielpause/Spielgeschwindigkeit und Siegkonflikten deterministisch in Ticks abbilden.
- 600 Sekunden entsprechen bei 20 Simulations-Ticks pro Sekunde vorläufig 12.000 Ticks; Taktfrequenz im aktuellen Code vor Umsetzung verifizieren. Keine alte 100-Takt-Besetzungsregel als neue Reliquienbedingung übernehmen.

## Beschlossen: 60-Sekunden-Kulanz bei unterbrochenem Reliquien-Countdown (2026-10-26)

Der Reliquiensieg benötigt weiterhin sämtliche Reliquien innerhalb der eigenen Basis für einen insgesamt zehnminütigen Sieg-Countdown. Wird die Bedingung unterbrochen (z. B. Diebstahl), **pausiert** der Sieg-Countdown sofort und eine **60-Sekunden-Unterbrechungsfrist** startet. Sind alle Reliquien **vor Ablauf** der 60 Sekunden wieder innerhalb der Basis, läuft der Sieg-Countdown **mit unverändertem Reststand** weiter. Besteht die Unterbrechung **mindestens 60 Sekunden**, wird der Sieg-Countdown vollständig auf 10:00 zurückgesetzt. Sind später wieder alle Reliquien in der Basis, startet ein neuer zehnminütiger Countdown. Eine Unterbrechung von genau 60 Sekunden zählt als Reset. Im HUD beide verbleibenden Zeiten anzeigen; die Relikt-Sichtbarkeit für alle Fraktionen soll während der laufenden Siegesphase und der Unterbrechung bestehen bleiben (Detail bei Umsetzung prüfen). Deterministisch über Simulationsticks und Save/Load abbilden.

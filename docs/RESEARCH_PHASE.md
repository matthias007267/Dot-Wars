# P6 – Gebäudegebundene Forschung, Energieversorgung und Implementierung

Status: Umsetzung auf Branch `feat/p6-research-foundation` / Draft-PR #8. **Ältere Abschnitte dokumentieren historische, inzwischen überholte Planungsstände. Maßgeblich sind die neuesten Beschlüsse am Dokumentende und der Implementierungsstatus.**

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

## Implementierungsbeschluss: P6 in inkrementellen Schritten (2026-10-26)

**Start der Umsetzung jetzt; keine weitere umfassende Vorabplanung.** Die alte Sofortkauf-Forschungslogik wird ersetzt, nicht der Datenkatalog/Forschungsbaum mit vier Zweigen und Abhängigkeiten. Arbeitstitel des von Anfang an baubaren Gebäudes: **Forschungszentrum**.

Reihenfolge für kleine testbare Änderungen:
1. P6.1 Forschungszentrum als baubares Gebäude mit Auswahl-/Informations-UI; keine Fusion wieder einführen.
2. P6.2 Zeitbasierte, gebäudegebundene Forschung pro Fraktion; mehrere Zentren können unabhängig parallel forschen; gemeinsamer Tech-Katalog, definierte Freischaltungen, deterministische Simulation, AI, Save/Load und Tests. Bestehende Sofortkauf-Upgrades vollständig migrieren/ersetzen.
3. P6.3 Gebäude fordern Energie bedarfsbezogen an; sichtbare Energie-Dots transportieren Energie vom Kern/Netz zum Ziel. Unterversorgung pausiert Aufträge, keine kostenlose Forschung.
4. P6.4 Aktivitätsglow nur bei tatsächlichem Verbrauch; optionale dauerhaft versorgte Gebäudebuffs mit kontinuierlichem Energiebedarf.
5. P6.5 Visueller pixelartgerechter Forschungsbaum mit vier Zweigen, Zoom/Pan und Abhängigkeiten auf dem gemeinsamen Tech-Katalog.
6. P6.6 Energienetz, Energieeffizienz und zusätzliche Gebäudetypen.
7. Reliquien-Energieerzeugung, Transport/Diebstahl und neuer Siegmodus als eigenes nachgelagertes Arbeitspaket.

Inkrementelle PRs mit Tests/CI, keine ungefragten Balancingzahlen, vorhandene Spielmechaniken möglichst stabil halten. Dies ist die Implementierungsreihenfolge, noch keine Behauptung, dass Code implementiert sei.

## WORK_HANDOFF – verbindliches Umsetzungs- und Prüfprotokoll

**Ziel:** In **demselben Draft-PR #8** P6.1 bis P6.6 entwickeln. Kein separater PR. Nutzer kann aktuell nicht selbst testen; nach vollständiger Umsetzung wird ChatGPT Work gezielt zum Prüfen, Optimieren und visuellen Polieren beauftragt. **Work soll das vorhandene System prüfen, nicht neu entwerfen oder von vorn bauen.** Bei Widerspruch haben die neuesten Beschlüsse Vorrang vor dem historischen Planungsabschnitt oben.

### Statuslegende
- `TODO`: nicht implementiert
- `IN PROGRESS`: in Arbeit, noch nicht integriert/validiert
- `CODE COMPLETE`: integriert, automatisierte Tests bestanden, aber kein manueller Live-Test
- `WORK VERIFIED`: in Godot live geprüft
- `BLOCKED`: konkrete Nutzerentscheidung nötig

### Umsetzungsstand (2026-10-26)
| ID | Status | Ziel und Abnahmekriterien |
| --- | --- | --- |
| P6.1 | IN PROGRESS | Forschungszentrum von Anfang an baubar, korrekt platziert, konstruiert, selektiert, gerendert, UI erreichbar; KI/Save/Load berücksichtigen |
| P6.2 | IN PROGRESS | Zeitbasierte, gebäudegebundene Forschungsjobs, mehrere Zentren/Parallelität, globale Fraktionswirkung, Unterversorgung pausiert, alte Sofortkäufe im normalen Spiel ersetzt, Fusion entfernt, Save/Load/AI/Tests |
| P6.3 | IN PROGRESS | Energie-Dots werden bei aktivem Bedarf vom Kern/Netz zum Ziel transportiert; keine reine Wallet-Simulation; Energiefluss und Unterbrechungen deterministisch |
| P6.4 | TODO | Glow **nur** bei tatsächlicher energieverbrauchender Tätigkeit oder dauerhaftem Buff; je Gebäudetyp angemessene Buffs; Dauerverbrauch und Unterversorgung |
| P6.5 | TODO | Datengetriebener vierzweigiger Forschungsbaum (Wirtschaft/Militär/Infrastruktur/Energietechnik) mit Abhängigkeiten, Freischaltungen, Fortschritt; zunächst funktionale UI, anschließend pixelartgerechte Visualisierung, Pan/Zoom |
| P6.6 | TODO | Energienetz/Netzansicht, Energieeffizienzforschung, erweiterbare Gebäude-/Versorgungsregeln; Balancing-Konfiguration statt ungeprüfter endgültiger Werte |

### Entscheidungen und Nichtziele
- Arbeitstitel Gebäude: **Forschungszentrum**; **von Anfang an baubar**.
- Forschung **findet in Gebäuden statt**, globaler Technologieeffekt pro Fraktion. Forschungsdauer und Verbrauch steigen mit Technologiekomplexität; Energie wird **während** der Tätigkeit verbraucht, nicht pauschal vorab. Bei fehlender Energie pausiert der Fortschritt ohne Verlust.
- Gebäude können auch ohne Buff funktionieren; nur aktive Verbraucher glühen. Dauerhafte Gebäudebuffs kosten laufend Energie. Gebäude nach Versetzen erneut anschließen. Energieeffizienz als erforschbare Verbesserung; Energieerzeuger-Buff darf keine unkontrollierte positive Rückkopplung auslösen.
- **Keine Fusion** (2×2/3×3), keine alten Sofortkauf-Forschungsbuttons, keine automatischen Verteidigungstürme als stillschweigende Erweiterung.
- Krieger T1/T2/T3 und weitere Technologien als datengetriebene spätere Erweiterungen; keine unbeschlossenen endgültigen Werte erfinden.
- Reliquien: **nur ein Typ**, begrenzte Anzahl, transportierbar/stehlbar, speisen nur bei Netzanschluss Energie ein. Reliquiensieg: alle Reliquien in eigener Basis -> 10:00 Countdown; global sichtbare Reliquien; bei Verlust Countdown pausiert und 60 Sekunden Kulanz, Wiederbeschaffung vor 60 Sekunden setzt Countdown fort, ab 60 Sekunden kompletter Reset. **Reliquien-Umsetzung ist ein eigenes Folgepaket, nicht stillschweigend Teil von P6.1–P6.6.**

### Pflichtprotokoll für jeden Implementierungsschritt
Beim Beginn Status auf `IN PROGRESS` setzen; bei Abschluss `CODE COMPLETE` erst nach nachvollziehbarer Integration und erfolgreichen relevanten Tests. Unter jedem Schritt dokumentieren: geänderte Dateien, technische Architektur/öffentliche APIs, Tests und deren Ergebnis/CI-Link, bekannte Einschränkungen, verbleibende Work-Prüfaufgaben, Commit-SHA. Ungetestete Funktionen niemals als geprüft markieren. PR #8 bis zur Abnahme Draft lassen; kein Merge.

### Work-Auftrag nach Code-Abschluss
1. **Zuerst dieses Dokument und PR #8 lesen**, Implementierungsstatus und Commit-Historie erfassen; vorhandene Implementierung nutzen.
2. Godot-Projekt starten, normale Spielrunde und Debug/Testlabor durchspielen: Forschungszentrum bauen, mehrere Forschungsaufträge, Energiefluss und Unterversorgung, Aktivitäts-Glow, Gebäudebuffs, Forschungsbaum, Save/Load, KI.
3. Godot-Debugger/Fehler, UI-Klickwege, Darstellungsfehler, Performance bei 1k/10k Dots, Framerate, Speicher und deterministische Simulation dokumentieren.
4. Pixelart-Kohärenz und Lesbarkeit verbessern, ohne Simulationsregeln neu zu implementieren; fehlende Funktionen/Regressionen als konkrete Tickets mit Repro-Schritten und Screenshots erfassen.
5. `WORK VERIFIED` nur für tatsächlich getestete Schritte setzen. Keine ungefragten Balance- oder Designänderungen.

### P6.1 Implementierungsjournal (2026-10-26)
- Commits: `90d3bff` (`src/sim/settlement_store.gd`), `5b2550e` (`src/sim/construction_system.gd`), `f2dc3db` (`src/ui/game_hud.gd`).
- Forschungszentrum als neuer `SettlementStore.Kind.RESEARCH_CENTER = 3`; Bauplatz 3×3, 200 HP, 300 Energie und 300 Arbeitertakte **vorläufige Prototypwerte**, noch kein finales Balancing. Bauen über das Fähigkeitenfenster von Anfang an, normale Bau-/Baustellenlogik und bestehende Site-Snapshot-Serialisierung.
- **Status IN PROGRESS:** Kein Godot-Lauf/CI-Nachweis vorhanden; Bau, Rendering, Auswahl, Speicherung und KI müssen geprüft werden. Forschungsaufträge, Energiefluss, Buffs und Baum sind **noch nicht implementiert**.
- Work-Prüfung: Gebäude setzen, Arbeiter zuweisen, Fertigstellung, Auswahl, Render-Farbe, Abbruch, Save/Load und alle Spielmodi; sicherstellen, dass Forschungszentren nicht versehentlich als Krieger-Produktionsstandort oder Sieg-/Überlebens-Kern gelten.

### P6.2 Implementierungsjournal (2026-10-26)
- Commits: `4897e0a` (neuer `src/sim/research_system.gd`), `2d0196d` (Simulation), `5c801f9` (SaveGame), `6aca958` (MatchRules), `bc2415d` (HUD), `c882136` (Scheduler-Korrektur), `4099ff6` (ConstructionAI).
- Datengetriebener erster Forschungskatalog mit stabilen IDs `dig`, `swarm`, `speed`, `core`, `energy_speed`, `victory`, vier Zweigen, Abhängigkeiten, Stufenlimits und **vorläufigen** Takt-/Energiekosten. Das ist ein **Startkatalog**, noch nicht der vollständige endgültige Forschungsbaum.
- Forschung ist einem fertigen Forschungszentrum zugeordnet, maximal ein aktiver Auftrag pro Zentrum und Technologie pro Fraktion. Mehrere Zentren können parallel unterschiedliche Technologien bearbeiten. Fraktions-Wallet wird pro Takt belastet; bei Energiemangel bleibt Fortschritt stehen. Bei zerstörtem Zentrum verfällt der Auftrag ohne Erstattung. Effekte wirken fraktionsweit. Kerntechnologie vorläufig nur für Fraktion 0 und bei aktivem Legacy-Kernsystem möglich.
- Simulation integriert Forschungsfortschritt und State-Hash. SaveGame enthält additive `research_state` (Stufen/Jobs), mit struktureller Validierung beim Laden. HUD enthält Technologie-Startknöpfe für ausgewähltes Zentrum und zeigt Taktfortschritt. Alte normale Sofortkauf-Buttons sind deaktiviert, Debug-Käufe weiterhin möglich. KI kann Forschungszentrum errichten und startet ausgewählte Forschungen über denselben Scheduler.
- **Nicht implementiert in P6.2:** physische Energie-Dot-Zufuhr (P6.3), optischer Glow (P6.4), vollständiger Forschungsbaum (P6.5), Energieeffizienz (P6.6), vollumfängliche alte Forschungssieg-Neukonzeption. Der aktuelle Wallet-Taktverbrauch ist **nur ein Übergang**, kein physischer Energietransport.
- **Status IN PROGRESS, nicht CODE COMPLETE:** Kein Godot-Binary/CI-Ergebnis in dieser Sitzung; Compile-, Laufzeit-, KI-, UI- und Save/Load-Tests stehen aus. Besondere Prüfpunkte: typisierte GDScript-Dictionary-Zugriffe, Forschungsjobs bei Kernexpansion, konsistente Wiederherstellung alter Saves und Fraktions-Wallet, Anzeige des Forschungsdialogs, Forschungszentrum-Rendering und Auswirkung auf normale Produktion. P6.1 ebenfalls weiterhin IN PROGRESS.

### P6.3 Implementierungsjournal (2026-10-26)
- Commits: `2fcf82e` (ResearchSystem: gebäudegebundener Energiepuffer, Empfänger), `8a8e146` (MatchRules: aktive Forschungszentren als Energie-Gates), `696ea14` (EnergyTransport: physische Dots am Forschungsgate in Gebäudepuffer statt Wallet), `999c580` (Forschungszentren nicht als Produktionsstandorte), `60dd0ad` (Singleplayer-Gates), `c48e11d` (Lieferstatistik).
- Aktive Forschungszentren registrieren eigene Empfangszellen. Die **bereits vorhandenen sichtbaren Energie-Dots** folgen dem regulären deterministischen Flowfield bis zur Gebäudekante; bei Ankunft wird exakt ein Dot entfernt und eine Einheit dem `research.supply[site]` gutgeschrieben. Forschung verbraucht diesen Puffer tickweise; bei fehlender Lieferung pausiert der Auftrag. Der normale Wallet-Eingang für Dots, die an andere Tore geliefert werden, bleibt bestehen. Versorgung und laufende Aufträge werden in `research_state` gespeichert und im State-Hash berücksichtigt.
- **Wichtige Einschränkung:** Die aktuelle Quelle der Dots ist das bestehende Bergbau-/Energiesystem. Ein *neuer, vom Kern ausgehender* Energie-Dot-Versand mit Nachfrage-/Reservierungslogik ist **noch nicht** implementiert; die Forschung konkurriert zunächst mit Kernempfängern um vorhandene bewegliche Energie-Dots. Eine garantierte faire Verteilung, Bedarfssteuerung und echte Kern-zu-Gebäude-Logistik bleiben offene P6.3-Aufgaben. Eine Forschung kann daher bei ungünstiger Routenpriorität ohne Energie bleiben. Physische Lieferungen sind keine bloßen Wallet-Abzüge, aber **noch nicht das vollständig vereinbarte Kern-Netz-System**.
- **Status IN PROGRESS:** Kein Godot-Binary vorhanden, keine automatisierten Tests ausgeführt; für den letzten Commit wurden keine PR-Workflow-Runs gefunden. Work/CI müssen GDScript-Parser, deterministische Parallelversorgung, Wegfindung, Energiemassenbilanz, Speicherstände, Zerstörung während der Lieferung, Faction-Isolation und nicht-Match-Modus prüfen.

### P6.3 Netzpflicht – Nutzerbeschluss und Zwischenstand (2026-10-26)
**Verbindliche Transportregeln:** Freie Energie-Dots (z. B. aus dem Abbau) werden vom Kern angezogen. Gezielter Energietransport **zwischen Gebäuden** (Kern -> Forschungszentrum, Bohrer -> Kern, Bohrer -> andere Gebäude, weitere Gebäudepaare) ist **ausschließlich über ein vorher vom Spieler platziertes, zusammenhängendes Energienetz** erlaubt. Keine unsichtbaren Direktverbindungen, kein freier Gebäudetransport durch die Luft. Energieeinheiten dürfen nicht dupliziert werden.

**Bereits implementierte Grundlage:** `src/sim/energy_network.gd` mit fraktionseigenen, einzeln kostenpflichtigen Leitungszellen, orthogonaler Wegsuche von Gebäuderand zu Gebäuderand, Snapshot/Restore und State-Hash (`fd4f274`, `029496b`); Integration in Simulation und SaveGame (`d4ea2a7`, `a9bbcd6`); manuelle Platzierung im Fähigkeitenfenster (`380c0ce`). `ResearchSystem` sendet nun bei Forschungsbedarf bezahlte, zellenweise durch das Leitungsnetz bewegte Energieeinheiten vom eigenen Kern zum Forschungszentrum; ohne Leitung kein Versand. Position/Unterbrechung bei Leitungsänderungen werden berücksichtigt (`304bc81`, `f6b1a07`). Forschungszentren sind keine freien Energie-Dot-Empfänger mehr; freie Dots werden weiterhin von den bisherigen Kern-/Außenposten-Gates angezogen (`a467b5f`, `077acb3`, `0a7ec72`).

**Noch offen, ausdrücklich nicht fertig:**
- Leitungsgebundene Energie-Dots/Sendungen müssen **sichtbar gerendert** werden; derzeit sind Sendungen Simulationsdaten, keine sichtbaren Dots.
- Bohrer/Quellen -> Kern bzw. andere Gebäude müssen an das Netz angeschlossen und über dasselbe Transportprotokoll geführt werden; bestehende Mining-Energie-Dots sind bislang frei und werden nach bisherigen Regeln zum Kern geleitet. Unterscheidung freier Mining-Dots vs. gebäudegebundener Förderenergie erforderlich.
- Bei Kern-Versand wird Energie derzeit aus der Wallet in eine Sendung umgewandelt; erst die spätere Ankunft am Forschungszentrum ermöglicht Forschung. Bei Zerstörung/Unterbrechung sind Rückerstattung/Verlust, Kapazitäten und faire Verteilung noch zu spezifizieren.
- Netzplatzierung braucht visuelle Leitungsdarstellung, Abbau/Reparatur, zusammenhängende Mauszeichnung und Kollisions-/Bauprüfung; bislang Einzelklick und keine Darstellung.
- KI baut derzeit keine Leitungen und kann Forschungszentren daher nicht versorgen. KI-Planung und Netzpfade nachrüsten.
- Performance: `connected_path` ist aktuell einfache BFS mit linearem `owner_at`; für viele Leitungen/Sendungen gecachte, inkrementelle Netzgraphen und Wegfindung einplanen.
- **Kein Godot-/CI-Test durchgeführt**; P6.3 bleibt `IN PROGRESS`, keinesfalls `CODE COMPLETE`. Work soll bestehende Dateien prüfen und gezielt ergänzen, nicht neu bauen.

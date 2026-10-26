# Konzeptabgleich und spätere Anpassungen

Aktueller Soll/Ist-Abgleich vom 26. Oktober 2026 einschließlich `main`/PR #8, P5/P6 und CI-Testmigration: [STATUS_AUDIT_2026-10-26.md](STATUS_AUDIT_2026-10-26.md). Die älteren Statusabschnitte unten sind historische Snapshots.

Aktueller Nachtrag D-062: P4 Energie ist als begrenzter Prototyp ausdrücklich beauftragt und lokal umgesetzt: Routenverfall, Abfangstationen, unbegrenztes erneutes Abfangen, Neutralisierung bei Stationszerstörung und vollständige Transportbilanz. Ältere „fehlt“-Aussagen zu diesen Energiepunkten sind historische Stände. Testwerte und Grenzen: [ENERGY_PHASE.md](ENERGY_PHASE.md). Fog/Welt/Forschungsbaum/Netzwerk fehlen weiterhin.

Aktueller Nachtrag D-060: Manuelle Reparaturen, Baustellenabbruch und KI-Bauplanung wurden ausdrücklich als Punkte 1–3 beauftragt und lokal integriert. Ältere Aussagen über noch fehlende Reparaturen/KI-Bauplanung sind historische Stände. [MAINTENANCE_PHASE.md](MAINTENANCE_PHASE.md) trennt die Umsetzung von vorläufigen Zahlen und offenen Grenzen. Welt/Fog/Energieraub/Verfall/Forschungsbaum/Netzwerk bleiben offen.

Nachtrag Bauphase D-059: Die drei Rückfragen sind beantwortet und die Bauintegration ist lokal umgesetzt: Hauptkerne/Außenposten mit festen Testflächen, Arbeiterbau, neue Produktions- und Energieempfangsorte, Ersatzkern und beschlossene Schutzprüfung. Die früheren „fehlt“-Aussagen zu A06/P3 beschreiben den historischen Abgleich; der aktuelle Umfang und offene Grenzen stehen in [CONSTRUCTION_PHASE.md](CONSTRUCTION_PHASE.md). Reparaturen, Fog, neue Welt, Energieraub/Verfall, Forschungsbaum und Netzwerk fehlen weiterhin.

Stand: 25. Oktober 2026. **Der ursprüngliche statische Abgleich unten ist ein historischer Snapshot der Planungspause. Danach wurde die Einheitenphase ausdrücklich beauftragt.**

## Aktueller Implementierungsnachtrag

Die Entscheidungen D-051 bis D-053 lösen die offenen Fragen zu Fusion, Endpositionen und Solo-Siegzielen. Umgesetzt sind das 50-Arbeiter-Limit einschließlich Käufen in der Warteschlange, getrennte Krieger mit HP/Produktion/Nahkampf, eigene Arbeiterdurchquerung bei freier Endposition, gegenseitige Kriegerblockade, freie gemischte Auswahl, Kernschaden durch Krieger und additive Speicherkompatibilität. Fusion und alte Solo-Siegziele sind deaktiviert. [UNIT_PROTOTYPE.md](UNIT_PROTOTYPE.md) enthält Tests, vorläufige Zahlen und Messgrenzen. Die früheren Aussagen „fehlen“ in A04/A05 und die offenen Fusions-/Solo-Fragen gelten deshalb nur für den ursprünglichen Snapshot.

P0 ist für diese Einheitenphase geklärt, P2 als begrenzter spielbarer Prototyp umgesetzt; die vollständige Skalierungsabnahme ist offen. P1 wurde nicht als großer gemeinsamer Architekturumbau begonnen. Welt/Diagonalen/Höhlen, Bau und Außenposten, Überleben durch begonnenen Kernbau, Energieraub und Verfall, Sichtwissen, zeitbasierte Forschung sowie echter Netzwerk-Multiplayer fehlen weiterhin. Die ursprüngliche priorisierte Liste bleibt als Planungsgrundlage erhalten und ist keine automatische Freigabe dieser Folgepakete.

## Ursprünglicher statischer Abgleich vor der Umsetzung

## Quellen, Geltung und geprüfter Stand

- Verbindliche neue Quelle: die Nutzerzusammenfassung in diesem Entwicklungs-Chat vom 25. Oktober 2026. Sie ist in [GAME_DESIGN.md](GAME_DESIGN.md) nach Verbindlichkeit, vorläufigen Werten, Skalierungszielen und offenen Fragen geordnet.
- Ergänzend gelesen: Chat [„Abbausystem überdenken“](chatgpt-conversation://6add1cc3-f640-83eb-90ee-193d6250c871). Die Schnittstelle lieferte fünf jüngste Nutzerbeiträge; die Assistentenantworten waren lediglich Inhaltsreferenzen und nicht als Klartext lesbar. Eine ältere Seite wurde nicht angeboten. Aus nicht abrufbaren Teilen werden keine weiteren Entscheidungen behauptet.
- Die lesbaren Nutzerbeiträge bestätigen freie Dot-/Gruppenauswahl, Verteidigungsradius, weiterarbeitende angegriffene Arbeiter, wiederholtes Abfangen, Gebäudegedächtnis, begonnenen Kernbau, Neutralisierung gepufferter Energie, Ausschluss zusätzlicher Fabriken, globale Forschung, Forschungszahlung und -parallelität, manuelle Reparatur, Sensoren und Mauerlinien.
- Geprüftes Hauptprojekt: `C:/Users/matth/Documents/GitHub/Dot-Wars`, Git-Stand `cf36ab4` („Performance Upgrade Tests“) samt vorhandener Arbeitskopie. Der Startzustand enthielt bereits eine nicht von diesem Auftrag erzeugte Änderung in `src/sim/swarm_mind.gd` und den nicht versionierten Unterordner `dot-wars/` mit separatem Checkout. Beides bleibt unangetastet; der zweite Checkout ist nicht die Grundlage dieses Abgleichs.
- Die Codeprüfung ist statisch. In dieser Planungspause wurden weder Spiel noch Benchmarks gestartet, kein neuer Spieltest als bestanden ausgegeben und keine alten Messungen als neuer Leistungsnachweis übernommen.

## Was als Grundlage erhalten werden kann

Die Trennung zwischen Headless-Simulation und Darstellung, Packed-Array-Daten, feste Ganzzahltakte, deterministische Konfliktauflösung, native Rechenkerne mit GDScript-Referenz und die bestehende Testsammlung sind brauchbare Grundlagen. Sie erfüllen die neuen Spielregeln aber nicht von selbst.

Bereits vorhanden sind pixelweiser Ressourcenabbau, unzerstörbares Material, Arbeiterbelegung, Auswahl einzelner Arbeiter und Auswahlrechtecke, physisch transportierte Energie, Gutschrift bei Ankunft und getrennte Guthaben lokaler KI-Fraktionen. Diese Anteile sollen später gezielt erweitert werden, statt funktionierende Teile pauschal zu löschen.

## Abweichungen nach Anforderungsgruppe

### A01 – Große Welt und Lobby: W01, W02

**Status: teilweise Grundlage vorhanden, Zielarchitektur und Lobby fehlen.** `SimConfig.validate()` begrenzt `world_size` heute auf 16–4096 und erzeugt eine quadratische Karte. `WorldState` hält weltweite Arrays (`width * height`); Rendering-Chunks sind keine nachladbare Welt. `WorldGenerator.generate()` erzeugt die ganze Karte auf einmal. Das Startmenü vergibt eine Größe für einen lokalen Lauf, keine gemeinsame Netzwerk-Lobby.

Späterer Bedarf: Entscheidung über Weltgrenzen und Lobbyparameter, geeignetes Koordinaten- und Speicherbudget, reproduzierbare Generierung größerer Bereiche, persistente Änderungen und Kartenparameter in einer echten Partie. Streaming, große endliche Karten oder ein bestimmtes Chunkformat sind bisher nur mögliche Lösungen.

### A02 – Pixel, Diagonalen und Höhlen: W03, W04

**Status: Pixelabbau und unzerstörbares Material vorhanden; Diagonalen und natürliche Höhlen fehlen.** `MiningSystem.acquire_target()`/`claim_cell()`, `MovementSystem.neighbor()`, Wegfelder, Frontsuche und native Rasterkerne verwenden vier orthogonale Nachbarn. `WorldGenerator.generate()` füllt einen Materialkörper und öffnet Startlichtungen; eine natürliche Höhlengenerierung ist nicht vorhanden. Das Demo-Vorkommen unzerstörbarer Felsen ist noch kein ausgearbeitetes Weltbiom.

Späterer Bedarf: Diagonal- und Eckregeln festlegen und dann Abbau, Pfade, Flächenlisten, UI-Aufträge, native und Referenzberechnung gemeinsam anpassen. Vorhandene orthogonale Tests bleiben bis zu dieser ausdrücklich beauftragten Regeländerung Bestandsprüfungen.

### A03 – Erkundung, Verbündete und Fog of War: W05, W06, F01–F04

**Status: Sicht-/Wissenssystem und Bündnisse fehlen; getrennte Konten teilweise vorhanden.** Weltbild und Minimap lesen den aktuellen Weltzustand. Es fehlen spieler-/bündnisbezogene aktuelle Sicht, erkundetes Gelände und letzte bekannte Gebäudezustände. `MatchRules.wallet()` und `EnergyStore.owner` trennen bereits lokale Fraktionsguthaben bzw. Energiezuordnung, bilden aber keine Sichtallianz ab.

Späterer Bedarf: Sichtblockaden durch Material und Gebäude, gemeinsames Wissen von Verbündeten bei getrennten Konten, sofortiges Ausblenden gegnerischer Dots und unveränderliche letzte bekannte Gebäudestände außerhalb der Sicht. Auch Minimap, Trefferprüfungen der Auswahl, Befehlsvorschau, Gegneranzeigen und später übertragene Netzwerkdaten müssen das Wissen respektieren. Versteckte Außenposten dürfen nicht über Nebenanzeigen bekannt werden.

### A04 – Arbeiterlimit, Krieger und Auswahl: D01–D03

**Status: Arbeiter und deren Auswahl vorhanden; vorläufiges 50er-Limit und Krieger fehlen.** Käufe und Testlabor können weit mehr als 50 Arbeiter erzeugen. `WorkerStore` besitzt keine eigenständigen Kriegerdaten mit Lebenspunkten und Angriffszustand. Der Krieger-Begriff in `DotOrder`/`GameHud.issue_war()` ist eine vorbereitete Befehlsoberfläche; die Meldung „Krieger folgen später“ ist kein implementierter Einheitentyp.

Späterer Bedarf: Limitdefinition einschließlich Warteschlangen und Verschmelzung, Produktion je Spieler über alle Produktionsgebäude, unterscheidbare Einheitentypen sowie freie Auswahl und Befehle für beide Typen. Die Beschränkung auf 50 Arbeiter ist vorläufig; mehrere Tausend Krieger pro Spieler sind ein neues Skalierungsziel, kein bereits gesetztes Einheitenlimit.

### A05 – Kollision und Kampf: D04–D10

**Status: gegenseitige Arbeiterblockade vorhanden; Krieger-Kollisionen und Nahkampf fehlen.** `WorkerStore.occupant` speichert genau eine Arbeiter-ID pro Zelle. `MovementSystem` und sein Native-Backend kennen nur den bisherigen Arbeiterbestand. Damit sind „alle Krieger blockieren sich“ und „eigene Krieger durchqueren eigene Arbeiter“ nicht allein durch einen zusätzlichen Fraktionsvergleich erfüllt.

`MatchRules._combat()` zählt heute benachbarte Arbeiter als Schaden am feindlichen Kern. Es gibt keinen Krieger-gegen-Dot-Kampf, keinen Verteidigungsradius und keinen Arbeiter-Lebenspunkte-/Todesablauf. Die neue Regel ist nicht durch das aktuelle Kernschadenssystem abgedeckt.

Späterer Bedarf: typ- und besitzerabhängige Durchquerung, Nahkampfreichweite, automatische Kontaktangriffe und Radiusreaktion, Schadens- und Todesreihenfolge sowie Erhalt von Arbeiteraufträgen bei Angriff. Räumliche Nachbarschaftssuche ist eine mögliche Skalierungshilfe; ein Vollvergleich jeder Einheit mit jeder anderen wäre für Tausende Krieger problematisch. Ob getrennte Belegungsebenen oder eine andere Struktur verwendet werden, ist noch keine Architekturentscheidung.

### A06 – Hauptkern, Außenposten und Niederlage: K01–K06

**Status: ein Kern je Fraktion und Arbeiterkauf vorhanden; Zielsystem fehlt.** `MatchRules.cores` hält eine Kernposition pro Fraktion, `core_hp` deren separaten Schadensstand. Die Materialzelle bleibt unzerstörbar; das ist vom HP-Modell zu unterscheiden. Außenposten, Kriegerproduktion, Gebäudebaustellen, Arbeiter-Baufortschritt und ein Wiederaufbau auf normalen Bauplätzen fehlen.

Die bisherige Kernauslöschung ruft `_eliminate()` auf und entfernt die Fraktionsarbeiter. Es gibt keine Prüfung eines tatsächlich begonnenen Kernbaus. Diese sofortige Entfernung widerspricht der neuen Wiederaufbau-/Überlebensregel und darf später nicht unverändert als Ziel-Niederlage übernommen werden.

Späterer Bedarf: Produktionsgebäude mit gemeinsamen Grundfunktionen, unterschiedliche Größen/Robustheit, steigende Außenpostenkosten, fester Wiederaufbaupreis sowie ein eindeutig erfasster erster Arbeiterbeitrag. Der komplette Niederlageausdruck einschließlich fertiger Außenposten, Baustellenabbruch und Zerstörung bleibt vor der Umsetzung zu präzisieren. Ein bloß bestellter Kern darf den Schutz nicht auslösen.

### A07 – Physischer Energietransport: E01–E03

**Status: physischer Transport und Ankunftsgutschrift vorhanden; mehrere Empfänger und Timeout unvollständig bzw. fehlend.** `EnergyStore.step()`/`_step_routed()` führen Energie über Distanzfelder und berücksichtigen Besitzer. Ein blockierter Dot wartet. `birth` ist eine Herkunftszelle, kein Alter oder Routen-Timer. Es gibt keinen 60-Sekunden-Verfall und kein allgemeines Empfängermodell für mehrere eigene Produktionsgebäude.

Späterer Bedarf: Empfängerauswahl und Routenbegriff, getrennte Behandlung einer fehlenden Route und vorübergehender Belegung, Timerregel und Verfallsbilanz. Die heutige Bilanz `generated = delivered + pending` deckt Verfall oder neutrale Stationspuffer nicht vollständig ab.

### A08 – Energieabfang und Neutralisierung: E04–E07

**Status: fehlt.** Ein Besitzerfeld ist vorhanden, aber weder Energie-Abfanggebäude noch deren Puffer, wiederholter Eigentumswechsel oder Neutralisierung bei Gebäudezerstörung. Das heutige `refined`-Merkmal für einmalige Veredelung ist kein Abfanglimit und darf dafür nicht umgedeutet werden.

Späterer Bedarf: physisch erhaltene Energieeinheiten, eindeutige Zustände für Transport/Puffer/Neutralität, unbegrenzte erneute Abfangbarkeit und Gutschrift nur beim neuen eigenen Empfänger. Bereits aus einer zerstörten Station weitertransportierte Energie behält ihren Zustand. Neue Bilanzen müssen Mehrfachzählung und Energieerzeugung durch bloßen Besitzerwechsel ausschließen.

### A09 – Gebäude, Freischaltung, Mauern und Reparatur: G01–G06

**Status: stark abweichender Prototyp.** `Buildings` unterstützt Quelle und Veredler, kleine begehbare Gebäude mit modusspezifischer Verfügbarkeit und unmittelbarer Platzierung. Kein Gebäudezustand bildet allgemeine Bauarbeit, Schaden, manuelle Reparatur oder Forschungsfreischaltung ab. Außenposten, Mauersequenzen, Abfangstationen, Energiefarmen im neuen Sinn und Sensoren fehlen.

Späterer Bedarf: Startverfügbarkeit nur des Hauptkerns, erforschte Freischaltungen, freier Baugrund, Arbeiterbaustellen, manuell zugewiesene Reparatur gegen Energie und Mauerlinien mit einzelnen Segmenten. Keine Fabriken, Forschungslabore oder automatischen Türme als Ersatz einführen. Quelle/Veredler bleiben bis zu einer Entscheidung Bestandsfeatures; ihre Zukunft ist offen.

### A10 – Globale Forschung: R01–R05

**Status: sofortige Upgrade-Käufe vorhanden; zeitbasierte Parallelforschung fehlt.** `Upgrades.try_buy()` zieht Kosten ab und wendet Wirkungen unmittelbar an. Der bestehende `research_level` ist außerdem ein Fortschrittswert des alten Forschungssiegs. Er ist weder eine Liste laufender Technologien noch ein Forschungsbaum mit Abschlusszeiten. Einzelne heutige Fähigkeiten haben Maximallevel, die Abbaustufe dagegen kein entsprechendes festes Maximum; dies erfüllt R05 nicht als allgemeines Forschungsmodell.

Späterer Bedarf: vollständige Zahlung bei Beginn, getrennte laufende Forschungsaufträge mit Zeit/Fertigstellung, mehrere parallele Technologien, Gebäude- und Upgradefreischaltungen sowie beschlossene Kosten- und Levelgrenzen. Wirtschaft/Militär/Infrastruktur/Energietechnik bleiben Vorschläge. Alte numerische Kaufwerte werden nicht als neue Forschungswerte bestätigt.

### A11 – Netzwerk, Speicherung und alte Modi

**Status: nur lokale KI-Partien; neue Zustandsfelder nicht gespeichert.** `CONTROL_REMOTE` ist ein Platzhalter, keine Netzwerkimplementierung. `SimConfig.ai_count` unterstützt 1–3 KI-Gegner, nicht eine frei konfigurierte menschliche Lobby. Speicherformat 2 bildet den Prototyp ab; neue Einheitentypen, Baustellen, Routen-Timer, geteiltes Wissen und laufende Technologien sind darin nicht vollständig repräsentiert.

Späterer Bedarf: ausdrücklich freigegebenes Synchronisations-/Autoritätskonzept, stabile Befehlsreferenzen, Lobbyparameter, Replays und eine entschiedene Speicherstrategie. Die heutige dichte Swap-ID-Verwaltung ist zu berücksichtigen, bevor Befehle über mehrere Takte oder Rechner an Einheiten adressiert werden. Die Behandlung der alten Solo-Modi, Reliquien-/Hügelsiege und Verschmelzung ist offen; sie wird nicht durch diese Dokumentation gelöscht.

### A12 – Performance-Ziel verschiebt sich

**Status: bestehende Arbeiterbenchmarks sind wertvolle Regressionen, aber kein Kriegernachweis.** `bench/live_benchmark.gd`, `population_benchmark.gd` und die lokalen Diagnosekopien betreffen Arbeiter, Abbau und bisherige Kernangriffe. Sie enthalten weder Tausende autonom kämpfende Krieger pro Spieler noch Fog of War oder echte Netzwerkgegner. Die aktuelle Arbeitskopie von `swarm_mind.gd` weicht zudem bereits vom letzten Commit ab; frühere Messwerte werden deshalb nicht als erneut verifizierter Istwert ausgegeben.

Späterer Bedarf: gemischte Populationen mit höchstens dem dann beschlossenen Arbeiterlimit, mehreren Kriegerarmeen, Engstellen, verbündeten Kriegern, Kontaktangriffen, Sichtblockaden, Energieverkehr und Baustellen. FPS allein genügt nicht: reale Takte/s, Frame-/Tick-Spitzen, verworfene Zeit, Speicher und Zustandsidentität müssen getrennt geprüft werden. [PERFORMANCE.md](PERFORMANCE.md) kennzeichnet die alten Lastfälle entsprechend.

### A13 – Veraltete Beschreibungen im Dokumentbestand

Die bisherige GAME_DESIGN mischte Zielregeln und Prototypverhalten, etwa ausschließlich orthogonalen Abbau und einen unzerstörbaren Einzelkern. Die alte Roadmap führt historische Review-Status und Speicherversion 1; tatsächlich verwendet der geprüfte Code Version 2. Die Architektur beschrieb die GDExtension noch als spätere Möglichkeit und erwähnte nur Fraktion 0, obwohl der Rechenkern und lokale KI-Fraktionen vorhanden sind. Die alte Massenformel in AGENTS.md behauptete Arbeiterwachstum durch Abbau, während `Simulation.expected_mass()` bereits Käufe und entfernte Fraktionsmasse bilanziert.

Diese Textabweichungen werden im Dokumentationsauftrag gekennzeichnet bzw. korrigiert. Sie sind kein Auftrag zur Änderung des Codes. Historische D-033-Überschriften sind im Entscheidungslog mehrfach vergeben; sie werden hier nicht umnummeriert, damit vorhandene Verweise nicht still ihre Bedeutung wechseln. Neue Entscheidungen verwenden die eindeutigen Nummern D-043 bis D-050.

## Priorisierte spätere Arbeitspakete – Vorschlag, keine Freigabe

Die Reihenfolge ist eine Empfehlung aus Abhängigkeiten. Kein Paket beginnt in der Planungspause.

1. **P0 – Offene Regeln und Bestand sichern.** Die 16 Anschlussfragen in GAME_DESIGN entscheiden; besonders Welt/Lobby, Diagonalen, Belegungsmatrix, Limitzählung, Niederlage und Routen-Timer. Alte Modi und Saves behandeln. Vor jeder Codephase bestehende Invarianten und Native-/Referenzgleichheit sichern. Ergebnis: freigegebener Umfang mit eindeutigen Beispielen; noch kein Weltumbau.
2. **P1 – Gemeinsame Daten- und Wissensgrenzen festlegen.** Koordinaten/Weltbereiche, Spieler-/Bündnisidentitäten, stabile Einheiten- und Gebäudereferenzen, Produktions-/Baustellenzustände, Forschungsfreischaltungen und Spielerwissen gemeinsam entwerfen. Auch das spätere Netzwerk darf verborgenes Wissen nicht vorweg übermitteln. Architekturvarianten und Speicherstrategie werden erst nach ausdrücklicher Auswahl umgesetzt.
3. **P2 – Einheiten, Kollisionen und Nahkampf.** Arbeiter/Krieger trennen, das dann freigegebene Arbeiterlimit prüfen, Kriegerblockade und erlaubte Arbeiterdurchquerung umsetzen. Kontaktangriffe, Radiusreaktion und weiterarbeitende Arbeiter absichern. Zunächst kleine deterministische Fälle, dann mehrere Tausend Krieger; native und Referenzpfade gemeinsam ändern.
4. **P3 – Kerne, Außenposten, Bau und Überleben.** Produktionsorte, Platzierung, Arbeiterbau, Kosten und manuelle Reparatur aufbauen. Niederlage einschließlich begonnenem Kernbau und den Randfall „keine Arbeiter, kein fertiger Kern, begonnener Bau“ prüfen. Keine Sofortauslöschung aus dem Altmodus ungeprüft übernehmen.
5. **P4 – Transport, Abfang und vollständige Energiebilanz.** Eigene Empfänger, fehlende Routen, 60-Sekunden-Verfall, Stationspuffer, erneutes Abfangen und neutrale Freigabe ergänzen. Eigentumswechsel ohne sofortige Gutschrift, ohne Duplizierung und mit physischem Weitertransport testen. Benötigt die in P1/P3 entschiedenen Gebäudezustände.
6. **P5 – Fog of War und gemeinsame Erkundung.** Sichtblockaden, Kenntnisstände und Bündnisfreigabe über die in P1 gezogenen Grenzen implementieren. Verborgene Gebäude, sofort verschwindende Dots, veraltetes Gebäudegedächtnis und Rückkehr in die Sicht prüfen. UI, Minimap und Abfragen gemeinsam berücksichtigen.
7. **P6 – Forschung und freigeschalteter Gebäudekatalog.** Erst nach Entscheidung des Forschungsbaums: volle Vorauszahlung, parallele Zeiten, Abschlusswirkungen, Maximallevel, Sensoren, Mauersegmente und Energiefarmen. Gezielte Bau-/Reparaturbefehle und Forschungshinweise in die Oberfläche einpassen; keine neuen Forschungsgebäude erfinden.
8. **P7 – Echte Multiplayerpartie und Skalierungsabnahme.** Nach ausdrücklicher Netzwerkfreigabe die Lobby und synchronisierte Befehle gegen das definierte Wissens- und Zustandsmodell bauen. Gemischte Kriegerlast, Sicht und Energie messen; anschließend Langzeit-/Mehrspielerabnahme und eine separat beauftragte Releaseprüfung. Die Netzarchitektur und Leistungsgrenzen werden hier nicht als bereits beschlossen ausgegeben.

P1–P7 dürfen nach späterer Freigabe feiner geschnitten werden. Insbesondere Sichtwissen muss bereits im Daten-/Netzentwurf berücksichtigt werden, auch wenn die eigentliche Sichtberechnung später umgesetzt wird. Forschungskosten und Gebäudeparameter werden nicht zum Schließen einer Planlücke erfunden.

## Vorgeschlagene spätere Abnahmefälle

- Diagonaler Abbau erreicht einen Pixel nach der beschlossenen Eckregel, ohne unzerstörbares Material oder verschlossene Ecken regelwidrig zu umgehen; Native- und GDScript-Ergebnis stimmen überein.
- Das Arbeiterlimit gilt über alle eigenen Produktionsorte und Warteschlangen nach der beschlossenen Zählregel; Krieger werden nicht versehentlich als Arbeiter gezählt.
- Eigene und verbündete Krieger blockieren sich. Die ausdrücklich erlaubte eigene Arbeiterdurchquerung funktioniert; nicht beschlossene Durchquerungen werden nicht still ergänzt.
- Ein feindlicher Kontaktangriff beschädigt einen Arbeiter, ohne dessen Arbeitsauftrag automatisch abzubrechen. Nahkampftode und neue Befehle wirken in festgelegter Reihenfolge.
- Ein nur geplanter Kern schützt nicht vor Niederlage; derselbe Kern nach dem ersten tatsächlichen Arbeiterbeitrag schützt auch ohne weitere Arbeiter und fertigen Kern.
- Energie wird erst am gültigen Empfänger gutgeschrieben. Fehlende Route führt gemäß der noch zu präzisierenden Timerregel zum Verfall nach 60 Sekunden; bloßes Warten vor einem Arbeiter wird nicht ungeprüft gleichgesetzt.
- Mehrfaches Abfangen ändert den Besitzer ohne Energie zu erzeugen. Bei Stationszerstörung wird nur der noch gepufferte Anteil neutral; unterwegs befindlicher Anteil wird nicht zurückgeholt.
- Ein Gegner verschwindet beim Sichtverlust sofort. Ein bekanntes gegnerisches Gebäude behält im Nebel seinen letzten Zustand, obwohl es außerhalb der Sicht zerstört oder verändert wurde.
- Verbündete sehen dieselbe aktuelle Sicht und Erkundung, haben aber weiterhin getrennte Energiekonten.
- Zwei Forschungsaufträge werden unabhängig vollständig bezahlt und laufen parallel. Kostenanstieg und Maximallevel stammen aus dem später beschlossenen Baum.
- Eine Mauerlinie erzeugt nachvollziehbare Segmente und Arbeiterbaustellen. Reparatur beginnt nur nach manueller Zuweisung und kostet Energie.
- Eine große Mischpopulation hält die später festgelegten Frame-, Takt- und Speicherziele ein; Ergebnisse aus reinen Arbeiter- oder statischen Darstellungstests werden nicht als Kampfabnahme ausgegeben.

Diese Abnahmefälle sind Prüfplanung. Es wurden dafür weder neue Tests geschrieben noch Implementierungen begonnen.


## Performance-Folgephase D-054, 25. Oktober 2026

Der nach dem Einheitenprototyp ausdrücklich beauftragte nächste Schritt ist lokal umgesetzt: optionaler nativer Armee-Rechenpfad mit taktweise geprüfter GDScript-Referenz und effizienterer pixelgleicher Kriegerdarstellung. Im offenen 10.000er-Marschfall sinkt die Taktzeit von 95,63 auf 2,61 ms. Verbleibende lange Grafikframes sind noch nicht nach Ursache isoliert. Aktuelle Messungen, Tests, Bibliothekswechsel und Grenzen stehen in [ARMY_PERFORMANCE.md](ARMY_PERFORMANCE.md); frühere gegenteilige Leistungsbefunde sind historische Messungen vor diesem Folgeschritt, keine aktuellen Taktzeiten. Weitere Spielsysteme wurden nicht begonnen.


## Stabilitätsauftrag 1–3, 25. Oktober 2026

Die ausdrücklich beauftragten Punkte sind geprüft und gezielt korrigiert. [STABILITY_VALIDATION.md](STABILITY_VALIDATION.md) enthält die vollständigen Nachweise: Windows-Gerätebaum-Meldungen als Frame-Ursache und Filter im eigenen Spielfenster; exakte Viele-Ziele-Wege mit begrenztem Terrain-Cache/Sichtgraph; 30 simulierte Minuten Attrition sowie 15 Minuten mit großen Reservearmeen, Wirtschaft und Kampf; additives Resume gegen abweichende Fortsetzung nach dem Laden. Die 60-s-Grafikprüfung mit 100 Arbeitern und rund 10.000 Kriegern erreicht rund 60 FPS und 20 Takte/s ohne Frame über 50 ms. Einzelne CPU-Spitzen der Headless-Langtests und synchrones Speichern bleiben ausdrücklich als Grenzen ausgewiesen. Feste Taktung und Spielregeln bleiben gleich; keine neuen Welt-/Bau-/Sicht-/Forschungs-/Netzwerksysteme begonnen.

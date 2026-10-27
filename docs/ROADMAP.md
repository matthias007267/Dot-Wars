# Roadmap

**Neuer Weltauftrag im Review:** [ORE_WORLD.md](ORE_WORLD.md) beschreibt die bestätigten Erzwerte, getrennte Start-Tunnelnetze, dauerhaftes Obsidian und anteilige Einzelenergie während des Abbaus. Dieser Auftrag ist ausdrücklich freigegeben (D-075/D-076) und enthält den noch offenen Steinbodenstand aus PR #12. Kein automatischer Merge; ältere Phasenstände unten bleiben historisch.

**Neuer Folgeauftrag nach Merge von PR #8:** [P6_PLAYABLE_RESEARCH.md](P6_PLAYABLE_RESEARCH.md) dokumentiert KI-Netzversorgung, Ausfallregeln, Sichtschutz, Freischaltungen und den grafischen Baum. Die älteren Statusangaben unten sind historische Snapshots.

**Energiephase P4 lokal umgesetzt und geprüft (D-062).** Routenverfall, Abfangstationen, wiederholter Eigentumswechsel, neutrale Stationspuffer, Energiebilanz und Speicherfortsetzung sind umgesetzt. Vorläufige Testwerte, Abschlussprüfungen und Grenzen: [ENERGY_PHASE.md](ENERGY_PHASE.md). Fog of War/P5, Forschungsbaum und Netzwerk bleiben eigene Aufträge.

**Folgephase Reparatur, Abbruch und KI-Bauplanung lokal umgesetzt und geprüft (D-060).** Sie ergänzt P3 nach ausdrücklichem Punkte-1–3-Auftrag; Prüfstand und vorläufige Regeln in [MAINTENANCE_PHASE.md](MAINTENANCE_PHASE.md). Das nächste größere Paket bleibt P4 Energie und benötigt einen eigenen Auftrag.

**Bauphase lokal umgesetzt und geprüft.** Der Nutzer hat den nächsten Durchlauf für Kerne, Außenposten und Überleben ausdrücklich beauftragt. Die drei Detailentscheidungen sind bestätigt (D-059). Gemeinsame Gebäudedaten, Arbeiterbau, Standorte für Produktion/Energie, Ersatzkern und Überleben sind lokal integriert; Abschlussprüfungen und Grenzen sind dort dokumentiert. Details in [CONSTRUCTION_PHASE.md](CONSTRUCTION_PHASE.md).

## Aktueller Status: Einheitenprototyp, 25. Oktober 2026

Nach der Planungspause ausdrücklich beauftragt: 50 Arbeiter einschließlich Warteschlange, keine Fusion, freie Krieger-/Arbeiterauswahl, Kriegerproduktion und Nahkampf mit genehmigten vorläufigen Werten, freie Endposition nach eigener Arbeiterdurchquerung und vollständig deaktivierte alte Solo-Siegziele. D-051 bis D-053 und [UNIT_PROTOTYPE.md](UNIT_PROTOTYPE.md) beschreiben Umsetzung und Grenzen. Lokal umgesetzt und geprüft, kein Commit/PR erstellt.

P2 aus [CONCEPT_SYNC.md](CONCEPT_SYNC.md) liegt als begrenzter spielbarer Prototyp vor. Die ausdrücklich freigegebene Performance-Folgephase D-054 ist umgesetzt: 10.000 Krieger benötigen im offenen Marschfall nur noch 2,61 ms/Takt; die Grafikmessung erreicht nahe 20 Takte/s, zeigt aber einzelne lange Frames. Aktuelle Details und Abnahmegrenzen in [ARMY_PERFORMANCE.md](ARMY_PERFORMANCE.md). Eine vollständige Kampfabnahme ist offen. Die danach ausdrücklich beauftragten Punkte 1 bis 3 sind geprüft und gezielt korrigiert: [STABILITY_VALIDATION.md](STABILITY_VALIDATION.md) enthält Frame-Ursache/-Fix, schwierige Wege und die 30-/15-Minuten-Langtests. Offen bleiben unter anderem Autosave-Spitzen und umfassende Hardware-/Releaseabnahme. Als nächste größere Pakete bleiben: P1 Daten-/Wissensgrenzen; P3 Bau und Überleben; P4 Energie; P5 Sicht; P6 Forschung; P7 Netzwerk und Gesamtlast. Diese Folgeschritte benötigen einen neuen abgegrenzten Auftrag. Forschungs- und Gebäudezahlen werden nicht als endgültig erfunden.

## Historischer Phasenplan vom 22. Oktober 2026

Die folgende Tabelle bleibt als Planungsgeschichte erhalten. Ihre damaligen Review-/PR-Status, Versionsangaben und offenen Punkte wurden nicht als aktueller GitHub-Status neu verifiziert. Sie sind keine Freigabe des neuen Konzepts und kein aktueller Nachweis fehlender bzw. abgeschlossener Features. Den heute statisch geprüften Stand beschreibt CONCEPT_SYNC.md; Speicherformat 2 und der vorhandene Native-Rechenkern sind dort berücksichtigt.

Stand: 22. Oktober 2026. Eine Phase ist erst abgeschlossen, wenn ihre Akzeptanzkriterien erfüllt sind oder eine Abweichung ausdrücklich akzeptiert wurde. Ein offener Pull Request hat den Status Review.

Der Simulationsprototyp auf diesem Branch (Welt, Arbeiter, Bewegung, Abbau, zwei Gruppen) entstand vor diesem Phasenplan. Er bleibt erhalten. Seine bloße Existenz erfüllt die Abnahme der Phasen 2 bis 5 nicht.

| Phase | Status | Branch | Pull Request | Abschluss | Offene Punkte |
|---|---|---|---|---|---|
| 1 Projektgrundlage | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Die Fraktions-ID wird seit Phase 3 gespeichert. Verwendet wird nur Fraktion 0. |
| 2 Welt und Darstellung | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Dieselbe PR wie Phase 1, weil sie noch nicht gemerged ist. |
| 3 Arbeiter und Wegfindung | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Dieselbe PR. Bis zu 32 Zellen korrigieren das Flow-Field lokal (D-020). Ein neues Laufziel oder ein neues Gebiet baut es neu. 60 FPS bei 1080p sind mit fünf Arbeitern erreicht, nicht mit einem großen Schwarm. |
| 4 Abbau und Wachstum | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Dieselbe PR. Ziehen markiert das Abbaugebiet der gewählten Gruppe. |
| 5 Farbgruppen | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Mindestens drei Gruppen. Neue Gruppe startet bei 0 %. Ungültige Quoten werden abgelehnt. |
| 6 Verschmelzung | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | 2×2 und 3×3 sind im Spiel erst nach dem Upgrade benutzbar. |
| 7 Opferloch und Upgrades | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Schutzregel und Ganzzahlregeln sind in `docs/DECISIONS.md` festgehalten. |
| 8 Ziele und Oberfläche | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Ein skriptierter Lauf mit Seed 1337 erreicht die drei Ziele auf der 256er-Welt nach 37:28. Ein menschliches Spiel fehlt. |
| 9 Performance und Speicherstände | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | 10.000 Arbeiter bleiben über 10 ms. 50.000 wurden gemessen. Speicherstände sind Version 1. Kleine Tunneländerungen bauen das Flow-Field nicht mehr komplett neu. |
| 10 Polish und Steam | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Kein Windows-Build in dieser Umgebung. Keine Steam-Veröffentlichung. Siehe `docs/RELEASE.md`. |

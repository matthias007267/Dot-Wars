# Roadmap

Stand: 22. Oktober 2026. Eine Phase ist erst abgeschlossen, wenn ihre Akzeptanzkriterien erfüllt sind oder eine Abweichung ausdrücklich akzeptiert wurde. Ein offener Pull Request hat den Status Review.

Der Simulationsprototyp auf diesem Branch (Welt, Arbeiter, Bewegung, Abbau, zwei Gruppen) entstand vor diesem Phasenplan. Er bleibt erhalten. Seine bloße Existenz erfüllt die Abnahme der Phasen 2 bis 5 nicht.

| Phase | Status | Branch | Pull Request | Abschluss | Offene Punkte |
|---|---|---|---|---|---|
| 1 Projektgrundlage | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Die Fraktions-ID wird seit Phase 3 gespeichert. Verwendet wird nur Fraktion 0. |
| 2 Welt und Darstellung | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Dieselbe PR wie Phase 1, weil sie noch nicht gemerged ist. |
| 3 Arbeiter und Wegfindung | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Dieselbe PR. Die Ansicht vergibt keinen Abbauauftrag. Das Flow-Field wird bei einer Änderung noch vollständig neu aufgebaut. 60 FPS bei 1080p sind auf der Messmaschine mit laufender Simulation nicht erreicht. |
| 4 Abbau und Wachstum | Nicht begonnen | — | — | — | Prototyp baut headless ab. Die Ansicht hat noch keine Abbauauswahl. Abbauzeit ist auf die beschlossene Regel gestellt. |
| 5 Farbgruppen | Nicht begonnen | — | — | — | Prototyp verteilt auf zwei Gruppen. Keine Namen, kein Anlegen oder Löschen. |
| 6 Verschmelzung | Nicht begonnen | — | — | — | — |
| 7 Opferloch und Upgrades | Nicht begonnen | — | — | — | Ganzzahlregel für +25 % Abbauleistung ist noch offen. |
| 8 Ziele und Oberfläche | Nicht begonnen | — | — | — | — |
| 9 Performance und Speicherstände | Nicht begonnen | — | — | — | Ein headless Benchmark existiert. Speicherstände fehlen. 10-ms-Ziel bei 10.000 Arbeitern ist nicht erreicht. |
| 10 Polish und Steam | Nicht begonnen | — | — | — | — |

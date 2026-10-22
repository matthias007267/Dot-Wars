# Roadmap

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
| 8 Ziele und Oberfläche | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Ein voller Durchlauf bis 90 % Abbau ist auf der Standardwelt lang und hier nicht gespielt worden. |
| 9 Performance und Speicherstände | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | 10.000 Arbeiter bleiben über 10 ms. 50.000 wurden gemessen. Speicherstände sind Version 1. Kleine Tunneländerungen bauen das Flow-Field nicht mehr komplett neu. |
| 10 Polish und Steam | Review | `cursor/phase-01-foundation-9244` | https://github.com/matthias007267/Dot-Wars/pull/1 | — | Kein Windows-Build in dieser Umgebung. Keine Steam-Veröffentlichung. Siehe `docs/RELEASE.md`. |

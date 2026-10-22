# Regeln für Agenten

Diese Datei gilt für jede Änderung an DOT WARS. Die Dokumentation unter `docs/` ist die verbindliche Quelle. Bei Widerspruch zwischen Code und Spezifikation wird der Widerspruch benannt, nicht still aufgelöst.

## Phasen

1. Es wird immer nur eine ausdrücklich freigegebene Phase bearbeitet. Am 22. Oktober 2026 sind die Phasen 4 bis 10 als Folge freigegeben worden. Sie liegen zusammen in Review. Alles danach wartet wieder auf eine eigene Freigabe.
2. Die nächste Phase beginnt nicht von selbst, auch wenn sie technisch naheliegend ist.
3. Nach Abschluss einer Phase endet die Arbeit. Es wird auf die nächste Freigabe gewartet.
4. Ein Pull Request enthält nur die freigegebene Phase. Vorhandener, bereits funktionierender Code wird dabei nicht gelöscht und nicht neu geschrieben.
5. Ein Pull Request wird nicht selbst nach `main` zusammengeführt.
6. Eine Phase gilt nach dem Pull Request als „Review“, nicht als abgeschlossen.

## Spielregeln

7. Beschlossene Spielregeln werden nicht ohne Freigabe geändert.
8. Vorläufige Balancingwerte, offene Fragen und verbindliche Regeln bleiben in den Dokumenten getrennt.
9. Die Massenformel gilt bei jeder Änderung an Arbeitern, Abbau oder Opferung:
   aktuelle Gesamtarbeitermasse = Anfangsmasse + vollständig abgebaute Materialfelder − geopferte Masse.
10. Noch nicht platzierte Arbeiter zählen zur Masse und handeln erst nach gültiger Platzierung.
11. Verschmelzung, Aufteilung und Gruppenwechsel ändern die Gesamtmasse nicht.
12. Simulation und Darstellung bleiben getrennt. Die Simulation läuft headless.
13. Es gibt keine Godot-Node pro Rasterzelle und keine pro Arbeiter.
14. Die Simulation bleibt bei gleichem Seed, gleichem Anfangszustand und gleicher Befehlsfolge reproduzierbar.

## Arbeitsweise

15. Vor der Umsetzung werden Repository, Dokumentation und der Stand der vorherigen Phase geprüft.
16. Neue Entscheidungen werden in `docs/DECISIONS.md` festgehalten.
17. Wichtige Spiellogik bekommt automatisierte Tests. Tests, die nicht gelaufen sind, gelten nicht als bestanden.
18. Optimierungen richten sich nach gemessenen Engpässen. Spielregeln werden nicht geändert, um einen Benchmark zu bestehen.
19. Es werden keine unfertigen Systeme für spätere Features angelegt.
20. Vorhandene funktionierende Änderungen werden nicht überschrieben, ohne sie vorher zu prüfen.

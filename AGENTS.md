# Regeln für Agenten

Diese Datei gilt für jede Änderung an DOT WARS. Die Dokumentation unter `docs/` ist die verbindliche Quelle. Bei Widerspruch zwischen Code und Spezifikation wird der Widerspruch benannt, nicht still aufgelöst.

## Konzeptstand und aktuelle Freigabe

Der Nutzer hat am 25. Oktober 2026 nach dem Dokumentationsabgleich ausdrücklich die Umsetzung beauftragt und die Detailfragen beantwortet. Einheitenphase: 50 Arbeiter je Spieler einschließlich bezahlter Warteschlangen; Fusion vollständig aus dem aktiven Spiel entfernen; Krieger mit freien Endpositionen, eigener Arbeiterdurchquerung und ausdrücklich vorläufigen Produktions-/Nahkampfwerten; alte Solo-Siegziele ganz deaktivieren. Entscheidungen D-051 bis D-053 und `docs/UNIT_PROTOTYPE.md` beschreiben Umfang und Grenzen. Die frühere Planungspause D-050 bleibt als historische Entscheidung erhalten. Anschließend wurde mit „gehe jetzt den nächsten Schritt vor“ die gemessene Armee-Performance-Phase ausdrücklich freigegeben: nativer Rechenpfad mit taktgleicher GDScript-Referenz, Grafikprüfung und Dokumentation nach D-054 / docs/ARMY_PERFORMANCE.md. Diese Folgephase ist lokal umgesetzt und geprüft. Danach hat der Nutzer ausdrücklich Punkte 1 bis 3 beauftragt: Frame-Ursache, schwierige Armeewege und längere gemischte Partie. Dieser Stabilitätsauftrag mit gezielten Fenster-/Wege-/Speicherfixes ist lokal umgesetzt und geprüft; Details in docs/STABILITY_VALIDATION.md und D-055 bis D-057. Weitere Spielsysteme beginnen nicht automatisch. Nach dem Stabilitätsabschluss hat der Nutzer den Durchlauf für die Bauphase für Kerne, Außenposten und Überleben ausdrücklich beauftragt. Die drei Rückfragen sind ausdrücklich beantwortet: genehmigte vorläufige Bauwerte, Außenposten nur über das Testlabor und vollständige Schutz-/Niederlageregel nach D-059. Datengrundlage und spielbare Integration sind lokal umgesetzt; aktueller Prüfstand und Grenzen in docs/CONSTRUCTION_PHASE.md.

Weltumbau, Fog of War, vollständiger Forschungsbaum und Netzwerk sind weiterhin nicht als Folgephasen freigegeben. Nach D-061 hat der Nutzer ausdrücklich Punkte 1–3 der Energieliste beauftragt: Routenverfall, Abfangstationen sowie Zerstörung/Energiebilanz. Diese Energiephase ist lokal integriert; Testregeln, Prüfstand und Grenzen stehen in docs/ENERGY_PHASE.md / D-062. Die nachgereichte Nutzerantwort bestätigt die angebotenen Timer-, Stations- und Neutralenergieregeln ausdrücklich als vorläufige Testregeln (D-063). Außenposten/Bau/Überleben sind ausdrücklich beauftragt und mit bestätigten Detailentscheidungen lokal integriert. Der Nutzer hat danach ausdrücklich Punkte 1–3 der nächsten Liste beauftragt: manuelle Reparaturen, Baustellenabbruch und KI-Bauplanung. Diese Folgephase ist lokal integriert; Umfang, Prüfung und Grenzen stehen in docs/MAINTENANCE_PHASE.md / D-060. Die nachgereichte Nutzerantwort bestätigt Reparaturwerte und Erstattungsregeln ausdrücklich als vorläufige Testregeln (D-061); die KI-Ausbaupolitik bleibt eine vorläufige Implementierungsannahme. Weitere große Systeme bleiben ein eigener Auftrag. Die Zielregeln stehen in `docs/GAME_DESIGN.md`; der historische Abgleich mit aktuellem Nachtrag in `docs/CONCEPT_SYNC.md`. Keine Leistungsziele allein aus funktionierenden Tests als erreicht ausgeben. Keine Commits, Veröffentlichung oder automatische Abschaltung aus diesem Auftrag ableiten.

## Aktueller Commit-/Push-Auftrag

Der Nutzer hat nach Abschluss und Bestätigung der Energiephase ausdrücklich beauftragt: „Dann mach jetzt alles für ein Commit fertig und push es nach Main“. Dieser Auftrag erlaubt einen gemeinsamen Commit des gesamten geprüften Hauptprojekt-Arbeitsstands einschließlich der vorhandenen Nutzeränderung und einen normalen Push nach `origin/main`. Die frühere Einschränkung, aus Implementierungsaufträgen keinen Commit abzuleiten, ersetzt diese ausdrückliche Freigabe nicht. Der separate lokale Checkout `dot-wars/`, erzeugte native Bibliotheken und Diagnoseartefakte werden nicht eingecheckt. Kein Force-Push, keine neue Featurephase und kein Release daraus ableiten. D-064 und `docs/COMMIT_VALIDATION.md` beschreiben Umfang und Prüfstand.

## Phasen

1. Es wird immer nur eine ausdrücklich freigegebene Phase bearbeitet. Aktuell gilt die abgegrenzte Energiephase nach dem ausdrücklichen Punkte-1–3-Auftrag zur Energieliste (D-062). Bauentscheidungen D-059 und bestätigte Reparatur-/Abbruchtestregeln D-061 bleiben erhalten. Die angebotenen Station-/Timer-/Neutralenergieregeln sind nach D-063 ausdrücklich für die Testfassung bestätigt; ergänzende Ausführungsdetails bleiben gesondert vorläufig. Weitere Phasen beginnen nicht von selbst. Historische Freigaben ersetzen keine neue Phasenfreigabe.
2. Die nächste Phase beginnt nicht von selbst, auch wenn sie technisch naheliegend ist.
3. Nach Abschluss einer Phase endet die Arbeit. Es wird auf die nächste Freigabe gewartet.
4. Ein Pull Request enthält nur die freigegebene Phase. Vorhandener, bereits funktionierender Code wird dabei nicht gelöscht und nicht neu geschrieben.
5. Ein Pull Request wird nicht selbst nach `main` zusammengeführt.
6. Eine Phase gilt nach dem Pull Request als „Review“, nicht als abgeschlossen.

## Spielregeln

7. Beschlossene Spielregeln werden nicht ohne Freigabe geändert.
8. Vorläufige Balancingwerte, offene Fragen und verbindliche Regeln bleiben in den Dokumenten getrennt.
9. Bilanzen: lebende Arbeitermasse einschließlich wartender Käufe = Anfangsmasse + Spieler-/KI-Käufe − entfernte Fraktionsmasse − Kampftode. Krieger: bezahlt − verloren = lebend + wartend. Abbau erzeugt Energie, keine Arbeiter. Energie nach D-062: erzeugt = geliefert + verfallen + unterwegs; unterwegs = frei mit Besitzer + gepuffert + frei neutral. Eigentumswechsel/Neutralisierung erzeugen keine Energie; Puffer zählen nicht doppelt.
10. Noch nicht platzierte Arbeiter zählen zur Masse und handeln erst nach gültiger Platzierung.
11. Fusion ist entfernt. Gruppenwechsel ändern keine Masse; alte fusionierte Version-2-Stände werden beim Laden massenerhaltend in Einzelarbeiter überführt.
12. Simulation und Darstellung bleiben getrennt. Die Simulation läuft headless.
13. Es gibt keine Godot-Node pro Rasterzelle und keine pro Arbeiter oder Krieger.
14. Die Simulation bleibt bei gleichem Seed, gleichem Anfangszustand und gleicher Befehlsfolge reproduzierbar.

## Arbeitsweise

15. Vor der Umsetzung werden Repository, Dokumentation und der Stand der vorherigen Phase geprüft.
16. Neue Entscheidungen werden in `docs/DECISIONS.md` festgehalten.
17. Wichtige Spiellogik bekommt automatisierte Tests. Tests, die nicht gelaufen sind, gelten nicht als bestanden.
18. Optimierungen richten sich nach gemessenen Engpässen. Spielregeln werden nicht geändert, um einen Benchmark zu bestehen.
19. Es werden keine unfertigen Systeme für spätere Features angelegt.
20. Vorhandene funktionierende Änderungen werden nicht überschrieben, ohne sie vorher zu prüfen.

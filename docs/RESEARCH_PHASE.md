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

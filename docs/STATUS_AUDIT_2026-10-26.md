# Soll/Ist und CI-Reparatur – 26. Oktober 2026

## Grundlage und Reichweite

Dieser Abgleich verwendet den tatsächlichen Repository-Stand: `main` bei `058f012` (P5/PR #7 gemergt), P6-Ausgangsstand `29acce3` auf `feat/p6-research-foundation` in Draft-PR [#8](https://github.com/matthias007267/Dot-Wars/pull/8) und die hier dokumentierte Testmigration. PR #8 bleibt Draft und wird nicht gemergt.

Der Chat **„Abbausystem überdenken“ ist in dieser Sitzung nicht direkt zugänglich**. Nachgereicht wurden jedoch `DOT_WARS_Vision_und_Roadmap_2026-10-26.md` und die Zusammenfassung aus dem Chat. Damit liegen die 17 Kapitel und alle 80 To-dos als Soll-Grundlage vor. Der vollständige ID-für-ID-Abgleich steht in [VISION_TODO_AUDIT_2026-10-26.md](VISION_TODO_AUDIT_2026-10-26.md); die folgenden Tabellen fassen ihn zusammen. Versionierte Regeln und insbesondere die jüngsten P6-Entscheidungen wurden damit abgeglichen. Vorschläge und offene Regeln bleiben ohne neue Freigabe offen.

`CONCEPT_SYNC.md`, `ROADMAP.md`, `FOG_PHASE.md`, `AGENTS.md` und der Anfang von `RESEARCH_PHASE.md` enthalten historische Statusaussagen. Beispielsweise ist P5 bereits gemergt, obwohl FOG_PHASE noch einen Draft nennt. Für P6 sind die jüngsten Entscheidungen maßgeblich: Forschungsgebäude, Energieverbrauch während der Tätigkeit und physische Versorgung über explizite Leitungen ersetzen die frühere globale Sofort-/Vorauszahlungslogik. Die Überschrift des bisherigen PRs beschrieb nur die erste Planung, nicht dessen inzwischen implementierten Umfang.

## Soll/Ist der versionierten Vision

„Vorhanden“ bezeichnet den begrenzten Prototyp; endgültiges Balancing, Grafikabnahme und große Leistungsmessungen folgen daraus nicht.

| Thema / Soll | Ist in `main` | Zusätzlich in PR #8 / verbleibend |
| --- | --- | --- |
| P0/P1: gemeinsame Daten, deterministische Zustände, geklärte Regeln | Packed-Array-Simulation, feste Takte, Gebäudedaten und Speichern vorhanden | Kein vollständig abgeschlossener Welt-/Multiplayer-Architekturumbau; offene Designfragen bleiben offen |
| Welt: große prozedurale Pixelwelt, Höhlen, diagonaler Abbau | Endliche Rasterwelt, Terrain und orthogonale Wege | Nahezu endlose Welt, Lobbygrößen und verbindliche Diagonal-/Eckregeln nicht vollständig umgesetzt |
| P2: 50 Arbeiter inkl. Warteschlange, freie Auswahl, Krieger/Nahkampf, keine Fusion | Im Prototyp umgesetzt; Native-/Referenzregressionen vorhanden | Keine neue Kampfstufe; 1k/10k-Grafik-/Leistungsabnahme mit P5/P6 nicht durch diese CI belegt |
| P3: Kerne/Außenposten, Arbeiterbau, begonnener Kern schützt vor Niederlage | Implementiert, inklusive bezahlter Reservierungen und Produktionsstandorte | Bauwerte bleiben vorläufig; Forschungszentren sind ausdrücklich weder Produktionsstandorte noch Überlebensschutz |
| Wartung: manuelle Reparatur, Bauabbruch, KI-Bauplanung | Implementiert | Regressionen auf Sichtwissen und neue KI-Forschungspriorität angepasst, ohne Kosten-/Arbeitsprüfungen zu entfernen |
| P4: physische Abbauenergie, Ankunftsgutschrift, 60 s ohne Route, Abfang/Neutralisierung | Implementiert und mit Bilanztests versehen | Leitungsgebundene Forschungsenergie ist ein zusätzlicher Transportpfad; umfassende neue Wirtschafts-/Fairnessregeln nicht fertig |
| P5: Sicht, Erkundung, Gebäudegedächtnis, Allianzsicht | PR #7 gemergt; Sicht-/Speichertests vorhanden | Vollständiger Informationsleck-Audit, visuelle Abnahme und große Fog-Benchmarks bleiben offen |
| P6.1: Forschungszentrum von Anfang an bauen | Fehlt in `main` | Bau-, Besitzer-, Fertigstellungs-, KI-, Produktionsausschluss- und Speichergrundlage implementiert; Live-Bedienung/Grafik noch nicht abgenommen |
| P6.2: gebäudegebundene parallele Forschung | Fehlt in `main` | Scheduler, Voraussetzungen, Levelgrenzen, globale Fraktionswirkung, Fortschritt, Unterversorgung und Speicherung implementiert; Startkatalog umfasst sechs Technologien. Keine normalen Sofortkäufe mehr |
| P6.3: reale Netzlieferung Kern → Forschungszentrum | Fehlt in `main` | Explizite kostenlose, nicht blockierende Leitungen, Versand und zellenweiser Transport; E-Platzierungsvorschau/Q-Abbruch vorhanden. Unterbrechung und deterministische Speicherfortsetzung automatisiert geprüft. KI baut bislang keine Versorgungsleitungen; Bohrer-/weitere Gebäuderouten fehlen |
| P6.4: Aktivitätsglow und sichtbare Energie | Fehlt in `main` | Versand-Darstellung und Forschungs-Verbrauchsstatus vorhanden; Taktnummer des Glows hier korrigiert. Keine visuelle Abnahme. Permanente Buffs und weitere Gebäudeverbraucher laut jüngstem Beschluss zurückgestellt |
| P6.5: visueller vierzweigiger Forschungsbaum | Fehlt in `main` | Scrollbare Zweigpanels mit Voraussetzungen, Kosten, Dauer und Fortschritt; noch kein vollständiger Baum mit Verbindungslinien, eigenem Pan/Zoom und Pixelart-Abnahme |
| P6.6: Energieeffizienz und Gebäudekatalog | Fehlt | Energieeffizienz-Technologie fehlt. Forschungsfreischaltungen für Außenposten/Abfangstationen, Mauern, Sensoren und Energiefarmen sind nicht vollständig im aktuellen Katalog enthalten; Debug-Freigaben sind kein Ersatz |
| Neue Reliquienregeln: ein Typ, Transport/Diebstahl, Netzanschluss, 10-min-Countdown mit Kulanz | Alter Reliquien-/Hügelprototyp vorhanden | Neue Regeln ausdrücklich Folgepaket; aktuelles Verhalten erfüllt diese Vision nicht |
| P7: echter Netzwerk-Multiplayer, Lobby, Synchronisation, Skalierungsabnahme | Lokale KI-Partien; CONTROL_REMOTE ist kein Netzwerk | Weiter offen; keine neue Netzwerkfunktion, kein Release durch diesen Auftrag |

## CI-Ausgangslage und Ursachen

Der letzte Lauf vor der Reparatur war [40330013001](https://github.com/matthias007267/Dot-Wars/actions/runs/40330013001), Commit `29acce3`, Ergebnis **failure / Exit 143**. Er erreichte keinen Testsummenabschluss; Fallback und Spielstart wurden übersprungen. Sieben Methoden meldeten davor Fehler: Bau-HUD; doppelte Sichtquelle; KI-Außenposten; Reparatur-HUD; KI-Baugruppen/Kapazität; Match-HUD; schwere KI. Ein solcher Abbruch ist keine vollständige Liste sämtlicher Fehler.

Die lokale Reproduktion identifizierte zusätzlich die blockierende Schleife in `test_worker_speed_upgrade_covers_more_ground`: `while speed_cost() >= 0` versuchte den nun verbotenen Sofortkauf immer wieder, ohne den Level zu ändern. Weitere erst danach erreichbare Annahmen betrafen den Sofortkauf der Schwarmkoordination und die Kernflächen-Darstellung. Keine Timeouts wurden erhöht, keine Tests deaktiviert und keine alten Sofortkäufe für Kompatibilität wieder eingeschaltet.

### Testmigration und erhaltene Regressionen

- `test_movement`: testet die Bewegungswirkung einer konfigurierten Forschungsstufe unabhängig vom Scheduler; Erwerb, Kosten und genaue Dauer sind in P6 getestet. Die unbeschränkte Kaufschleife entfällt.
- `test_swarm_mind`: echte gebäudegebundene Forschung von Abbau-Voraussetzung und allen Schwarmstufen; maximaler Level, Forschungseffekt, Wartezustand, Save/Load und neue Baum-Anzeige bleiben geprüft. Die gemeinsame Testhilfe nutzt ausdrücklich bereits gelieferten Puffer und begrenzte Takte; echte Lieferung wird separat geprüft.
- `test_world_view`: Kernfläche als Rendering-Fixture aufbauen, statt einen alten Kauf zu simulieren; Pixel-/Farbaussagen bleiben erhalten.
- `test_construction` / `test_maintenance`: nach manuellem Einsetzen eines Arbeiters Sicht aktualisieren und Auswahl ausdrücklich prüfen. Bau, Produktion, Reparatur, Rückerstattung und Arbeitszuweisung bleiben unverändert getestet.
- `test_maintenance`: Außenposten-spezifische KI-Fixtures besitzen bereits ein Forschungszentrum. Dessen neue Priorität erhält zusätzlich einen eigenen Test mit normalem Preis und realem Arbeiterbau.
- `test_match`: die neue Siegtechnologie im Forschungsbaum statt des versteckten alten Knopfs prüfen. Die schwere KI kann nach erfolglosem Forschungsstart regulär Arbeiter/Krieger kaufen; Kosten und Käufe werden explizit bilanziert, Marsch-/Abbaugebietsaussagen bleiben bestehen.
- `test_fog_of_war`: zwei Arbeiter derselben Fraktion als Sichtquellen anlegen; der Test erreicht nun seine Sichtprüfungen, statt ohne Assertion zurückzukehren.
- `test_research_p6`: fertiges/eigenes Zentrum, Voraussetzungen, belegtes Zentrum, Fraktionsisolation, parallele Jobs, reale Leitungsplatzierung, tatsächlicher zellenweiser Versand, verspätete Ankunft, Unterversorgung/Fortsetzung, exakte Dauer und Energie je Stufe, Maximallevel, Freischaltung der Folgeforschung, Speicherfortsetzung mit unterwegs befindlicher Energie und nach Netzunterbrechung, atomare Ablehnung beschädigter Daten sowie Ausschluss von Produktion/Überlebensschutz.

Die CI verwendet nun ausdrücklich `shell: bash`, damit GitHub Actions `pipefail` aktiviert: Ein fehlgeschlagener Godot-/Timeout-Prozess wird in den `tee`-Pipelines nicht durch deren erfolgreichen Exitstatus verdeckt. Die bisherigen Skriptfehlerprüfungen bleiben bestehen.

### Echte Implementierungsfehler

`src/sim/research_system.gd`:

1. Verbrauch wurde vor `tick_count += 1` mit der alten Nummer gespeichert; der Renderer prüft den veröffentlichten neuen Takt. Aktivitätsglow konnte dadurch trotz Energieverbrauch nie aktiv sein. Der gespeicherte Verbrauchstakt entspricht jetzt dem abgeschlossenen Takt.
2. Ein fehlender Netzpfad pausiert Sendungen regulär, wurde beim Laden desselben Zustands aber als ungültig abgewiesen. Pausierte Sendungen bleiben nun speicherbar; Typen, Weltgrenzen, Besitzer und fertiges Forschungsziel bleiben validiert. Wiederanschluss setzt denselben Transport deterministisch fort, ohne Direktlieferung.
3. `restore` übernahm Levels/Jobs/Puffer bereits vor Prüfung der Sendungen. Beschädigte Daten konnten den Zustand trotz Rückgabe `false` verändern. Übernahme erfolgt jetzt erst nach vollständiger Prüfung; Aktivitätsdaten werden bei erfolgreichem Restore zurückgesetzt.

## Verifikation

Godot **4.3.stable.official.77dcf97d8**, Linux x86-64, nativer C11-Kern mit Repository-Buildskript. Reproduzierbare vollständige Befehle aus `/workspace/Dot-Wars` (hier mit gepinntem Wrapper im PATH):

```sh
bash native/build.sh
timeout 120s godot --headless --path . --import
timeout 300s godot --headless --path . -s tests/run_tests.gd -- --require-native
timeout 600s godot --headless --path . -s tests/run_tests.gd -- --no-native
timeout 30s godot --headless --path . --quit-after 8
```

Lokaler vollständiger Abschluss bei Commit `3612986` (vor dem ergänzenden Zerstörungs-Regressionsfall aus A-03):

| Prüfung | Tatsächliches Ergebnis |
| --- | --- |
| Nativer Linux-Build / Godot-Import | Erfolgreich; vorhandene C-ABI-/Einrückungswarnungen, keine Buildfehler |
| Vollständige native Suite | **314 Tests / 33.680 Prüfungen / 0 Fehler**, Exit 0 |
| Vollständiger GDScript-Fallback | **314 Tests / 30.386 Prüfungen / 0 Fehler**, Exit 0 |
| Skript-/Parser-/Ladefehler in beiden Abschlusslogs | Keine |
| Hauptszene | Exit 0, `DOT WARS bereit: 256x256 Seed 1337` |
| `git diff --check` | Erfolgreich |

Exitstatus und Skript-/Parserfehler werden separat ausgewertet. Erwartete Negativtests ungültiger Weltkonfigurationen dürfen Fehlermeldungen schreiben; sie sind keine unbeachteten Skriptfehler. Der verbindliche neue GitHub-Actions-Nachweis und dessen geprüfter Commit werden nach dem Push im PR-Abschlussprotokoll und in der Aufgabenantwort festgehalten. Ein grüner lokaler Lauf wird nicht als bereits erfolgreicher GitHub-Lauf ausgegeben.

Keine visuellen Windows-/Godot-Livetests, keine neuen 1k/10k-Performance- oder Multiplayernachweise. P6 bleibt ein begrenzter Prototyp mit offenen Punkten aus obiger Tabelle; grüne CI wäre keine Abnahme der gesamten Vision.


### Bestätigter GitHub-Abschluss und nachgereichte Vision

[Actions-Lauf 40333687469](https://github.com/matthias007267/Dot-Wars/actions/runs/40333687469) für `3612986044a58bf0a437d2a7061836fbf02770c9`: **success**. Nativer Build, Import, komplette native Suite (**314 / 33.680 / 0**), kompletter Fallback (**314 / 30.386 / 0**) und Hauptszene wurden sämtlich erfolgreich beendet; keine Schritte übersprungen.

Anschließend lieferte der Nutzer die vollständige Vision mit 80 To-dos nach. [VISION_TODO_AUDIT_2026-10-26.md](VISION_TODO_AUDIT_2026-10-26.md) gleicht jede ID gegen Code, Tests und verbleibende Abnahme ab. Ergänzt wurde der in A-03 ausdrücklich genannte Zerstörungsfall: ein aktives Forschungszentrum mit bezahlter Sendung wird zerstört; Auftrag, Puffer und Sendung verschwinden ohne Technologie oder doppelte Energie, ein neuer Auftrag wird abgelehnt, der Zustand bleibt speicherbar. Die gezielte P6-Suite besteht nun aus **15 Tests / 214 Prüfungen / 0 Fehler**. Der ergänzende Commit wird nochmals durch den vollständigen Actions-Workflow geprüft; dessen tatsächlicher Abschluss steht im PR-Abschlussprotokoll.

# Bauphase: Kerne, Außenposten und Überleben

Folgephase: Der spätere ausdrückliche Punkte-1–3-Auftrag ergänzt Reparaturen, Baustellenabbruch und KI-Bauplanung. Aktueller Umfang und Prüfstand stehen in [MAINTENANCE_PHASE.md](MAINTENANCE_PHASE.md). Die nachfolgenden Abgrenzungen beschreiben die ursprüngliche Bauphase D-059 und werden durch D-060 entsprechend ergänzt.

Stand: 25. Oktober 2026. Der Folgeauftrag und alle drei Rückfragen sind ausdrücklich bestätigt (D-058 / D-059). Die Bauphase ist lokal implementiert; Prüfstand und verbleibende Grenzen stehen unten. Kein Commit, PR oder Release wird daraus abgeleitet.

## Verbindliche Regeln und genehmigte Testwerte

Hauptkerne und fertige Außenposten produzieren Arbeiter und Krieger und empfangen physisch transportierte eigene Energie. Die Gutschrift erfolgt bei Ankunft. Der Verlust des Hauptkerns beendet das Match nicht, solange ein fertiger eigener Außenposten oder ein tatsächlich begonnener Hauptkernbau existiert. Arbeiter allein und ein nur bezahlter Plan schützen nicht. Ein begonnener Hauptkernbau schützt auch ohne jeden Arbeiter und fertigen Standort. Erst der Verlust des letzten solchen Schutzes entfernt die Fraktion. Ein unfertiger Außenposten schützt nicht.

Ausdrücklich vorläufige, vom Nutzer bestätigte Bauwerte:

- Hauptkern: 5×5 Zellen, 600 HP, fester Preis 500 Energie, 600 Arbeiter-Takte.
- Außenposten: 3×3 Zellen, 200 HP, 200 + 100 Energie je bereits vorhandenem eigenen Außenposten einschließlich reservierter/angefangener Baustellen; 300 Arbeiter-Takte.
- Bei 20 Takten/s benötigt ein ungestört am Rand arbeitender Arbeiter 30 bzw. 15 Sekunden. Anreise kommt hinzu. Mehrere eigene Arbeiter tragen gemeinsam je einen Arbeitsschritt pro Takt bei.
- Vorläufig höchstens ein eigener Hauptkern einschließlich geplanter/angefangener Baustelle. Nach Zerstörung ist ein Ersatz an einem normalen freien Bauplatz möglich.

Außenposten bleiben im normalen Spiel gesperrt. Ausschließlich eine explizite Testlabor-Aktion schaltet sie für den aktuellen Lauf frei. Das ist keine fertig erforschte Technologie; der globale Forschungsbaum bleibt ein späterer Auftrag.

## Spielbarer Ablauf

1. Neue Partie starten. Die Startkerne belegen 5×5 Zellen; ein freier Ring bietet Arbeits- und Produktionsplätze. Alte Ein-Zellen-Kerne werden beim Laden geometrisch erhalten.
2. Für Außenpostentests: Escape → Testlabor aktivieren → „Außenposten freischalten (Test)“. „+1000 Bauenergie (Test)“ erleichtert die Prüfung. Veränderte Testläufe schreiben weiterhin keine regulären Saves.
3. Eigene Arbeiter auswählen, unten „AUSSENPOSTEN“ wählen und auf die linke obere Ecke eines freien 3×3-Bauplatzes klicken. Der Platz muss vollständig frei von Fels, Einheiten, Gebäuden und Energie-Dots sein. „KERN BAUEN“ funktioniert entsprechend mit 5×5, sobald kein eigener Kern/Bauplatz mehr vorhanden ist.
4. Die Energie wird erst nach vollständiger gültiger Platzierungsprüfung abgezogen. Die Baustelle reserviert sofort ihre gesamte Fläche. Der erste tatsächliche Beitrag eines zugewiesenen eigenen Arbeiters am orthogonalen Rand setzt „begonnen“.
5. Weitere Arbeiter auswählen und per Rechtsklick auf die Baustelle zuweisen. Ein neuer Marsch-/Abbauauftrag beendet ihre Bauzuweisung. Bei Tod/Slottausch behält der nachgerückte Arbeiter seine eigene Zuordnung.
6. Einen eigenen Standort anklicken, anschließend Arbeiter oder Krieger kaufen. Nur fertige Standorte produzieren; eine ausgewählte unfertige Baustelle weicht nicht still auf den Hauptkern aus. Ohne Standortauswahl dient der erste fertige eigene Standort als Standard. Die 50-Arbeiter-Grenze gilt gemeinsam für alle Standorte und bezahlten wartenden Käufe.

Einzelne Gebäude werden als Fläche mit Besitzfarbe gezeichnet. Der Balken zeigt Baufortschritt, nach Fertigstellung HP. Der Hauptkern ist zusätzlich mit einem Kreuz markiert. Die obere Kernanzeige beschreibt den gewählten Standort. Es gibt keine Node pro Baustelle, Zelle oder Einheit.

## Technische Umsetzung und weitere Prototypfestlegungen

`settlement_store.gd` ist die maßgebliche Gebäude-/Baustellendatenhaltung mit stabilen IDs, Besitzer, Fläche, HP, Arbeitsbedarf und geplant/begonnen/fertig/zerstört. `construction_system.gd` prüft Baugrund, bezahlt, weist Arbeiter zu, führt sie über gemeinsame Distanzfelder und bindet Kampf, Energieempfang, Überleben und Produktionsursprung an. Die nativen und GDScript-Bewegungswege lassen Bauarbeiter in Ruhe; Arbeiter können sie weiterhin nicht durchqueren. Wegfelder verwenden bei Verfügbarkeit den bestehenden nativen BFS-Kern.

Die folgenden zusätzlichen Ausführungsdetails sind als Prototypverhalten dokumentiert und keine endgültigen Balancingentscheidungen:

- Bezahlte unbegonnene Außenpostenplätze zählen bereits zum nächsten Preis; zerstörte Plätze zählen nicht. Das verhindert billige parallele Reservierungen.
- Baustellen besitzen in dieser Phase bereits ihre vorgesehenen vollen HP. Baufortschritt heilt keinen erhaltenen Schaden. Die endgültige Bau-HP-Kurve ist offen.
- Zerstörung gibt den Baugrund frei und beendet zugeordnete Bauarbeit. Bezahlte, noch nicht erschienene Einheiten des Standorts werden sofort ohne Erstattung als Verlust bilanziert. Blockierte Produktion an einem lebenden Standort wartet ohne weitere Abbuchung. Abbruch-/Erstattungs- und endgültige Warteschlangenregeln bleiben offen.
- Arbeiterkosten und Kriegerwerte bleiben die genehmigten Einheiten-Testwerte (10 bzw. 20 Energie; Krieger eine Sekunde Produktionszeit). Die KI kauft Arbeiter wie bisher direkt, ausschließlich über einen fertigen eigenen Standort. Eine neue KI-Bauplanung ist nicht enthalten.
- Die Niederlageprüfung erfolgt im Match nach der gesammelten Gebäudeschadensauswertung. Eine einzelne Attacke darf nicht bereits vor der Prüfung weiterer Schutzstandorte eine Fraktion entfernen.
- Das historische Kernflächen-Upgrade bleibt für alte Ein-Zellen-Kerne erhalten. Bei neuen Gebäudekernen ist es gesperrt, damit der alte Freiflächenmechanismus nicht die feste Baugeometrie und Arbeitsplätze überlagert. Neue Gebäude-Upgrades gehören zur späteren Forschung.

## Speichern und Altstände

Version 2 wird additiv um Gebäudedaten, stabile Bauzuweisungen und Produktionsbindungen erweitert. Laden validiert Flächen, Zustände, Besitzer, Arbeiteraufträge, Hauptkernlimit und Warteschlangen. Eine laufende Baustelle wird einschließlich Bauarbeit und Anreise taktgleich fortgesetzt; Laufzeit-Forschungsfreigaben und UI-Auswahl werden nicht gespeichert.

Alte Version-2-Saves ohne Bauabschnitt importieren ihre vorhandenen Kerne als Ein-Zellen-Gebäude mit gespeichertem Schadensstand und dem ursprünglichen 160-HP-Maximum (bei historischen Sonderwerten mindestens den gespeicherten HP). Sie werden nicht über vorhandene Einheiten oder Terrain zu 5×5 erweitert. Bereits bezahlte alte Warteschlangen bleiben erhalten. Neue Ersatzkerne verwenden die neuen Werte.

## Validierung

Lokal ausgeführt mit Godot 4.3 unter Windows:

- Vollständige native Suite: 253 Tests, 33.165 Prüfungen, 0 Fehler.
- Vollständige GDScript-Fallback-Suite (`--no-native`): 253 Tests, 29.871 Prüfungen, 0 Fehler. Die geringere Prüfzahl folgt aus den bereits vorhandenen optionalen Native-Tests.
- Abschließend zusätzlich der Platzierungsschutz gegen das Einschließen von Energie-Dots: Bau-Suite in beiden Rechenwegen zuletzt jeweils 17 Tests / 484 Prüfungen / 0 Fehler, einschließlich explizitem Altstand-Import mit ursprünglichem HP-Maximum. Die Energie-Platzierungsprüfung und dieser zusätzliche Altstand-Test liegen zeitlich nach den genannten Gesamtläufen. Keine Script-/Parsefehler in den erfolgreichen Läufen; die vier erwarteten Negativmeldungen der Konfigurations-/Weltgrenzentests sind keine Testfehler.
- Kontrollierter Grafiklauf mit echtem HUD bei 1280×720: Baustelle über HUD angelegt, Screenshot vor/nach Bau geprüft, Außenposten fertig, anschließend ein Arbeiter und ein Krieger produziert. Bei Takt 516: 9 eigene Arbeiter, 1 Krieger, 300/300 Arbeit, keine Invariantenfehler. Testlaborzustand, keine regulären Autosaves.
- Eine simulierte Minute `mixed_reserve` mit anfänglich 10.000 Kriegern und konstant 100 Arbeitern: Mittel 4,75 ms/Takt, p95 9,84 ms, Maximum 22,20 ms; 9.836 Krieger am Ende, 224 Verluste inklusive Ersatzproduktion, 1.288 Pixel abgebaut, Energie 2.932 = 1.535 geliefert + 1.397 unterwegs; keine Invariantenfehler.
- Zusätzlicher Bau unter derselben Mischlast: 1.200 Takte, Mittel 4,55 ms, p95 8,76 ms, Maximum 18,05 ms. Außenposten bei Takt 677 fertig, einschließlich Anreise und gegenseitiger Arbeiterblockade; 300 tatsächliche Arbeitsbeiträge. Während der 677 Bau-/Anreisetakte Mittel 3,76 ms, Maximum 13,07 ms. Am Ende 9.861 Krieger und 100 Arbeiter, keine Invariantenfehler. Das ist eine kurze Regressionsmessung, keine neue Langzeit-/Allgemeinabnahme für beliebige Gebäudezahlen oder größere Welten.

Reproduzierbare Einstiegspunkte: `tests/run_tests.gd -- test_construction`, `bench/construction_live_check.gd -- --capture-dir=<Ordner>`, `bench/construction_benchmark.gd` und `bench/stability_benchmark.gd -- --case=mixed_reserve --ticks=1200`. Native Variante mit `--require-native`, Referenz mit `--no-native`. Grafikdiagnose standardmäßig unter `bench/results/construction`, wahlweise expliziter Ausgabeordner.

Die automatisierten Bauprüfungen decken unter anderem Genehmigungswerte, Forschungssperre, Zahlung, freie Flächen, gemeinsame Bauzeit, Anreise bei Intelligenz 4, neue Befehle, Slottausch, physische Energie, Hauptkernverlust mit Außenposten, begonnene/unbegonnene Kernbauten ohne Arbeiter, zerstörte Warteschlangen und Speicherfortsetzung ab.

## Abgrenzung und spätere Arbeit

Nicht Teil dieser Phase: Reparaturen/Abbruchsteuerung, endgültige Produktions-/Forschungszahlen, neue KI-Bauplanung, Energieraub und 60-Sekunden-Verfall, Sichtwissen/Fog of War, nahezu endlose Welt, diagonale Wege oder Netzwerk. Die heutige Welt und KI kennen weiterhin globale Gegnerpositionen; Außenpostenversteck durch Erkundung ist damit noch keine erfüllte Zielregel. Alte Quelle-/Veredlermechaniken in historischen Solo-Modi bleiben als ausdrücklich dokumentierte Altmechaniken erhalten.

10.000 Krieger bleiben ein gemessenes Skalierungsziel mit Szenariogrenzen; funktionierende Bauprüfungen ersetzen keine allgemeine Leistungs- oder Releaseabnahme.

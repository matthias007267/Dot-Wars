# Kriegstürme und Versorgung aus dem Gesamtguthaben

Aktuelle Regeln D-082/D-083, neuer Review-Branch `feat/grid-powered-defense` ab `main`/`923ed15` nach Merge von PR #14. Die neu bestätigte Gesamtzahlung ersetzt die früheren Forschungs-/Waffenpuffer und Leitungssendungen. Abbau, Sicht, Bau, Reparatur und die bestehenden Nahkampfregeln bleiben erhalten.

## Spielen und vorläufige Werte

1. Ein fertiges Forschungszentrum mit einem eigenen Hauptkern oder Außenposten durch Leitungen verbinden. Im Militärzweig nach Energietransport die **Verteidigungstechnik** erforschen (vorläufig 120 Energie, 18 Spielsekunden).
2. Arbeiter wählen → **Kriegsturm** → freien, aufgeklärten Baugrund anklicken. 250 Energie, 3×3 Felder, 200 HP, 300 Arbeitertakte. Der Turm produziert keine Einheiten und verhindert allein keine Niederlage.
3. Den fertigen Turm an eine eigene Quelle anschließen. Bei genügend Guthaben wird eine Minute Unterhalt bezahlt. Ohne Netz oder bezahlte Betriebszeit bleibt die Waffe aus.
4. Turm auswählen und lokal **Schnellfeuer** bzw. **Strahl** ausbauen: 150/300 Energie, jeweils 10 Spielsekunden ohne Feuern. Ein bezahlter Ausbau läuft auch bei fehlendem Netz weiter. Die dritte Stufe ist das Maximum. Die symmetrische Plattform behält ihren Teamrand.

| Gebäude/Stufe | Reichweite ab Mitte (Manhattan) | Wirkung bei dauerhaftem Ziel | Unterhalt je Spielminute |
| --- | ---: | --- | ---: |
| Hauptkern/Außenposten | 5 | 1 Schaden alle 1,5 s | 25 Energie |
| Kriegsturm I | 7 | Einzelgeschoss: 2 Schaden alle 1 s | 100 Energie |
| Kriegsturm II | 7 | Schnellfeuer: 2 Schaden alle 0,5 s | 100 Energie |
| Kriegsturm III | 8 | Strahl: 1 Schaden alle 0,2 s | 100 Energie |

Diese Kampf-/Preiswerte sind ausdrücklich vorläufig. Unterhalt ist eine vollständige Vorauszahlung für **1.200 Simulationstakte = 60 Spielsekunden bei 1×**. Keine weiteren Schusskosten, keine anteilige Abbuchung und kein negatives Guthaben. 2×/4× und Pause wirken über den normalen Simulationstakt. Auch während Inaktivität/Ausbau läuft eine bereits bezahlte Minute weiter; bei Netzabriss wird sie weder erstattet noch verlängert. Eine unbezahlte Verlängerung bleibt aus, bis ausreichend Geld und Verbindung vorhanden sind. Bei gleichzeitigen Fälligkeiten werden stabile Gebäude-IDs zuerst bedient. Der Hauptkern und Außenposten sind selbst Quellen und benötigen keinen zusätzlichen Rückweg zum Hauptkern. Das bestehende Solo-Wirtschaftsspiel erhält keinen automatischen Waffenunterhalt.

Nur tatsächlich fertige Gebäude feuern automatisch auf **feindliche sichtbare Krieger**, nicht auf Arbeiter oder Verbündete. Ein Ziel bleibt bis zum Verlust seiner Gültigkeit gebunden, danach gewinnt das nächste Ziel, bei Gleichstand die kleinere stabile Krieger-ID. Normales Gestein, Erze, Obsidian und andere Gebäude blockieren; die eigene Grundfläche ist ausgenommen. Eine diagonal berührte massive Ecke lässt keinen Schuss durch. Die vier Felder tiefe Fog-Regel ist keine Waffen-Durchdringung.

Geschosse bewegen sich alle zwei Takte um eine Rasterzelle, verfolgen die stabile Ziel-ID und verursachen Schaden erst beim Auftreffen. Sie verfallen bei Ziel-/Sichtverlust, neuer Barriere oder nach ihrem begrenzten Flugweg; ein Slotnachrücker wird nicht versehentlich getroffen. Bereits gestartete Geschosse können nach dem Abschalten noch eintreffen. Der Strahl benötigt bei jedem Schadensimpuls weiterhin gültige Sicht und freie Schusslinie. Treffer und Tode nutzen die bestehende Kampfoptik. Keine Energie entsteht beim Tod.

## Forschung: eine Zahlung, ein Zeitfortschritt

Ein eigener fertiger, verbundener und freier Forschungsstandort sowie das gesamte nötige Guthaben sind Startvoraussetzungen. Abhängigkeiten, globale Fraktionsfreischaltungen, Maximalstufen, parallele verschiedene Technologien und ein Auftrag pro Zentrum gelten weiter. Die Effizienzstufe beim Start bestimmt den eingefrorenen Preis.

Der vollständige Preis wird beim Start genau einmal vom Fraktionsguthaben abgezogen. Danach läuft ausschließlich die Zeit. **Guthaben null stoppt bezahlte Forschung nicht.** Bei Netzunterbrechung pausiert sie ohne Fortschrittsverlust; Wiederanschluss oder eine angeschlossene Ersatzquelle setzen ohne neue Kosten fort. Bei Zerstörung des Zentrums endet der Auftrag ohne Erstattung, auch wenn unmittelbar danach gespeichert wird. Der Forschungsbaum und die Auftragsübersicht zeigen einen Zeitfortschritt in Sekunden und den schon bezahlten Betrag, keine zweite Energie-Fortschrittsleiste.

## Netz und Darstellung

`EnergyNetwork.prepare_power` ermittelt eigene Leitungs-Komponenten und angeschlossene fertige Quellen. Die Ergebnisse werden wiederverwendet. Gleiche Abfragen, HP-Verlust und Terrainänderungen abseits der Leitungen bauen die Topologie nicht neu auf. Abriss, Eigentümerwechsel einer Leitung, Quelle/Baufertigstellung/-verlust oder wirklich blockierte Leitungszellen invalidieren sie. Andere Fraktionen werden nicht als Quelle benutzt. Es gibt weder eine Einzelenergie-Liste für Forschung/Waffen noch eine Ankunfts-/Wegeberechnung pro Punkt.

Eine Fraktion mit Restguthaben oder bereits bezahlter Aktivität hat Netzlicht in ihren verbundenen Netzen. Der Status am jeweiligen Gebäude zeigt zusätzlich, ob dessen individueller Unterhalt bezahlt ist. Nicht angeschlossene Leitungen oder ein vollständig unfinanziertes Netz zeigen nur eine dunkle statische Leitung. Ein eigener Shader erzeugt den kontinuierlichen leicht pulsierenden Lichtfluss; er stellt keine transportierten Einheiten dar und verändert keinen Spielzustand. Die Simulation berechnet weder einzelne Lichtteilchen noch deren Ankunft. Im pausierten Spiel bleibt das rein optische Netzlicht lebendig.

Sichtschutz gilt für Leitungsenden, Geschosse, Strahlen und Halos. Fremde Aktivität wird nur in aktuell sichtbaren Feldern gezeichnet; Erinnerungsbilder zeigen keine live veränderten Turmstufen. Die bestehende gemeinsame Kampf-MultiMesh-Grenze von 2.048 zugeschnittenen Quads bleibt erhalten, zusätzlich höchstens 64 sichtbare Geschosse/16 Strahlen. Keine Node pro Waffe, Energiepunkt oder Partikel.

**Abbau-Dots bleiben erhalten:** ein Energiepunkt pro Dot, kontinuierliche Freisetzung beim Abbau, tatsächlicher Transport zum Kern/Außenposten sowie Abfangen/Neutralisieren/Verfall und ihre Bilanz. Ihr Eingang erhöht das gemeinsame Guthaben; es gibt keinen Abzweig in Waffenpuffer.

## KI und Speichern

Die KI verwendet dieselben Bau-/Preis-/Netzregeln, verbindet fertige Türme und zahlt lokale Ausbauten. Vorläufige Turmbaucaps leicht/mittel/schwer: 1/2/3, mit mindestens drei Bauarbeitern und Geldreserve. Zusätzliche Einheiten dürfen den nächsten Forschungs-Startpreis bzw. unbezahlten Turmunterhalt nicht aufbrauchen; die minimale Arbeiterbelegschaft hat Vorrang.

SaveGame bleibt additiv **Version 2**. Forschungssnapshots tragen `payment_mode = 2`. Alte P6-Stände ohne diesen Marker werden strikt geprüft und migriert: bisher verbrauchte Energie plus bezahlte Puffer/Sendungen werden dem Auftrag angerechnet. Ein noch fehlender Rest wird bei ausreichendem Guthaben/Netz einmal vollständig bezahlt; bis dahin pausiert der Altauftrag. Unbenutzte Reservierungen werden genau einmal dem Besitzer zurückgebucht. Laden allein bucht keinen neuen Forschungsbetrag ab. Neue Stände haben keine Puffer oder Sendungen mehr.

Speicherbar sind bezahlte Forschungszeit, Effizienzpreis, Unterhaltsende, individueller Turmausbau, Ziel-ID, Schussabklingzeit und fliegende Geschosse. Beschädigte Ziele/Fristen/Kosten werden abgewiesen. Die native Schnittstelle ist unverändert, **v11 bleibt kompatibel**. Ein Spielneustart lädt die GDScript-/Shaderänderungen.

## Nachweise und Messgrenzen

```text
godot --headless --path . -s tests/run_tests.gd -- --require-native
godot --headless --path . -s tests/run_tests.gd -- --no-native
godot --headless --path . -s bench/network_supply_benchmark.gd
godot --path . -s bench/defense_visual_check.gd
```

Lokaler Godot-4.3-/Linux-Vergleich mit denselben **36 echten Forschungszentren**, vier Fraktionen, 180 Leitungszellen und 80 Forschungs-Taktschritten: bisherige Einzelversorgung **1,66 ms im Mittel / 10,34 ms Spitze**, neue Versorgung je nach Wiederholung **0,13–0,15 ms / 0,39–0,56 ms**. Nach dem alten Lauf waren 52 bezahlte Leitungssendungen unterwegs, nach dem neuen null. Das ist eine isolierte CPU-Probe des Forschungsschritts, keine volle Partie, kein FPS-, Windows- oder 10.000-Einheiten-Nachweis. Rohprotokolle: lokal `/tmp/network-before.log` und `/tmp/network-after.log` (letzte Wiederholung: `/tmp/network-after-final.log`); das CI-Protokoll der neuen Probe liegt beim Verteidigungsartefakt.

Tests decken die exakte Vorauszahlung und letzte Forschungssekunde, parallele Fraktionen, Nullguthaben, Unterbrechung/Wiederaufnahme, einmalige Migration, Forschungs-/Gebäudeverlust, lokale Upgrades, Unterhaltsgrenzen ohne Doppelzahlung, echte Projektiltreffer, neue Wände, stabile IDs, Nebel, KI-Reserven und deterministische Native-/GDScript-Speicherfortsetzung ab. Alte Tests auf Einzelenergie-Lieferung wurden durch Prüfungen der ausdrücklich neuen Regeln ersetzt; gültige Bau-/Wartungs-/Sicht-/Abfangregressionen bleiben erhalten und berücksichtigen separat den neuen Unterhalt.

Der zehnte Grafikcheck prüft tatsächliche Pixel von Kern-/Außenpostengeschossen und Turmstrahl, lokalen Ausbau über HUD, das kompakte Arbeitermenü und den lebenden bzw. nach Ablauf vollständig ausgeschalteten Netzfluss. Die Fixture bezahlt echte Ausbauten und Unterhalt und lässt 60 Sekunden ohne Einkommen ablaufen; keine Waffenpuffer werden erzeugt. Artefakt `defense-visual-check`: `defense-weapons.png`, `defense-upgrade.png`, `defense-build-menu.png`, `defense-compact.png`, `grid-unpowered.png` und Protokolle. Alle neun bisherigen Grafikprüfungen bleiben aktiv. Kein automatischer Merge oder Release.

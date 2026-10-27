# DOT WARS

Kriegstürme mit drei Ausbaustufen: Einzelschuss, Schnellfeuer und Strahl. Hauptkern/Außenposten verteidigen sich schwächer. Forschung bezahlt ihren Gesamtpreis beim Start und pausiert nur bei Netzabriss; Waffen bezahlen ihren Unterhalt pro Minute im Voraus. Das Gebäudenetz zeigt einen pulsierenden Lichtfluss ohne einzelne Leitungssendungen. Abbau-Energiedots bleiben erhalten. Bedienung, vorläufige Werte, Speicherübernahme und Messgrenzen: [GRID_DEFENSE.md](docs/GRID_DEFENSE.md). Native v11 bleibt kompatibel; Spiel neu starten.

Kampfoptik: kurze teamfarbene Nahkampfimpulse, weißer Trefferblitz innerhalb des Teamrands und quadratischer Pixelzerfall bei besiegten Dots. Arbeiter zerfallen in acht, Krieger in zwölf Splitter. Nebel, Pause und Tempo gelten auch für die Effekte; Partikel erzeugen keine Energie. Darstellung und Vorschau: [COMBAT_EFFECTS.md](docs/COMBAT_EFFECTS.md). Spiel neu starten; das vorhandene Native-Modul v11 bleibt kompatibel.

Nebel überarbeitet: Fertige und begonnene Gebäude geben eigenes Grundlicht und Sicht, ohne vom eigenen Fundament verdeckt zu werden. Ressourcen und fremde Fundamente lassen die Sicht vier Rasterfelder ab der ersten Barriere weiterreichen; danach bleibt unbekanntes Gebiet schwarz. Erkundete Flächen sind heller dargestellt. Regeln und Grafiknachweise: [FOG_DEPTH.md](docs/FOG_DEPTH.md). Windows-Native-Modul **v11** neu bauen und das Spiel vollständig neu starten.

HUD nach der markierten Referenz: Energie und Einheitenzahlen oben links, laufende Aufträge als Icons darunter, Menü oben rechts. Unten links wechseln Bau-/Produktions-/Forschungsaktionen mit der Auswahl; daneben stehen Produktionsübersicht und Hover-Erklärung. Minimap und Team-Zielstände liegen unten rechts. Details und Bedienung: [HUD_REFERENCE.md](docs/HUD_REFERENCE.md).

Bestätigte Energie-Dots: kleine weiße Lichtquadrate mit Teamrand, cyanfarbenem Innenlicht und dezentem Glow. Im Fernzoom bleibt die Teamfarbe erhalten, gepufferte Energie hat ein bernsteinfarbenes Innenlicht. Entwurf und Grafiknachweise: [ENERGY_DOT_ART.md](docs/ENERGY_DOT_ART.md).

Neue Weltgenerierung: je Spieler ein getrenntes freies Tunnelnetz, abbaubares Gestein, acht seltene Erzarten und dauerhaftes violettes Obsidian. Energie entsteht bereits während des Abbaus als einzelne Dots; Diamant liefert vorläufig 20.000 Energie bei 128 Sekunden Basisarbeit. Forschung beschleunigt den Abbau. Werte, Grafikprüfung und Speicherregeln: [ORE_WORLD.md](docs/ORE_WORLD.md).

Dunkler Steinboden für freie Flächen: ursprünglich frei ist leicht kühler, durch Ressourcenabbau freigegraben dezent wärmer. Die Abbauhistorie bleibt gespeichert und erscheint im Nebel nur als zuletzt bekanntes Wissen. Ältere Spielstände kennen noch keine individuelle Abbauhistorie; neuer Abbau wird ab dem Laden markiert. Details: [STONE_FLOOR.md](docs/STONE_FLOOR.md).

Die Grafik verwendet jetzt die bestätigten einfachen Quadrat-Einheiten: Arbeiter mit hellem Kern, Krieger mit dunklem Panzerrahmen und stets sichtbarem Teamrand. Drei verwandte Kriegergrafiken liegen im Katalog; reguläre Partien verwenden den bestehenden Basiskrieger. Die Einheiten drehen sich beim Arbeiten nicht. Weltgrafik und Menüporträts teilen die Assets; Forschungszentren behalten ihre sichtbaren Betriebszustände. Assetformat und Grafikprüfungen: [SPRITE_CATALOG.md](docs/SPRITE_CATALOG.md).

Erste neue Höhlenoptik: texturierte Stein-/Tunneloberflächen, fraktionsbezogene Lichtfelder, metallische Gebäudesilhouetten, unterscheidbare Dot-Arten und eine gemeinsame untere Bau-/Infoleiste mit Minimap. Diese Darstellung baut auf PR #9 auf und ändert keine Spielregeln. Stand, Grenzen und Grafikprüfungen: [CAVERN_VISUALS.md](docs/CAVERN_VISUALS.md).

P6-Folgeauftrag: KI-Netzversorgung, reguläre Außenposten-/Abfangstationsforschung, Energieeffizienz und grafischer Forschungsbaum. **E**: Leitungszug mit Vorschau, Platzierung beim Loslassen; **Q**: Leitungs-/Arbeiterabriss. Im Fähigkeitenfenster ein Forschungszentrum wählen, Knoten inspizieren und Forschung starten; Mausrad/−/+ zoomen, mittlere Maustaste verschiebt den Baum. Regeln, vorläufige Werte und Prüfungen: [P6_PLAYABLE_RESEARCH.md](docs/P6_PLAYABLE_RESEARCH.md). Historische Beschreibungen unten sind teilweise überholt.

Prüfung des gesammelten Commitstands aus einem sauberen Export: [COMMIT_VALIDATION.md](docs/COMMIT_VALIDATION.md).

Energiephase lokal integriert: 60 Sekunden ohne Terrainroute führen zum Verfall; Abfangstationen übernehmen physische gegnerische Energie, puffern und senden sie zum eigenen Kern/Außenposten. Bei Stationszerstörung wird nur der verbleibende Puffer neutral. Testlaborfreigabe und Bau unter Fähigkeiten → Energietransport; Regeln, Bilanz und Prüfstand in [ENERGY_PHASE.md](docs/ENERGY_PHASE.md).

Reparatur, Baustellenabbruch und KI-Bauplanung sind lokal ergänzt. Eigene Arbeiter und ein beschädigtes fertiges Gebäude auswählen → „REPARIEREN“; eigene Baustelle auswählen → „ABBRUCH +…“. Die KI benutzt regulär bezahlte Bauplätze und ersetzt verlorene Hauptkerne. Vorläufige Kosten, Erstattung, Testfreigabe und Prüfstand: [MAINTENANCE_PHASE.md](docs/MAINTENANCE_PHASE.md).

Bauphase lokal integriert: Arbeiter errichten Kerne und Außenposten, fertige Standorte produzieren Einheiten und empfangen Energie; begonnener Kernbau und fertige Außenposten schützen nach Hauptkernverlust. Außenposten sind vorläufig nur im Testlabor freischaltbar. Bedienung, bestätigte Testwerte und Grenzen: [CONSTRUCTION_PHASE.md](docs/CONSTRUCTION_PHASE.md).

**Stand 25. Oktober 2026: spielbarer Einheitenprototyp.** Maximal 50 Arbeiter je Spieler einschließlich bezahlter Warteschlange; getrennte Krieger mit Produktion und Nahkampf; keine Fusion; alte Solo-Siegziele deaktiviert. Eigene Krieger passieren eigene Arbeiter und brauchen eine freie Endposition. Kampfwerte sind ausdrücklich vorläufig.

[UNIT_PROTOTYPE.md](docs/UNIT_PROTOTYPE.md) enthält Testanleitung, Messungen und Grenzen. Das [Zielkonzept](docs/GAME_DESIGN.md) umfasst weiterhin noch nicht implementierte Systeme wie Außenposten, Fog of War, große prozedurale Welt und zeitbasierte Forschung. Der [Stabilitätsstand](docs/STABILITY_VALIDATION.md) behebt die nachgewiesenen Windows-Gerätemeldungs-Hänger, erweitert exakte Viele-Ziele-Wege und korrigiert das Fortsetzen nach dem Laden. Der gemischte Grafiktest erreicht rund 60 FPS bei 20 Takten/s. Grenzen, Langtests und die neue v7-Bibliothek stehen im Prüfbericht; das Spiel dafür vollständig neu starten. Die aktuelle Arbeitskopie ist lokal geändert, ohne Commit oder Veröffentlichung.

Minimalistisches Echtzeit-Strategiespiel mit Godot 4. Die verbindlichen Regeln stehen in `docs/GAME_DESIGN.md`, die Architektur in `docs/ARCHITECTURE.md`, der Phasenstand in `docs/ROADMAP.md`. Agenten arbeiten nach `AGENTS.md`.

`godot --path .` öffnet das Startmenü. „Neues Spiel“ startet die Welt. Das reduzierte HUD zeigt Masse, Energie, Abbaufortschritt und Missionsziele. Farbgruppen werden intern verwaltet und erscheinen nicht mehr als eigene Spielereinstellung. Beim Abbau entstehen ausschließlich Energie-Dots, die zum Energiekern transportiert werden. Härte, Dauer und Ertrag sind getrennte Materialwerte. Nur eingelagerte Energie kann ausgegeben werden.

## Voraussetzungen

* Godot 4.3, Standardvariante (nicht .NET)
* Git

Godot 4.3 wird lokal und in GitHub Actions verwendet.

## Projekt starten

```bash
godot --path .
```

Andere Entwicklungsgröße oder anderer Seed, die Argumente stehen hinter `--`:

```bash
godot --path . -- --size=64 --seed=7
```

Die Szene prüft die Konfiguration, zeichnet die Welt und lässt die Arbeiter mit 20 Takten pro Sekunde laufen. Neue Erze mit Härte 8 benötigen ohne Forschung 128 Sekunden Arbeit eines einzelnen Basis-Arbeiters. Bei einem Fehler beendet sich das Programm mit Code 1.

Steuerung im Fenster:

* „Abbau“ ist der Startmodus. Ziehen mit der linken Taste markiert das Abbaugebiet des Schwarms. Die Fläche bleibt als Rahmen sichtbar.
* „Bewegen“ und ein Klick in einen Tunnel setzen den Sammelpunkt. Er wird als farbige Zelle gezeichnet.
* „Arbeiter +10“ kauft einen gelben Arbeiter für 10 bereits gelieferte Energie. Er erscheint am Energiekern. Die Energiezeile zeigt das Guthaben und in Klammern die Dots, die noch unterwegs sind.
* „KRIEGER“ bestellt einen Nahkämpfer für vorläufig 20 Energie. Linksklick oder Auswahlrechteck wählt eigene Arbeiter und Krieger; Rechtsklick erteilt der Auswahl einen Marschbefehl.
* „Fähigkeiten“ öffnet die vorhandenen Tempo-/Abbau-Upgrades. „1×“ wechselt auf 2× und 4×.
* „Speichern“ und „Laden“ nutzen `user://slot.dw`, ebenso F5 und F9. Alle 600 Takte entsteht `user://autosave.dw`.
* Leertaste oder „Pause“ hält die Simulation an. F11 schaltet Vollbild.
* Die Übersicht unten rechts springt die Kamera. Mausrad zoomt zur Cursorposition.
* Rechte oder mittlere Maustaste verschiebt die Ansicht, ebenso WASD und die Pfeiltasten.
* `G` schaltet das Zellraster ein, sobald eine Zelle mindestens 8 Pixel groß ist.
* `C` schaltet die Chunk-Grenzen ein.

Ohne Argumente erscheint das Menü. `--size`, `--seed`, `--play` oder ein Headless-Start überspringen es. Aktuell gibt es nur zwei bewegliche Dot-Arten: gelbe Arbeiter und cyanfarbene Energie-Dots. Rote Krieger-Dots sind für später geplant. Interne Farbgruppen teilen sich dieselbe Arbeiterfarbe.

Der Zoom reicht von der ganzen Welt im Fenster bis zu 40 Pixeln je Zelle. Gestartet wird mit 10 Pixeln je Zelle auf dem Starttunnel.

Headless, ohne Fenster:

```bash
godot --headless --path . --quit-after 8
```

Eine erfolgreiche Prüfung schreibt `DOT WARS bereit` in die Ausgabe.

## Tests

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

Ein optionaler Filter wählt Dateien:

```bash
godot --headless --path . -s tests/run_tests.gd -- mining
```

Der Runner endet mit Code 1, wenn eine Prüfung fehlschlägt oder kein Test läuft. GitHub Actions führt dieselben Tests und den Headless-Start aus.

## Testlabor (Performance und Fortschritte)

Im laufenden Spiel **Escape → TESTLABOR AKTIVIEREN** wählen. Im Pausemenü können
Arbeiter-/Energie-Tempo, Abbau, Intelligenz, Kern, Forschung und
Gebäudestufen kostenlos über **− / +** geändert werden. Mit **+100 Dots**
oder **+500 Dots** lassen sich größere Schwärme erzeugen, soweit freie
Zellen vorhanden sind. Nach „WEITER“ erscheint oben rechts ein Overlay mit
FPS, Tickdauer, Zielsuche, Bewegung, Abbau und der Zahl individueller BFS-Läufe.

Der Testmodus ist nur für den laufenden Spielstand aktiv. **Speichern und
Autosave sind nach einer Teständerung bis zum Neustart deaktiviert**, damit Testwerte nicht in normale
Spielstände gelangen. Nach einem Neustart gelten wieder normale Kaufkosten.
Ein herabgestufter Kern macht bereits freigelegte Weltzellen nicht rückgängig.

Manuelle Marschbefehle graben abhängig von der Zahl der beauftragten Dots
einen 1–9 Zellen breiten Arbeitskorridor. Dies ist eine erste
lastabhängige Verbreiterung, noch keine dynamische Navigationskohorte.

## Benchmark

Der Simulations-Benchmark misst keine Bildrate. Die Darstellung hat einen eigenen Messlauf. Vergleiche insbesondere p95/p99, `stage_avg_ms` und die Schwarmstufen 0 und 4 auf derselben Hardware.

```bash
godot --headless --path . -s bench/benchmark.gd -- --workers=1000,10000 --ticks=200
# Vergleich mit individueller Zielsuche, gleicher Seed und gleiche Hardware:
godot --headless --path . -s bench/benchmark.gd -- --workers=1000,10000 --ticks=200 --swarm=4
godot --path . -- --size=1000 --frames=150 --window=1920x1080
```

Ergebnisse und die Grenzen der Messung stehen in `docs/PERFORMANCE.md`.

## Struktur

```
src/sim/                 headlesse Simulation
src/main.gd              Menü, Takt, Aufträge
src/ui/                  Startmenü, reduziertes HUD, klickbare Minimap
src/render/              Kamera, Weltbild, Arbeiter, Auftragsrahmen, Koordinaten
scenes/main.tscn
tests/                   Test-Runner und Fälle
bench/benchmark.gd
docs/                    Regeln, Architektur, Entscheidungen, Roadmap, Messungen
.github/workflows/       CI
```

## Phasen

Die Phasen 1 bis 10 liegen in Review auf demselben Pull Request. Der Stand steht in `docs/ROADMAP.md`. Veröffentlichung und Windows-Export stehen in `docs/RELEASE.md`.

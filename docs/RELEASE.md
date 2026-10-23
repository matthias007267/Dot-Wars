# Release

Stand: 23. Oktober 2026. Version in `project.godot`: 0.3.0, Test-Beta mit Energie-Dots und gekauften Arbeitern. Eine Steam-Veröffentlichung ist nicht erfolgt und braucht eine eigene Freigabe.

## Was hier geprüft wurde

* 168 automatisierte Tests, 22 549 Prüfungen, headless, Godot 4.3. Kein Fehler.
* Headless-Start schreibt `DOT WARS bereit`.
* Startmenü und die Spielansicht wurden in dieser Linux-Umgebung geöffnet.
* Simulation mit 1.000, 10.000 und 50.000 Arbeitern, dazu eine 1.000×1.000-Welt. Zahlen in `docs/PERFORMANCE.md`.
* Speicherstand Version 2: speichern, laden, gleiche Fortsetzung. Version 1 wird abgelehnt und nicht umgerechnet.
* 4 000 Energie-Dots auf einer leeren 64er-Welt, 20 Takte, im Schnitt 2,34 ms. Ein enger Gang mit 24 Dots ist als Test festgehalten. Zahlen in `docs/PERFORMANCE.md`.

## Was hier nicht geprüft wurde

* Ein Windows-Rechner. Exportvorlagen für Godot 4.3 sind in dieser Umgebung nicht installiert, deshalb gibt es keine `build/dotwars.exe`.
* Eine von einem Menschen gespielte Partie bis zu den drei Siegzielen. Ein skriptierter Lauf mit Seed 1337 erreicht sie auf der 256er-Welt nach 37:28. Zahlen in `docs/PERFORMANCE.md`.
* Eine volle Partie, in der Abbau und mehrere tausend Energie-Dots gleichzeitig laufen.
* Ton auf einem echten Audiogerät. Diese Maschine fällt auf den Dummy-Treiber zurück.

## Windows-Build

Godot 4.3, Standardvariante, nicht .NET. Vorlage: Export Templates 4.3-stable.

```bash
godot --headless --path . --export-release "Windows Desktop" build/dotwars.exe
```

Die Vorgabe liegt in `export_presets.cfg`. Der Export bettet das PCK ein und zielt auf x86_64. Danach die Datei auf einem sauberen Windows-System starten: Menü, neues Spiel, Abbau, Pause, Speichern, Laden, Vollbild.

## Bekannte Grenzen

* Bei 10.000 Arbeitern liegt ein Takt auf der Messmaschine über 10 ms. 50.000 Arbeiter liegen bei etwa 87 ms.
* Kleine Tunneländerungen korrigieren die Zielsuche lokal. Große Änderungen und neue Ziele rechnen die erreichbare Fläche neu, verteilt über mehrere Takte. Eine geöffnete Zelle setzt eine laufende vollständige Berechnung nicht zurück.
* Mehrspieler läuft lokal gegen eine bis drei KI, ohne den alten Mittelkern. Auslöschen, Forschung, Reliquien und König des Hügels sind schaltbar. Leicht, Mittel, Schwer und Gemischt ändern den Plan der KI. Andere Spieler sind noch nicht verbunden. Rote Krieger fehlen.
* Escape öffnet Speichern, Laden, Neu starten, Lautstärke und Beenden. Die untere Leiste behält Arbeiter, Größe, Fähigkeiten und das Tempo.
* Die linke Taste wählt Arbeiter. Die rechte schickt sie oder erobert ein Gebiet. Ohne Auswahl gehen etwa zehn Prozent der nächsten Arbeiter. Gruppen über die Zifferntasten und Krieger sind noch nicht im Spiel.
* 3×3 kostet 250 Energie. Ein Arbeiter kostet vorläufig 10 Energie. Beides sind vorläufige Werte.
* Energie-Dots warten, wenn ein Arbeiter auf der nächsten Zelle zum Kern steht. Untereinander teilen sie die Zelle.
* Ohne die Fähigkeit Kern können Arbeiter die beiden Zugänge blockieren. Danach bleibt die Fläche frei und wächst bis Radius 4. Die Kosten 40 je angefangene Stufe sind vorläufig.
* Neue Spiele starten Arbeiter und Energie-Dots mit einem Schritt alle 8 Takte. Die Fähigkeiten unter Bewegung verkürzen das in Stufen bis auf jeden Takt. Die Kosten 25 und 30 je angefangene Stufe sind vorläufig.
* Das Menü trennt Einzelspieler und Mehrspieler. Räumung behält die drei Ziele, Förderung zählt 1.000 gelieferte Energie, Veredelung 400 veredelte Energie. Mehrspieler spielt mit schaltbaren Zielen und einer KI-Schwierigkeit. Die Zielzahlen und die Kosten sind vorläufig.
* Speicherstände der Version 1 sind mit dieser Wirtschaft nicht lesbar.
* Musik fehlt, weil kein lizenziertes Stück beiliegt.

## Checkliste vor einer Veröffentlichung

- [ ] Tests auf dem Release-Commit grün
- [ ] Windows-Build auf einem sauberen System gestartet
- [ ] Speicherstand aus dem Build geladen
- [ ] Vollbild und Fenster geprüft
- [ ] Mindestens eine Partie mit einem fremden Seed bis zu einer bewussten Entscheidung am Opferloch
- [ ] Store-Text und Screenshots aus `docs/STEAM.md` an den tatsächlichen Build angepasst
- [ ] Lizenzen aus `docs/LICENSES.md` dem Build beigelegt
- [ ] Ausdrückliche Freigabe für jede Veröffentlichung

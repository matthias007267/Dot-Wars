# Release

Stand: 22. Oktober 2026. Version in `project.godot`: 0.1.0. Eine Steam-Veröffentlichung ist nicht erfolgt und braucht eine eigene Freigabe.

## Was hier geprüft wurde

* 104 automatisierte Tests, headless, Godot 4.3.
* Headless-Start schreibt `DOT WARS bereit`.
* Startmenü und die Spielansicht wurden in dieser Linux-Umgebung geöffnet.
* Simulation mit 1.000, 10.000 und 50.000 Arbeitern, dazu eine 1.000×1.000-Welt. Zahlen in `docs/PERFORMANCE.md`.
* Speicherstand: speichern, laden, gleiche Fortsetzung, Ablehnung einer falschen Version.

## Was hier nicht geprüft wurde

* Ein Windows-Rechner. Exportvorlagen für Godot 4.3 sind in dieser Umgebung nicht installiert, deshalb gibt es keine `build/dotwars.exe`.
* Eine komplette Partie bis zu den drei Siegzielen. 90 % einer 256er- oder 500er-Welt sind ein langer Lauf.
* Ton auf einem echten Audiogerät. Diese Maschine fällt auf den Dummy-Treiber zurück.

## Windows-Build

Godot 4.3, Standardvariante, nicht .NET. Vorlage: Export Templates 4.3-stable.

```bash
godot --headless --path . --export-release "Windows Desktop" build/dotwars.exe
```

Die Vorgabe liegt in `export_presets.cfg`. Der Export bettet das PCK ein und zielt auf x86_64. Danach die Datei auf einem sauberen Windows-System starten: Menü, neues Spiel, Abbau, Pause, Speichern, Laden, Vollbild.

## Bekannte Grenzen

* Bei 10.000 Arbeitern liegt ein Takt auf der Messmaschine über 10 ms. 50.000 Arbeiter liegen bei etwa 87 ms.
* Die Zielsuche rechnet bei einer Tunneländerung die erreichbare Fläche neu, verteilt über mehrere Takte.
* Es gibt eine Fraktion. Kampf, KI und Mehrspieler fehlen.
* 3×3 kostet 250 Energie. Das ist ein vorläufiger Wert.
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

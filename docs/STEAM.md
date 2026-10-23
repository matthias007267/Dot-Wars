# Steam-Vorbereitung

Keine Veröffentlichung, kein Steamworks-Upload und keine kostenpflichtige Registrierung. Das braucht eine eigene Freigabe.

## Store-Text, Entwurf

DOT WARS ist ein minimalistisches Echtzeit-Strategiespiel. Die Welt ist ein Raster aus farbigen Punkten. Du steuerst keine einzelnen Arbeiter, sondern Farbgruppen: wo sie graben, wie groß sie werden sollen und wie viel Masse du opferst.

Jedes abgebaute Feld ergibt einen neuen Arbeiter. Weiches Material fällt schnell, hartes Material dauert. Aus kleinen Dots werden größere, wenn der Tunnel breit genug ist. Das Opferloch im Startbereich tauscht Masse gegen Energie. Energie kauft Tempo, Abbaukraft und größere Dots.

Die Runde ist gewonnen, wenn drei Dinge zusammen stimmen: 100 Masse, zwei Upgrades und 90 Prozent des abbaubaren Materials. Danach kann weiter gegraben werden.

Einzelspiel, eine prozedurale Welt pro Durchlauf, Windows.

## Screenshots und Trailer

Vor einem Store-Eintrag braucht es eigene Aufnahmen des Release-Builds:

* Startmenü mit Weltgröße und Seed
* Frühe Partie mit drei Gruppen und einem Abbaurechteck
* Tunnelwachstum und neue Dots
* Eine 2×2-Einheit neben Basis-Arbeitern
* Opferloch und Upgrade-Leiste
* Sieganzeige, während das Spiel weiterläuft

Ein Trailer ist nicht nötig für die technische Vorbereitung. Wenn einer entsteht, nur mit eigenem oder ausdrücklich lizenziertem Material.

## Steamworks

Für einen echten Upload fehlen eine Steamworks-App, ein Depot und die Steamworks-SDK. Godot 4.3 kann den Windows-Build ohne Steam-API ausliefern. Eine Integration der Steam-API, von Errungenschaften oder Cloud-Speicherständen ist nicht eingebaut. Speicherstände liegen lokal unter dem Godot-Benutzerverzeichnis.

## System, vorläufig

* Windows 10 oder 11, 64 Bit
* Grafik: OpenGL 3, der Kompatibilitäts-Renderer
* Eingabe: Maus und Tastatur
* Einzelspiel, offline lauffähig

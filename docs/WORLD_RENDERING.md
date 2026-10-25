# Premium Pixel Tactics – nur die Spielwelt

Standhinweis vom 25. Oktober 2026: Dieser Bericht beschreibt die bestehende Prototypdarstellung, keine Sichtregel des neuen Zielspiels. Der unten genannte Zugriff der Minimap auf die unveränderte Originaltextur ist Ist-Verhalten. Mit Fog of War müssen Weltbild, Minimap und sonstige Anzeigen das aktuelle bzw. zuletzt bekannte Spielerwissen beachten; unbekannte Gegnergebäude dürfen nicht darüber sichtbar werden. Sichtfilterung und eine mögliche andere Welt-/Texturarchitektur sind noch nicht implementiert oder zur Umsetzung freigegeben. Maßgeblich: [GAME_DESIGN.md](GAME_DESIGN.md), [ARCHITECTURE.md](ARCHITECTURE.md), [CONCEPT_SYNC.md](CONCEPT_SYNC.md).

Diese Aenderung betrifft **ausschliesslich die Weltansicht**. Das vorhandene HUD,
die Buttons, das Startmenue, die Minimap und die Simulation bleiben unveraendert.

## Darstellung

- `terrain.gdshader`: prozedurale, deterministische Struktur fuer weiches,
  mittleres, hartes und unzerstoerbares Material; beleuchtete Felskanten,
  vertiefte Tunnel, leichter Kontrast und Vignette im Weltbild.
- `dot_glow.gdshader`: scharfe Dot-Mitte mit schwachem Halo aus vier
  Nachbarpixeln. Derselbe Shader wird von Arbeitern und Energie verwendet.
- `WorldRenderer`: Ein einzelner `Sprite2D` stellt die vorhandene
  Welttextur mit Shader dar. Der Kern aller Fraktionen erhaelt einen dezent
  pulsierenden Lichtkreis, ohne einen Node pro Dot oder Zelle.
- `WorldRenderer.current_texture()` liefert weiterhin die **unveraenderte
  Originaltextur** an die Minimap.

Alle Effekte werden in der GPU ausgefuehrt, ohne die Material-IDs,
Wegfindung, Tickrate, KI, Kollisionen oder Energieabrechnung zu veraendern.
Die Welt-Textur bleibt ein Pixel pro Zelle; das ist ein stilisierter
Pixel-Art-Relief-Effekt und keine hochaufgeloeste Asset-Textur.

## Optionen (im Inspector oder per Code, keine neuen HUD-Elemente)

- `WorldRenderer.world_fx_enabled` – Weltshader und Kernlicht an/aus.
- `WorldRenderer.terrain_detail` – prozedurale Materialstruktur.
- `WorldRenderer.tunnel_depth` – Relief der Tunnel- und Felskanten.
- `WorldRenderer.vignette_strength` – schwache Abdunklung an Bildschirmraendern.
- `WorkerRenderer.glow_enabled / glow_strength` – Arbeiter-Glow.
- `EnergyRenderer.glow_enabled / glow_strength` – Energie-Glow.

Die Effekte sind standardmaessig eingeschaltet. Bei niedrigen Zoomstufen
wird das animierte Kernlicht weggelassen, damit Marker erkennbar bleiben.
Die Kern-Animation zeichnet hoechstens ca. 15 Mal pro Sekunde neu, ohne
dabei die Welttextur erneut hochzuladen.

## Performance-Pruefung

Vergleiche bei gleicher Weltgroesse, Arbeiterzahl, Kamera und Zoomstufe:

1. GPU-Framezeit mit/ohne Weltshader.
2. GPU-Framezeit mit/ohne Dot-Glow.
3. CPU-Framezeit der Simulation (sollte sich nicht aendern).
4. Verhalten bei 256, 512 und 1024 Weltzellen je Seite.

Shader-Kosten haengen von Aufloesung, Zoomstufe und GPU ab. Eine
konkrete FPS-Verbesserung wird nicht behauptet.

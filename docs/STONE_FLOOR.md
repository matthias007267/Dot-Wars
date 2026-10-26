# Steinboden und Abbauhistorie

Der Nutzer beauftragt den dunklen Steinhintergrund als Boden ohne Ressourcen und einen leichten Farbunterschied zwischen anfangs freien und freigegrabenen Flächen. Zuvor hatten alle freien Zellen denselben warmen körnigen Tunnelshader; pro Zelle gab es keine gespeicherte Abbauhistorie. Diese Änderung liegt auf `feat/stone-floor-history`, Basis `cfd2df3` einschließlich der bereits gemergten Performance-Korrekturen. Kein automatischer Merge.

## Darstellung

`assets/pixel/cavern_floor.png` wurde mit dem Bildwerkzeug aus der dunklen Steinoptik der Einheiten-Konzeptübersicht als reine Bodenkachel aufbereitet. Der Shader wiederholt sie an festen Weltkoordinaten. Die Detailabtastung bleibt pixelig; der Boden wirkt flach und enthält keine Ressourcenfacetten. Ursprünglich freie Zellen sind etwas kühler, tatsächlich abgebaute Zellen etwas wärmer. Dieselbe Textur und identische Koordinaten verhindern, dass die Farbkennung als neues Material wirkt. Ressourcenwände, Gebäude, Lichtquellen und ihre Regeln bleiben erhalten. Die Minimap behält ihre Materialfarben.

Eine eigene R8-Textur liefert nur die 0/1-Bodenhistorie. Sie verändert weder Rohmaterialpalette noch Begehbarkeit oder Abbauwerte. `WorldRenderer` aktualisiert sie nur bei neuem Abbau; gewöhnliche Fortschritts-/Markeränderungen verwenden dieselbe Textur. Bestehende Dirty-Chunks und inkrementelle Fog-Updates bleiben erhalten. Keine Node pro Zelle.

## Wann ein Boden freigegraben ist

- `WorldState.excavated` enthält ein Byte je Zelle, anfangs 0.
- Ausschließlich erfolgreicher Ressourcenabbau über `mine_cell()` setzt die Markierung auf 1. Generierte Hohlräume, `carve_rect()` und Öffnen ohne Ressourcenabbau setzen sie nicht.
- Die Markierung bleibt unter einem Gebäude-Fundament erhalten und erscheint nach dessen Entfernung wieder. Bei vorhandenen Ressourcen/Fundamenten wird kein Boden darüber gezeichnet.
- Der neue Zustand wird mitgehasht und gespeichert. Er beeinflusst keine Bewegung, Härte, Arbeitsleistung, Energie-/Massenbilanz, Sichtweite oder Weltgenerierung.

Der visuelle Unterschied ist dauerhaft, kein zeitabhängiger Frisch-Abbau-Effekt. Es werden weder zusätzliche Ressourcentypen noch Baukosten für den Boden eingeführt.

## Speicherung und Sichtschutz

Version-2-Spielstände erhalten optional `excavated` für die Welt und im Fog-Snapshot die je Fraktion zuletzt gesehenen Bodenmarkierungen. Typ, Länge und boolesche Werte werden vor Übernahme geprüft. Verdeckte Abbauarbeiten verändern nur den Weltzustand, nicht das Spielerwissen. Sichtkontakt übernimmt die Markierung; nach Sichtverlust bleibt das gedimmte Erinnerungsbild unverändert. Fog-Chunks lesen ausschließlich das gespeicherte Fraktionswissen, keine Live-Bodenmaske aus der Welt.

Ältere Spielstände bleiben ladbar. Ihnen fehlt die Information, welche bereits freien Zellen tatsächlich abgebaut wurden; diese Vergangenheit wird nicht geraten. Alle freien Flächen erhalten die Steintextur, fehlende Bodenmarkierungen starten neutral/kühl. Neuer Ressourcenabbau wird anschließend normal markiert. Neue Speicherstände behalten Welt- und Wissenshistorie vollständig beim Laden.

Die bereits gemergten nativen Sichtlisten und GDScript-Referenzpfade werden gemeinsam um Bodenwissen ergänzt. Es gibt keine neue native Methode oder geänderte Sichtlogik. Der Wissensabgleich wird auch bei einer reinen Änderung der Bodenhistorie korrekt invalidiert; unveränderte lokale Sichtstrahlen bleiben wiederverwendbar.

## Prüfung

`tests/test_floor_history.gd` prüft tatsächlichen Abbau gegenüber Generatoröffnung, Erhalt unter Fundamenten, Speicherung von Welt-/Fraktionswissen, alte Spielstände ohne das neue Feld, ungültige Masken, fehlgeschlagene atomare Fog-Wiederherstellung, verborgenen Abbau und unveränderte Terrainfarben bei geändertem Bodenwissen. Ein Renderercheck prüft die R8-Daten, Wiederverwendung und unveränderten Spielzustand beim Zeichnen.

`bench/floor_visual_check.gd` zeigt dieselbe Steinfläche zweimal im tatsächlichen Weltshader: links ursprünglich frei, rechts ausschließlich mit echten `mine_cell()`-Aufrufen freigegraben. Identische Texturkoordinaten, ohne Licht-/Missionsmarkerunterschiede. Der Grafikcheck prüft den wärmeren Rot-/kühleren Blauanteil, Stillstand bei Pause und unveränderte Welt beim Zeichnen. Ausgabe und Bild: `FLOOR SUMMARY: 0 failures`, `/tmp/floor-comparison.png`.

Die CI führt diesen Check zusätzlich zu den vollständigen nativen/Referenztests, Hauptszenenstart und den bisherigen P6-/Cavern-/Sprite-Grafikprüfungen aus. Shader-/Scriptfehler schlagen fehl; Vergleichsbild und Protokoll werden als `floor-visual-check` hochgeladen. Tatsächlicher Commit und Ergebnis werden im PR dokumentiert. Eine neue Windows-/10.000er-Leistungsabnahme wird aus dieser Grafikänderung nicht abgeleitet.

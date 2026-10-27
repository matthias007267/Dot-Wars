class_name HudOverview
extends RefCounted
## Read-only HUD data. No enemy jobs, invented score or simulation commands.

static func site_name(kind: int) -> String:
	return ["Hauptkern", "Außenposten", "Abfangstation", "Forschungszentrum", "Kriegsturm"][clampi(kind, 0, 4)]

static func site_icon(kind: int) -> String:
	return ["core", "outpost", "interceptor", "research", "tower"][clampi(kind, 0, 4)]

static func jobs(sim: Simulation) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in sim.research.jobs:
		if int(job.faction) != 0: continue
		var waiting := not sim.research.running(sim, job)
		var title: String = ResearchSystem.CATALOG[str(job.tech)].label
		result.append({"key": "research:%d" % job.site, "site": int(job.site), "icon": "research", "title": title, "count": 1,
			"progress": float(job.elapsed) / maxi(1, int(job.ticks)), "waiting": waiting,
			"detail": "%s · Zentrum #%d\n%.1f/%.1f Sekunden · %d Energie vorausbezahlt\n%s" % [title, job.site, job.elapsed / 20.0, job.ticks / 20.0, job.paid, "Pausiert: Netzanschluss oder Altauftrag-Restzahlung fehlt." if waiting else "Bezahlte Forschung läuft; keine weitere Abbuchung."]})
	for site in sim.construction.sites.records:
		if site.destroyed or site.owner != 0: continue
		if int(site.kind) == 4 and int(site.get("weapon_upgrade", -1)) >= 0:
			result.append({"key": "tower_upgrade:%d" % site.id, "site": int(site.id), "icon": "tower", "title": "Kriegsturm ausbauen", "count": 1,
				"progress": clampf(1.0 - float(int(site.weapon_upgrade) - sim.tick_count) / BuildingDefense.UPGRADE_TICKS, 0.0, 1.0), "waiting": false,
				"detail": "Turm #%d → Stufe %d · Waffe während des Ausbaus pausiert." % [site.id, int(site.weapon_level) + 1]})
		if not site.ready:
			var title := site_name(int(site.kind)) + " bauen"
			result.append({"key": "build:%d" % site.id, "site": int(site.id), "icon": site_icon(int(site.kind)), "title": title, "count": 1,
				"progress": float(site.work) / maxi(1, int(site.required)), "waiting": int(site.work) == 0,
				"detail": "%s · #%d\n%d/%d Arbeitertakte · %d/%d HP\nAusgewählte Arbeiter erreichen die Baustelle und leisten die Bauarbeit." % [title, site.id, site.work, site.required, site.hp, site.max_hp]})
		if sim.construction.demolitions.has(site.id):
			var order: Dictionary = sim.construction.demolitions[site.id]
			result.append({"key": "demolish:%d" % site.id, "site": int(site.id), "icon": "demolish", "title": "Gebäude abreißen", "count": 1,
				"progress": float(order.get("work", 0)) / maxi(1, int(order.get("required", 1))), "waiting": false,
				"detail": "%s #%d · Arbeiterabriss beauftragt." % [site_name(int(site.kind)), site.id]})
	var workers := {}
	for site in sim.spawner.site_queue(): workers[site] = int(workers.get(site, 0)) + 1
	for site in workers:
		result.append({"key": "worker:%d" % site, "site": int(site), "icon": "worker", "title": "Arbeiter bereit zur Platzierung", "count": int(workers[site]), "progress": 1.0, "waiting": true,
			"detail": "%d bezahlte Arbeiter · Standort #%d\nWarten auf einen freien Entstehungsplatz. Sie zählen bereits zum 50-Arbeiter-Limit." % [workers[site], site]})
	var warriors := {}
	for item in sim.army.queue:
		if int(item.owner) != 0: continue
		var site := int(item.site)
		if not warriors.has(site): warriors[site] = {"count": 0, "ready": int(item.ready)}
		warriors[site].count += 1
		warriors[site].ready = mini(int(warriors[site].ready), int(item.ready))
	for site in warriors:
		var row: Dictionary = warriors[site]
		var remaining := maxi(0, int(row.ready) - sim.tick_count)
		result.append({"key": "warrior:%d" % site, "site": int(site), "icon": "warrior", "title": "Kriegerproduktion", "count": int(row.count), "progress": 1.0 - float(remaining) / ArmyState.PRODUCTION_TICKS, "waiting": remaining == 0,
			"detail": "%d bezahlte Krieger · Standort #%d\nNächste Fertigstellung in %.1f s%s" % [row.count, site, remaining / 20.0, "; wartet auf freien Platz." if remaining == 0 else "."]})
	return result

static func team_rows(sim: Simulation) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var count := sim.rules.faction_count if sim._match_live() else 1
	for faction in count:
		if not sim.army.allied(0, faction): continue
		var scores := PackedStringArray()
		var mask := sim.config.victory_mask if sim._match_live() else 0
		if (mask & MatchRules.VICTORY_RESEARCH) != 0: scores.append("F %d" % sim.rules.wallet(sim, faction).research_level)
		if (mask & MatchRules.VICTORY_RELICS) != 0: scores.append("R %d" % sim.rules.relic_owner.count(faction))
		if (mask & MatchRules.VICTORY_HILL) != 0: scores.append("H %d" % sim.rules.hill_score[faction])
		rows.append({"owner": faction, "name": "Du" if faction == 0 else "Verbündeter %d" % (faction + 1), "score": " · ".join(scores) if not scores.is_empty() else "Freies Spiel" if not sim._match_live() else "Überleben"})
	return rows

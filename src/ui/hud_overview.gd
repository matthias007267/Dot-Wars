class_name HudOverview
extends RefCounted
## Read-only HUD data. No enemy jobs, invented score or simulation commands.

static func site_name(kind: int) -> String:
	return ["Hauptkern", "Außenposten", "Abfangstation", "Forschungszentrum"][clampi(kind, 0, 3)]

static func jobs(sim: Simulation) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in sim.research.jobs:
		if int(job.faction) != 0: continue
		var remaining_energy := maxi(0, int(job.energy) - int(job.spent))
		var charge := ceili(float(remaining_energy) / maxi(1, int(job.ticks) - int(job.elapsed)))
		var waiting := charge > 0 and int(sim.research.supply.get(int(job.site), 0)) < charge and not sim.research.is_powered(int(job.site), sim.tick_count)
		var title: String = ResearchSystem.CATALOG[str(job.tech)].label
		result.append({"key": "research:%d" % job.site, "site": int(job.site), "icon": "research", "title": title, "count": 1,
			"progress": float(job.elapsed) / maxi(1, int(job.ticks)), "waiting": waiting,
			"detail": "%s · Zentrum #%d\n%d/%d Forschungstakte · %d/%d Energie verbraucht\n%s" % [title, job.site, job.elapsed, job.ticks, job.spent, job.energy, "Wartet auf Energielieferung / Netzversorgung." if waiting else "Forschung läuft mit tatsächlich gelieferter Energie."]})
	for site in sim.construction.sites.records:
		if site.destroyed or site.owner != 0: continue
		if not site.ready:
			var title := site_name(int(site.kind)) + " bauen"
			result.append({"key": "build:%d" % site.id, "site": int(site.id), "icon": ["core", "outpost", "interceptor", "research"][int(site.kind)], "title": title, "count": 1,
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

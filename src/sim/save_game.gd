class_name SaveGame
extends RefCounted
## Versionierter Speicherstand. Beschädigte Daten ergeben null, keinen Absturz.

const VERSION := 2


static func snapshot(sim: Simulation) -> Dictionary:
	var units: Array[Dictionary] = []
	for id in sim.workers.count:
		units.append({
			"cell": sim.workers.cell[id],
			"group": sim.workers.group[id],
			"faction": sim.workers.faction[id],
			"size": sim.workers.size[id],
			"state": sim.workers.state[id],
			"target": sim.workers.target[id],
			"aim": sim.workers.aim[id],
			"idle": sim.workers.idle_ticks[id],
			"idle_cell": sim.workers.idle_cell[id],
			"moved": sim.workers.last_move_tick[id],
		})
	var groups: Array[Dictionary] = []
	for g in sim.quotas.size():
		var rects: Array[Rect2i] = sim.areas.rects[g]
		groups.append({
			"name": sim.group_names[g],
			"color": sim.group_colors[g],
			"quota": sim.quotas[g],
			"open": sim.group_open[g],
			"desired": sim.desired_size[g],
			"sacrifice": sim.sacrifice_on[g],
			"goal": sim.move_goal(g),
			"rects": rects.duplicate(),
			# Nach dem Entfernen leerer Rechtecke kann die Maske noch alte Leerzellen markieren.
			# Für deterministisches Fortsetzen die tatsächliche Maske mit speichern.
			"mask": (sim.areas.masks[g] as PackedByteArray).duplicate(),
		})
	return {
		"version": VERSION,
		"seed": sim.config.world_seed,
		"mode": sim.config.mode,
		"ai_count": sim.config.ai_count,
		"victory_mask": sim.config.victory_mask,
		"difficulty": sim.config.difficulty,
		"size": sim.world.width,
		"tick": sim.tick_count,
		"initial_mass": sim.initial_mass,
		"sacrificed": sim.sacrificed_mass,
		"purchased_workers": sim.purchased_workers,
		"energy_cells": sim.energy_dots.cells.duplicate(),
		"energy_birth": sim.energy_dots.birth.duplicate(),
		"energy_owner": sim.energy_dots.owner.duplicate(),
		"energy_delivered_to": sim.energy_dots.delivered_to.duplicate(),
		"energy_refined": sim.energy_dots.refined.duplicate(),
		"energy_generated": sim.energy_dots.generated,
		"energy_delivered": sim.energy_dots.delivered,
		"refined_delivered": sim.energy_dots.refined_delivered,
		"source_level": sim.buildings.source_level,
		"refinery_level": sim.buildings.refinery_level,
		"buildings": sim.buildings.export_entries(),
		"peak_mass": sim.peak_mass,
		"max_units": sim.max_units,
		"won": sim.won,
		"win_tick": sim.win_tick,
		"selected": sim.selected_group,
		"command_group": sim.command_group,
		"march_cell": sim.march_cell,
		"cells": sim.world.cells.duplicate(),
		"progress": sim.world.progress.duplicate(),
		"progress_frac": sim.world.progress_frac.duplicate(),
		"progress_frac_high": _export_frac_high(sim.world),
		"mined": sim.world.mined_count,
		"opened": sim.world.opened_count,
		"core_level": sim.upgrades.core_level,
		"units": units,
		"groups": groups,
		# Abbaugebiete können leere Rechtecke entfernen, ohne die Revision zu senken.
		# Die Revisionen müssen für identische Fortsetzung nach dem Laden erhalten bleiben.
		"areas_revision": sim.areas.revision,
		"areas_group_revision": sim.areas.group_revision.duplicate(),
		"queue": sim.spawner.export_queue(),
		"energy": sim.upgrades.energy,
		"speed_level": sim.upgrades.speed_level,
		"energy_speed": sim.upgrades.energy_speed_level,
		"dig_level": sim.upgrades.dig_level,
		"fusion2": sim.upgrades.fusion2,
		"fusion3": sim.upgrades.fusion3,
		"purchased": sim.upgrades.purchased,
		"research_level": sim.upgrades.research_level,
		"swarm_level": sim.upgrades.swarm_level,
		"match": sim.rules.export_state(),
		"move_period": sim.config.move_period_ticks,
		"quotas_config": sim.config.group_quotas.duplicate(),
	}


static func _export_frac_high(world: WorldState) -> Array:
	var keys: Array = world.progress_frac_high.keys()
	keys.sort()
	var rows: Array = []
	for key in keys:
		var copy: Array = []
		for limb in world.progress_frac_high[key]:
			copy.append(int(limb))
		rows.append({"cell": int(key), "limbs": copy})
	return rows


static func _restore_frac_high(world: WorldState, rows) -> bool:
	if typeof(rows) != TYPE_ARRAY:
		return false
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			return false
		var cell := int(row.get("cell", -1))
		if cell < 0 or cell >= world.cell_count():
			return false
		var limbs = row.get("limbs", [])
		if typeof(limbs) != TYPE_ARRAY or limbs.is_empty():
			return false
		var clean: Array = []
		for limb in limbs:
			var value := int(limb)
			if value < 0 or value >= 2147483648:
				return false
			clean.append(value)
		world.progress_frac_high[cell] = clean
	return true


static func to_bytes(sim: Simulation) -> PackedByteArray:
	return var_to_bytes(snapshot(sim))


static func from_bytes(bytes: PackedByteArray) -> Simulation:
	var data = bytes_to_var(bytes)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return from_snapshot(data)


static func from_snapshot(data: Dictionary) -> Simulation:
	if int(data.get("version", 0)) != VERSION:
		return null
	var cells: PackedByteArray = data.get("cells", PackedByteArray())
	var width := int(data.get("size", 0))
	if width < 16 or cells.size() != width * width:
		return null
	var groups: Array = data.get("groups", [])
	if groups.is_empty():
		return null
	var live_quotas := PackedInt32Array()
	for group in groups:
		live_quotas.append(int(group.get("quota", 0)))
	var config := SimConfig.new()
	config.world_size = width
	config.world_seed = int(data.get("seed", 1))
	config.initial_workers = 1
	config.move_period_ticks = int(data.get("move_period", 2))
	config.mode = int(data.get("mode", SimConfig.MODE_CLEARING))
	config.ai_count = int(data.get("ai_count", 0))
	config.victory_mask = int(data.get("victory_mask", MatchRules.VICTORY_ALL))
	config.difficulty = int(data.get("difficulty", SimConfig.DIFFICULTY_NORMAL))
	config.group_quotas = live_quotas
	if not config.validate().is_empty():
		return null
	var world := WorldState.new(width, width, config.chunk_size, Materials.EMPTY)
	var progress: PackedInt32Array = data.get("progress", PackedInt32Array())
	var frac: PackedInt32Array = data.get("progress_frac", PackedInt32Array())
	if progress.size() != cells.size() or frac.size() != cells.size():
		return null
	for idx in cells.size():
		if cells[idx] != Materials.EMPTY:
			world.set_material(idx, cells[idx])
		world.progress[idx] = progress[idx]
		world.progress_frac[idx] = frac[idx]
	if not _restore_frac_high(world, data.get("progress_frac_high", [])):
		return null
	world.mined_count = int(data.get("mined", 0))
	world.opened_count = int(data.get("opened", 0))
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	if sim == null:
		return null
	sim.initial_mass = int(data.get("initial_mass", 0))
	sim.sacrificed_mass = int(data.get("sacrificed", 0))
	sim.purchased_workers = int(data.get("purchased_workers", 0))
	sim.energy_dots.cells = data.get("energy_cells", PackedInt32Array()).duplicate()
	sim.energy_dots.birth = data.get("energy_birth", PackedInt32Array()).duplicate()
	sim.energy_dots.owner = data.get("energy_owner", PackedByteArray()).duplicate()
	sim.energy_dots.delivered_to = data.get("energy_delivered_to", PackedInt32Array()).duplicate()
	sim.energy_dots.refined = data.get("energy_refined", PackedByteArray()).duplicate()
	sim.energy_dots.generated = int(data.get("energy_generated", 0))
	sim.energy_dots.delivered = int(data.get("energy_delivered", 0))
	sim.energy_dots.refined_delivered = int(data.get("refined_delivered", 0))
	sim.energy_dots.ensure_tracks()
	sim.buildings.source_level = clampi(int(data.get("source_level", 0)), 0, Buildings.SOURCE_TIER_MAX)
	sim.buildings.refinery_level = clampi(int(data.get("refinery_level", 0)), 0, Buildings.REFINERY_TIER_MAX)
	var entries: Array = data.get("buildings", [])
	if not sim.buildings.restore(entries):
		return null
	sim.peak_mass = int(data.get("peak_mass", 0))
	sim.max_units = int(data.get("max_units", 0))
	sim.won = bool(data.get("won", false))
	sim.win_tick = int(data.get("win_tick", -1))
	sim.tick_count = int(data.get("tick", 0))
	if groups.size() != sim.quotas.size():
		return null
	for g in groups.size():
		var group: Dictionary = groups[g]
		sim.group_names[g] = str(group.get("name", sim.group_names[g]))
		sim.group_colors[g] = group.get("color", sim.group_colors[g])
		sim.quotas[g] = int(group.get("quota", 0))
		sim.group_open[g] = int(group.get("open", 1))
		sim.desired_size[g] = int(group.get("desired", 1))
		sim.sacrifice_on[g] = 0
		var rects: Array = group.get("rects", [])
		for rect in rects:
			sim.areas.assign_rect(g, rect)
		var saved_mask: PackedByteArray = group.get("mask", PackedByteArray())
		if not saved_mask.is_empty():
			if saved_mask.size() != sim.world.cell_count():
				return null
			sim.areas.masks[g] = saved_mask.duplicate()
		var goal := int(group.get("goal", -1))
		if goal >= 0:
			sim.set_move_goal(g, goal)
	# Ältere Version-2-Stände ohne diese Felder behalten die rekonstruierten Revisionen.
	var area_group_revisions: PackedInt32Array = data.get("areas_group_revision", PackedInt32Array())
	if area_group_revisions.size() == sim.areas.group_revision.size():
		sim.areas.group_revision = area_group_revisions.duplicate()
	if data.has("areas_revision"):
		sim.areas.revision = int(data["areas_revision"])
	sim.selected_group = clampi(int(data.get("selected", 0)), 0, sim.quotas.size() - 1)
	sim.command_group = int(data.get("command_group", -1))
	if sim.command_group < 0 or sim.command_group >= sim.quotas.size():
		sim.command_group = -1
	sim.march_cell = int(data.get("march_cell", -1))
	var units: Array = data.get("units", [])
	for unit in units:
		var unit_size := int(unit.get("size", 1))
		var id := -1
		if unit_size <= 1:
			id = sim.workers.add(int(unit["cell"]), int(unit["group"]), int(unit.get("faction", 0)))
		else:
			id = sim.workers.add_sized(int(unit["cell"]), int(unit["group"]), int(unit.get("faction", 0)), unit_size)
		sim.workers.state[id] = int(unit.get("state", 0))
		sim.workers.target[id] = int(unit.get("target", -1))
		sim.workers.aim[id] = int(unit.get("aim", -1))
		sim.workers.idle_ticks[id] = int(unit.get("idle", 0))
		sim.workers.idle_cell[id] = int(unit.get("idle_cell", -1))
		sim.workers.last_move_tick[id] = int(unit.get("moved", -1))
	var queue: PackedInt32Array = data.get("queue", PackedInt32Array())
	sim.spawner.import_queue(queue)
	sim.upgrades.energy = int(data.get("energy", 0))
	sim.upgrades.speed_level = int(data.get("speed_level", 0))
	sim.upgrades.energy_speed_level = int(data.get("energy_speed", 0))
	sim.upgrades.dig_level = int(data.get("dig_level", 0))
	sim.upgrades.fusion2 = bool(data.get("fusion2", false))
	sim.upgrades.fusion3 = bool(data.get("fusion3", false))
	sim.upgrades.purchased = int(data.get("purchased", 0))
	sim.upgrades.research_level = int(data.get("research_level", 0))
	sim.upgrades.swarm_level = int(data.get("swarm_level", 0))
	sim.upgrades.core_level = int(data.get("core_level", 0))
	if sim.config.mode == SimConfig.MODE_MATCH and not sim.rules.restore(data.get("match", {})):
		return null
	if sim.upgrades.core_level > 0 and not sim._bind_core(sim.upgrades.core_level, false):
		return null
	if not sim.check_invariants().is_empty():
		return null
	return sim


static func write_file(path: String, sim: Simulation) -> bool:
	# Vor dem Öffnen prüfen: WRITE würde einen vorhandenen Stand abschneiden.
	if sim.debug_mode or sim.debug_modified:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(to_bytes(sim))
	file.close()
	return true


static func read_file(path: String) -> Simulation:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return from_bytes(bytes)

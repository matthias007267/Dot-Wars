extends TestCase
const Fog = preload("res://src/sim/fog_of_war.gd")

func _sim() -> Simulation:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.mode = SimConfig.MODE_MATCH
	config.ai_count = 1
	config.initial_workers = 1
	var sim := Simulation.from_world(config, WorldState.new(32, 32, 8, Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	return sim

func test_only_actual_mining_marks_floor_and_foundations_keep_history() -> void:
	var world := WorldState.new(16, 16, 8, Materials.SOFT)
	world.carve_rect(Rect2i(0, 0, 1, 1))
	world.open_without_mining(1)
	check_eq(world.excavated[0], 0, "Generatoröffnung bleibt ursprünglich frei")
	check_eq(world.excavated[1], 0, "Öffnen ohne Abbau ist kein Ressourcenabbau")
	check(world.mine_cell(2), "tatsächlicher Abbau")
	check_eq(world.excavated[2], 1, "freigegraben")
	check(not world.mine_cell(2), "kein doppelter Abbau")
	check_eq(world.mined_count, 1, "Bilanz unverändert")
	world.set_material(2, Materials.INDESTRUCTIBLE)
	world.set_material(2, Materials.EMPTY)
	check_eq(world.excavated[2], 1, "Bodenhistorie nach Fundament und Abriss erhalten")

func test_history_and_player_knowledge_roundtrip_and_old_saves_load() -> void:
	var sim := _sim()
	var cell := sim.world.index(2, 12) # visible free ground, outside core foundations
	sim.world.set_material(cell, Materials.SOFT)
	sim.world.mine_cell(cell)
	sim.fog.update(sim)
	var snapshot := SaveGame.snapshot(sim)
	var loaded := SaveGame.from_snapshot(snapshot)
	check(loaded != null, "neuer Spielstand ladbar")
	if loaded == null: return
	check_eq(loaded.world.excavated, sim.world.excavated, "Abbauhistorie gespeichert")
	check_eq(loaded.fog.known_excavated, sim.fog.known_excavated, "Spielerwissen gespeichert")
	check_eq(loaded.state_hash(), sim.state_hash(), "identischer Zustand nach Laden")
	snapshot.erase("excavated")
	snapshot.fog.erase("excavated")
	var legacy := SaveGame.from_snapshot(snapshot)
	check(legacy != null, "Version-2-Altstand ohne Historie ladbar")
	if legacy != null:
		check_eq(legacy.world.excavated[cell], 0, "fehlende Altinformationen werden nicht erfunden")
		check_eq(legacy.fog.known_excavated[0][cell], 0, "Altgedächtnis neutral")

func test_invalid_history_is_rejected_without_partially_restoring_fog() -> void:
	var sim := _sim()
	for payload in [PackedByteArray([1]), "wrong type"]:
		var data := SaveGame.snapshot(sim)
		data.excavated = payload
		check(SaveGame.from_snapshot(data) == null, "ungültige Weltmaske abgewiesen")
	var data := SaveGame.snapshot(sim)
	data.excavated[0] = 2
	check(SaveGame.from_snapshot(data) == null, "nur boolesche Markierungen")
	var fog := Fog.new()
	fog.setup(sim.world, 2)
	fog.update(sim)
	var before := fog.snapshot()
	var invalid := fog.snapshot()
	invalid.excavated[0][0] = 2
	check(not fog.restore(invalid, sim.world, 2), "ungültiges Bodengedächtnis abgewiesen")
	check_eq(fog.snapshot(), before, "fehlgeschlagene Wiederherstellung verändert kein Wissen")

func test_hidden_mining_never_changes_known_floor_until_revisited() -> void:
	var sim := _sim()
	var cell := sim.world.index(25, 2)
	check(not sim.fog.is_visible(0, cell), "Teststelle außerhalb der Sicht")
	var view := FogOverlay.new()
	view.sim = sim
	view.show_tick(0)
	var before := view._floor_bytes.duplicate()
	sim.world.set_material(cell, Materials.SOFT)
	sim.world.mine_cell(cell)
	sim.fog.update(sim)
	view.show_tick(1)
	check_eq(sim.world.excavated[cell], 1, "wahrer Zustand freigegraben")
	check_eq(sim.fog.known_excavated[0][cell], 0, "kein Wissen über verborgenen Abbau")
	check_eq(view._floor_bytes, before, "keine verräterische Bodenaktualisierung")
	var scout := sim.workers.add(cell, 0, 0)
	sim.fog.update(sim)
	view.show_tick(2)
	check_eq(sim.fog.known_excavated[0][cell], 1, "Sichtkontakt übernimmt Abbauwissen")
	sim.workers.remove_swap(scout)
	sim.fog.update(sim)
	view.show_tick(3)
	check(not sim.fog.is_visible(0, cell), "Sicht wieder verloren")
	check_eq(view._floor_bytes[cell], 1, "gedimmtes Erinnerungsbild behält bekannte Bodenart")
	view.free()

func test_floor_only_changes_invalidate_knowledge_and_overlay_cache() -> void:
	var sim := _sim()
	var cell := sim.world.index(2, 12)
	sim.fog.update(sim)
	var view := FogOverlay.new()
	view.sim = sim
	view.show_tick(0)
	# Identical final material but newly known history must invalidate both caches.
	sim.world.set_material(cell, Materials.SOFT)
	sim.world.mine_cell(cell)
	sim.fog.update(sim)
	view.show_tick(1)
	check_eq(sim.fog.known_excavated[0][cell], 1, "Historie trotz gleicher Material-Endfarbe übernommen")
	check_eq(view._floor_bytes[cell], 1, "Bodenänderung trotz gleicher RGB-Daten aktualisiert")
	var renderer := WorldRenderer.new()
	renderer.world = sim.world
	var before := sim.state_hash()
	var texture := renderer.floor_history_texture()
	check_eq(renderer.floor_history_texture(), texture, "Textur ohne neuen Abbau wiederverwendet")
	check_eq(texture.get_image().get_pixel(cell % 32, cell / 32).r8, 1, "R8-Historie trägt tatsächliche Markierung")
	check_eq(sim.state_hash(), before, "Zeichnen verändert keinen Zustand")
	renderer.free()
	view.free()

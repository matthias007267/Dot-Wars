extends TestCase
## UI-Befehle ohne aktive Szene. Die Farbgruppen bleiben intern und erhalten gemeinsame Ziele.

func _new_hud() -> GameHud:
	var config := TestHelpers.default_config()
	config.world_size = 32
	config.initial_workers = 5
	config.group_quotas = PackedInt32Array([40, 30, 30])
	var sim := Simulation.create(config)
	var hud := GameHud.new()
	hud.sim = sim
	hud.clock = TickClock.new()
	return hud


func test_conquer_sends_only_the_selection() -> void:
	var hud := _new_hud()
	var layer := Control.new()
	hud._build_stats(layer)
	var rect := Rect2i(1, 1, 8, 8)
	check(not hud.issue_conquer(rect), "Eroberung ohne Auswahl")
	check(hud._message.text.contains("Wähle"), "Hinweis zur Auswahl")
	check_eq(hud.sim.command_group, -1, "ohne Auswahl keine Befehlsgruppe")
	hud.select_at(hud.sim.workers.cell[0])
	check(hud.issue_conquer(rect), "Eroberung der Auswahl")
	var group_id := hud.sim.command_group
	check(group_id >= 0, "Befehlsgruppe")
	check_eq(hud.sim.areas.rects[group_id].size(), 1, "ein Gebiet")
	check_eq(hud.sim.areas.rects[group_id][0], rect, "das markierte Rechteck")
	check_eq(hud.sim.workers.group_counts[group_id], 1, "nur der gewählte Arbeiter")
	for g in hud.sim.group_open.size():
		if g == group_id:
			continue
		check_eq(hud.sim.areas.rects[g].size(), 0, "andere Gruppen graben das nicht")
	check_no_errors(hud.sim.check_invariants(), "Befehle verändern keine Masse")
	layer.free()
	hud.free()


func test_right_drag_pans_until_ctrl_marks_an_area() -> void:
	check_eq(GameHud.pointer_gesture(MOUSE_BUTTON_RIGHT, false, true), GameHud.Pointer.PAN, "Rechtszug verschiebt die Karte")
	check_eq(GameHud.pointer_gesture(MOUSE_BUTTON_RIGHT, true, true), GameHud.Pointer.CONQUER, "Strg und Rechtszug setzen das Gebiet")
	check_eq(GameHud.pointer_gesture(MOUSE_BUTTON_RIGHT, false, false), GameHud.Pointer.MARCH, "Rechtsklick schickt die Auswahl")
	check_eq(GameHud.pointer_gesture(MOUSE_BUTTON_RIGHT, true, false), GameHud.Pointer.WAR, "Strg und Rechtsklick")
	check_eq(GameHud.pointer_gesture(MOUSE_BUTTON_LEFT, false, true), GameHud.Pointer.SELECT_RECT, "Linkszug wählt")


func test_selected_workers_march_together() -> void:
	var hud := _new_hud()
	hud.select_in_rect(Rect2i(0, 0, 32, 32))
	check_eq(hud.selection.size(), hud.sim.workers.count, "alle eigenen Arbeiter")
	var pit_neighbor := hud.sim.world.find_nearest_empty(16, 16)
	check(pit_neighbor >= 0, "eine Tunnelzelle ist vorhanden")
	check(hud.issue_march(pit_neighbor), "Marsch der Auswahl")
	check_eq(hud.sim.move_goal(hud.sim.command_group), pit_neighbor, "Laufziel der Auswahl")
	check_eq(hud.sim.workers.group_counts[hud.sim.command_group], hud.sim.workers.count, "die Auswahl geht gemeinsam")
	check_no_errors(hud.sim.check_invariants(), "Befehle verändern keine Masse")
	hud.free()


func test_buy_worker_requires_energy() -> void:
	var hud := _new_hud()
	check(not hud.sim.buy_worker(), "ohne Energie kein Arbeiter")
	hud.sim.upgrades.energy = Simulation.WORKER_COST
	check(hud.sim.buy_worker(), "Arbeiter gekauft")
	check_eq(hud.sim.upgrades.energy, 0, "Energie abgebucht")
	check_eq(hud.sim.spawner.pending(), 1, "gekaufter Arbeiter wartet am Kern")
	check_no_errors(hud.sim.check_invariants(), "Bilanz nach Kauf")
	hud.free()


func test_fusion_requests_are_rejected_for_all_groups() -> void:
	var hud := _new_hud()
	check(not hud.set_size_all(2), "gesperrte Größe wird abgewiesen")
	hud.sim.upgrades.fusion2 = true
	check(not hud.set_size_all(2), "Fusion bleibt auch mit altem Flag entfernt")
	for g in hud.sim.group_open.size():
		check_eq(hud.sim.desired_size[g], 1, "alle Gruppen bleiben bei einzelnen Arbeitern")
	check(hud.set_size_all(1), "Größe gilt für alle Gruppen")
	check_eq(hud.sim.desired_size[2], 1, "alle internen Gruppen gleich")
	check_no_errors(hud.sim.check_invariants(), "keine Masse durch Größeneinstellung verloren")
	hud.free()


func test_status_card_shows_owned_building_health() -> void:
	var hud := _new_hud()
	var layer := Control.new()
	hud._build_stats(layer)
	hud._build_goals(layer)
	hud._build_dock(layer)
	hud._build_upgrade_panel(layer)
	hud.refresh()
	check_eq(hud._kern_value.text, "Kern 600/600 HP", "neuer fertiger Hauptkern")
	check_eq(hud._kern_bar.value, 100.0, "volle HP")
	hud.sim.construction.damage(hud.sim, 0, 150)
	hud.refresh()
	check_eq(hud._kern_value.text, "Kern 450/600 HP", "Schaden sichtbar")
	check_eq(hud._kern_bar.value, 75.0, "relativer HP-Balken")
	layer.free()
	hud.free()


func test_escape_menu_holds_save_and_the_dock_does_not() -> void:
	var hud := _new_hud()
	var layer := Control.new()
	hud._build_stats(layer)
	hud._build_dock(layer)
	hud._build_pause_menu(layer)
	var dock := _texts(hud._dock_row)
	check(not dock.has("ABBAU"), "Abbau ist kein eigener Knopf")
	check(not dock.has("BEWEGEN"), "Bewegen ist kein eigener Knopf")
	check(hud._buy_worker_button.get_parent() == hud._dock_row, "Arbeiter bleibt im Befehlsraster")
	check(not dock.has("SPEICHERN"), "Speichern ist nicht in der Leiste")
	check(not dock.has("PAUSE"), "Pause ist nicht in der Leiste")
	check(not hud.menu_open(), "das Menü ist zu")
	hud.toggle_pause_menu()
	check(hud.menu_open(), "Escape öffnet das Menü")
	check(hud.clock.paused, "das Spiel steht")
	var menu := _texts(hud._pause_layer)
	check(menu.has("SPEICHERN"), "Speichern")
	check(menu.has("LADEN"), "Laden")
	check(menu.has("NEU STARTEN"), "Neustart")
	check(menu.has("BEENDEN"), "Beenden")
	hud.toggle_pause_menu()
	check(not hud.menu_open(), "Weiter schließt das Menü")
	check(not hud.clock.paused, "das Spiel läuft")
	layer.free()
	hud.free()


func test_unreachable_dig_order_is_announced() -> void:
	var config := TestHelpers.default_config()
	config.move_period_ticks = 1
	var sim := TestHelpers.sim_from_ascii([
		"..#########",
		"w.#########",
		"..#########",
		"..#########",
	], config)
	var hud := GameHud.new()
	hud.sim = sim
	var layer := Control.new()
	hud._build_stats(layer)
	hud.select_at(sim.workers.cell[0])
	check(hud.issue_conquer(Rect2i(5, 1, 3, 2)), "Auftrag")
	check(hud._message.text.contains("nicht erreichbar"), "Hinweis auf den Weg")
	layer.free()
	hud.free()


func _texts(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	if node is Button:
		found.append((node as Button).text)
	for child in node.get_children():
		found.append_array(_texts(child))
	return found

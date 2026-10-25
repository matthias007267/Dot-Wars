extends TestCase
const Store = preload("res://src/sim/settlement_store.gd")

func _store():
	var store = Store.new()
	store.setup(32, 32, 2)
	return store

func test_paid_plan_is_not_a_begun_core_and_only_actual_work_changes_it() -> void:
	var store = _store()
	var id: int = store.add(Store.Kind.MAIN_CORE, 0, Rect2i(4, 4, 3, 3), 100, 100, 10, false)
	check(id >= 0, "Bauplatz angelegt")
	check(not store.has_begun_core(0), "bloßer Plan schützt nicht")
	check_eq(store.contribute(id, 1, 1), 0, "fremder Besitzer darf nicht beitragen")
	check_eq(store.contribute(id, 0, 0), 0, "Nullarbeit startet nicht")
	check(not store.has_begun_core(0), "immer noch nur geplant")
	check_eq(store.contribute(id, 0, 1), 1, "erster echter Beitrag")
	check(store.has_begun_core(0), "begonnener Kern ist vorhanden, unabhängig von externen Arbeiterzahlen")
	check_eq(store.contribute(id, 0, 99), 9, "Bauarbeit wird am Ziel begrenzt")
	check_eq(store.ready_sites(0), PackedInt32Array([id]), "fertiger Produktionsort")
	check_eq(store.contribute(id, 0, 5), 0, "keine doppelte Fertigstellung")

func test_footprints_reserve_ground_and_ids_are_not_reused_after_destruction() -> void:
	var store = _store()
	var rect := Rect2i(4, 4, 3, 3)
	var first: int = store.add(Store.Kind.OUTPOST, 0, rect, 100, 100, 10, true)
	check_eq(store.add(Store.Kind.OUTPOST, 1, rect, 100, 100, 10, false), -1, "keine überschneidenden Bauplätze")
	check_eq(store.add(Store.Kind.OUTPOST, 0, Rect2i(31, 31, 3, 3), 100, 100, 10, false), -1, "kein Bauen über Weltrand")
	check_eq(store.damage(first, 150), 100, "kein negativer HP-Überlauf")
	check(store.space_free(rect), "zerstörte Fläche freigegeben")
	var second: int = store.add(Store.Kind.OUTPOST, 1, rect, 100, 100, 10, false)
	check(second > first, "neue Baustelle behält getrennte stabile ID")
	check(not store.valid(first), "alte ID kann nicht neue Baustelle beschädigen")
	check_eq(store.damage(first, 5), 0, "veralteter Treffer unschädlich")

func test_working_perimeter_has_no_diagonals_and_is_clipped() -> void:
	var store = _store()
	var id: int = store.add(Store.Kind.MAIN_CORE, 0, Rect2i(0, 0, 3, 3), 100, 100, 10, true)
	var cells: PackedInt32Array = store.perimeter(id)
	check_eq(cells.size(), 6, "am Rand nur rechte und untere Arbeitsplätze")
	check(not cells.has(3 * 32 + 3), "diagonale Ecke ist kein Arbeitskontakt")
	for cell in cells: check(cell >= 0 and cell < 32 * 32, "innerhalb Welt")

func test_snapshot_roundtrip_and_invalid_payload_leave_store_unchanged() -> void:
	var store = _store()
	var id: int = store.add(Store.Kind.MAIN_CORE, 0, Rect2i(4, 4, 3, 3), 100, 100, 10, false)
	store.contribute(id, 0, 1)
	var restored = _store()
	check(restored.restore(bytes_to_var(var_to_bytes(store.snapshot()))), "binär übertragener Zustand lesbar")
	check_eq(restored.state_hash(), store.state_hash(), "Baufortschritt und stabile ID identisch")
	var before: int = restored.state_hash()
	var data: Dictionary = store.snapshot()
	data.records[0].work = 0
	check(not restored.restore(data), "begonnen ohne Arbeit ist widersprüchlich")
	check_eq(restored.state_hash(), before, "fehlerhaftes Laden ist atomar")
	data = store.snapshot()
	data.records.append(data.records[0].duplicate(true))
	data.records[1].id = 1
	check(not restored.restore(data), "doppelte Fläche abgelehnt")
	check_eq(restored.state_hash(), before, "keine Teilübernahme beschädigter Daten")

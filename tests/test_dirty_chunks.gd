extends TestCase


func test_new_world_marks_all_chunks_dirty_once() -> void:
	var world := WorldState.new(100, 70, 32, Materials.SOFT)
	check_eq(world.chunks_x, 4, "Chunks in x")
	check_eq(world.chunks_y, 3, "Chunks in y")
	var first := world.consume_dirty_chunks()
	check_eq(first.size(), 12, "alle Chunks beim ersten Abruf")
	check_eq(world.consume_dirty_chunks().size(), 0, "danach keine")


func test_mining_marks_only_the_affected_chunk() -> void:
	var world := WorldState.new(100, 70, 32, Materials.SOFT)
	world.consume_dirty_chunks()
	world.mine_cell(world.index(40, 5))
	var dirty := world.consume_dirty_chunks()
	check_eq(dirty, PackedInt32Array([1]), "Chunk (1,0)")
	world.mine_cell(world.index(64, 64))
	check_eq(world.consume_dirty_chunks(), PackedInt32Array([2 * 4 + 2]), "Chunk (2,2)")


func test_chunk_is_listed_once_and_noop_changes_do_not_dirty() -> void:
	var world := WorldState.new(64, 64, 32, Materials.SOFT)
	world.consume_dirty_chunks()
	world.mine_cell(world.index(1, 1))
	world.mine_cell(world.index(2, 1))
	world.mine_cell(world.index(31, 31))
	check_eq(world.consume_dirty_chunks(), PackedInt32Array([0]), "Chunk 0 genau einmal")
	check(not world.mine_cell(world.index(1, 1)), "leere Zelle lässt sich nicht erneut abbauen")
	world.set_material(world.index(1, 1), Materials.EMPTY)
	check_eq(world.consume_dirty_chunks().size(), 0, "keine Änderung → kein Dirty")
	world.mine_cell(world.index(32, 0))
	world.mine_cell(world.index(31, 0))
	check_eq(world.consume_dirty_chunks(), PackedInt32Array([1, 0]), "Grenzzellen betreffen den jeweils eigenen Chunk")


func test_chunk_rect_is_clamped_at_world_edge() -> void:
	var world := WorldState.new(100, 70, 32, Materials.SOFT)
	check_eq(world.chunk_rect(0), Rect2i(0, 0, 32, 32), "innerer Chunk")
	check_eq(world.chunk_rect(3), Rect2i(96, 0, 4, 32), "schmaler Randchunk")
	check_eq(world.chunk_rect(11), Rect2i(96, 64, 4, 6), "Eckchunk")


func test_counters_track_mining() -> void:
	var world := WorldState.new(10, 10, 8, Materials.MEDIUM)
	check_eq(world.solid_count, 100, "Start")
	world.mine_cell(5)
	world.mine_cell(5)
	check_eq(world.solid_count, 99, "ein Abbau")
	check_eq(world.mined_count, 1, "einmal gezählt")
	check_eq(world.mined_fraction(), 1.0 / 100.0, "Anteil")
	world.carve_rect(Rect2i(0, 0, 2, 2))
	check_eq(world.mined_count, 1, "Aushub zählt nicht als Abbau")

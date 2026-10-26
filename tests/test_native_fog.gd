extends TestCase
const Backend = preload("res://src/sim/native_search.gd")
const Fog = preload("res://src/sim/fog_of_war.gd")

func _backend():
	var native = Backend.backend()
	if "--require-native" in OS.get_cmdline_user_args():
		check(native != null and native.has_method("fog_visible"), "v9 fog backend required")
	return native if native != null and native.has_method("fog_visible") else null

func test_native_union_matches_independent_rays_with_overlaps_edges_and_opaque_origins() -> void:
	var native = _backend()
	if native == null:
		check(true, "native fog unavailable; reference remains usable")
		return
	var fog := Fog.new()
	var world := WorldState.new(32, 32, 1, Materials.EMPTY)
	fog.setup(world, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 971119
	for iteration in 12:
		var blockers := PackedByteArray()
		blockers.resize(1024)
		for cell in 1024: blockers[cell] = rng.randi_range(0, 4) if rng.randf() < .15 else 0
		var sources := PackedInt32Array([0,0,9, 1,31,12, 2,1023,7, 0,31*32,9, 0,0,9])
		for source in 25:
			sources.append(source % 3)
			sources.append(rng.randi_range(0,1023))
			sources.append(rng.randi_range(0,12))
		var before := blockers.duplicate()
		var result: Array = native.fog_visible(blockers, sources, 3, 32)
		check_eq(result.size(), 3, "one sparse list per faction")
		for owner in 3:
			var expected := PackedByteArray()
			expected.resize(1024)
			for index in range(0,sources.size(),3):
				if sources[index] == owner: fog._reveal(expected,blockers,sources[index+1],sources[index+2])
			var actual := PackedByteArray()
			actual.resize(1024)
			for cell in result[owner]:
				check_eq(actual[cell],0,"no duplicate visible cell")
				actual[cell]=1
			check_eq(actual,expected,"exact union, iteration %d faction %d" % [iteration,owner])
		check_eq(blockers,before,"native operation preserves input")

func test_invalid_native_fog_payloads_fail_without_partial_output() -> void:
	var native = _backend()
	if native == null:
		check(true,"reference mode")
		return
	check_eq(native.fog_visible(PackedByteArray(),PackedInt32Array(),2,32),null,"empty world")
	check_eq(native.fog_visible(PackedByteArray([0]),PackedInt32Array([0,0]),2,1),null,"incomplete source")
	check_eq(native.fog_visible(PackedByteArray([0]),PackedInt32Array([2,0,7]),2,1),null,"invalid owner")
	check_eq(native.fog_visible(PackedByteArray([0]),PackedInt32Array([0,1,7]),2,1),null,"invalid origin")
	check_eq(native.fog_visible(PackedByteArray([0]),PackedInt32Array([0,0,-1]),2,1),null,"invalid radius")
	check_eq(native.fog_visible(PackedByteArray([0]),PackedInt32Array(),0,1),null,"invalid faction count")
	check_eq(native.fog_visible(PackedByteArray([0,0,0]),PackedInt32Array(),2,2),null,"nonrectangular grid")
	check_eq(native.fog_visible(PackedByteArray([0]),PackedInt32Array(),2,1),[PackedInt32Array(),PackedInt32Array()],"empty source set gives empty sight")

func test_native_and_reference_preserve_complete_faction_knowledge_each_tick() -> void:
	var native = _backend()
	if native == null:
		check(true,"reference mode")
		return
	var config := SimConfig.new()
	config.world_size=64
	config.mode=SimConfig.MODE_MATCH
	config.ai_count=1
	config.initial_workers=8
	var sim:=Simulation.create(config)
	for cell in sim.world.cell_count():
		if sim.world.cells[cell]==Materials.EMPTY and sim.workers.occupant[cell]<0 and sim.army.count<80:
			sim.army.add(cell,sim.army.count%2)
	var other:=SaveGame.from_snapshot(SaveGame.snapshot(sim))
	other.fog.reference_only=true
	for tick in 24:
		if tick % 4 == 0:
			var cell:=100+tick
			sim.world.cells[cell]=Materials.HARD if tick%8==0 else Materials.EMPTY
			other.world.cells[cell]=sim.world.cells[cell]
		if tick==8 or tick==16:
			sim.fog.alliance[1]=0 if tick==8 else 1
			other.fog.alliance[1]=sim.fog.alliance[1]
		sim.tick_once()
		other.tick_once()
		check_eq(sim.state_hash(),other.state_hash(),"game state at tick %d" % tick)
		check_eq(sim.fog.snapshot(),other.fog.snapshot(),"all knowledge at tick %d" % tick)
	check(sim.fog.native_updates>0,"native path actually executed")
	check_eq(other.fog.native_updates,0,"reference remains independent")

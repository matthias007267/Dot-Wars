extends TestCase

func _sim() -> Simulation:
	var config := SimConfig.new()
	config.world_size=32
	config.mode=SimConfig.MODE_MATCH
	config.ai_count=1
	config.initial_workers=2
	var sim:=Simulation.from_world(config,WorldState.new(32,32,8,Materials.EMPTY))
	sim.rules.control.fill(MatchRules.CONTROL_REMOTE)
	sim.army.add(10*32+10,0)
	sim.army.add(20*32+20,1)
	sim.fog.update(sim)
	return sim

func test_minimap_batches_only_visible_owned_units_and_keeps_marker_positions() -> void:
	var sim:=_sim()
	var view:=WorldMinimap.new()
	view.world=sim.world
	var origin:=Vector2(3,7)
	view._sync_unit_markers(sim,0,origin,2.0)
	var expected:=0
	for id in sim.workers.count:
		if sim.workers.faction[id]==0 and sim.fog.is_visible(0,sim.workers.cell[id]): expected+=1
	for id in sim.army.count:
		if sim.army.owners[id]==0 and sim.fog.is_visible(0,sim.army.cells[id]): expected+=1
	check_eq(view._unit_markers.visible_instance_count,expected,"no hidden or enemy markers")
	var first_cell:=sim.workers.cell[0]
	check_eq(Vector2(view._marker_buffer[3],view._marker_buffer[7]),origin+Vector2(first_cell%32,first_cell/32)*2.0,"batched map coordinates")
	check_eq(view._marker_buffer[8],1.0,"worker marker color buffer")
	# Dummy headless rendering cannot read back MultiMesh transforms/colors.
	if DisplayServer.get_name() != "headless":
		var first:=sim.workers.cell[0]
		check_eq(view._unit_markers.get_instance_transform_2d(0).origin,origin+Vector2(first%32,first/32)*2.0,"same map coordinates")
		check_eq(view._unit_markers.get_instance_color(0),Color.WHITE,"worker marker color")
	var own_warrior:=sim.army.cells[0]
	sim.fog.visible[0][own_warrior]=0
	view._sync_unit_markers(sim,0,origin,2.0)
	check_eq(view._unit_markers.visible_instance_count,expected-1,"lost sight removed in next marker update")
	for id in sim.workers.count: sim.fog.visible[0][sim.workers.cell[id]]=0
	view._sync_unit_markers(sim,0,origin,2.0)
	check_eq(view._unit_markers.visible_instance_count,0,"no stale instances remain")
	view.free()

func test_warrior_pixels_and_activity_equal_catalog_and_clear_dead_or_hidden_cells() -> void:
	var sim:=_sim()
	var view:=ArmyRenderer.new()
	view.sim=sim
	var cell:=sim.army.cells[0]
	sim.army.last_attack[0]=10
	view.show_tick(11)
	check_eq(view._bytes[cell*4+3],255,"visible warrior painted")
	check_eq(view._details[cell*4],SpriteCatalog.warrior_row(1),"same atlas row")
	check_eq(view._details[cell*4+1],SpriteCatalog.warrior_activity(sim.army,0,11),"same attack state")
	sim.fog.visible[0][cell]=0
	view.show_tick(12)
	check_eq(view._bytes[cell*4+3],0,"hidden pixel cleared")
	check_eq(view._details[cell*4+1],0,"hidden activity cleared")
	sim.fog.visible[0][cell]=1
	sim.army.last_attack[0]=-1
	sim.army.next_move[0]=30
	view.show_tick(13)
	check_eq(view._details[cell*4+1],SpriteCatalog.warrior_activity(sim.army,0,13),"same movement state")
	sim.army.remove(sim.army.ids[0])
	view.show_tick(14)
	check_eq(view._bytes[cell*4+3],0,"dead warrior cleared")
	view.free()

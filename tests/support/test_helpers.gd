class_name TestHelpers
extends RefCounted
## Hilfsfunktionen zum Aufbau kleiner, lesbarer Testwelten per ASCII-Karte.
##
## Zeichen: '#' weich, 'M' mittel, 'H' hart, '.' leer, 'w' leer mit Arbeiter.


static func default_config() -> SimConfig:
	var config := SimConfig.new()
	config.group_quotas = PackedInt32Array([100, 0])
	return config


static func parse_world(rows: Array) -> Dictionary:
	var height := rows.size()
	var width: int = rows[0].length()
	var world := WorldState.new(width, height, 8, Materials.EMPTY)
	var starts := PackedInt32Array()
	for y in height:
		var row: String = rows[y]
		assert(row.length() == width, "Zeile %d hat falsche Länge" % y)
		for x in width:
			match row[x]:
				"#":
					world.set_material(y * width + x, Materials.SOFT)
				"M":
					world.set_material(y * width + x, Materials.MEDIUM)
				"H":
					world.set_material(y * width + x, Materials.HARD)
				"w":
					starts.append(y * width + x)
	return {"world": world, "starts": starts}


static func sim_from_ascii(rows: Array, config: SimConfig = null) -> Simulation:
	if config == null:
		config = default_config()
	var parsed := parse_world(rows)
	return Simulation.from_world(config, parsed["world"], parsed["starts"])


static func rect_of(sim: Simulation) -> Rect2i:
	return Rect2i(0, 0, sim.world.width, sim.world.height)


static func worker_xy(sim: Simulation, id: int) -> Vector2i:
	var c := sim.workers.cell[id]
	return Vector2i(c % sim.world.width, c / sim.world.width)


## Anzahl erreichbarer leerer Zellen ab `start` (orthogonal), unabhängig vom Spielcode berechnet.
static func reachable_empty_cells(world: WorldState, start: int) -> int:
	var seen := {start: true}
	var stack: Array[int] = [start]
	while not stack.is_empty():
		var c: int = stack.pop_back()
		var x := c % world.width
		var y := c / world.width
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if not world.in_bounds(nx, ny):
				continue
			var n := ny * world.width + nx
			if world.cells[n] == Materials.EMPTY and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen.size()


static func legacy_core_sim(config: SimConfig) -> Simulation:
	var world := WorldGenerator.generate(config)
	var sim := Simulation.from_world(config, world, PackedInt32Array(), false)
	sim.construction.initial(sim, sim.pit_index(), 0, true)
	sim._place_initial_workers(PackedInt32Array())
	sim.initial_mass = sim.workers.mass_sum()
	sim.peak_mass = sim.initial_mass
	sim.max_units = sim.workers.count
	return sim


## Scheduler fixture with already delivered energy. Physical delivery is tested separately.
## Bounded loop: a rejected start fails the test instead of hanging CI.
static func complete_buffered_research(sim: Simulation, site: int, tech: String, faction := 0) -> bool:
	if not sim.research.start(sim, faction, site, tech): return false
	var cost := sim.research.details(tech, sim.research.level(faction, tech) + 1)
	sim.research.supply[site] = int(sim.research.supply.get(site, 0)) + int(cost.energy)
	var expected := sim.research.level(faction, tech) + 1
	for tick in int(cost.ticks):
		sim.tick_count += 1
		sim.research.step(sim)
	return sim.research.level(faction, tech) == expected

class_name CavernGenerator
extends RefCounted
## Integer-seeded tunnel regions, a permanent wall forest and sparse mixed ore veins.
class Stream:
	var state: int
	func _init(seed_value: int) -> void: state = seed_value & 0x7fffffff
	func pick(limit: int) -> int:
		state = (state * 1103515245 + 12345) & 0x7fffffff
		return (state >> 8) % maxi(1, limit)

const VEIN_INTERVALS := [600, 1200, 2800, 6500, 13000, 28000, 70000, 300000]
const VEIN_LENGTHS := [8, 7, 6, 5, 4, 3, 2, 1]
const DIRECTIONS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static func match_centers(size: int, count: int) -> Array[Vector2i]:
	var inset := maxi(WorldGenerator.START_CLEARING_RADIUS + 7, size / 5)
	if size == 32 and count == 4: inset = 8
	var mid := size / 2
	var all: Array[Vector2i] = [Vector2i(inset, mid), Vector2i(size - 1 - inset, mid), Vector2i(mid, inset), Vector2i(mid, size - 1 - inset)]
	if size == 32 and count >= 3:
		all = [Vector2i(8, 8), Vector2i(23, 23), Vector2i(23, 8), Vector2i(8, 23)]
	var result: Array[Vector2i] = []
	for index in mini(count, 4): result.append(all[index])
	return result

static func populate(world: WorldState, config: SimConfig) -> void:
	var rng := Stream.new(config.world_seed)
	var centers: Array[Vector2i] = []
	if config.mode == SimConfig.MODE_MATCH: centers = match_centers(world.width, config.ai_count + 1)
	else: centers.append(WorldGenerator.sacrifice_cell(world))
	if config.mode == SimConfig.MODE_MATCH: world.start_regions = centers.duplicate()
	_walls(world, centers, rng)
	for owner in centers.size(): _tunnels(world, centers, owner, config.mode == SimConfig.MODE_MATCH, rng)
	for ore in 8:
		var interval: int = VEIN_INTERVALS[ore]
		var count: int = world.cell_count() / interval
		if rng.pick(interval) < world.cell_count() % interval: count += 1
		for vein in count:
			var cell := rng.pick(world.cell_count())
			for attempt in 12:
				if world.cells[cell] == Materials.ROCK: break
				cell = rng.pick(world.cell_count())
			for step in VEIN_LENGTHS[ore]:
				if world.cells[cell] == Materials.ROCK:
					world.cells[cell] = Materials.COPPER + (maxi(0, ore - 1) if rng.pick(5) == 0 else ore)
				var p: Vector2i = Vector2i(cell % world.width, cell / world.width) + DIRECTIONS[rng.pick(4)]
				if world.in_bounds(p.x, p.y): cell = world.index(p.x, p.y)
	# Raw generation is intentional: one final count/face rebuild, no per-cell signals.
	world.solid_count = 0
	world.indestructible_count = 0
	for material in world.cells:
		if material != Materials.EMPTY: world.solid_count += 1
		if material == Materials.INDESTRUCTIBLE: world.indestructible_count += 1
	world.rebuild_faces()

static func _zone(p: Vector2i, centers: Array[Vector2i]) -> int:
	var owner := 0
	var best := 2147483647
	for i in centers.size():
		var d := absi(p.x - centers[i].x) + absi(p.y - centers[i].y)
		if d < best:
			best = d
			owner = i
	return owner

static func _safe(p: Vector2i, world: WorldState, centers: Array[Vector2i], owner: int, match_mode: bool) -> bool:
	if p.x < 3 or p.y < 3 or p.x >= world.width - 3 or p.y >= world.height - 3: return false
	if match_mode and maxi(absi(p.x - world.width / 2), absi(p.y - world.height / 2)) <= 6: return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not region_open(p + Vector2i(dx, dy), centers, owner): return false
	return true

static func _open(world: WorldState, p: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if world.in_bounds(p.x + dx, p.y + dy): world.cells[world.index(p.x + dx, p.y + dy)] = Materials.EMPTY

static func _tunnels(world: WorldState, centers: Array[Vector2i], owner: int, match_mode: bool, rng: Stream) -> void:
	var root := centers[owner]
	var branches: Array[Vector2i] = [root]
	_open(world, root)
	for branch in maxi(4, world.width / 24):
		var goal := root
		for attempt in 64:
			var candidate := Vector2i(rng.pick(world.width), rng.pick(world.height))
			if _safe(candidate, world, centers, owner, match_mode):
				goal = candidate
				break
		var p := branches[rng.pick(branches.size())]
		for step in world.width * 3:
			if p == goal: break
			var dx := signi(goal.x - p.x)
			var dy := signi(goal.y - p.y)
			var horizontal := (rng.pick(2) == 0 and dx != 0) or dy == 0
			var next := p + (Vector2i(dx, 0) if horizontal else Vector2i(0, dy))
			if not _safe(next, world, centers, owner, match_mode):
				next = p + (Vector2i(0, dy) if horizontal else Vector2i(dx, 0))
				if next == p or not _safe(next, world, centers, owner, match_mode): break
			p = next
			_open(world, p)
			branches.append(p)
	# Start clearing geometry is preserved and cannot bridge the protected region seams.
	for dy in range(-2, 3):
		var half := 1 if absi(dy) == 2 else 2
		for dx in range(-half, half + 1): world.cells[world.index(root.x + dx, root.y + dy)] = Materials.EMPTY
	if not match_mode: world.cells[world.index(root.x, root.y)] = Materials.INDESTRUCTIBLE

static func _reserved(p: Vector2i, world: WorldState, centers: Array[Vector2i]) -> bool:
	if maxi(absi(p.x - world.width / 2), absi(p.y - world.height / 2)) <= 5: return true
	for root in centers:
		if maxi(absi(p.x - root.x), absi(p.y - root.y)) <= 4: return true
	return false

static func _walls(world: WorldState, centers: Array[Vector2i], rng: Stream) -> void:
	# A planar tree of interior wall segments cannot enclose or sever a region.
	# Carving tunnels later only removes edges, preserving that property.
	var stride := 12
	var cols := maxi(1, (world.width - 8) / stride + 1)
	var rows := maxi(1, (world.height - 8) / stride + 1)
	var visited := PackedByteArray()
	visited.resize(cols * rows)
	var stack: Array[int] = [0]
	visited[0] = 1
	while not stack.is_empty():
		var node: int = stack.back()
		var options: Array[int] = []
		for d in DIRECTIONS:
			var x: int = node % cols + d.x
			var y: int = node / cols + d.y
			if x >= 0 and y >= 0 and x < cols and y < rows and visited[y * cols + x] == 0: options.append(y * cols + x)
		if options.is_empty():
			stack.pop_back()
			continue
		var next: int = options[rng.pick(options.size())]
		visited[next] = 1
		stack.append(next)
		var p := Vector2i(4 + (node % cols) * stride, 4 + (node / cols) * stride)
		var end := Vector2i(4 + (next % cols) * stride, 4 + (next / cols) * stride)
		var direction := Vector2i(signi(end.x - p.x), signi(end.y - p.y))
		for step in stride + 1:
			if not _reserved(p, world, centers): world.cells[world.index(p.x, p.y)] = Materials.INDESTRUCTIBLE
			p += direction
	if cols * rows == 1:
		world.cells[world.index(2, 2)] = Materials.INDESTRUCTIBLE

static func region_open(p: Vector2i, centers: Array[Vector2i], owner: int) -> bool:
	if _zone(p, centers) != owner: return false
	for direction in DIRECTIONS:
		if _zone(p + direction, centers) != owner: return false
	return true

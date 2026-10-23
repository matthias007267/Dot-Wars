class_name MiningSystem
extends RefCounted
## Zielwahl und Abbaufortschritt. Datenorientiert und zustandslos (GDExtension-tauglich).
##
## Der Fortschritt liegt an der Zelle. Eine Zelle wird genau einmal abgeschlossen: Sobald sie leer
## ist, tragen weitere Arbeiter im selben Tick nichts mehr bei.


## Sucht eine feste, markierte Nachbarzelle (Reihenfolge N, O, S, W). Setzt bei Erfolg Ziel und Zustand.
static func acquire_target(workers: WorkerStore, world: WorldState, areas: DigAreas, id: int) -> bool:
	if workers.size[id] > 1:
		return _acquire_around_footprint(workers, world, areas, id)
	var c := workers.cell[id]
	var mask: PackedByteArray = areas.masks[workers.group[id]]
	var cells := world.cells
	var w := world.width
	var x := c % w
	var found := WorkerStore.NO_TARGET
	if c >= w and _can_mine(cells, mask, c - w):
		found = c - w
	elif x < w - 1 and _can_mine(cells, mask, c + 1):
		found = c + 1
	elif c < world.cell_count() - w and _can_mine(cells, mask, c + w):
		found = c + w
	elif x > 0 and _can_mine(cells, mask, c - 1):
		found = c - 1
	if found == WorkerStore.NO_TARGET:
		return false
	workers.target[id] = found
	workers.state[id] = WorkerStore.STATE_MINING
	return true


## Verarbeitet alle abbauenden Arbeiter in ID-Reihenfolge. Gibt die Zahl abgeschlossener Zellen zurück
## und trägt deren Positionen in `spawner` ein.
static func step(
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	energy: EnergyStore,
	work_per_hardness: int,
	dig_power: int,
) -> int:
	var completed := 0
	var cells := world.cells
	var progress := world.progress
	var state := workers.state
	var target := workers.target
	for id in workers.count:
		if state[id] != WorkerStore.STATE_MINING:
			continue
		var cell := target[id]
		var mask: PackedByteArray = areas.masks[workers.group[id]]
		if not Materials.is_mineable(cells[cell]) or mask[cell] == 0:
			if not acquire_target(workers, world, areas, id):
				state[id] = WorkerStore.STATE_WAITING
			continue
		var total := progress[cell] + dig_power
		if total >= Materials.durability(cells[cell], work_per_hardness):
			var hardness := Materials.hardness(cells[cell])
			if world.mine_cell(cell):
				energy.enqueue(cell, hardness, int(workers.faction[id]))
				completed += 1
		else:
			progress[cell] = total
			world.note_progress(cell)
	return completed


## Wie `step`, aber mit der Abbaustufe 5/4 und verteilter Leistung großer Einheiten.
## `faction_level` ersetzt `dig_level` je Fraktion, sobald das Array gefüllt ist.
static func step_scaled(
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	energy: EnergyStore,
	work_per_hardness: int,
	dig_power: int,
	dig_level: int,
	faction_level: PackedInt32Array = PackedInt32Array(),
) -> int:
	var completed := 0
	for id in workers.count:
		if workers.state[id] != WorkerStore.STATE_MINING:
			continue
		var targets := _targets_for(workers, world, areas, id)
		if targets.is_empty():
			if not acquire_target(workers, world, areas, id):
				workers.state[id] = WorkerStore.STATE_WAITING
			continue
		var power := WorkerStore.SIZE_POWER[workers.size[id]] * dig_power
		var base := power / targets.size()
		var extra := power % targets.size()
		var level := dig_level
		if not faction_level.is_empty():
			var faction_id := int(workers.faction[id])
			if faction_id < faction_level.size():
				level = faction_level[faction_id]
		for index in targets.size():
			var share := base + (1 if index < extra else 0)
			if share <= 0:
				continue
			if _apply_power(workers, world, areas, energy, id, targets[index], share, work_per_hardness, level):
				completed += 1
	return completed


static func _can_mine(cells: PackedByteArray, mask: PackedByteArray, idx: int) -> bool:
	return Materials.is_mineable(cells[idx]) and mask[idx] == 1


static func _acquire_around_footprint(
	workers: WorkerStore, world: WorldState, areas: DigAreas, id: int
) -> bool:
	var targets := _targets_for(workers, world, areas, id)
	if targets.is_empty():
		return false
	workers.target[id] = targets[0]
	workers.state[id] = WorkerStore.STATE_MINING
	return true


static func _targets_for(workers: WorkerStore, world: WorldState, areas: DigAreas, id: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	var seen := {}
	var mask: PackedByteArray = areas.masks[workers.group[id]]
	var cells := world.cells
	var width := world.width
	var limit := int(workers.size[id])
	var anchor := workers.cell[id]
	for dy in limit:
		for dx in limit:
			var center := anchor + dy * width + dx
			var x := center % width
			var neighbors: Array[int] = []
			if center >= width:
				neighbors.append(center - width)
			if x < width - 1:
				neighbors.append(center + 1)
			if center + width < world.cell_count():
				neighbors.append(center + width)
			if x > 0:
				neighbors.append(center - 1)
			for cell in neighbors:
				if seen.has(cell) or not _can_mine(cells, mask, cell):
					continue
				seen[cell] = true
				found.append(cell)
				if found.size() == limit:
					return found
	return found


static func _apply_power(
	workers: WorkerStore,
	world: WorldState,
	areas: DigAreas,
	energy: EnergyStore,
	id: int,
	cell: int,
	share: int,
	work_per_hardness: int,
	dig_level: int,
) -> bool:
	var mask: PackedByteArray = areas.masks[workers.group[id]]
	if not _can_mine(world.cells, mask, cell):
		return false
	var points := share
	if dig_level > 0:
		var scaled: Array = _scale(_read_rem(world, cell), share, dig_level)
		points = int(scaled[0])
		_write_rem(world, cell, scaled[1])
	var current := int(world.progress[cell])
	var durability := Materials.durability(world.cells[cell], work_per_hardness)
	if current >= durability or points >= durability - current:
		var hardness := Materials.hardness(world.cells[cell])
		if world.mine_cell(cell):
			energy.enqueue(cell, hardness, int(workers.faction[id]))
			return true
		return false
	world.progress[cell] = current + points
	world.note_progress(cell)
	return false


## Basis 2^31. Jedes Glied bleibt eine positive 32-Bit-Zahl. Das niedere Glied liegt in `progress_frac`.
const _LIMB := 2147483648
const _I64 := 9223372036854775807


## Addiert `share * (5/4)^level` zum Rest. Liefert [Punkte, neue Glieder].
static func _scale(rem: Array, share: int, level: int) -> Array:
	var rem_i := _limbs_as_int(rem)
	if rem_i >= 0:
		var num := 1
		var den := 1
		var fit := true
		for _step in level:
			if num > _I64 / 5 or den > _I64 / 4:
				fit = false
				break
			num *= 5
			den *= 4
		if fit and (share <= 0 or num <= _I64 / maxi(share, 1)):
			var product := share * num
			if rem_i <= _I64 - product:
				var acc := rem_i + product
				return [int(acc / den), _limbs_from_int(int(acc % den))]
	var wide := _mul_limbs(_pow_small(5, level), _limbs_from_int(share))
	wide = _add_limbs(wide, rem if not rem.is_empty() else [0])
	return _divmod_pow4(wide, level)


static func _read_rem(world: WorldState, cell: int) -> Array:
	var low := int(world.progress_frac[cell])
	if low < 0:
		low = 0
	var limbs: Array = [low]
	if world.progress_frac_high.has(cell):
		for limb in world.progress_frac_high[cell]:
			limbs.append(int(limb))
	return limbs


static func _write_rem(world: WorldState, cell: int, limbs: Array) -> void:
	var cleaned: Array = []
	for limb in limbs:
		cleaned.append(int(limb))
	while cleaned.size() > 1 and int(cleaned[cleaned.size() - 1]) == 0:
		cleaned.remove_at(cleaned.size() - 1)
	var low := 0
	if not cleaned.is_empty():
		low = int(cleaned[0])
	world.progress_frac[cell] = low
	if cleaned.size() <= 1:
		if world.progress_frac_high.has(cell):
			world.progress_frac_high.erase(cell)
		return
	var high: Array = []
	for index in range(1, cleaned.size()):
		high.append(int(cleaned[index]))
	world.progress_frac_high[cell] = high


static func _limbs_from_int(value: int) -> Array:
	if value <= 0:
		return [0]
	var limbs: Array = []
	var rest := value
	while rest > 0:
		limbs.append(rest % _LIMB)
		rest /= _LIMB
	return limbs


static func _limbs_as_int(limbs: Array) -> int:
	var value := 0
	var scale := 1
	for index in limbs.size():
		var limb := int(limbs[index])
		if limb < 0 or limb >= _LIMB:
			return -1
		if limb != 0:
			if scale > _I64 / limb:
				return -1
			var add := limb * scale
			if value > _I64 - add:
				return -1
			value += add
		if index + 1 < limbs.size():
			if scale > _I64 / _LIMB:
				return -1
			scale *= _LIMB
	return value


static func _limbs_to_int(limbs: Array) -> int:
	var value := _limbs_as_int(limbs)
	return _I64 if value < 0 else value


static func _pow_small(base: int, exp: int) -> Array:
	var out: Array = [1]
	for _step in exp:
		out = _mul_small(out, base)
	return out


static func _mul_small(limbs: Array, factor: int) -> Array:
	if factor <= 0:
		return [0]
	if factor >= _LIMB:
		return _mul_limbs(limbs, _limbs_from_int(factor))
	var out: Array = []
	var carry := 0
	for limb in limbs:
		var product: int = int(limb) * factor + carry
		out.append(product % _LIMB)
		carry = product / _LIMB
	while carry > 0:
		out.append(carry % _LIMB)
		carry /= _LIMB
	return _trim(out)


static func _mul_limbs(a: Array, b: Array) -> Array:
	if a.is_empty() or b.is_empty() or (a.size() == 1 and int(a[0]) == 0) or (b.size() == 1 and int(b[0]) == 0):
		return [0]
	var out: Array = []
	out.resize(a.size() + b.size())
	for index in out.size():
		out[index] = 0
	for i in a.size():
		var carry := 0
		for j in b.size():
			var product: int = int(out[i + j]) + int(a[i]) * int(b[j]) + carry
			out[i + j] = product % _LIMB
			carry = product / _LIMB
		var k := i + b.size()
		while carry > 0:
			if k == out.size():
				out.append(0)
			var cur: int = int(out[k]) + carry
			out[k] = cur % _LIMB
			carry = cur / _LIMB
			k += 1
	return _trim(out)


static func _add_limbs(a: Array, b: Array) -> Array:
	var count := maxi(a.size(), b.size())
	var out: Array = []
	var carry := 0
	for index in count:
		var total := carry
		if index < a.size():
			total += int(a[index])
		if index < b.size():
			total += int(b[index])
		out.append(total % _LIMB)
		carry = total / _LIMB
	if carry > 0:
		out.append(carry)
	return out


static func _div_small_inplace(limbs: Array, divisor: int) -> int:
	var rem := 0
	for index in range(limbs.size() - 1, -1, -1):
		var cur: int = rem * _LIMB + int(limbs[index])
		limbs[index] = cur / divisor
		rem = cur % divisor
	return rem


static func _divmod_pow4(acc: Array, level: int) -> Array:
	var rem: Array = [0]
	var place: Array = [1]
	for _step in level:
		var digit := _div_small_inplace(acc, 4)
		if digit != 0:
			rem = _add_limbs(rem, _mul_small(place, digit))
		place = _mul_small(place, 4)
	return [_limbs_to_int(_trim(acc)), _trim(rem)]


static func _trim(limbs: Array) -> Array:
	while limbs.size() > 1 and int(limbs[limbs.size() - 1]) == 0:
		limbs.remove_at(limbs.size() - 1)
	if limbs.is_empty():
		return [0]
	return limbs

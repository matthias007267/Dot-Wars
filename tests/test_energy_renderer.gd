extends TestCase

class Sight extends RefCounted:
	var hidden := -1
	func is_visible(_viewer: int, cell: int) -> bool: return cell != hidden

func test_energy_team_buffer_and_visibility_follow_current_physical_dots() -> void:
	var world := WorldState.new(16, 16, 8, Materials.EMPTY)
	var energy := EnergyStore.new()
	for owner in 4: energy.enqueue(32 + owner, 1, owner)
	energy.enqueue(36, 1, EnergyStore.NEUTRAL)
	energy.enqueue(37, 1, 2)
	energy.held_by[5] = 7
	var sight := Sight.new()
	sight.hidden = 35
	var view := EnergyRenderer.new()
	view.world = world
	view.energy = energy
	view.fog = sight
	var before := hash([world.state_hash(), energy.state_hash()])
	view._ready()
	for owner in 3:
		var offset := (32 + owner) * 4
		check_eq(view._bytes[offset], int(MatchRules.FACTION_COLORS[owner].r * 255), "Teamfarbe bleibt erkennbar")
	check_eq(view._bytes[35 * 4 + 3], 0, "verdeckte Energie ohne Sprite und Glow")
	check_eq(view._bytes[36 * 4], 180, "neutrale Energie bleibt grau")
	check_eq(view._bytes[37 * 4 + 2], int(MatchRules.FACTION_COLORS[2].b * 255), "Puffer behält Besitzerfarbe")
	check_eq(hash([world.state_hash(), energy.state_hash()]), before, "Darstellung verändert weder Welt noch Energiebilanz")
	sight.hidden = 32
	view.show_energy()
	check_eq(view._bytes[32 * 4 + 3], 0, "Sichtverlust entfernt Energie sofort")
	check(view._bytes[35 * 4 + 3] > 0, "wieder sichtbare Energie erscheint")
	view.free()

func test_twenty_thousand_dots_share_one_render_cell_without_merging_energy() -> void:
	var energy := EnergyStore.new()
	energy.enqueue(100, 20000, 0)
	var view := EnergyRenderer.new()
	view.world = WorldState.new(16, 16, 8, Materials.EMPTY)
	view.energy = energy
	view._ready()
	check_eq(view._previous.size(), 1, "Renderarbeit zählt belegte Zellen statt mehrfach dieselbe Zelle")
	check_eq(energy.pending(), 20000, "physisch weiterhin 20000 einzelne Punkte")
	view.energy = EnergyStore.new()
	view.show_energy()
	check_eq(view._bytes[100 * 4 + 3], 0, "leere Transportzelle hinterlässt kein Bild")
	view.free()

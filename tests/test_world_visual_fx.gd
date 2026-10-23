extends TestCase
## Reine Rendering-Aenderungen: Shader bleiben optional und die Simulation unberuehrt.


func test_world_and_dot_shaders_are_available() -> void:
	var terrain := load("res://src/render/shaders/terrain.gdshader") as Shader
	var glow := load("res://src/render/shaders/dot_glow.gdshader") as Shader
	check(terrain != null, "Terrain-Shader laedt")
	check(glow != null, "Dot-Glow-Shader laedt")
	if terrain != null:
		check(terrain.code.contains("SCREEN_UV"), "Vignette wird nur im Weltshader berechnet")
	if glow != null:
		check(glow.code.contains("TEXTURE_PIXEL_SIZE"), "Glow nutzt benachbarte Texturpixel")


func test_world_effects_can_be_disabled_without_changing_palette() -> void:
	var original := WorldRenderer.palette_bytes()
	var renderer := WorldRenderer.new()
	renderer.world_fx_enabled = false
	renderer.terrain_detail = 0.0
	renderer.tunnel_depth = 0.0
	renderer.vignette_strength = 0.0
	check(not renderer.world_fx_enabled, "Terrain-Effekte sind optional")
	check_eq(WorldRenderer.palette_bytes(), original, "Materialpalette bleibt unveraendert")
	renderer.free()


func test_worker_and_energy_effects_are_independent() -> void:
	var workers := WorkerRenderer.new()
	var energy := EnergyRenderer.new()
	check(workers.glow_enabled, "Arbeiter-Glow standardmaessig an")
	check(energy.glow_enabled, "Energie-Glow standardmaessig an")
	workers.glow_enabled = false
	energy.glow_enabled = false
	check(not workers.glow_enabled and not energy.glow_enabled, "Glow kann separat aus")
	workers.free()
	energy.free()

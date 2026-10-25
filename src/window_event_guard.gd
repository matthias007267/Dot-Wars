extends Node
## Filter only redundant generic device-tree broadcasts in this game's window.
var backend: RefCounted
var active := false
var self_test := PackedInt64Array()
func _ready() -> void:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless" or "--no-device-change-guard" in OS.get_cmdline_user_args(): return
	backend = preload("res://src/sim/native_search.gd").backend()
	if backend == null or not backend.has_method("device_change_guard"): return
	var result: Variant = backend.device_change_guard(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), true)
	active = result is PackedInt64Array and result.size() == 5 and result[0] == 1
	if active and "--validate-device-guard" in OS.get_cmdline_user_args():
		self_test = backend.device_change_guard_self_test(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))
		result = backend.device_change_guard(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), true)
		active = result is PackedInt64Array and result.size() == 5 and result[0] == 1
func stop() -> PackedInt64Array:
	if not active: return PackedInt64Array()
	active = false
	return backend.device_change_guard(0, false)
func _exit_tree() -> void: stop()

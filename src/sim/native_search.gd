extends RefCounted
## Optionaler nativer Rechenkern. GDScript bleibt ausführbare Referenz/Fallback.
## Keine Spielregel und kein eigener Simulationstakt steckt in diesem Adapter.

static var enabled: bool = true
static var _checked: bool = false
static var _instance: RefCounted


static func backend() -> RefCounted:
	if not enabled or "--no-native" in OS.get_cmdline_user_args():
		return null
	if _instance != null:
		return _instance
	if _checked:
		return null
	_checked = true
	if not ClassDB.class_exists("DotWarsNativeSearch"):
		var binary := "res://native/bin/dot_wars_native.windows.x86_64.v11.dll"
		if OS.get_name() == "Linux":
			binary = "res://native/bin/libdot_wars_native.linux.x86_64.so"
		elif OS.get_name() != "Windows":
			return null
		if not FileAccess.file_exists(binary):
			return null
		GDExtensionManager.load_extension("res://native/dot_wars.gdextension")
	if ClassDB.class_exists("DotWarsNativeSearch"):
		_instance = ClassDB.instantiate("DotWarsNativeSearch") as RefCounted
	return _instance

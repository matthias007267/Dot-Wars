extends SceneTree
## Test-Runner: `godot --headless --path . -s tests/run_tests.gd [-- Filter]`
## Führt alle `tests/test_*.gd` aus. Exit-Code 1 bei Fehlern.

const TEST_DIR := "res://tests"


func _init() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		filter = user_args[0]

	var total_assertions := 0
	var total_tests := 0
	var failures: Array[String] = []
	var files := _test_files()
	for file in files:
		if not filter.is_empty() and not file.contains(filter):
			continue
		var path := "%s/%s" % [TEST_DIR, file]
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			failures.append("%s: Testskript konnte nicht geladen werden (Syntaxfehler?)" % file)
			continue
		var suite := script.new() as TestCase
		if suite == null:
			failures.append("%s: Testskript ist keine TestCase-Suite" % file)
			continue
		for method in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			suite.begin_test("%s::%s" % [file.get_basename(), method_name])
			var started := Time.get_ticks_msec()
			var before := suite.failures.size()
			var assertions_before := suite.assertion_count
			suite.call(method_name)
			total_tests += 1
			if suite.assertion_count == assertions_before:
				suite.failures.append("%s: keine Prüfung ausgeführt (Skriptfehler?)" % method_name)
			var status := "ok  " if suite.failures.size() == before else "FAIL"
			print("[%s] %s::%s (%d ms)" % [status, file.get_basename(), method_name, Time.get_ticks_msec() - started])
		total_assertions += suite.assertion_count
		failures.append_array(suite.failures)

	print("")
	print("%d Tests, %d Prüfungen, %d Fehler" % [total_tests, total_assertions, failures.size()])
	for failure in failures:
		printerr("  FEHLER ", failure)
	quit(1 if not failures.is_empty() or total_tests == 0 else 0)


func _test_files() -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd"):
			result.append(file)
	result.sort()
	return result

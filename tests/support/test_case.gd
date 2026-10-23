class_name TestCase
extends RefCounted
## Basisklasse für Tests. Methoden mit Präfix `test_` werden vom Runner ausgeführt.

var failures: Array[String] = []
var assertion_count: int = 0
var _current_test: String = ""


func check(condition: bool, message: String = "") -> void:
	assertion_count += 1
	if not condition:
		failures.append("%s: %s" % [_current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertion_count += 1
	if actual != expected:
		failures.append("%s: %s (erwartet %s, erhalten %s)" % [_current_test, message, str(expected), str(actual)])


func check_no_errors(errors: PackedStringArray, message: String = "") -> void:
	assertion_count += 1
	if not errors.is_empty():
		failures.append("%s: %s %s" % [_current_test, message, ", ".join(errors)])


func begin_test(test_name: String) -> void:
	_current_test = test_name

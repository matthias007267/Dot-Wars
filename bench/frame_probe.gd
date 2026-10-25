extends Node
## Diagnostic only. Splits consecutive main-loop frames around render signals.
class LateProbe:
	extends Node
	var owner_probe: Node
	func _process(_delta: float) -> void: owner_probe.nodes_end = Time.get_ticks_usec()

var app: Node
var frame_start := 0
var nodes_end := 0
var pre_draw := 0
var post_draw := 0
var seen := 0
var spikes: Array[Dictionary] = []
var script_ms := PackedFloat64Array()
var draw_ms := PackedFloat64Array()
var gap_ms := PackedFloat64Array()
var trace_backend: RefCounted
var max_gpu_ms := 0.0
var max_render_cpu_ms := 0.0

func _ready() -> void:
	process_priority = -10000
	if "--trace-window" in OS.get_cmdline_user_args():
		trace_backend = preload("res://src/sim/native_search.gd").backend()
		if trace_backend != null and trace_backend.has_method("trace_window"):
			trace_backend.trace_window(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE), true)
	var late := LateProbe.new()
	late.owner_probe = self
	late.process_priority = 10000
	add_child(late)
	RenderingServer.frame_pre_draw.connect(_pre)
	RenderingServer.frame_post_draw.connect(_post)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

func _pre() -> void: pre_draw = Time.get_ticks_usec()
func _post() -> void: post_draw = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if frame_start > 0 and nodes_end >= frame_start:
		var scripts := (nodes_end - frame_start) / 1000.0
		var draw := (post_draw - pre_draw) / 1000.0 if pre_draw >= frame_start and post_draw >= pre_draw else 0.0
		var after_nodes := (now - nodes_end) / 1000.0
		var tail := (now - post_draw) / 1000.0 if post_draw >= frame_start else after_nodes
		script_ms.append(scripts)
		draw_ms.append(draw)
		gap_ms.append(tail)
		seen += 1
		var rid := get_viewport().get_viewport_rid()
		max_gpu_ms = maxf(max_gpu_ms, RenderingServer.viewport_get_measured_render_time_gpu(rid))
		max_render_cpu_ms = maxf(max_render_cpu_ms, RenderingServer.viewport_get_measured_render_time_cpu(rid))
		if now - frame_start > 50000 and spikes.size() < 100:
			spikes.append({"frame_ms": (now - frame_start) / 1000.0, "script_ms": scripts,
				"draw_signal_ms": draw, "after_nodes_ms": after_nodes, "after_draw_ms": tail,
				"pre_draw_gap_ms": (pre_draw - nodes_end) / 1000.0 if pre_draw >= nodes_end else 0,
				"app_ms": app.last_app_process_usec / 1000.0, "tick_ms": app.sim.last_tick_usec / 1000.0})
	frame_start = now

func summary() -> Dictionary:
	var messages: Array[Dictionary] = []
	if trace_backend != null and trace_backend.has_method("trace_window"):
		var raw: Variant = trace_backend.trace_window(0, false)
		if raw is PackedInt64Array:
			for index in range(0, raw.size(), 5):
				messages.append({"message": raw[index], "event": raw[index + 1], "calls": raw[index + 2], "total_ms": raw[index + 3] / 1000.0, "max_ms": raw[index + 4] / 1000.0})
	return {"device_guard_self_test": app.device_guard.self_test if app.device_guard != null else PackedInt64Array(), "device_guard": trace_backend.device_change_guard(0, false) if trace_backend != null and trace_backend.has_method("device_change_guard") else PackedInt64Array(), "window_messages": messages, "frames": seen, "max_script_ms": _max(script_ms), "max_draw_signal_ms": _max(draw_ms),
		"max_tail_ms": _max(gap_ms), "max_gpu_reported_ms": max_gpu_ms,
		"max_render_cpu_reported_ms": max_render_cpu_ms, "spikes": spikes}

func _max(values: PackedFloat64Array) -> float:
	var result := 0.0
	for value in values: result = maxf(result, value)
	return result

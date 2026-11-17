extends Node
class_name PocketSessionDiagnostics

# Small persistent breadcrumb for Android's game subprocess. Android can kill
# the game without producing a GDScript error or invoking _exit_tree().
const TRACE_PATH := "user://pocket_district_last_session.json"
const SNAPSHOT_PERIOD := 5.0

var elapsed_seconds: float = 0.0
var snapshot_clock: float = 0.0
var previous: Dictionary = {}
var previous_unexpected: bool = false
var game: Node


func _ready() -> void:
	previous = read_snapshot()
	previous_unexpected = String(previous.get("state", "")) == "running"
	if previous_unexpected:
		print("POCKET DISTRICT PREVIOUS SESSION UNEXPECTEDLY ENDED: ", JSON.stringify(previous))
	else:
		print("POCKET DISTRICT PREVIOUS SESSION: ", String(previous.get("state", "no history")))
	write_snapshot("running")


func _process(delta: float) -> void:
	elapsed_seconds += delta
	snapshot_clock += delta
	if snapshot_clock >= SNAPSHOT_PERIOD:
		snapshot_clock = 0.0
		write_snapshot("running")


func _exit_tree() -> void:
	write_snapshot("closed")


func read_snapshot() -> Dictionary:
	if not FileAccess.file_exists(TRACE_PATH):
		return {}
	var file := FileAccess.open(TRACE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func write_snapshot(state: String) -> void:
	var memory_mb := int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	var scene_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var snapshot := {
		"state": state,
		"seconds": snappedf(elapsed_seconds, 0.1),
		"memory_mb": memory_mb,
		"nodes": scene_nodes,
		"draw_calls": draw_calls,
		"platform": OS.get_name(),
		"fps": Engine.get_frames_per_second(),
		"renderer": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"editor_embed_note": "Try Game > Game Embed Mode > Disabled on Android editor"
	}
	if is_instance_valid(game):
		snapshot["wanted"] = int(game.get("wanted"))
		snapshot["indoors"] = bool(game.get("indoors"))
		snapshot["police"] = game.get("city").police_root.get_child_count()
	var file := FileAccess.open(TRACE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(snapshot))
	file.flush()
	file.close()


func previous_summary() -> String:
	if not previous_unexpected:
		return ""
	return "前回: %.0f秒で中断 / メモリ %dMB / ノード %d" % [
		float(previous.get("seconds", 0.0)),
		int(previous.get("memory_mb", 0)),
		int(previous.get("nodes", 0))
	]

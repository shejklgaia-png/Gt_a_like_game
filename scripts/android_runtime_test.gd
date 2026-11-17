extends SceneTree
# Run Android-only game initialization on Linux CI to test its GDScript paths.
const SessionDiagnostics = preload("res://scripts/session_diagnostics.gd")

func _initialize() -> void:
	call_deferred("exercise_mobile_startup")

func failed(reason: String, exit_code: int) -> void:
	push_error(reason)
	quit(exit_code)

func exercise_mobile_startup() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		failed("Mobile startup scene failed to load", 101)
		return
	var game = scene.instantiate()
	game.mobile_optimization_enabled = true
	game.save_path_override = "user://pocket_district_android_runtime_test.json"
	root.add_child(game)
	await process_frame
	if not is_instance_valid(game.session_diagnostics):
		failed("Android session diagnostics did not start", 102)
		return
	var diagnostics: PocketSessionDiagnostics = game.session_diagnostics
	var saved: Dictionary = diagnostics.read_snapshot()
	if saved.get("state", "") != "running":
		failed("Android diagnostic state was not persisted", 103)
		return
	if int(saved.get("nodes", 0)) < 100:
		failed("Android diagnostics did not capture loaded scene nodes", 104)
		return
	if game.city.people.size() != 46:
		failed("Android optimization unexpectedly removed the town population", 105)
		return
	for i in range(6):
		await process_frame
	diagnostics.write_snapshot("running")
	saved = diagnostics.read_snapshot()
	if String(saved.get("platform", "")) == "" or not saved.has("memory_mb"):
		failed("Android diagnostics did not capture platform/memory", 106)
		return
	# Do not force-delete our own diagnostic file; closing the scene should mark
	# it closed through _exit_tree(), which is also part of our regression checks.
	root.remove_child(game)
	game.free()
	saved = diagnostics.read_snapshot() if is_instance_valid(diagnostics) else SessionDiagnostics.new().read_snapshot()
	if String(saved.get("state", "")) != "closed":
		failed("Gracefully leaving game did not close the diagnostic session", 107)
		return
	print("PASS: Android-only startup, mobile LOD, 5-second diagnostic schema and graceful shutdown")
	quit(0)

extends SceneTree
## Regression test for long sessions, autosave, audio voice pressure and scene growth.

const SafeSave = preload("res://scripts/safe_save.gd")

func _initialize() -> void:
	call_deferred("run_stability")


func fail(reason: String, code: int) -> void:
	push_error(reason)
	quit(code)


func run_stability() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		fail("Stability test scene could not be loaded", 80)
		return
	var game = scene.instantiate()
	game.save_path_override = "user://pocket_district_stability_test.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	# Keep an existing save used by other tests or local development untouched.
	var start_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if start_nodes < 500:
		fail("Expected populated 3D world at stability test start", 81)
		return
	if game.city.people.size() != 46 or game.sound == null:
		fail("Population or audio service missing", 82)
		return
	# This used to produce 46 get_global_transform errors during pre-parent setup.
	for person in game.city.people:
		if not person.is_inside_tree() or person.target == Vector3.ZERO:
			fail("Civilian route was not initialized after scene attachment", 83)
			return
	# 200 rapid sound requests must not allocate an unlimited number of players.
	for i in range(200):
		game.sound.play_ui("ui")
	if game.sound.one_shot_voice_count() > game.sound.MAX_ONE_SHOT_VOICES:
		fail("Transient audio node cap was exceeded", 84)
		return
	# Exercise the usual 18-second autosave multiple times without replacing
	# an existing player's save data. Explicit save writes also exercise backup rotation.
	for i in range(3):
		game.autosave_clock = 18.1
		await process_frame
		await process_frame
		var data: Dictionary = SafeSave.load_json(game.SAVE_PATH)
		if data.is_empty() or not data.has("residents") or int(data.get("version", 0)) != 2:
			fail("Repeated autosaves did not preserve game state", 85)
			return
	# Stress a civilian death and 8-second delayed replacement as well.
	var resident: PocketActor = game.city.people[4]
	resident.hit(200.0)
	game.wanted = 0
	# Run past the natural autosave deadline and the delayed respawn timer.
	for frame in range(1350):
		await physics_frame
		if frame % 300 == 0 and game.sound.one_shot_voice_count() > game.sound.MAX_ONE_SHOT_VOICES:
			fail("One-shot voice count increased beyond its cap", 86)
			return
	if not is_instance_valid(game.city.people[4]) or game.city.people[4].dead:
		fail("Civilian was not replaced after delayed cleanup", 87)
		return
	if game.city.people[4].resident_id != 4:
		fail("Respawn did not retain the resident slot identity", 88)
		return
	var final_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if final_nodes > start_nodes + 100:
		fail("Scene node count grew over an idle session: %d -> %d" % [start_nodes, final_nodes], 89)
		return
	if game.sound.one_shot_voice_count() > game.sound.MAX_ONE_SHOT_VOICES:
		fail("Audio players were not bounded in the long session", 90)
		return
	print("PASS: 1,350 physics frames, 3 autosaves, resident respawn, sound-voice cap, node-count guard")
	quit(0)

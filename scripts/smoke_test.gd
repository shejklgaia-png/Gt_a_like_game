extends SceneTree

func _initialize() -> void:
	call_deferred("run_smoke")


func run_smoke() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("Failed to load starting scene")
		quit(1)
		return
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var town := game.get_node_or_null("OutdoorWorld") as PocketCity
	var hero := game.get_node_or_null("Player") as PocketHero
	var inside := game.get_node_or_null("IndoorWorld") as PocketInterior
	if town == null or hero == null or inside == null:
		push_error("Core world nodes failed to initialize")
		quit(2)
		return
	if town.buildings.size() != 36 or town.cars.size() != 18 or town.people.size() != 46:
		push_error("Generated city counts are incorrect")
		quit(3)
		return
	var lot: Dictionary = town.buildings[0]
	var layout: Dictionary = PocketInterior.make_layout(String(lot["id"]))
	inside.display_layout(String(lot["id"]), layout)
	if not inside.exit_near(PocketInterior.INTERIOR_ORIGIN + Vector3(0, 0, 7.6)):
		push_error("Interior exit interaction is invalid")
		quit(4)
		return
	if game.selected_gun()["id"] != "Handgun":
		push_error("Expected starter handgun")
		quit(5)
		return
	# Exercise camera orbit and articulated weapon variants.
	var first_yaw: float = game.camera_yaw
	game.rotate_camera(Vector2(50, -25))
	if absf(float(game.camera_yaw) - first_yaw) < 0.1:
		push_error("Camera orbit controls did not change yaw")
		quit(6)
		return
	for gun_name in ["Handgun", "Rifle", "Shotgun", "Sniper", "Machine Gun"]:
		hero.equip_weapon(gun_name)
		if hero.weapon_kind != gun_name or hero.muzzle == null or not is_instance_valid(hero.muzzle):
			push_error("Weapon model or muzzle marker invalid for " + gun_name)
			quit(7)
			return
	hero.equip_weapon("Handgun")
	# Citizens must be placed alongside roads, never randomly in a roadway.
	for citizen in town.people:
		if citizen.sidewalk_axis == 0:
			if absf(citizen.position.x - citizen.anchor.x) > 0.15:
				push_error("Pedestrian has left its marked sidewalk corridor")
				quit(8)
				return
		elif absf(citizen.position.z - citizen.anchor.z) > 0.15:
			push_error("Pedestrian has left its marked sidewalk corridor")
			quit(8)
			return
	# NPCs fall before they are removed; police have a separate baton action.
	var first_citizen: PocketActor = town.people[0]
	first_citizen.hit(250)
	if not first_citizen.dead:
		push_error("NPC death animation state did not activate")
		quit(9)
		return
	var police: PocketActor = town.add_police_near(hero.global_position, 999)
	if not police.officer or not police.has_method("try_baton_attack"):
		push_error("Police melee equipment not initialized")
		quit(10)
		return
	var car: PocketVehicle = town.cars[0]
	car.open_driver_door(true)
	if not car.door_open:
		push_error("Car takeover door animation flag failed")
		quit(11)
		return
	# Regression: civilian collision masks must ignore other civilians and vehicles.
	# Actors remain hittable via layer 2 and collide with the continuous world on layer 1.
	for citizen in town.people:
		if citizen.collision_layer != 2 or (citizen.collision_mask & 2) != 0 or (citizen.collision_mask & 8) != 0:
			push_error("Civilian crowd collision layers can recreate crosswalk jams")
			quit(12)
			return
	if hero.collision_mask != 11 or town.cars[0].collision_mask != 15:
		push_error("Hero/vehicle collision masks are inconsistent")
		quit(13)
		return
	# Regression: previously raised solid sidewalk prevented hero moving out of the road.
	# Check all building foundation pads are non-solid, not just a single intersection.
	for building in town.buildings:
		var center: Vector3 = building["position"]
		var pavement := false
		for child in town.get_children():
			if child is Node3D and child.position.distance_to(Vector3(center.x, 0.026, center.z)) < 0.02:
				if child is StaticBody3D:
					push_error("Raised sidewalk still blocks player and NPCs")
					quit(14)
					return
				pavement = true
		if not pavement:
			push_error("Walkable sidewalk visuals were removed")
			quit(15)
			return
	# Put the player at a roadway curb and walk toward the sidewalk while the game runs.
	hero.global_position = Vector3(4.15, 0.20, 16.0)
	hero.velocity = Vector3.ZERO
	game.camera_yaw = 0.0
	game.camera.global_position = hero.global_position + Vector3(0.0, 7.0, 5.0)
	game.camera.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0))
	game.stick_value = Vector2(1.0, 0.0)
	for frame in range(36):
		await physics_frame
	game.stick_value = Vector2.ZERO
	if hero.global_position.x < 5.5:
		push_error("Player cannot cross roadway to sidewalk: pos=%s, velocity=%s, camera_right=%s, slide=%d" % [str(hero.global_position), str(hero.velocity), str(game.camera.global_transform.basis.x), hero.get_slide_collision_count()])
		quit(16)
		return
	# A stopped pedestrian must be able to reroute instead of standing forever.
	var walker: PocketActor = town.people[4]
	walker.stalled_time = 1.9
	walker.previous_distance = INF
	walker.target = walker.position + Vector3(0, 0, 15.0) if walker.sidewalk_axis == 0 else walker.position + Vector3(15.0, 0, 0)
	for tick in range(4):
		await physics_frame
	if walker.stalled_time > 1.8:
		push_error("Stalled pedestrians are not recalculating waypoints")
		quit(17)
		return
	# Validate the new generated assets and control modules.
	if game.sound == null or game.sound.sounds.size() < 12:
		push_error("Procedural sound library is not generated")
		quit(18)
		return
	if game.minimap == null or game.settings_panel == null or game.reload_button == null:
		push_error("Minimap/settings/reload HUD missing")
		quit(19)
		return
	if town.get_node_or_null("TrafficLights") == null:
		push_error("Traffic signals not spawned")
		quit(20)
		return
	# Buying, reloading, receiving an order, and persistence should work.
	game.ammunition["Handgun"] = 75
	game.loaded_rounds["Handgun"] = 0
	game.reload_gun()
	if game.reload_weapon_id != "Handgun" or game.reload_clock <= 0.0:
		push_error("Reload state did not start")
		quit(21)
		return
	game.finish_reload()
	if int(game.loaded_rounds["Handgun"]) != 15 or int(game.ammunition["Handgun"]) != 60:
		push_error("Reload did not move magazine rounds from reserves")
		quit(22)
		return
	game.mission_stage = 0
	game.advance_delivery()
	if game.mission_stage != 1 or game.mission_limit <= 0 or game.mission_reward <= 0:
		push_error("Delivery order did not initialize correctly")
		quit(23)
		return
	game.save_game()
	var state: Dictionary = load("res://scripts/safe_save.gd").load_json(game.SAVE_PATH)
	if int(state.get("mission_stage", -1)) != 1 or int(state.get("version", 0)) < 2:
		push_error("Versioned mission save/load is incorrect")
		quit(24)
		return
	# Every resident has a stable identity and a fully connected, finite dialogue tree.
	var dialogue_library = load("res://scripts/resident_dialogue.gd")
	for resident_index in range(town.people.size()):
		var civilian: PocketActor = town.people[resident_index]
		if civilian.resident_id != resident_index:
			push_error("Resident identity is not stable for slot %d" % resident_index)
			quit(27)
			return
		var resident_profile: Dictionary = dialogue_library.make_profile(resident_index)
		for talk_index in range(3):
			var branches: Dictionary = dialogue_library.make_tree(resident_profile, talk_index)
			if not dialogue_library.is_valid_tree(branches):
				push_error("Broken dialogue branches for resident %d, visit %d" % [resident_index, talk_index])
				quit(28)
				return
	# A complete conversation must reach its ending and persist only that resident's affinity.
	var speaker: PocketActor = town.people[2]
	game.resident_relations.erase(str(speaker.resident_id))
	game.wanted = 0 # A previous combat regression test deliberately raised the wanted level.
	hero.global_position = speaker.global_position + Vector3(0, 0, 1.0)
	game.begin_conversation(speaker)
	if not speaker.chatting or not game.dialogue_panel.visible or game.conversation_node != "start":
		push_error("Conversation panel failed to open")
		quit(29)
		return
	var opening_options: Array = game.conversation_tree["nodes"]["start"]["choices"]
	var first_option: Dictionary = opening_options[0]
	game.select_conversation_option(0)
	if game.conversation_node != String(first_option["next"]):
		push_error("Dialogue did not enter its randomly selected branch")
		quit(30)
		return
	game.select_conversation_option(0)
	game.select_conversation_option(0)
	game.select_conversation_option(0)
	if game.conversation_node != "friendly_bye":
		push_error("Dialogue could not reach its expected ending")
		quit(31)
		return
	var relationship: Dictionary = game.resident_relations.get(str(speaker.resident_id), {})
	if int(relationship.get("talks", 0)) != 1 or int(relationship.get("affinity", 0)) != 4 + int(first_option["affinity"]):
		push_error("Resident relationship did not follow selected answers")
		quit(32)
		return
	game.end_conversation()
	if speaker.chatting or game.dialogue_panel.visible:
		push_error("Conversation failed to release civilian movement and UI")
		quit(33)
		return
	var saved_chat: Dictionary = load("res://scripts/safe_save.gd").load_json(game.SAVE_PATH)
	if not saved_chat.get("residents", {}).has(str(speaker.resident_id)):
		push_error("Resident relationships were not saved")
		quit(34)
		return
	game.toggle_settings()
	if not game.settings_panel.visible or not paused:
		push_error("Pause panel failed to suspend gameplay")
		quit(25)
		return
	game.toggle_settings()
	if game.settings_panel.visible or paused:
		push_error("Pause panel failed to resume gameplay")
		quit(26)
		return
	print("PASS: traffic lights, synthesized audio, minimap, pausing, weapon reloading, mission timer and saved state")
	print("PASS: sidewalks navigable; pedestrians ignore crowd/vehicle collisions and recover stalled routes")
	quit(0)

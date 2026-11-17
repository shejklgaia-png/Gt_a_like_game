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
	# The new perimeter and elevated freeway lie beyond the old |x,z|<120
	# save bounds. Both exterior ground and elevated positions must round-trip.
	var initial_position: Vector3 = hero.global_position
	game.save_path_override = "user://pocket_district_outer_route_test.json"
	for saved_point in [Vector3(128.0, 0.3, 90.0), Vector3(0.0, 7.3, 137.0)]:
		hero.global_position = saved_point
		game.save_game()
		hero.global_position = Vector3(18.0, 0.3, -34.0)
		game.load_game()
		if hero.global_position.distance_to(saved_point) > 0.02:
			push_error("Outer route or freeway save position did not round-trip: %s" % str(saved_point))
			quit(73)
			return
	game.save_path_override = ""
	hero.global_position = initial_position
	# The destination compass uses projected camera axes, not world east/north.
	var camera_right: Vector3 = game.camera.global_transform.basis.x
	var camera_up: Vector3 = game.camera.global_transform.basis.y
	if game.waypoint_arrow(Vector3(camera_right.x, 0, camera_right.z) * 10.0) != "→":
		push_error("Waypoint arrow does not align with screen right")
		quit(74)
		return
	if game.waypoint_arrow(Vector3(camera_up.x, 0, camera_up.z) * 10.0) != "↑":
		push_error("Waypoint arrow does not align with screen up")
		quit(75)
		return
	# The 2,000 configurations contain no stock dialogue joins: spoken text
	# must be made solely from a topic's individually authored paragraphs.
	var dialogue_library = load("res://scripts/resident_dialogue.gd")
	if not dialogue_library.is_valid_catalog() or dialogue_library.CONVERSATION_COUNT != 2000:
		push_error("The 200 subject catalog is incomplete")
		quit(35)
		return
	var seen_scenarios: Dictionary = {}
	var genre_counts: Dictionary = {}
	var first_profile: Dictionary = dialogue_library.make_profile(0)
	for visit in range(2000):
		var graph: Dictionary = dialogue_library.make_tree(first_profile, visit)
		if not dialogue_library.is_valid_tree(graph):
			push_error("Dialogue uses a mismatched, generic or invalid line at variant %d" % visit)
			quit(36)
			return
		var scenario: int = int(graph.get("scenario_id", -1))
		if seen_scenarios.has(scenario) or scenario < 0 or scenario >= 2000:
			push_error("Conversation permutation repeated prematurely at %d" % visit)
			quit(37)
			return
		seen_scenarios[scenario] = true
		genre_counts[String(graph.get("genre", ""))] = true
	if seen_scenarios.size() != 2000 or genre_counts.size() != 25:
		push_error("Conversation catalog does not cover all 2,000 openings / 25 genres")
		quit(38)
		return
	for resident_index in range(town.people.size()):
		var civilian: PocketActor = town.people[resident_index]
		if civilian.resident_id != resident_index:
			push_error("Resident identity did not match citizen slot %d" % resident_index)
			quit(27)
			return
		var profile: Dictionary = dialogue_library.make_profile(resident_index)
		for talk_index in range(3):
			if not dialogue_library.is_valid_tree(dialogue_library.make_tree(profile, talk_index)):
				push_error("Invalid topic for resident %d visit %d" % [resident_index, talk_index])
				quit(28)
				return
	# Explore every unique piece of specialist knowledge in a single encounter.
	var speaker: PocketActor = town.people[2]
	game.resident_relations.erase(str(speaker.resident_id))
	game.wanted = 0
	hero.global_position = speaker.global_position + Vector3(0, 0, 1.0)
	game.begin_conversation(speaker)
	if not speaker.chatting or not game.dialogue_panel.visible or game.conversation_node != "start":
		push_error("Dialogue did not start")
		quit(29)
		return
	if game.dialogue_scroll == null or game.dialogue_next == null:
		push_error("Dialogue scroll or next-topic control is missing")
		quit(39)
		return
	var initial_graph: Dictionary = game.conversation_tree
	var authorial_text: String = String(initial_graph["nodes"]["start"]["text"])
	if game.dialogue_text.text != authorial_text:
		push_error("Text was rewritten with a stock connector or non-authored message")
		quit(40)
		return
	var first_count: int = game.conversation_displayed_options.size()
	if first_count < 2 or first_count > 4:
		push_error("Opening does not expose valid nonrepeating choices")
		quit(41)
		return
	var expected_first: String = String(game.conversation_displayed_options[0]["next"])
	game.select_conversation_option(0)
	if game.conversation_node != expected_first:
		push_error("Dialogue did not follow the chosen topic-specific path")
		quit(30)
		return
	var knowledge: Dictionary = dialogue_library.catalog()[int(initial_graph["scenario_id"]) / 10]
	if game.dialogue_text.text != String(knowledge[expected_first]):
		push_error("Specialist passage is not the authored subject text")
		quit(42)
		return
	# Consume all remaining unique branches, never repeating a paragraph.
	var chosen: Dictionary = {expected_first: true}
	for branch_index in range(4):
		if game.conversation_displayed_options.is_empty():
			break
		var next_branch: String = String(game.conversation_displayed_options[0]["next"])
		if chosen.has(next_branch):
			push_error("Repeated an already-spoken specialist paragraph")
			quit(43)
			return
		game.select_conversation_option(0)
		if game.dialogue_text.text != String(knowledge[next_branch]):
			push_error("Branch contained a generic connecting sentence")
			quit(44)
			return
		chosen[next_branch] = true
	if not game.conversation_displayed_options.is_empty():
		push_error("Visited specialist topics are still offered as new content")
		quit(45)
		return
	var opened: Dictionary = {int(game.conversation_tree["scenario_id"]): true}
	# No turn limit, no filler on the transitions, bounded per-topic memory.
	for transition in range(80):
		game.continue_conversation()
		if game.conversation_node != "start":
			push_error("Conversation stopped during subject transition %d" % transition)
			quit(46)
			return
		var scenario_num: int = int(game.conversation_tree["scenario_id"])
		if opened.has(scenario_num):
			push_error("Repeated a scenario before exhausting the library")
			quit(47)
			return
		opened[scenario_num] = true
		if not dialogue_library.is_valid_tree(game.conversation_tree):
			push_error("Unattributed text was used while switching topics")
			quit(48)
			return
		if not game.conversation_displayed_options.is_empty():
			var target: String = String(game.conversation_displayed_options[0]["next"])
			game.select_conversation_option(0)
			var current_topic: Dictionary = dialogue_library.catalog()[scenario_num / 10]
			if game.dialogue_text.text != String(current_topic[target]):
				push_error("Dialogue contained a template filler after switching topics")
				quit(49)
				return
	var relationship: Dictionary = game.resident_relations[str(speaker.resident_id)]
	if int(relationship.get("talks", -1)) != 1 or int(relationship.get("topics_seen", -1)) != 81:
		push_error("Long conversation changed the resident's meeting count or topic cursor")
		quit(50)
		return
	game.end_conversation()
	if speaker.chatting or game.dialogue_panel.visible:
		push_error("Conversation failed to close correctly")
		quit(33)
		return
	game.begin_conversation(speaker)
	if not game.dialogue_panel.visible or game.conversation_node != "start":
		push_error("Could not talk to the same resident again")
		quit(51)
		return
	game.end_conversation()
	var saved_chat: Dictionary = load("res://scripts/safe_save.gd").load_json(game.save_destination())
	var saved_relation: Dictionary = saved_chat.get("residents", {}).get(str(speaker.resident_id), {})
	if int(saved_relation.get("topics_seen", -1)) != 82 or int(saved_relation.get("talks", -1)) != 2:
		push_error("Long authored conversation was not saved")
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

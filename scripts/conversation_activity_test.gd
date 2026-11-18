extends SceneTree
## Dialogue -> gameplay integration including save compatibility and one-time
## rewards. Dedicated user:// file prevents modifying a real player's save.

const Dialogue = preload("res://scripts/resident_dialogue.gd")


func _initialize() -> void:
	call_deferred("check")


func fail(message: String, code: int) -> void:
	push_error(message)
	quit(code)


func check() -> void:
	print("ACTIVITY QA: begin")
	var save_path := "user://pocket_conversation_activity_qa.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		fail("Conversation activity test scene unavailable", 451)
		return
	var game = scene.instantiate()
	game.save_path_override = save_path
	root.add_child(game)
	print("ACTIVITY QA: scene added")
	await process_frame
	await physics_frame
	print("ACTIVITY QA: after first frames")
	if not Dialogue.is_valid_catalog():
		fail("Existing 200 authored conversation subjects were modified", 452)
		return
	var activities: PocketConversationActivities = game.conversation_activities
	if not is_instance_valid(activities) or activities.TYPES.size() != 7:
		fail("Seven independently playable resident activities are missing", 453)
		return
	if activities.active or activities.total_completed != 0:
		fail("Fresh save must not have a pending conversation activity", 454)
		return
	print("ACTIVITY QA: catalog and manager")
	var kinds: Dictionary = {}
	for resident in game.city.people:
		if not is_instance_valid(resident):
			continue
		var sample: Dictionary = Dialogue.make_profile(resident.resident_id)
		var scenario: int = Dialogue.scenario_id(sample, 0)
		var proposals: Array[Dictionary] = activities.offers_for(resident.resident_id, resident.daily_role, scenario)
		if proposals.size() != 2 or String(proposals[0]["id"]) == String(proposals[1]["id"]):
			fail("Resident %d did not have two unique activity offers" % resident.resident_id, 455)
			return
		for offer in proposals:
			kinds[String(offer["id"])] = true
	if kinds.size() < 5:
		fail("NPC roles/topics do not vary conversation activities sufficiently", 456)
		return

	print("ACTIVITY QA: 46 offers inspected")
	var giver: PocketActor = game.city.people[0]
	game.hero.global_position = giver.global_position + Vector3(0.4, 0, 0.3)
	print("ACTIVITY QA: about to open dialogue")
	game.begin_conversation(giver)
	if not game.dialogue_panel.visible or game.dialogue_activity_offers.size() != 2:
		fail("Opening a resident dialogue did not expose activity alternatives", 457)
		return
	if game.dialogue_activity_buttons.size() != 2 or not game.dialogue_activity_buttons[0].visible:
		fail("Activity choices are not touch-selectable", 458)
		return
	print("ACTIVITY QA: dialogue opened")
	var spoken: String = game.dialogue_text.text
	var original_tree: Dictionary = game.conversation_tree
	if spoken != String(original_tree["nodes"]["start"]["text"]) or not Dialogue.is_valid_tree(original_tree):
		fail("Activity UI modified the author's unique spoken paragraphs", 459)
		return
	if game.dialogue_recommend_button == null or not game.dialogue_recommend_button.visible:
		fail("Resident conversation has no route into pre-existing city services", 482)
		return
	if game.dialogue_panel.find_children("*", "ScrollContainer", true, false).size() < 2:
		fail("Mobile dialogue and activity choices are not vertically scrollable", 460)
		return
	# Normal click on the activity offer, not a direct model call.
	var proposed: Dictionary = game.dialogue_activity_offers[0].duplicate(true)
	var initial_cash: int = game.cash
	var initial_earnings: int = game.total_earnings
	var previous_affinity: int = int(game.resident_relations.get(str(giver.resident_id), {}).get("affinity", 0))
	print("ACTIVITY QA: before accept")
	game.dialogue_activity_buttons[0].pressed.emit()
	print("ACTIVITY QA: after accept")
	if game.dialogue_panel.visible or not activities.active or activities.giver_id != giver.resident_id:
		fail("Activity offer did not close dialogue and create a real mission", 461)
		return
	if game.navigation_kind != "activity" or game.city_waypoint_point().distance_to(activities.objective_position()) > 0.1:
		fail("Accepted conversation activity is not tracked by CITY GPS", 462)
		return
	if game.cash != initial_cash:
		fail("Activity paid cash without performing any tasks", 463)
		return
	print("ACTIVITY QA: before phone")
	game.city_phone.open_phone()
	game.city_phone.open_page("仕事")
	var phone_found := false
	for entry in game.city_phone.entries.get_children():
		if entry is Button and String(entry.text).contains("住民の活動"):
			phone_found = true
	if not phone_found:
		fail("The new activity is not reachable via CITY jobs menu", 464)
		return
	game.city_phone.close_phone()
	print("ACTIVITY QA: phone closed")
	if paused:
		fail("Closing CITY phone after accepting activity left the city paused", 465)
		return

	# Save mid-route and reload; step and the giver must survive.
	game.save_game()
	print("ACTIVITY QA: before state reset")
	activities.restore({})
	if activities.active:
		fail("Regression harness could not reset temporary activity state", 466)
		return
	print("ACTIVITY QA: before load")
	game.load_game()
	print("ACTIVITY QA: after load")
	if not activities.active or activities.giver_id != giver.resident_id or activities.kind != String(proposed["id"]):
		fail("Mid-activity save/load did not restore assigned NPC, type and progress", 467)
		return

	if activities.kind == "meet":
		# The second person must actually be spoken to. Merely approaching
		# them cannot finish an introduction or hand out an easy reward.
		var friend_id: int = activities.target_resident_id()
		if friend_id < 0 or friend_id == giver.resident_id:
			fail("Social introduction points back to the same resident", 468)
			return
		var peer: PocketActor = game.city.people[friend_id]
		game.hero.global_position = peer.global_position + Vector3(0.3, 0, 0.3)
		game.begin_conversation(peer)
		if activities.active or game.cash != initial_cash + int(proposed["reward"]):
			fail("Introduction did not finish through the second NPC's dialogue", 469)
			return
		game.end_conversation()
	else:
		var first_site: Vector3 = activities.objective_position()
		game.hero.global_position = first_site + Vector3(0, 0.3, 0)
		print("ACTIVITY QA: before site ACTION")
		game.interaction()
		print("ACTIVITY QA: after site ACTION")
		if not activities.active or activities.step_index != 1 or game.cash != initial_cash:
			fail("First ACTION must advance the resident's two-site errand without paying", 470)
			return
		var second_site: Vector3 = activities.objective_position()
		if first_site.distance_to(second_site) < 3.0 or game.city_waypoint_point().distance_to(second_site) > 0.1:
			fail("Conversation errand did not update to its distinct second waypoint", 471)
			return
		game.save_game()
		print("ACTIVITY QA: before state reset")
	activities.restore({})
		print("ACTIVITY QA: before load")
	game.load_game()
	print("ACTIVITY QA: after load")
		if activities.step_index != 1 or not activities.active:
			fail("The second activity stage was lost after save/reload", 472)
			return
		game.hero.global_position = second_site + Vector3(0, 0.3, 0)
		print("ACTIVITY QA: before site ACTION")
		game.interaction()
		print("ACTIVITY QA: after site ACTION")
		if activities.active or game.cash != initial_cash + int(proposed["reward"]):
			fail("Completing the second site did not pay exactly once", 473)
			return
	if game.total_earnings != initial_earnings + int(proposed["reward"]) or activities.total_completed != 1:
		fail("Finished resident activity did not update financial statistics exactly once", 474)
		return
	if int(game.resident_relations[str(giver.resident_id)]["affinity"]) != previous_affinity + 8:
		fail("Resident relationship reward was not applied", 475)
		return
	if game.navigation_kind == "activity":
		fail("Completed conversation activity left stale GPS active", 476)
		return
	var still_offered: Array[Dictionary] = activities.offers_for(giver.resident_id, giver.daily_role, int(original_tree["scenario_id"]))
	for offer in still_offered:
		if String(offer["id"]) == String(proposed["id"]):
			fail("Player can repeatedly farm the same resident's completed request", 477)
			return
	if not activities.interact_at(game.hero.global_position).is_empty():
		fail("Finished activity still grants interaction rewards", 478)
		return
	game.save_game()
	print("ACTIVITY QA: before load")
	game.load_game()
	print("ACTIVITY QA: after load")
	if activities.total_completed != 1 or not activities.completed.has(activities.record_key(giver.resident_id, String(proposed["id"]))):
		fail("Completed activity anti-farming state did not persist", 479)
		return

	# The social-introduction mechanic must work, even when a different
	# role-based tour was the first option chosen during dialogue.
	if String(proposed["id"]) != "meet":
		var another_giver: PocketActor = game.city.people[1]
		if not activities.accept("meet", another_giver.resident_id):
			fail("Introductions are not accepted as a distinct resident activity", 480)
			return
		game.set_city_waypoint("activity", "", "別の住民を紹介してもらう", activities.objective_position())
		var before_social: int = game.cash
		var target_id: int = activities.target_resident_id()
		var contact: PocketActor = game.city.people[target_id]
		game.hero.global_position = contact.global_position + Vector3(0.4, 0, 0)
		game.begin_conversation(contact)
		if activities.active or game.cash != before_social + 160 or game.navigation_kind == "activity":
			fail("Social introduction did not resolve through a valid actual conversation", 481)
			return
		game.end_conversation()
	# Independently, NPC conversations can recommend *existing* shops,
	# housing, garages and board jobs without inventing any speech.
	var recommender: PocketActor = game.city.people[2]
	game.hero.global_position = recommender.global_position + Vector3(0.35, 0, 0.2)
	print("ACTIVITY QA: before recommended NPC dialogue")
	game.begin_conversation(recommender)
	if not game.dialogue_panel.visible or game.dialogue_recommendation.is_empty():
		fail("A second resident did not offer existing city systems", 483)
		return
	var recommendation: Dictionary = game.dialogue_recommendation.duplicate(true)
	var prior_cash: int = game.cash
	print("ACTIVITY QA: before recommend button")
	game.dialogue_recommend_button.pressed.emit()
	if game.dialogue_panel.visible or game.cash != prior_cash:
		fail("Recommendation navigated without closing conversation, or paid without action", 484)
		return
	if not game.navigation_kind in ["lot", "job_board"] or game.navigation_kind != String(recommendation["kind"]):
		fail("NPC recommendation did not select a real CITY GPS service", 485)
		return
	if game.city_waypoint_point().distance_to(recommendation["position"]) > 0.2:
		fail("Recommended destination is not the actual entry or job board", 486)
		return
	game.clear_city_waypoint()
	# Declining a partly accepted request must remove its waypoint and never
	# consume a resident's one-time completion status or pay a reward.
	var rescuer: PocketActor = game.city.people[3]
	if not activities.accept("food", rescuer.resident_id):
		fail("Could not accept another activity for decline test", 487)
		return
	game.set_city_waypoint("activity", "", "食べ歩きの下見", activities.objective_position())
	var before_cancel: int = game.cash
	print("ACTIVITY QA: before cancellation")
	game.cancel_conversation_activity()
	if activities.active or game.cash != before_cancel or game.navigation_kind == "activity":
		fail("Cancelling a social activity did not cleanly remove the active state", 488)
		return
	if activities.completed.has(activities.record_key(rescuer.resident_id, "food")):
		fail("Cancelling activity falsely marked request complete", 489)
		return
	game.save_game()
	print("ACTIVITY QA: before load")
	game.load_game()
	print("ACTIVITY QA: after load")
	if activities.active or activities.completed.has(activities.record_key(rescuer.resident_id, "food")):
		fail("Cancelled activity returned after save and reload", 490)
		return
	print("ACTIVITY QA: all checks completed")
	print("PASS: 46 residents offer multiple diverse activities tied to role/topic")
	print("PASS: original dialogue paragraphs and 200-topic content remain unchanged")
	print("PASS: tap an offer -> real mission, 2-site ACTION progression, GPS and CITY phone")
	print("PASS: 2-stage save/load, once-only cash, rapport, anti-farming, introduction dialogue")
	print("PASS: conversations recommend existing city services without instant rewards")
	print("PASS: jobs can be cancelled without payment or corrupting saves")
	quit(0)

extends SceneTree
## CITY phone regression: every tab, UI interaction and persistent GPS guidance.
## Separate save path keeps player save data untouched.

func _initialize() -> void:
	call_deferred("run_checks")


func fail(message: String, code: int) -> void:
	push_error(message)
	quit(code)


func run_checks() -> void:
	var path := "user://pocket_district_city_phone_test.json"
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		fail("CITY phone test scene did not load", 230)
		return
	var game = scene.instantiate()
	game.save_path_override = path
	root.add_child(game)
	await process_frame
	await physics_frame
	if game.city_phone == null or game.city_phone_button == null or game.navigation_banner == null:
		fail("CITY phone and navigation controls were not initialized", 231)
		return
	var phone: PocketCityPhone = game.city_phone
	if phone.visible or phone.page != "仕事":
		fail("Phone must start hidden and on the jobs tab", 232)
		return
	if not game.on_action_button(game.city_phone_button.global_position + Vector2(8.0, 8.0)):
		fail("CITY button is not protected against joystick/camera gestures", 233)
		return
	game.city_phone_button.pressed.emit()
	if not phone.visible or not paused or phone.entries.get_child_count() < 3:
		fail("CITY button did not open a touch-friendly, paused jobs menu", 234)
		return

	var categories := ["仕事", "店舗", "住居", "車両", "情報"]
	var minimum_options := [2, 7, 1, 1, 3]
	for i in range(categories.size()):
		phone.open_page(categories[i])
		var options := 0
		for child in phone.entries.get_children():
			if child is Button:
				options += 1
		if options < minimum_options[i]:
			fail("Missing navigation entries in %s: got %d" % [categories[i], options], 235)
			return

	phone.open_page("仕事")
	var parcel_press: Button = null
	for child in phone.entries.get_children():
		if child is Button and String(child.text).contains("配達"):
			parcel_press = child
			break
	if parcel_press == null:
		fail("Cannot find courier guidance in CITY phone jobs", 236)
		return
	var original_hero: Vector3 = game.hero.global_position
	parcel_press.pressed.emit()
	if phone.visible or paused or game.navigation_kind != "delivery":
		fail("Phone GPS selection failed to close the modal and resume gameplay", 237)
		return
	if game.hero.global_position.distance_to(original_hero) > 0.2:
		fail("CITY phone incorrectly teleported the player", 238)
		return
	if game.city_waypoint_point().distance_to(game.mission_point) > 0.02:
		fail("Courier GPS does not track the current parcel", 239)
		return
	game.update_hud()
	if not game.navigation_banner.text.contains("GPS:") or not game.navigation_banner.text.contains("m"):
		fail("Persistent GPS distance/direction absent from HUD", 240)
		return

	var jobs: PocketNeighborhoodJobs = game.neighborhood_jobs
	game.set_city_waypoint("side_job", "", "地域ジョブ", jobs.objective_position())
	if game.city_waypoint_point().distance_to(jobs.board_position) > 0.01:
		fail("Side-job GPS does not route to the reception board", 241)
		return
	game.hero.global_position = jobs.board_position
	game.interaction()
	if not jobs.active or game.city_waypoint_point().distance_to(jobs.objective_position()) > 0.01:
		fail("Side-job GPS did not advance from acceptance to first stop", 242)
		return
	game.hero.global_position = jobs.objective_position()
	game.interaction()
	if jobs.step_index != 1 or game.city_waypoint_point().distance_to(jobs.objective_position()) > 0.01:
		fail("Side-job GPS did not follow the second stop", 243)
		return

	var shop: Dictionary = phone.closest_lot("furniture")
	if shop.is_empty():
		fail("Furniture store unavailable from the system guide", 244)
		return
	var shop_door: Vector3 = shop["door"]
	game.set_city_waypoint("lot", String(shop["id"]), "家具店", shop_door)
	if game.city_waypoint_point().distance_to(shop_door) > 0.01:
		fail("Shop GPS did not target its real entrance", 245)
		return

	var first_cache_id: String = game.street_finds.site_ids[0]
	game.set_city_waypoint("cache", first_cache_id, "発見品", game.street_finds.site_positions[0])
	if game.city_waypoint_point().distance_to(game.street_finds.site_positions[0]) > 0.01:
		fail("Street-find GPS did not point to the selected cache", 246)
		return

	game.garage_owned = true
	game.spawn_garage_car()
	if not is_instance_valid(game.garage_car):
		fail("Owned vehicle could not initialize for GPS", 247)
		return
	game.set_city_waypoint("owned_car", "", "マイカー", game.garage_car.global_position)
	var shifted: Vector3 = game.garage_car.global_position + Vector3(2.0, 0, 0)
	game.garage_car.global_position = shifted
	if game.city_waypoint_point().distance_to(shifted) > 0.02:
		fail("Owned-car GPS failed to follow its moving position", 248)
		return

	game.set_city_waypoint("lot", String(shop["id"]), "家具店", shop_door)
	game.save_game()
	game.navigation_kind = ""
	game.navigation_label = ""
	game.load_game()
	if game.navigation_kind != "lot" or game.navigation_label != "家具店" or game.city_waypoint_point().distance_to(shop_door) > 0.02:
		fail("Selected route was not recovered from save data", 249)
		return

	game.toggle_city_phone()
	if not phone.visible or not paused:
		fail("Cannot reopen phone after loading navigation state", 250)
		return
	phone.clear_waypoint()
	if game.navigation_kind != "" or game.navigation_label != "" or paused or phone.visible:
		fail("Clearing GPS failed to resume play or remove guidance", 251)
		return
	game.load_game()
	if game.navigation_kind != "":
		fail("GPS clear operation did not persist after reload", 252)
		return
	game.update_hud()
	if not game.navigation_banner.text.contains("CITY"):
		fail("No discoverability hint after clearing navigation", 253)
		return
	print("PASS: CITY phone work, shops, homes, vehicle and info tabs all accessible")
	print("PASS: modal touch-safe flow, no teleport, GPS marker and HUD destination")
	print("PASS: live courier, side jobs, shop, cache, moving car and save/load routes")
	print("PASS: player can clear the GPS and resume the game safely")
	quit(0)

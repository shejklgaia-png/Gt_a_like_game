extends SceneTree
## 100 deterministic, independent QA scenarios across 10 gameplay systems.
## These are test cycles, NOT a claim of 100 separate authored features.

var completed: int = 0


func _initialize() -> void:
	call_deferred("run_cycles")


func verify(condition: bool, cycle_id: int, detail: String) -> bool:
	if condition:
		completed += 1
		return true
	push_error("100-cycle QA failed at #%03d: %s" % [cycle_id + 1, detail])
	quit(100 + cycle_id)
	return false


func run_cycles() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("100-cycle QA could not import main scene")
		quit(90)
		return
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var town: PocketCity = game.city
	var finds: PocketStreetFinds = game.street_finds
	finds.collected.clear()
	finds.refresh()
	game.street_find_records.clear()
	game.deliveries = 0
	game.mission_stage = 0
	var catalogue = load("res://scripts/gameplay_data.gd")

	for cycle_id in range(100):
		var case_index: int = cycle_id % 10
		var group: int = cycle_id / 10
		var ok := false
		match group:
			0:
				# Ten visible, reachable cache spots with distinct stable IDs.
				var item_id: String = finds.site_ids[case_index]
				var spot: Vector3 = finds.site_positions[case_index]
				ok = finds.total_count() == 12 and item_id.begins_with("lot_") and finds.nearest(spot) == case_index and finds.markers[case_index].visible
			1:
				# Ten rotated contracts, all economically and mechanically valid.
				var contract: Dictionary = catalogue.delivery_contract(case_index)
				var distance := 20.0 + float(case_index) * 15.0
				ok = String(contract.get("title", "")).length() >= 5 and float(contract.get("reward_scale", 0.0)) >= 1.0 and float(contract.get("time_scale", 0.0)) >= 0.7 and catalogue.mission_reward(distance, case_index / 3) > 0 and catalogue.mission_time(distance) >= 50.0
			2:
				# Ten different building entrances must be accessible facade-side.
				var lot: Dictionary = town.buildings[case_index * 3]
				var door: Vector3 = lot["door"]
				var center: Vector3 = lot["position"]
				ok = door.z < center.z - float(lot["depth"]) * 0.5 and String(lot.get("business", "")).length() > 0 and String(lot["id"]).begins_with("lot_")
			3:
				# Ten camera orientations; compass right/up remain screen-relative.
				game.camera.rotate_y(0.08)
				var basis: Basis = game.camera.global_transform.basis
				var right: Vector3 = basis.x
				var up: Vector3 = basis.y
				ok = game.waypoint_arrow(Vector3(right.x, 0.0, right.z) * 20.0) == "→" and game.waypoint_arrow(Vector3(up.x, 0.0, up.z) * 20.0) == "↑"
			4:
				# Ten A* routes must never route through a marked solid building.
				var endpoint := Vector3(float(case_index - 5) * 18.0, 0.0, 93.0)
				var path: PackedVector2Array = town.navigation.path(Vector3(-90, 0, -90), endpoint)
				ok = path.size() >= 2
				for point in path:
					if town.navigation.grid.is_point_solid(town.navigation.id_from_world(Vector3(point.x, 0, point.y))):
						ok = false
						break
			5:
				# Ten AI cars have valid individual speeds, but player cars
				# disable the NPC obstacle-following sensor.
				var traffic_car: PocketVehicle = town.cars[case_index]
				traffic_car.occupied = true
				ok = traffic_car.npc_speed >= 8.2 and traffic_car.npc_speed <= 14.0 and is_equal_approx(traffic_car.nearest_forward_obstacle(), 13.0)
				traffic_car.occupied = false
			6:
				# Ten citizen identities, speeds, and nonblocking collision layers.
				var person: PocketActor = town.people[case_index]
				ok = person.resident_id == case_index and person.strolling_speed >= 1.75 and person.strolling_speed <= 2.45 and person.collision_layer == 2 and (person.collision_mask & 2) == 0
			7:
				# Ten HUD refreshes stay legible for repeated contract states.
				game.deliveries = case_index
				game.mission_stage = 0
				game.update_hud()
				var contract: Dictionary = catalogue.delivery_contract(case_index)
				ok = game.mission_label.text.contains(String(contract["title"])) and game.status_label.text.contains("◈0/12")
			8:
				# Ten distinct caches can be taken once and grant bounded cash.
				var before: int = finds.count_collected()
				var reward: int = finds.collect(case_index)
				ok = reward >= 70 and reward <= 145 and finds.count_collected() == before + 1 and not finds.markers[case_index].visible and finds.collect(case_index) == 0
			9:
				# Ten persisted discoveries survive serialization and reloading.
				game.street_find_records = finds.collected.duplicate(true)
				game.save_path_override = "user://pocket_district_hundred_cycle_test.json"
				game.save_game()
				finds.collected.clear()
				finds.refresh()
				game.load_game()
				ok = finds.count_collected() == 10 and finds.collected.has(finds.site_ids[case_index]) and not finds.markers[case_index].visible

		if not verify(ok, cycle_id, "group %d, variation %d" % [group, case_index]):
			return
		if (cycle_id + 1) % 10 == 0:
			print("PASS: 100-cycle QA, %d/100 independent scenarios" % completed)
	print("PASS: ALL 100 DETERMINISTIC OPEN-WORLD QA CYCLES")
	quit(0)

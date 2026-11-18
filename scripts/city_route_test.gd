extends SceneTree
## Regression checks for CITY A* routing around all building footprints.
## A distinct save path prevents changes to a player's city state.

func _initialize() -> void:
	call_deferred("run_checks")


func fail(message: String, code: int) -> void:
	push_error(message)
	quit(code)


func horizontal(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


func run_checks() -> void:
	var save_path := "user://pocket_district_route_test.json"
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		fail("Cannot import Pocket District main scene", 301)
		return
	var game = scene.instantiate()
	game.save_path_override = save_path
	root.add_child(game)
	await process_frame
	await physics_frame
	var city: PocketCity = game.city
	var route: PocketCityRoute = game.city_route
	if route == null or route.navigation != city.navigation:
		fail("CITY GPS did not share the city's existing police nav grid", 302)
		return
	var start := Vector3(-90, 0.3, -90)
	var tested := 0
	for index in range(0, city.buildings.size(), 3):
		var lot: Dictionary = city.buildings[index]
		var door: Vector3 = lot["door"]
		route.clear()
		route.refresh(start, door)
		if route.path_points.size() < 3:
			fail("Cannot route to building %s" % String(lot["id"]), 303)
			return
		for point in route.path_points:
			var nav_grid := city.navigation.grid
			if nav_grid.is_point_solid(city.navigation.id_from_world(Vector3(point.x, 0.0, point.y))):
				fail("A* guidance crosses a building at %s" % str(point), 304)
				return
		var straight := horizontal(start).distance_to(horizontal(door))
		var distance := route.remaining_distance(start, door)
		if distance < straight - 0.5 or not is_finite(distance):
			fail("Route distance was shorter than a straight path", 305)
			return
		var next_guide: Vector3 = route.next_guidance_point(start, door)
		if not next_guide.is_finite() or horizontal(next_guide).distance_to(horizontal(start)) > 30.0:
			fail("Next GPS heading points too far away or is invalid", 306)
			return
		tested += 1
	if tested != 12:
		fail("Unexpected building sample count in GPS routing", 307)
		return
	# Force a building between the origin and target to prove the displayed
	# distance reflects detouring around collision volumes, not just direction.
	var obstacle: Dictionary = city.buildings[12]
	var center: Vector3 = obstacle["position"]
	var halfwidth: float = float(obstacle["width"]) * 0.5
	var from := center + Vector3(-halfwidth - 4.0, 0.3, 0.0)
	var goal := center + Vector3(halfwidth + 4.0, 0.3, 0.0)
	route.clear()
	route.refresh(from, goal)
	if route.path_points.is_empty() or route.remaining_distance(from, goal) < horizontal(from).distance_to(horizontal(goal)) + 7.0:
		fail("GPS shortcut is still passing through a building", 308)
		return
	var preview := route.visible_route(from, goal)
	if preview.size() < 4:
		fail("Minimap lacks multiple points for a detour route", 309)
		return
	var original_count: int = route.computation_count
	for repeat in range(120):
		route.refresh(from + Vector3(float(repeat % 3) * 0.2, 0.0, 0.0), goal, 0.10)
	if route.computation_count != original_count:
		fail("GPS is recalculating A* continuously without movement", 310)
		return
	# When the player deviates, recompute only after cooldown rather than per frame.
	route.refresh(from + Vector3(-14.0, 0, -4.0), goal, 1.6)
	if route.computation_count != original_count + 1:
		fail("GPS failed to recalculate route after a significant detour", 311)
		return
	var moved_goal := goal + Vector3(0, 0, 8.0)
	route.refresh(from, moved_goal)
	if route.computation_count != original_count + 2:
		fail("GPS failed to update for moving objective", 312)
		return
	if not route.is_arrived(goal, goal + Vector3(2.0, 0, 0)):
		fail("GPS arrival distance does not recognize accessible interaction zone", 313)
		return
	if route.is_arrived(from, goal):
		fail("GPS arrival prematurely completes a distant route", 314)
		return
	if not route.visible_route(goal, goal).is_empty():
		fail("Arrival did not hide completed minimap trail", 315)
		return

	# Full integration with dynamic courier/side-job and persistent phone state.
	game.set_city_waypoint("lot", String(obstacle["id"]), "建物", Vector3(obstacle["door"]))
	game.update_hud()
	if not game.navigation_banner.text.contains("次") or not game.navigation_banner.text.contains("約"):
		fail("HUD does not report next direction and routed distance", 316)
		return
	var gps_before: String = game.navigation_label
	game.save_game()
	game.clear_city_waypoint()
	game.load_game()
	if game.navigation_label != gps_before or game.navigation_kind != "lot":
		fail("GPS state no longer compatible with loading existing saves", 317)
		return
	game.hero.global_position = Vector3(obstacle["door"]) + Vector3(0, 0.3, 0)
	game.update_hud()
	if not game.navigation_banner.text.contains("到着"):
		fail("GPS did not show a usable arrival hint at a physical storefront", 318)
		return
	game.clear_city_waypoint()
	if not route.path_points.is_empty():
		fail("Clearing GPS left a stale path displayed on minimap", 319)
		return
	print("PASS: twelve CITY paths avoid every sampled building footprint")
	print("PASS: GPS detours around buildings and supports minimap breadcrumbs")
	print("PASS: low-frequency route cache, dynamic objectives and deviation repath")
	print("PASS: guided distance, next direction, arrival prompt and save/load continuity")
	quit(0)

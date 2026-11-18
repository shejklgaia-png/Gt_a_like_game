extends SceneTree
const Rules = preload("res://scripts/traffic_rules.gd")
## Pedestrian navigation must use sidewalk corridors and only marked crossings.
## Test the real ACTION->commerce route to prevent invisible garage services.

func _initialize() -> void:
	call_deferred("check")


func fail(reason: String, code: int) -> void:
	push_error(reason)
	quit(code)


func check() -> void:
	var save_path := "user://sidewalk_city_navigation_test.json"
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		fail("Missing game scene", 400)
		return
	var game = scene.instantiate()
	game.save_path_override = save_path
	root.add_child(game)
	await process_frame
	await physics_frame
	var walk: PocketSidewalkRoute = game.walk_route
	if walk == null or walk.city_nav != game.city.navigation or walk.graph.get_point_count() != 198:
		fail("Expected one reusable 196-node sidewalk graph and two GPS endpoints", 401)
		return
	var sidewalk_start := Vector3(-101.65, 0.3, -93.0)
	var examined := 0
	var crossed := 0
	var paths_with_crossings := 0
	for lot_index in range(0, game.city.buildings.size(), 3):
		var lot: Dictionary = game.city.buildings[lot_index]
		var entrance: Vector3 = lot["door"]
		if not walk.can_route(sidewalk_start, entrance):
			fail("A city storefront is outside walkable graph bounds: " + String(lot["id"]), 402)
			return
		walk.clear()
		walk.refresh(sidewalk_start, entrance)
		if walk.path_points.size() < 2:
			fail("No sidewalk route to " + String(lot["id"]), 403)
			return
		var crossings_for_building := 0
		for index in range(1, walk.path_points.size()):
			var previous: Vector2 = walk.path_points[index - 1]
			var next: Vector2 = walk.path_points[index]
			if previous.distance_to(next) > 23.5:
				fail("Unmarked shortcut over road: " + str(previous) + " -> " + str(next), 404)
				return
			var axis: int = walk.crosswalk_axis(previous, next)
			if axis >= 0:
				crossings_for_building += 1
				crossed += 1
			if index > 1 and index < walk.path_points.size() - 1:
				var cell: Vector2i = walk.city_nav.id_from_world(Vector3(next.x, 0, next.y))
				if walk.city_nav.grid.is_point_solid(cell):
					fail("Marked sidewalk passes through building obstacle: " + str(next), 405)
					return
		var detour: float = walk.remaining_distance(sidewalk_start, entrance)
		if not is_finite(detour) or detour + 0.6 < Vector2(sidewalk_start.x - entrance.x, sidewalk_start.z - entrance.z).length():
			fail("Sidewalk GPS gave shorter-than-direct distance", 406)
			return
		if crossings_for_building > 0:
			paths_with_crossings += 1
		examined += 1
	if examined != 12 or crossed < 4 or paths_with_crossings < 4:
		fail("Insufficient crosswalk coverage in city routes", 407)
		return
	if walk.crosswalk_axis(Vector2(6.35, -6.35), Vector2(6.35, 6.35)) != 0:
		fail("North/south crossing has wrong traffic-light axis", 408)
		return
	if walk.crosswalk_axis(Vector2(-6.35, 6.35), Vector2(6.35, 6.35)) != 1:
		fail("East/west crossing has wrong traffic-light axis", 409)
		return
	if walk.crosswalk_axis(Vector2(6.35, 6.35), Vector2(29.65, 6.35)) != -1:
		fail("Normal sidewalk segment wrongly classified as crossing", 410)
		return

	var across_z := Vector3(6.35, 0.3, 13.0)
	walk.clear()
	walk.refresh(Vector3(6.35, 0.3, -6.35), across_z)
	var upcoming_signal: Dictionary = walk.next_crosswalk(Vector3(6.35, 0.3, -6.35))
	if upcoming_signal.is_empty() or int(upcoming_signal["axis"]) != 0:
		fail("GPS failed to recognize upcoming painted Z-direction crossing", 411)
		return
	if bool(upcoming_signal["green"]) != Rules.pedestrians_have_green(0):
		fail("GPS signal state disagrees with the world's shared traffic phase", 412)
		return
	var signal_hint := walk.crossing_hint(Vector3(6.35, 0.3, -6.35))
	if not signal_hint.contains("横断歩道"):
		fail("Crosswalk signal hint missing for near-curb pedestrian", 413)
		return
	var before: int = walk.computation_count
	for repeat in range(60):
		walk.refresh(Vector3(6.35, 0.3, -6.35) + Vector3(0, 0, float(repeat % 3) * 0.05), across_z, 0.1)
	if walk.computation_count != before:
		fail("Foot-route pathfinding did not throttle stationary replans", 414)
		return
	walk.refresh(Vector3(6.35, 0.3, -26.0), across_z, 1.6)
	if walk.computation_count != before + 1:
		fail("Walkway path did not update after leaving mapped route", 415)
		return
	if walk.can_route(Vector3(0, 7.0, 137.0), across_z):
		fail("Elevated freeway must not use the ground-level pedestrian grid", 416)
		return

	# A historically hidden garage bug: menu was accessible by direct
	# open_commerce_for(), but not by the actual in-game ACTION interaction.
	var garage: Dictionary = {}
	for lot in game.city.buildings:
		if String(lot["business"]) == "garage":
			garage = lot
			break
	if garage.is_empty():
		fail("Missing CITY GARAGE lot", 417)
		return
	game.cash = 2000
	game.wanted = 0
	game.hero.global_position = Vector3(garage["door"]) + Vector3(0, 0.3, 0)
	game.interaction()
	if game.indoors or not game.commerce_panel.visible or game.commerce_options.is_empty():
		fail("ACTION at CITY GARAGE still skips the actual car purchase menu", 418)
		return
	if String(game.commerce_options[0]["type"]) != "buy_garage_car":
		fail("Garage ACTION did not offer player-car purchase", 419)
		return
	game.select_commerce_option(0)
	if not game.garage_owned or not is_instance_valid(game.garage_car) or game.cash != 650:
		fail("Vehicle purchase did not complete through regular ACTION flow", 420)
		return
	if game.wanted > 0 or game.commerce_panel.visible:
		fail("Legal garage purchase raised wanted stars or left menu open", 421)
		return
	game.hero.global_position = Vector3(garage["door"]) + Vector3(0, 0.3, 0)
	game.interaction()
	if not game.commerce_panel.visible or String(game.commerce_options[0]["type"]) != "recall_garage_car":
		fail("ACTION at owned garage did not offer recall", 422)
		return
	game.close_commerce()
	# Route selection must preserve the previously tested vehicle A*.
	game.set_city_waypoint("lot", String(garage["id"]), "CITY GARAGE", garage["door"])
	if game.active_city_route() != walk:
		fail("On-foot game GPS did not activate sidewalk route", 423)
		return
	game.hero.global_position = Vector3(0, 7.0, 137.0)
	if game.active_city_route() != game.city_route:
		fail("Elevated player unexpectedly received ground-level pedestrian route", 424)
		return
	game.clear_city_waypoint()
	print("PASS: 196-node sidewalk mesh, 12 facility routes, %d marked crosswalk legs" % crossed)
	print("PASS: correct traffic-light axes, live red/green crossing hint, 60 idle updates throttled")
	print("PASS: foot vs freeway routing, pedestrian detours without building obstacles")
	print("PASS: actual ACTION opens garage purchase/recall, legal vehicle and retained save")
	quit(0)

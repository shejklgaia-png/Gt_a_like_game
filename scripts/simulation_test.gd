extends SceneTree
## Longer headless simulation: catches update-loop errors that short boot tests miss.

func _initialize() -> void:
	call_deferred("exercise")

func fail(message: String, code: int) -> void:
	push_error(message)
	quit(code)

func exercise() -> void:
	var game_scene := load("res://scenes/main.tscn") as PackedScene
	if game_scene == null:
		fail("Game scene did not import", 51)
		return
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var city: PocketCity = game.city
	if city.navigation == null:
		fail("No A* route grid", 52)
		return
	var route := city.navigation.path(Vector3(0,0,0), Vector3(36,0,36))
	if route.size() < 3:
		fail("Cannot route around block buildings", 53)
		return
	for pos in route:
		if city.navigation.grid.is_point_solid(city.navigation.id_from_world(Vector3(pos.x, 0, pos.y))):
			fail("Generated police navigation cuts through a building", 54)
			return
	# Citizen rhythms must be varied without changing the street-crossing collision rules.
	var unique_paces: Dictionary = {}
	for citizen in city.people:
		if citizen.strolling_speed < 1.75 or citizen.strolling_speed > 2.45:
			fail("Resident speed outside safe walking range", 71)
			return
		unique_paces[int(citizen.strolling_speed * 100.0)] = true
	if unique_paces.size() < 8:
		fail("Crowd walking pace has lost its per-resident variety", 72)
		return
	# AI traffic is staggered rather than running at exactly one convoy pace.
	var observed_cruise: Dictionary = {}
	for traffic_car in city.cars:
		if traffic_car.npc_speed < 8.2 or traffic_car.npc_speed > 14.0:
			fail("Road AI cruise speed outside expected safe range", 73)
			return
		observed_cruise[roundi(traffic_car.npc_speed * 10.0)] = true
	if observed_cruise.size() < 6:
		fail("Traffic has lost its per-vehicle cruising variety", 74)
		return
	var sensor_car: PocketVehicle = city.cars[0]
	sensor_car.occupied = true
	if absf(sensor_car.nearest_forward_obstacle() - 13.0) > 0.01:
		fail("Driven vehicle is incorrectly using pedestrian following sensor", 75)
		return
	sensor_car.occupied = false
	var first: PocketActor = city.people[0]
	var spawned: Vector3 = first.global_position
	for frame in range(160):
		await physics_frame
	if not is_instance_valid(first) or first.dead:
		fail("Civilians died during idle traffic simulation", 55)
		return
	if first.sidewalk_axis == 0 and absf(first.global_position.x - first.anchor.x) > 0.42:
		fail("Walking NPC escaped sideways into traffic", 56)
		return
	if first.sidewalk_axis == 1 and absf(first.global_position.z - first.anchor.z) > 0.42:
		fail("Walking NPC escaped sideways into traffic", 57)
		return
	var rules = load("res://scripts/traffic_rules.gd")
	if rules.cars_have_green(0) and rules.cars_have_green(1):
		fail("Both perpendicular road directions have green lights simultaneously", 58)
		return
	if game.perf_overlay == null or game.sound == null:
		fail("Runtime performance and sound services were not initialized", 59)
		return
	# Stable deterministic interior seed and a collectible that cannot be harvested twice.
	var room_a: Dictionary = PocketInterior.make_layout("lot_2_1")
	var room_b: Dictionary = PocketInterior.make_layout("lot_2_1")
	if JSON.stringify(room_a) != JSON.stringify(room_b):
		fail("Regenerated room changed despite same building ID", 60)
		return
	game.interior.display_layout("lot_2_1", room_a)
	var center := PocketInterior.INTERIOR_ORIGIN + Vector3(4.5, 0.35, 5.2)
	var first_take: int = game.interior.search_loot(center)
	var second_take: int = game.interior.search_loot(center)
	if first_take <= 0 or second_take != 0:
		fail("Room loot was not unique", 61)
		return
	game.interior.display_layout("lot_2_1", room_a, true)
	if game.interior.loot_near(center):
		fail("Collected loot respawned when revisiting room", 62)
		return
	# Regression: every physical prop must leave the walking lanes and crosswalk
	# approaches clear. Benches must face the facade rather than the junction.
	var props := city.get_node_or_null("StreetProps") as Node3D
	if props == null or props.get_child_count() < 25:
		fail("Façade street props did not generate", 63)
		return
	for item in props.get_children():
		var prop := item as Node3D
		var side: int = int(prop.get_meta("side", 0))
		var kind: int = int(prop.get_meta("kind", -1))
		if side == 0 or kind < 0:
			fail("Street prop is missing its pedestrian clearance metadata", 64)
			return
		if float(prop.get_meta("pedestrian_lane_clearance", 0.0)) < 0.85:
			fail("Street prop extends into a pedestrian lane", 65)
			return
		var expected_yaw := -float(side) * PI * 0.5
		if absf(wrapf(prop.rotation.y - expected_yaw, -PI, PI)) > 0.05:
			fail("Street bench/furniture orientation is facing away from building", 66)
			return
		var z_from_junction := absf(prop.position.z - roundf(prop.position.z / 36.0) * 36.0)
		if z_from_junction < 9.0:
			fail("Street furnishing obstructs an intersection approach", 67)
			return
	# Generated sidewalks and facades should be brightly varied, not monochrome.
	var wall_tints := {}
	var pavement_tints := {}
	for building in city.buildings:
		var wall: Color = building["wall_color"]
		var pavement: Color = building["sidewalk_color"]
		wall_tints[wall.to_html()] = true
		pavement_tints[pavement.to_html()] = true
	if wall_tints.size() < 10 or pavement_tints.size() < 6:
		fail("City color scheme does not contain distinct facade and pavement colors", 68)
		return
	# Camera stays locked to the player with the fixed elevated angle after a
	# temporary orbit gesture, and has a meaningfully longer viewing distance.
	if game.camera_distance < 15.5 or absf(game.camera_pitch - deg_to_rad(69.0)) > 0.02:
		fail("New long-range fixed overhead camera was not initialized", 69)
		return
	game.camera_yaw = 0.65
	game.camera_override_timer = 0.0
	for tick in range(36):
		await physics_frame
	if absf(game.camera_yaw) > 0.13 or absf(game.camera_pitch - deg_to_rad(69.0)) > 0.02:
		fail("Overhead camera failed to return to its fixed orientation", 70)
		return
	print("PASS: side-facade objects have crossing clearance; benches face inward; colorful blocks and long-range fixed overhead camera")
	print("PASS: 160-frame autonomous city simulation, varied crowd pace, nav grid, traffic phases, and unique interior loot")
	quit(0)

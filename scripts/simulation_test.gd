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
	print("PASS: 160-frame autonomous city simulation, nav grid, traffic phases, generated ambience and unique deterministic interior loot")
	quit(0)

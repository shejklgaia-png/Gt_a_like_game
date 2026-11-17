extends SceneTree
## Integrated tests for road network, zoning, purchasable rooms, furniture and
## an occasional hostile NPC encounter. Uses a private save path.
const Furniture = preload("res://scripts/furniture_catalog.gd")
const SafeSave = preload("res://scripts/safe_save.gd")
const Interior = preload("res://scripts/interior.gd")

func _initialize() -> void:
	call_deferred("run")

func abort(message: String, code: int) -> void:
	push_error(message)
	quit(code)

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		abort("City scene cannot load", 110)
		return
	var game = scene.instantiate()
	game.save_path_override = "user://pocket_district_district_test.json"
	root.add_child(game)
	await process_frame
	await physics_frame
	var city: PocketCity = game.city
	if city.buildings.size() != 36:
		abort("Legacy city lot identities are not preserved", 111)
		return
	var road_root := city.get_node_or_null("RoadNetworkExtensions")
	if road_root == null or road_root.get_node_or_null("Boulevards") == null or road_root.get_node_or_null("CurvedPerimeterRoads") == null or road_root.get_node_or_null("ServiceAlleys") == null:
		abort("Road geometry did not generate", 112)
		return
	var elevated := road_root.get_node_or_null("ElevatedFreeway") as Node3D
	if elevated == null:
		abort("Expressway is not present", 113)
		return
	var physical_span := false
	var slope := false
	for piece in elevated.get_children():
		if piece is StaticBody3D and piece.position.y >= 6.9:
			physical_span = true
		if piece is StaticBody3D and piece.position.y > 1.5 and piece.position.y < 5.5:
			slope = true
	if not physical_span or not slope:
		abort("Elevated freeway is missing collision surface or connecting ramps", 114)
		return
	var business_set: Dictionary = {}
	var district_set: Dictionary = {}
	var home_lot: Dictionary = {}
	var furniture_lot: Dictionary = {}
	var nightlife_lot: Dictionary = {}
	var alley_count := 0
	for lot in city.buildings:
		var business: String = String(lot.get("business", ""))
		business_set[business] = true
		district_set[String(lot.get("district", ""))] = true
		if business == "apartment" and home_lot.is_empty():
			home_lot = lot
		if business == "furniture":
			furniture_lot = lot
		if business in ["lounge", "club"]:
			nightlife_lot = lot
		if bool(lot.get("alley", false)):
			alley_count += 1
			var center: Vector3 = lot["block_center"]
			var building_center: Vector3 = lot["position"]
			var free_lane: float = center.x + 6.7 - (building_center.x + float(lot["width"]) / 2.0)
			if free_lane < 2.0:
				abort("Service alley collides with building footprint", 115)
				return
	for kind in ["gun", "supermarket", "convenience", "clothing", "furniture", "market", "office", "lounge", "club", "apartment"]:
		if not business_set.has(kind):
			abort("Missing shop/district use: " + kind, 116)
			return
	if district_set.size() < 5 or alley_count < 3 or home_lot.is_empty():
		abort("Districts or home listings did not populate", 117)
		return
	game.cash = 10000
	game.open_commerce_for(home_lot)
	if not game.commerce_panel.visible or game.commerce_options.is_empty():
		abort("Property sale UI did not open", 118)
		return
	game.select_commerce_option(0)
	var address: String = String(home_lot["id"])
	if not game.purchased_homes.has(address) or game.cash >= 10000:
		abort("Property payment/ownership did not persist", 119)
		return
	game.close_commerce()
	game.open_commerce_for(furniture_lot)
	game.select_commerce_option(0)
	if int(game.furniture_inventory.get("sofa", 0)) != 1:
		abort("Furniture store did not add a purchasable sofa", 120)
		return
	game.close_commerce()
	game.enter_interior(home_lot)
	if not game.indoors or not game.interior.home_mode or game.interior.occupants.size() != 0:
		abort("Owned home is not a private editable room", 121)
		return
	var placed := false
	for x in [-5.5, 0.0, 5.5]:
		for z in [-5.5, -2.0, 1.0]:
			var point := Vector3(x, 0, z)
			if game.interior.valid_furniture_position(point, "sofa", []):
				game.hero.body_visual.rotation.y = 0
				game.hero.global_position = Interior.INTERIOR_ORIGIN + point + Vector3(0, 0.35, 2.1)
				game.place_home_item("sofa")
				placed = true
				break
		if placed:
			break
	if not placed or game.placed_furniture.get(address, []).size() != 1:
		abort("Furniture could not be placed with valid wall/door clearance", 122)
		return
	if int(game.furniture_inventory.get("sofa", 0)) != 0:
		abort("Placed furniture was not removed from inventory", 123)
		return
	var saved: Dictionary = SafeSave.load_json(game.save_destination())
	if not saved.get("homes", {}).has(address) or saved.get("furnishings", {}).get(address, []).size() != 1:
		abort("Home ownership/furniture positions were not saved", 124)
		return
	game.remove_nearby_furniture()
	if int(game.furniture_inventory.get("sofa", 0)) != 1 or game.placed_furniture.get(address, []).size() != 0:
		abort("Reclaiming furniture did not return it to inventory", 125)
		return
	game.leave_interior()
	var encounter_found := false
	for visit in range(1, 60):
		game.enter_interior(nightlife_lot)
		if game.interior.occupants.size() < 1 or game.interior.occupants.size() > 4:
			abort("Interior contains wrong civilian count", 126)
			return
		for person in game.interior.occupants:
			if person.mafia:
				encounter_found = true
				if person.chase_target != game.hero:
					abort("Mafia hostile AI was not armed", 127)
					return
				game.hero.global_position = person.global_position + Vector3(1.5, 0, 0)
				if not person.try_baton_attack(game.hero, 8.0):
					abort("Mafia cannot initiate a close-range attack", 128)
					return
				break
		game.leave_interior()
		await process_frame
		if encounter_found:
			break
	if not encounter_found:
		abort("Mafia never appears across repeated nightlife interior visits", 129)
		return
	print("PASS: curved/arterial/freeway/alley streets, all zones and retail stores, home sale, furniture placement/save/reclaim, 1-4 indoor NPCs, rare mafia engagement")
	quit(0)

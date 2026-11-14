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
	print("PASS: 36 buildings, 18 traffic cars, 46 pedestrians; orbit camera, 5 gun models, sidewalks, police baton and death states")
	quit(0)

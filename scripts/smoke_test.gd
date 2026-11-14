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
	print("PASS: Game starts; 36 buildings, 18 cars, 46 pedestrians; interiors and loadout initialized")
	quit(0)

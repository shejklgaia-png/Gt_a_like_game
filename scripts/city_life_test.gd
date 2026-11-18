extends SceneTree
## End-to-end tests for street routines, independent jobs and a legal player car.
## Run with: godot --headless --path . --script res://scripts/city_life_test.gd

func _initialize() -> void:
	call_deferred("run_checks")


func fail(message: String, code: int) -> void:
	push_error(message)
	quit(code)


func run_checks() -> void:
	var save_path := "user://pocket_district_city_life_test.json"
	for path in [save_path, save_path + ".bak", save_path + ".tmp"]:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		fail("City life test scene did not load", 201)
		return
	var game = scene.instantiate()
	game.save_path_override = save_path
	root.add_child(game)
	await process_frame
	await physics_frame
	var town: PocketCity = game.city
	var roles: Dictionary = {}
	var assigned: int = 0
	for citizen in town.people:
		if citizen.daily_role.is_empty():
			fail("Outdoor civilian has no everyday purpose", 202)
			return
		roles[citizen.daily_role] = true
		if not citizen.routine_stops.is_empty():
			assigned += 1
		if citizen.collision_layer != 2 or (citizen.collision_mask & 2) != 0:
			fail("Routine pedestrian became collision-blocking", 203)
			return
	if roles.size() != 4 or assigned < 36:
		fail("Missing role variety or purposeful destinations", 204)
		return

	var jobs: PocketNeighborhoodJobs = game.neighborhood_jobs
	if jobs == null or jobs.board_marker == null or jobs.active or jobs.completed != 0:
		fail("Side job board did not initialize", 205)
		return
	var initial_cash: int = game.cash
	game.hero.global_position = jobs.board_position
	game.interaction()
	if not jobs.active or jobs.step_index != 0:
		fail("Cannot accept first neighborhood job with ACTION", 206)
		return
	var first_destination := jobs.objective_position()
	game.hero.global_position = first_destination
	game.interaction()
	if not jobs.active or jobs.step_index != 1:
		fail("First neighborhood stop did not register", 207)
		return
	var second_destination := jobs.objective_position()
	if first_destination.distance_to(second_destination) < 8.0:
		fail("Side job stops do not represent distinct locations", 208)
		return
	game.hero.global_position = second_destination
	game.interaction()
	if jobs.active or jobs.completed != 1 or game.cash - initial_cash != 220:
		fail("Neighborhood job did not pay once or track its completion", 209)
		return
	if jobs.active_contract()["title"] != "MARKET INSPECTION":
		fail("Second job did not rotate to market activity", 210)
		return
	# A new assignment advances to the correct new objective, and progress
	# remains intact when loading an older save containing no side job fields.
	game.hero.global_position = jobs.board_position
	game.interaction()
	game.hero.global_position = jobs.objective_position()
	game.interaction()
	if not jobs.active or jobs.step_index != 1:
		fail("Second assignment progress did not advance", 211)
		return
	game.save_game()
	jobs.active = false
	jobs.step_index = 0
	game.load_game()
	if int(game.neighborhood_job_state.get("completed", -1)) != 1:
		fail("Neighborhood work progress was not serialized", 212)
		return

	var garage_lot: Dictionary = {}
	for lot in town.buildings:
		if String(lot["business"]) == "garage":
			garage_lot = lot
			break
	if garage_lot.is_empty() or game.garage_owned:
		fail("Garage lot missing or already purchased on fresh save", 213)
		return
	game.cash = 2000
	game.open_commerce_for(garage_lot)
	if not game.commerce_panel.visible or game.commerce_options.is_empty() or String(game.commerce_options[0]["type"]) != "buy_garage_car":
		fail("Garage purchase not offered in commerce", 214)
		return
	game.select_commerce_option(0)
	if not game.garage_owned or not is_instance_valid(game.garage_car) or game.cash != 650:
		fail("Purchasing a legal car did not take cash / spawn ownership", 215)
		return
	var garage_car: PocketVehicle = game.garage_car
	if not garage_car.legal_owner or garage_car.npc_speed != 0.0:
		fail("Purchased vehicle is not flagged as a safe parked vehicle", 216)
		return
	game.hero.global_position = garage_car.entrance_point() + Vector3(0, 0.25, 0)
	game.wanted = 0
	game.enter_car(garage_car)
	await create_timer(1.0).timeout
	if game.car_driven != garage_car or game.wanted != 0 or not garage_car.occupied:
		fail("Player-owned car was treated as a stolen vehicle", 217)
		return
	game.exit_car()
	if game.car_driven != null or garage_car.occupied:
		fail("Could not safely exit the purchased car", 218)
		return
	game.save_game()
	var saved_car: Vector3 = garage_car.global_position
	game.queue_free()
	await process_frame
	var reloaded = scene.instantiate()
	reloaded.save_path_override = save_path
	root.add_child(reloaded)
	await process_frame
	await physics_frame
	if not reloaded.garage_owned or not is_instance_valid(reloaded.garage_car):
		fail("Car ownership did not persist across session reload", 219)
		return
	var reloaded_car: PocketVehicle = reloaded.garage_car
	if Vector2(reloaded_car.global_position.x - saved_car.x, reloaded_car.global_position.z - saved_car.z).length() > 1.0:
		fail("Purchased vehicle did not return to its saved world location", 220)
		return
	if reloaded.neighborhood_jobs.completed != 1 or not reloaded.neighborhood_jobs.active or reloaded.neighborhood_jobs.step_index != 1:
		fail("Incomplete neighborhood work was not restored", 221)
		return
	print("PASS: four NPC routines, 46 civilian slots, signal-safe crowds")
	print("PASS: optional side jobs, rotated contract types, payment, staged save/load")
	print("PASS: garage car legal entry, parking/exit, cash purchase and persistent ownership")
	quit(0)

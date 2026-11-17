extends Node3D
class_name PocketCity

const Shapes = preload("res://scripts/shape_factory.gd")
const VehicleScene = preload("res://scripts/vehicle.gd")
const ActorScene = preload("res://scripts/actor.gd")
const UrbanAssets = preload("res://scripts/urban_assets.gd")
const TrafficLights = preload("res://scripts/traffic_light_visuals.gd")
const NavigationGrid = preload("res://scripts/nav_grid.gd")
var buildings: Array[Dictionary] = []
var cars: Array[PocketVehicle] = []
var people: Array[PocketActor] = []
var rng := RandomNumberGenerator.new()
var car_root: Node3D
var person_root: Node3D
var police_root: Node3D
var navigation: PocketNavGrid
const ROAD_COLOR := Color("#293341")
const SIDEWALK_COLORS := [
	Color("#79c6bc"), Color("#e9b48d"), Color("#b6a0d9"), Color("#e6d17c"),
	Color("#9ebfdd"), Color("#a9cd98"), Color("#eba4b1"), Color("#b2a3d9"),
	Color("#dfba8f"), Color("#88cbd3"), Color("#d9a1ca"), Color("#c2d67f")
]


func build_city() -> void:
	rng.seed = 234894
	Shapes.box(self, Vector3(0, -0.35, 0), Vector3(280, 0.7, 280), Color("#465958"), true)
	for n in range(-3, 4):
		var pos := float(n) * 36.0
		Shapes.box(self, Vector3(pos, 0.010, 0), Vector3(10.0, 0.02, 246), ROAD_COLOR)
		Shapes.box(self, Vector3(0, 0.010, pos), Vector3(246, 0.02, 10.0), ROAD_COLOR)
	add_lane_markings()
	add_crosswalks()
	for ix in range(-3, 3):
		for iz in range(-3, 3):
			create_building(ix, iz)
	navigation = NavigationGrid.new()
	for building in buildings:
		navigation.building(building["position"], float(building["width"]) * 0.5, float(building["depth"]) * 0.5)
	car_root = Node3D.new()
	car_root.name = "Traffic"
	add_child(car_root)
	person_root = Node3D.new()
	person_root.name = "Pedestrians"
	add_child(person_root)
	police_root = Node3D.new()
	police_root.name = "Police"
	add_child(police_root)
	spawn_traffic()
	spawn_civilians()
	add_street_props()
	UrbanAssets.install(self, buildings)
	var lights := TrafficLights.new()
	lights.name = "TrafficLights"
	add_child(lights)


func add_lane_markings() -> void:
	var bar := BoxMesh.new()
	bar.size = Vector3(0.13, 0.015, 3.5)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = bar
	batch.instance_count = 7 * 25 * 2
	var index := 0
	for road in range(-3, 4):
		var p := float(road) * 36.0
		for k in range(-12, 13):
			var along := float(k) * 9.0
			batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(p, 0.056, along)))
			index += 1
			batch.set_instance_transform(index, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(along, 0.057, p)))
			index += 1
	var strip := MultiMeshInstance3D.new()
	strip.name = "LaneMarkings"
	strip.multimesh = batch
	strip.material_override = Shapes.material(Color("#aab2a0"))
	add_child(strip)


func add_crosswalks() -> void:
	# One instanced mesh instead of 1176 individual MeshInstances for mobile GPUs.
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(2.0, 0.02, 0.6)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = stripe_mesh
	batch.instance_count = 7 * 7 * 6 * 4
	var index := 0
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var x := float(ix) * 36.0
			var z := float(iz) * 36.0
			for stripe in range(6):
				var offset := float(stripe) * 1.45 - 3.65
				for side in [-1.0, 1.0]:
					var pos_a := Vector3(x + side * 6.35, 0.073, z + offset)
					batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, pos_a))
					index += 1
					var pos_b := Vector3(x + offset, 0.074, z + side * 6.35)
					batch.set_instance_transform(index, Transform3D(Basis(Vector3.UP, PI * 0.5), pos_b))
					index += 1
	var painted := MultiMeshInstance3D.new()
	painted.name = "Crosswalks"
	painted.multimesh = batch
	painted.material_override = Shapes.material(Color("#e7ebdc"))
	add_child(painted)


func create_building(ix: int, iz: int) -> void:
	var cx := (float(ix) + 0.5) * 36.0
	var cz := (float(iz) + 0.5) * 36.0
	var tall := rng.randi_range(11, 32)
	var height := float(tall)
	var width := rng.randf_range(18.5, 20.0)
	var depth := rng.randf_range(18.5, 20.0)
	var shop := ix == 0 and iz == -1
	if shop:
		height = 12.0
	var sidewalk_color: Color = SIDEWALK_COLORS[posmod(ix * 13 + iz * 7, SIDEWALK_COLORS.size())]
	Shapes.box(self, Vector3(cx, 0.026, cz), Vector3(27, 0.04, 27), sidewalk_color) # Flat and nonblocking; streets and sidewalks share one physical ground plane.
	var wall_hue := fposmod(float(ix + 3) * 0.207 + float(iz + 3) * 0.133 + rng.randf_range(-0.025, 0.025), 1.0)
	var wall_color := Color.from_hsv(wall_hue, rng.randf_range(0.47, 0.69), rng.randf_range(0.74, 0.91))
	if shop:
		wall_color = Color("#bc8178")
	Shapes.box(self, Vector3(cx, height * 0.5 + 0.02, cz), Vector3(width, height, depth), wall_color, true)
	Shapes.box(self, Vector3(cx, height + 0.31, cz), Vector3(width + 1.0, 0.35, depth + 1.0), wall_color.lightened(0.20))
	var front_z := cz - depth / 2.0
	var door := Vector3(cx, 0, front_z - 1.1)
	Shapes.box(self, Vector3(cx, 1.62, front_z - 0.075), Vector3(2.65, 3.25, 0.14), Color("#162534"))
	Shapes.box(self, Vector3(cx, 2.95, front_z - 0.18), Vector3(3.0, 0.2, 0.28), Color("#00d5c2") if not shop else Color("#ffcc74"))
	Shapes.sign3d(self, "GUN SHOP" if shop else "ENTER", Vector3(cx, 4.05, front_z - 0.6), Color("#ffdf8a") if shop else Color("#91e7df"))
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(2.7, 1.7, 0.13)
	var transforms: Array[Transform3D] = []
	for row in range(2, mini(int(height / 4.1), 7)):
		for col in [-1, 0, 1]:
			if col == 0 and row == 2:
				continue
			var wx: float = cx + float(col) * width * 0.27
			var wy := 1.1 + float(row) * 3.65
			transforms.append(Transform3D(Basis.IDENTITY, Vector3(wx, wy, front_z - 0.075)))
	if not transforms.is_empty():
		var window_batch := MultiMesh.new()
		window_batch.transform_format = MultiMesh.TRANSFORM_3D
		window_batch.mesh = window_mesh
		window_batch.instance_count = transforms.size()
		for win_index in range(transforms.size()):
			window_batch.set_instance_transform(win_index, transforms[win_index])
		var windows := MultiMeshInstance3D.new()
		windows.name = "BuildingWindows"
		windows.multimesh = window_batch
		windows.material_override = Shapes.material(Color("#638b98"))
		add_child(windows)
	buildings.append({
		"id": "lot_%d_%d" % [ix, iz],
		"position": Vector3(cx, 0, cz),
		"door": door,
		"shop": shop,
		"height": height,
		"width": width,
		"depth": depth,
		"wall_color": wall_color,
		"sidewalk_color": sidewalk_color
	})


func add_street_props() -> void:
	# Place lamps beside building facades rather than intersection corners.
	# The intersection stop-line and sidewalk corridors stay clear.
	var lights := Node3D.new()
	lights.name = "StreetLamps"
	add_child(lights)
	for building_index in range(buildings.size()):
		if OS.get_name() == "Android" and building_index % 2 != 0:
			continue
		var building: Dictionary = buildings[building_index]
		var center: Vector3 = building["position"]
		var width: float = float(building["width"])
		var depth: float = float(building["depth"])
		var lamp_position := Vector3(center.x + width * 0.5 + 0.52, 0.05, center.z)
		var lamp := Node3D.new()
		lamp.name = "FacadeLamp"
		lamp.position = lamp_position
		lamp.set_meta("lot", String(building["id"]))
		lights.add_child(lamp)
		Shapes.box(lamp, Vector3(0, 1.9, 0), Vector3(0.20, 3.8, 0.20), Color("#344350"))
		# The arm points inward toward the facade and away from the sidewalk lane.
		Shapes.box(lamp, Vector3(-0.48, 3.85, 0), Vector3(1.10, 0.14, 0.17), Color("#425c66"))
		Shapes.box(lamp, Vector3(-0.90, 3.73, 0), Vector3(0.45, 0.08, 0.40), Color("#ffeab2"))


func spawn_traffic() -> void:
	for i in range(18):
		var axis := i % 2
		var travel := 1.0 if ((i / 2) % 2) == 0 else -1.0
		var street := float(rng.randi_range(-3, 3)) * 36.0
		var lane := street + (2.35 if travel < 0 else -2.35)
		var car: PocketVehicle = VehicleScene.new()
		var paint := Color.from_hsv(rng.randf(), 0.48, 0.85)
		car.setup(axis, travel, lane, paint)
		if axis == 0:
			car.position = Vector3(lane, 1.00, rng.randf_range(-102.0, 102.0))
		else:
			car.position = Vector3(rng.randf_range(-102.0, 102.0), 1.00, lane)
		car_root.add_child(car)
		cars.append(car)


func spawn_civilians() -> void:
	for i in range(46):
		var v := float(rng.randi_range(-3, 3)) * 36.0
		var block := rng.randi_range(-3, 2)
		var along := float(block) * 36.0 + rng.randf_range(8.5, 27.5)
		var person: PocketActor = ActorScene.new()
		var seed_number := rng.randi()
		if i % 2 == 0:
			person.position = Vector3(v + 6.35, 0.13, along)
		else:
			person.position = Vector3(along, 0.13, v + 6.35)
		person.setup(false, person.position, seed_number, i % 2)
		person.resident_id = i
		person_root.add_child(person)
		people.append(person)


func add_police_near(at: Vector3, seed_value: int) -> PocketActor:
	var cop: PocketActor = ActorScene.new()
	var street_x := roundf(at.x / 36.0) * 36.0
	var walk_z := clampf(at.z + rng.randf_range(-19.0, 19.0), -110.0, 110.0)
	cop.position = Vector3(street_x + 6.35, 0.24, walk_z)
	cop.setup(true, cop.position, seed_value)
	cop.navigation = navigation
	police_root.add_child(cop)
	return cop


func closest_door(at: Vector3, distance_max: float = 3.6) -> Dictionary:
	var found: Dictionary = {}
	var best := distance_max
	for item in buildings:
		var d: Vector3 = item["door"]
		var dist := Vector2(at.x - d.x, at.z - d.z).length()
		if dist < best:
			best = dist
			found = item
	return found


func closest_car(at: Vector3, distance_max: float = 4.5) -> PocketVehicle:
	var found: PocketVehicle = null
	var best := distance_max
	for car in cars:
		if not is_instance_valid(car):
			continue
		var dist := car.global_position.distance_to(at)
		if dist < best:
			found = car
			best = dist
	return found

func closest_resident(at: Vector3, distance_max: float = 3.0) -> PocketActor:
	var nearest: PocketActor = null
	var best := distance_max
	for person in people:
		if not is_instance_valid(person) or person.dead or person.panic_time > 0.0:
			continue
		var distance := Vector2(at.x - person.global_position.x, at.z - person.global_position.z).length()
		if distance < best:
			best = distance
			nearest = person
	return nearest


func replenish_pedestrians() -> Array[PocketActor]:
	var newcomers: Array[PocketActor] = []
	for index in range(people.size()):
		if is_instance_valid(people[index]):
			continue
		var axis := index % 2
		var road := float(rng.randi_range(-3, 3)) * 36.0
		var block := float(rng.randi_range(-3, 2)) * 36.0
		var along := block + rng.randf_range(10.0, 25.0)
		var person: PocketActor = ActorScene.new()
		if axis == 0:
			person.position = Vector3(road + 6.35, 0.13, along)
		else:
			person.position = Vector3(along, 0.13, road + 6.35)
		person.setup(false, person.position, rng.randi(), axis)
		person.resident_id = index
		person_root.add_child(person)
		people[index] = person
		newcomers.append(person)
	return newcomers


# Android's Godot editor runs the game alongside the editor itself, leaving less
# RAM and CPU/GPU headroom than a standalone exported build. Keep the 46 resident
# identities and all traffic slots, but stop simulating and drawing distant actors.
# Call at a low frequency from main.gd; never disable police or active carjacking.
const RESIDENT_ACTIVE_DISTANCE_SQ := 65.0 * 65.0
const CAR_ACTIVE_DISTANCE_SQ := 100.0 * 100.0

func update_mobile_activity(focus: Vector3, driven_car: PocketVehicle = null) -> void:
	for person in people:
		if not is_instance_valid(person):
			continue
		var horizontal := Vector2(person.global_position.x - focus.x, person.global_position.z - focus.z)
		var active := horizontal.length_squared() <= RESIDENT_ACTIVE_DISTANCE_SQ or person.chatting or person.dead or person.panic_time > 0.0
		if person.visible != active:
			person.visible = active
			person.set_process(active)
			person.set_physics_process(active)
			person.collision_layer = 2 if active else 0
	for car in cars:
		if not is_instance_valid(car):
			continue
		var horizontal := Vector2(car.global_position.x - focus.x, car.global_position.z - focus.z)
		var active := horizontal.length_squared() <= CAR_ACTIVE_DISTANCE_SQ or car == driven_car or car.occupied or car.being_stolen
		if car.visible != active:
			car.visible = active
			car.set_process(active)
			car.set_physics_process(active)
			car.collision_layer = 8 if active else 0


func restore_all_activity() -> void:
	# Used by tests and when the performance mode is switched off.
	for person in people:
		if not is_instance_valid(person):
			continue
		person.visible = true
		person.set_process(true)
		person.set_physics_process(true)
		person.collision_layer = 2
	for car in cars:
		if not is_instance_valid(car):
			continue
		car.visible = true
		car.set_process(true)
		car.set_physics_process(true)
		car.collision_layer = 8

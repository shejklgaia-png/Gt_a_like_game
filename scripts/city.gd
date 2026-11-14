extends Node3D
class_name PocketCity

const Shapes = preload("res://scripts/shape_factory.gd")
const VehicleScene = preload("res://scripts/vehicle.gd")
const ActorScene = preload("res://scripts/actor.gd")
var buildings: Array[Dictionary] = []
var cars: Array[PocketVehicle] = []
var people: Array[PocketActor] = []
var rng := RandomNumberGenerator.new()
var car_root: Node3D
var person_root: Node3D
var police_root: Node3D
const ROAD_COLOR := Color("#293341")
const SIDEWALK_COLOR := Color("#697480")


func build_city() -> void:
	rng.seed = 234894
	Shapes.box(self, Vector3(0, -0.44, 0), Vector3(280, 0.7, 280), Color("#465958"), true)
	for n in range(-3, 4):
		var pos := float(n) * 36.0
		Shapes.box(self, Vector3(pos, -0.015, 0), Vector3(10.0, 0.12, 246), ROAD_COLOR)
		Shapes.box(self, Vector3(0, -0.012, pos), Vector3(246, 0.12, 10.0), ROAD_COLOR)
		for k in range(-12, 13):
			Shapes.box(self, Vector3(pos, 0.056, k * 9.0), Vector3(0.13, 0.015, 3.5), Color("#aab2a0"))
			Shapes.box(self, Vector3(k * 9.0, 0.058, pos), Vector3(3.5, 0.015, 0.13), Color("#aab2a0"))
	add_crosswalks()
	for ix in range(-3, 3):
		for iz in range(-3, 3):
			create_building(ix, iz)
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


func add_crosswalks() -> void:
	# Zebra stripes exactly aligned with the two sidewalk lines at every intersection.
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var x := float(ix) * 36.0
			var z := float(iz) * 36.0
			for stripe in range(6):
				var offset := float(stripe) * 1.45 - 3.65
				for side in [-1.0, 1.0]:
					Shapes.box(self, Vector3(x + side * 6.35, 0.073, z + offset), Vector3(2.0, 0.02, 0.6), Color("#e7ebdc"))
					Shapes.box(self, Vector3(x + offset, 0.074, z + side * 6.35), Vector3(0.6, 0.02, 2.0), Color("#e7ebdc"))


func create_building(ix: int, iz: int) -> void:
	var cx := (float(ix) + 0.5) * 36.0
	var cz := (float(iz) + 0.5) * 36.0
	var tall := rng.randi_range(11, 32)
	var height := float(tall)
	var width := rng.randf_range(20.0, 24.0)
	var depth := rng.randf_range(19.0, 24.0)
	var shop := ix == 0 and iz == -1
	if shop:
		height = 12.0
	Shapes.box(self, Vector3(cx, 0.09, cz), Vector3(27, 0.24, 27), SIDEWALK_COLOR, true)
	var wall_color := Color.from_hsv(rng.randf_range(0.52, 0.68), rng.randf_range(0.12, 0.30), rng.randf_range(0.42, 0.75))
	if shop:
		wall_color = Color("#444d60")
	Shapes.box(self, Vector3(cx, height * 0.5 + 0.22, cz), Vector3(width, height, depth), wall_color, true)
	Shapes.box(self, Vector3(cx, height + 0.31, cz), Vector3(width + 1.0, 0.35, depth + 1.0), wall_color.lightened(0.20))
	var front_z := cz - depth / 2.0
	var door := Vector3(cx, 0, front_z - 1.1)
	Shapes.box(self, Vector3(cx, 1.62, front_z - 0.075), Vector3(2.65, 3.25, 0.14), Color("#162534"))
	Shapes.box(self, Vector3(cx, 2.95, front_z - 0.18), Vector3(3.0, 0.2, 0.28), Color("#00d5c2") if not shop else Color("#ffcc74"))
	Shapes.sign3d(self, "GUN SHOP" if shop else "ENTER", Vector3(cx, 4.05, front_z - 0.6), Color("#ffdf8a") if shop else Color("#91e7df"))
	for row in range(2, mini(int(height / 4.1), 7)):
		for col in [-1, 0, 1]:
			if col == 0 and row == 2:
				continue
			var wx: float = cx + float(col) * width * 0.27
			var wy := 1.1 + float(row) * 3.65
			Shapes.box(self, Vector3(wx, wy, front_z - 0.075), Vector3(2.7, 1.7, 0.13), Color("#638b98"))
	buildings.append({
		"id": "lot_%d_%d" % [ix, iz],
		"position": Vector3(cx, 0, cz),
		"door": door,
		"shop": shop,
		"height": height
	})


func add_street_props() -> void:
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var x := float(ix) * 36.0 + 7.2
			var z := float(iz) * 36.0 + 7.2
			Shapes.box(self, Vector3(x, 1.9, z), Vector3(0.22, 3.8, 0.22), Color("#253244"))
			Shapes.box(self, Vector3(x, 3.85, z - 0.8), Vector3(0.17, 0.14, 1.7), Color("#273443"))
			Shapes.box(self, Vector3(x, 3.8, z - 1.4), Vector3(0.55, 0.11, 0.48), Color("#c9d8a1"))


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
		person_root.add_child(person)
		people.append(person)


func add_police_near(at: Vector3, seed_value: int) -> PocketActor:
	var cop: PocketActor = ActorScene.new()
	var street_x := roundf(at.x / 36.0) * 36.0
	var walk_z := clampf(at.z + rng.randf_range(-19.0, 19.0), -110.0, 110.0)
	cop.position = Vector3(street_x + 6.35, 0.24, walk_z)
	cop.setup(true, cop.position, seed_value)
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

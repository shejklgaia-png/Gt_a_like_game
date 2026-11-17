extends RefCounted
## Cheap road geometry. Ground-level links are visual on the already physical
## world floor; elevated segments use collision so cars/players can traverse.
const Shapes = preload("res://scripts/shape_factory.gd")
const ROAD := Color("#283441")
const FREEWAY := Color("#394956")
const ALLEY := Color("#36414b")

static func install(parent: Node3D, buildings: Array[Dictionary]) -> void:
	var root := Node3D.new()
	root.name = "RoadNetworkExtensions"
	parent.add_child(root)
	add_arterials(root)
	add_curved_connectors(root)
	add_alley_lanes(root, buildings)
	add_freeway(root)


static func road_segment(root: Node3D, from: Vector3, to: Vector3, width: float, tint: Color, solid: bool = false) -> void:
	var direction := to - from
	var length := direction.length()
	if length <= 0.05:
		return
	var forward := direction / length
	var lateral := Vector3.UP.cross(forward).normalized()
	if lateral.length_squared() <= 0.01:
		return
	var up := forward.cross(lateral).normalized()
	var road := Shapes.box(root, (from + to) * 0.5, Vector3(width, 0.32 if solid else 0.035, length + 0.15), tint, solid)
	road.basis = Basis(lateral, up, forward).orthonormalized()


static func add_arterials(root: Node3D) -> void:
	var arterials := Node3D.new()
	arterials.name = "Boulevards"
	root.add_child(arterials)
	# Wider boulevard stretches; the original intersection lights and lanes
	# stay in the same places. 11.2 m fits inside existing 12.7 m curb gap.
	Shapes.box(arterials, Vector3(0, 0.041, 0), Vector3(11.2, 0.035, 246), Color("#344457"))
	Shapes.box(arterials, Vector3(0, 0.042, 0), Vector3(246, 0.035, 11.2), Color("#344457"))
	for along in range(-11, 12):
		var p: float = float(along) * 10.0
		Shapes.box(arterials, Vector3(0, 0.068, p), Vector3(0.22, 0.012, 3.3), Color("#c7ab6d"))
		Shapes.box(arterials, Vector3(p, 0.069, 0), Vector3(3.3, 0.012, 0.22), Color("#c7ab6d"))


static func add_curved_connectors(root: Node3D) -> void:
	var curves := Node3D.new()
	curves.name = "CurvedPerimeterRoads"
	root.add_child(curves)
	# Exterior ring links allow drivers to follow the curves around the city.
	for side in [-1.0, 1.0]:
		road_segment(curves, Vector3(side * 128.0, 0.04, -98), Vector3(side * 128.0, 0.04, 98), 7.8, ROAD)
		road_segment(curves, Vector3(-98, 0.04, side * 128.0), Vector3(98, 0.04, side * 128.0), 7.8, ROAD)
	# Quarter-circle connector: the road is an actual sequence of tangent
	# surfaces, not painted scenery. Corners reach the outer ring roads.
	for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var sx: float = corner.x
		var sz: float = corner.y
		var points: Array[Vector3] = []
		for step in range(17):
			var angle := float(step) / 16.0 * PI * 0.5
			points.append(Vector3(sx * (98.0 + cos(angle) * 30.0), 0.04, sz * (98.0 + sin(angle) * 30.0)))
		for i in range(points.size() - 1):
			road_segment(curves, points[i], points[i + 1], 7.8, ROAD)
		# Short approach links make the arc visibly continuous with the grid.
		road_segment(curves, Vector3(sx * 108.0, 0.04, sz * 98.0), points[0], 7.8, ROAD)
		road_segment(curves, points[16], Vector3(sx * 98.0, 0.04, sz * 108.0), 7.8, ROAD)


static func add_alley_lanes(root: Node3D, buildings: Array[Dictionary]) -> void:
	var alleys := Node3D.new()
	alleys.name = "ServiceAlleys"
	root.add_child(alleys)
	for lot in buildings:
		if not bool(lot.get("alley", false)):
			continue
		var center: Vector3 = lot["block_center"]
		var x := center.x + 8.4
		road_segment(alleys, Vector3(x, 0.055, center.z - 17.9), Vector3(x, 0.055, center.z + 17.9), 3.4, ALLEY)
		# Loading bays, dumpsters and a service sign mark alley use.
		Shapes.box(alleys, Vector3(x + 2.1, 0.47, center.z + 4.1), Vector3(0.7, 0.94, 0.7), Color("#5a6669"))
		Shapes.sign3d(alleys, "SERVICE LANE", Vector3(x, 3.0, center.z - 10.0), Color("#b9c8d3"))


static func add_freeway(root: Node3D) -> void:
	var freeway := Node3D.new()
	freeway.name = "ElevatedFreeway"
	root.add_child(freeway)
	# An elevated east-west road above the northern edge of the district,
	# accessed by a long ramp at each end. Segments are physically walkable
	# and driveable (rises 7m over a 36m ramp length).
	var main_from := Vector3(-104, 7.0, 137)
	var main_to := Vector3(104, 7.0, 137)
	for index in range(13):
		var a: Vector3 = main_from.lerp(main_to, float(index) / 13.0)
		var b: Vector3 = main_from.lerp(main_to, float(index + 1) / 13.0)
		road_segment(freeway, a, b, 9.8, FREEWAY, true)
	road_segment(freeway, Vector3(-144, 0.25, 137), main_from, 9.8, FREEWAY, true)
	road_segment(freeway, main_to, Vector3(144, 0.25, 137), 9.8, FREEWAY, true)
	# The ground roads lead into each ramp; no invisible access barriers.
	road_segment(freeway, Vector3(-162, 0.055, 137), Vector3(-144, 0.055, 137), 9.8, ROAD)
	road_segment(freeway, Vector3(144, 0.055, 137), Vector3(162, 0.055, 137), 9.8, ROAD)
	for index in range(-5, 6):
		var x: float = float(index) * 18.0
		Shapes.box(freeway, Vector3(x, 3.15, 137), Vector3(1.7, 6.3, 1.7), Color("#56616c"))
	# Guards are visual on mobile to keep collision geometry bounded.
	for rail_side in [-1.0, 1.0]:
		for segment in range(-5, 6):
			var x: float = float(segment) * 19.0
			Shapes.box(freeway, Vector3(x, 7.32, 137.0 + rail_side * 5.0), Vector3(18.7, 0.5, 0.23), Color("#879aa5"))
	Shapes.sign3d(freeway, "CITY EXPRESSWAY", Vector3(0, 11.0, 137), Color("#c3e2d8"))


static func perimeter_route() -> Array[Vector3]:
	# Clockwise path following the actual perimeter road and four round corners.
	var points: Array[Vector3] = [Vector3(128, 0, -98), Vector3(128, 0, 98)]
	for part in range(4):
		var center := Vector2(98, 98)
		var first_angle := 0.0
		match part:
			0:
				center = Vector2(98, 98)
				first_angle = 0.0
			1:
				center = Vector2(-98, 98)
				first_angle = PI * 0.5
			2:
				center = Vector2(-98, -98)
				first_angle = PI
			_:
				center = Vector2(98, -98)
				first_angle = PI * 1.5
		for step in range(1, 9):
			var a := first_angle + float(step) / 8.0 * PI * 0.5
			points.append(Vector3(center.x + cos(a) * 30.0, 0, center.y + sin(a) * 30.0))
		match part:
			0: points.append(Vector3(-98, 0, 128))
			1: points.append(Vector3(-128, 0, -98))
			2: points.append(Vector3(98, 0, -128))
	return points


static func freeway_route() -> Array[Vector3]:
	return [
		Vector3(-159, 0, 137), Vector3(-144, 0.25, 137),
		Vector3(-104, 7, 137), Vector3(-50, 7, 137),
		Vector3(50, 7, 137), Vector3(104, 7, 137),
		Vector3(144, 0.25, 137), Vector3(159, 0, 137)
	]

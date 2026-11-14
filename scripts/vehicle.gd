extends CharacterBody3D
class_name PocketVehicle

const Shapes = preload("res://scripts/shape_factory.gd")
var occupied: bool = false
var being_stolen: bool = false
var npc_speed: float = 10.0
var drive_speed: float = 0.0
var axis: int = 0
var travel: float = 1.0
var road_lane: float = 0.0
var drive_input: Vector2 = Vector2.ZERO
var nitro: bool = false
var tint: Color = Color("#e5bd64")
var door_hinge: Node3D
var door_open: bool = false
var door_angle: float = 0.0
var brake_lights: Array[MeshInstance3D] = []


func setup(p_axis: int, p_travel: float, p_lane: float, color: Color) -> void:
	axis = p_axis
	travel = p_travel
	road_lane = p_lane
	tint = color


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(2.3, 1.45, 4.5)
	shape.shape = box_shape
	shape.position = Vector3(0, 0.32, 0)
	add_child(shape)
	Shapes.box(self, Vector3(0, -0.12, 0), Vector3(2.15, 0.65, 4.25), tint)
	Shapes.box(self, Vector3(0, 0.48, 0.25), Vector3(1.82, 0.85, 2.45), tint.darkened(0.17))
	Shapes.box(self, Vector3(0, 0.51, -1.02), Vector3(1.62, 0.62, 0.06), Color("#456574"))
	Shapes.box(self, Vector3(0, 0.55, 1.50), Vector3(1.60, 0.34, 0.05), Color("#456574"))
	door_hinge = Node3D.new()
	door_hinge.position = Vector3(-1.10, 0.22, -1.18)
	add_child(door_hinge)
	Shapes.box(door_hinge, Vector3(-0.01, 0.0, 0.61), Vector3(0.12, 0.74, 1.22), tint.darkened(0.12))
	Shapes.box(door_hinge, Vector3(-0.09, 0.07, 0.62), Vector3(0.055, 0.11, 0.22), Color("#2f3942"))
	for side in [-1.0, 1.0]:
		for fore_aft in [-1.45, 1.45]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.43
			wheel_mesh.bottom_radius = 0.43
			wheel_mesh.height = 0.25
			wheel.mesh = wheel_mesh
			wheel.material_override = Shapes.material(Color("#101820"))
			wheel.position = Vector3(side * 1.08, -0.46, fore_aft)
			wheel.rotation.z = PI / 2.0
			add_child(wheel)
	for side in [-0.78, 0.78]:
		Shapes.box(self, Vector3(side, -0.12, -2.15), Vector3(0.33, 0.20, 0.05), Color("#fff1bc"))
		var light := Shapes.box(self, Vector3(side, -0.12, 2.15), Vector3(0.33, 0.20, 0.05), Color("#c92d4c"))
		if light.get_child_count() > 0 and light.get_child(0) is MeshInstance3D:
			brake_lights.append(light.get_child(0) as MeshInstance3D)


func _process(delta: float) -> void:
	var target_angle := -1.18 if door_open else 0.0
	door_angle = lerpf(door_angle, target_angle, clampf(delta * 11.0, 0.0, 1.0))
	if is_instance_valid(door_hinge):
		door_hinge.rotation.y = door_angle


func open_driver_door(open: bool) -> void:
	door_open = open


func entrance_point() -> Vector3:
	return global_position + global_transform.basis.x * -2.05 + global_transform.basis.z * -0.50


func pedestrian_ahead() -> bool:
	if occupied or being_stolen:
		return false
	var origin := global_position + Vector3(0, 0.05, 0) - global_transform.basis.z * 2.45
	var tip := origin - global_transform.basis.z * 7.2
	var params := PhysicsRayQueryParameters3D.create(origin, tip)
	params.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.is_empty():
		return false
	var collider: Object = result.get("collider")
	if collider is PocketHero:
		return not (collider as PocketHero).dead
	if collider is PocketActor:
		return not (collider as PocketActor).dead
	if collider is PocketVehicle:
		return true
	return false


func _physics_process(delta: float) -> void:
	if being_stolen:
		drive_speed = move_toward(drive_speed, 0.0, delta * 36.0)
		velocity = -global_transform.basis.z * drive_speed
	elif occupied:
		var max_speed := 33.0 if nitro else 22.0
		var throttle := clampf(-drive_input.y, -1.0, 1.0)
		var wanted_speed := throttle * max_speed
		drive_speed = move_toward(drive_speed, wanted_speed, delta * (23.0 if absf(throttle) > 0.05 else 13.0))
		var turn_factor := clampf(absf(drive_speed) / 8.0, 0.0, 1.0)
		rotation.y -= drive_input.x * delta * 1.55 * turn_factor * (1.0 if drive_speed >= 0 else -1.0)
		velocity = -global_transform.basis.z * drive_speed
	else:
		var heading := Vector3.ZERO
		if axis == 0:
			heading.z = travel
		else:
			heading.x = travel
		rotation.y = atan2(-heading.x, -heading.z)
		var desired := 0.0 if pedestrian_ahead() else npc_speed
		drive_speed = move_toward(drive_speed, desired, delta * (26.0 if desired == 0.0 else 8.0))
		velocity = heading * drive_speed
	move_and_slide()
	if not occupied and not being_stolen:
		if axis == 0 and absf(position.z) > 121.0:
			position.z = -signf(position.z) * 120.0
		elif axis == 1 and absf(position.x) > 121.0:
			position.x = -signf(position.x) * 120.0
	for item in brake_lights:
		if is_instance_valid(item):
			item.material_override = Shapes.material(Color("#ff4b50") if drive_speed < 1.0 else Color("#c92d4c"))

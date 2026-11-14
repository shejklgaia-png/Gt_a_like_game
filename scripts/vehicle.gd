extends CharacterBody3D
class_name PocketVehicle

const Shapes = preload("res://scripts/shape_factory.gd")
var occupied: bool = false
var npc_speed: float = 10.0
var drive_speed: float = 0.0
var axis: int = 0
var travel: float = 1.0
var road_lane: float = 0.0
var steering: float = 0.0
var drive_input: Vector2 = Vector2.ZERO
var nitro: bool = false
var tint: Color = Color("#e5bd64")


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
		Shapes.box(self, Vector3(side, -0.12, 2.15), Vector3(0.33, 0.20, 0.05), Color("#c92d4c"))


func _physics_process(delta: float) -> void:
	if occupied:
		var max_speed := 33.0 if nitro else 22.0
		var throttle := clampf(-drive_input.y, -1.0, 1.0)
		var wanted_speed := throttle * max_speed
		drive_speed = move_toward(drive_speed, wanted_speed, delta * (23.0 if absf(throttle) > 0.05 else 13.0))
		var turn_factor := clampf(absf(drive_speed) / 8.0, 0.0, 1.0)
		rotation.y -= drive_input.x * delta * 1.55 * turn_factor * (1.0 if drive_speed >= 0 else -1.0)
		velocity = -global_transform.basis.z * drive_speed
	else:
		drive_speed = npc_speed
		var heading := Vector3.ZERO
		if axis == 0:
			heading.z = travel
			position.z += 0.0
		else:
			heading.x = travel
		rotation.y = atan2(-heading.x, -heading.z)
		velocity = heading * npc_speed
	move_and_slide()
	if not occupied:
		if axis == 0 and absf(position.z) > 121.0:
			position.z = -signf(position.z) * 120.0
		elif axis == 1 and absf(position.x) > 121.0:
			position.x = -signf(position.x) * 120.0

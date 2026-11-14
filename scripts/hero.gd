extends CharacterBody3D
class_name PocketHero

const Shapes = preload("res://scripts/shape_factory.gd")
var hp: float = 100.0
var max_hp: float = 100.0
var speed_walk: float = 7.0
var speed_sprint: float = 12.0
var body_visual: Node3D

func _ready() -> void:
	var hitbox := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	hitbox.shape = capsule
	hitbox.position.y = 1.0
	add_child(hitbox)
	body_visual = Node3D.new()
	add_child(body_visual)
	Shapes.box(body_visual, Vector3(0, 1.15, 0), Vector3(0.73, 0.95, 0.42), Color("#3b9da8"))
	Shapes.ball(body_visual, Vector3(0, 1.86, 0), 0.32, Color("#e2b28e"))
	Shapes.box(body_visual, Vector3(-0.24, 0.46, 0), Vector3(0.22, 0.88, 0.28), Color("#1d2835"))
	Shapes.box(body_visual, Vector3(0.24, 0.46, 0), Vector3(0.22, 0.88, 0.28), Color("#1d2835"))
	Shapes.box(body_visual, Vector3(0.48, 1.16, -0.20), Vector3(0.18, 0.65, 0.20), Color("#d49b7b"))
	Shapes.box(body_visual, Vector3(0.53, 1.06, -0.48), Vector3(0.15, 0.17, 0.57), Color("#292d38"))


func walk(input: Vector2, sprint: bool, camera: Camera3D, delta: float) -> void:
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var dir := (right * input.x + forward * -input.y).normalized()
	var desired_speed := speed_sprint if sprint else speed_walk
	velocity.x = dir.x * desired_speed
	velocity.z = dir.z * desired_speed
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if dir.length_squared() > 0.02:
		var yaw := atan2(-dir.x, -dir.z)
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, yaw - rotation.y, minf(1.0, delta * 10.0))


func hurt(points: float) -> void:
	hp = maxf(0.0, hp - points)


func reset_health() -> void:
	hp = max_hp

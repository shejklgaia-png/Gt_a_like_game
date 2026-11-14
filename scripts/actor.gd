extends CharacterBody3D
class_name PocketActor

signal injured(actor: PocketActor)
signal died(actor: PocketActor)

const Shapes = preload("res://scripts/shape_factory.gd")
var officer: bool = false
var health: float = 80.0
var anchor: Vector3 = Vector3.ZERO
var target: Vector3 = Vector3.ZERO
var chase_target: Node3D
var engage: bool = false
var sidewalk_axis: int = 0
var strike_cooldown: float = 0.0
var rng := RandomNumberGenerator.new()


func setup(is_officer: bool, initial_anchor: Vector3, seed_value: int, p_axis: int = 0) -> void:
	officer = is_officer
	sidewalk_axis = p_axis
	anchor = initial_anchor
	target = anchor
	rng.seed = seed_value


func _ready() -> void:
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.31
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.93
	add_child(collider)
	var outfit: Color = Color("#334f85") if officer else Color.from_hsv(rng.randf(), 0.36, 0.83)
	Shapes.box(self, Vector3(0, 1.12, 0), Vector3(0.65, 0.86, 0.36), outfit)
	Shapes.ball(self, Vector3(0, 1.75, 0), 0.28, Color("#caa48f"))
	Shapes.box(self, Vector3(-0.18, 0.38, 0), Vector3(0.20, 0.7, 0.25), Color("#263144"))
	Shapes.box(self, Vector3(0.18, 0.38, 0), Vector3(0.20, 0.7, 0.25), Color("#263144"))
	if officer:
		Shapes.box(self, Vector3(0, 2.05, 0), Vector3(0.63, 0.16, 0.49), Color("#14263e"))
		Shapes.box(self, Vector3(0, 1.18, -0.205), Vector3(0.22, 0.18, 0.025), Color("#9acde4"))
	else:
		Shapes.box(self, Vector3(0, 1.98, 0), Vector3(0.55, 0.17, 0.47), Color("#423a43"))


func _physics_process(delta: float) -> void:
	strike_cooldown = maxf(0.0, strike_cooldown - delta)
	if officer and engage and is_instance_valid(chase_target):
		target = chase_target.global_position
	elif global_position.distance_to(target) < 1.4:
		if sidewalk_axis == 0:
			target = anchor + Vector3(0.0, 0.0, rng.randf_range(-12.0, 12.0))
		else:
			target = anchor + Vector3(rng.randf_range(-12.0, 12.0), 0.0, 0.0)
	var direction := target - global_position
	direction.y = 0
	var distance := direction.length()
	if distance > (2.6 if officer and engage else 0.8):
		var speed := 6.0 if officer and engage else 2.0
		velocity.x = direction.normalized().x * speed
		velocity.z = direction.normalized().z * speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = -0.4
	move_and_slide()


func hit(points: float) -> void:
	health -= points
	injured.emit(self)
	if health <= 0:
		died.emit(self)
		queue_free()

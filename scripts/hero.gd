extends CharacterBody3D
class_name PocketHero

signal damaged(points: float)
signal died

const Shapes = preload("res://scripts/shape_factory.gd")
const GunModels = preload("res://scripts/gun_models.gd")

var hp: float = 100.0
var max_hp: float = 100.0
var speed_walk: float = 7.0
var speed_sprint: float = 12.0
var body_visual: Node3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var gun_mount: Node3D
var gun_model: Node3D
var muzzle: Marker3D
var move_amount: float = 0.0
var stride_time: float = 0.0
var recoil_amount: float = 0.0
var pain_time: float = 0.0
var death_time: float = 0.0
var dead: bool = false
var carjacking: bool = false
var carjack_time: float = 0.0
var weapon_kind: String = "Handgun"


func _ready() -> void:
	var hitbox := CollisionShape3D.new()
	hitbox.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	hitbox.shape = capsule
	hitbox.position.y = 1.0
	add_child(hitbox)
	body_visual = Node3D.new()
	body_visual.name = "Visual"
	add_child(body_visual)
	Shapes.box(body_visual, Vector3(0, 1.24, 0), Vector3(0.73, 0.86, 0.42), Color("#3b9da8"))
	Shapes.ball(body_visual, Vector3(0, 1.92, 0), 0.30, Color("#e2b28e"))
	Shapes.box(body_visual, Vector3(0, 0.88, -0.02), Vector3(0.69, 0.23, 0.43), Color("#273e4e"))
	arm_left = limb(Vector3(-0.48, 1.56, 0.0), Vector3(0.21, 0.74, 0.27), Color("#c69b80"), -0.34)
	arm_right = limb(Vector3(0.48, 1.56, 0.0), Vector3(0.21, 0.74, 0.27), Color("#c69b80"), -0.34)
	leg_left = limb(Vector3(-0.23, 0.86, 0.0), Vector3(0.26, 0.87, 0.32), Color("#1d2835"), -0.42)
	leg_right = limb(Vector3(0.23, 0.86, 0.0), Vector3(0.26, 0.87, 0.32), Color("#1d2835"), -0.42)
	gun_mount = Node3D.new()
	gun_mount.position = Vector3(0.0, -0.52, -0.33)
	arm_right.add_child(gun_mount)
	equip_weapon(weapon_kind)


func limb(at: Vector3, size: Vector3, tint: Color, offset: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	body_visual.add_child(pivot)
	Shapes.box(pivot, Vector3(0, offset, 0), size, tint)
	return pivot


func equip_weapon(kind: String) -> void:
	weapon_kind = kind
	if is_instance_valid(gun_model):
		gun_model.queue_free()
	gun_model = GunModels.build(gun_mount, kind)
	muzzle = gun_model.get_node("Muzzle") as Marker3D


func face_direction(dir: Vector3, delta: float = 1.0) -> void:
	if dir.length_squared() <= 0.01:
		return
	var yaw := atan2(-dir.x, -dir.z)
	body_visual.rotation.y = lerp_angle(body_visual.rotation.y, yaw - rotation.y, clampf(delta * 13.0, 0.0, 1.0))


func walk(input: Vector2, sprint: bool, camera: Camera3D, delta: float) -> void:
	if dead or carjacking:
		velocity = Vector3.ZERO
		move_amount = 0.0
		return
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	var dir := (right.normalized() * input.x + forward.normalized() * -input.y).normalized()
	var desired_speed := speed_sprint if sprint else speed_walk
	velocity.x = dir.x * desired_speed
	velocity.z = dir.z * desired_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 19.6 * delta
	move_and_slide()
	move_amount = move_toward(move_amount, minf(input.length(), 1.0), delta * 7.0)
	if dir.length_squared() > 0.02:
		face_direction(dir, delta)


func _process(delta: float) -> void:
	pain_time = maxf(0.0, pain_time - delta)
	recoil_amount = move_toward(recoil_amount, 0.0, delta * 5.5)
	if dead:
		death_time += delta
		body_visual.rotation.z = lerp_angle(body_visual.rotation.z, -PI * 0.45, delta * 3.4)
		body_visual.rotation.x = lerp_angle(body_visual.rotation.x, -PI * 0.46, delta * 3.5)
		body_visual.position.y = -minf(death_time * 0.32, 0.36)
		arm_left.rotation.x = 0.1
		arm_right.rotation.x = 0.3
		leg_left.rotation.x = 0.12
		leg_right.rotation.x = -0.25
		return
	var target_walk := move_amount
	if carjacking:
		carjack_time += delta
		target_walk = 0.0
	stride_time += delta * (13.5 if move_amount > 0.05 else 2.0)
	var step := sin(stride_time) * target_walk
	leg_left.rotation.x = lerpf(leg_left.rotation.x, step * 0.58, delta * 10.0)
	leg_right.rotation.x = lerpf(leg_right.rotation.x, -step * 0.58, delta * 10.0)
	arm_left.rotation.x = lerpf(arm_left.rotation.x, -step * 0.4, delta * 9.0)
	var arm_pose := -0.68 - step * 0.10 - recoil_amount * 0.52
	if carjacking:
		arm_pose = -1.5 - sin(minf(carjack_time / 0.7, 1.0) * PI) * 0.6
		body_visual.rotation.z = lerpf(body_visual.rotation.z, -0.17, delta * 11.0)
	else:
		body_visual.rotation.z = lerpf(body_visual.rotation.z, (0.04 if pain_time > 0 else 0.0), delta * 9.0)
	arm_right.rotation.x = lerpf(arm_right.rotation.x, arm_pose, delta * 15.0)
	body_visual.position.y = sin(stride_time * 2.0) * 0.045 * target_walk
	gun_mount.rotation.x = -recoil_amount * 0.22


func kick_recoil(value: float) -> void:
	recoil_amount = clampf(recoil_amount + value, 0.0, 1.0)


func start_carjack() -> void:
	carjacking = true
	carjack_time = 0.0
	move_amount = 0.0
	velocity = Vector3.ZERO


func stop_carjack() -> void:
	carjacking = false
	body_visual.rotation.z = 0.0
	carjack_time = 0.0


func hurt(points: float) -> void:
	if dead:
		return
	hp = maxf(0.0, hp - points)
	pain_time = 0.32
	damaged.emit(points)
	if hp <= 0.0:
		dead = true
		death_time = 0.0
		velocity = Vector3.ZERO
		died.emit()


func reset_health() -> void:
	hp = max_hp
	dead = false
	death_time = 0.0
	body_visual.rotation.x = 0.0
	body_visual.rotation.z = 0.0
	body_visual.position.y = 0.0
	carjacking = false

extends CharacterBody3D
class_name PocketActor

signal injured(actor: PocketActor)
signal died(actor: PocketActor)

const Shapes = preload("res://scripts/shape_factory.gd")
const Fx = preload("res://scripts/combat_fx.gd")
var officer: bool = false
var health: float = 80.0
var anchor: Vector3 = Vector3.ZERO
var target: Vector3 = Vector3.ZERO
var chase_target: Node3D
var engage: bool = false
var strike_cooldown: float = 0.0
var sidewalk_axis: int = 0
var segment_min: float = -10.0
var segment_max: float = 10.0
var rng := RandomNumberGenerator.new()
var visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var walk_cycle: float = 0.0
var moving: float = 0.0
var hurt_clock: float = 0.0
var death_clock: float = 0.0
var dead: bool = false
var attack_clock: float = -1.0
var attack_contact: bool = false
var attack_damage: float = 0.0
var attack_target: Node3D


func setup(is_officer: bool, initial_anchor: Vector3, seed_value: int, p_axis: int = 0) -> void:
	officer = is_officer
	sidewalk_axis = p_axis
	anchor = initial_anchor
	target = anchor
	rng.seed = seed_value
	var along: float = anchor.z if sidewalk_axis == 0 else anchor.x
	var block_index := floori(along / 36.0)
	segment_min = float(block_index) * 36.0 + 6.8
	segment_max = float(block_index + 1) * 36.0 - 6.8
	if not officer:
		select_sidewalk_goal()


func _ready() -> void:
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.31
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.93
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	var outfit: Color = Color("#334f85") if officer else Color.from_hsv(rng.randf(), 0.36, 0.83)
	Shapes.box(visual, Vector3(0, 1.12, 0), Vector3(0.65, 0.86, 0.36), outfit)
	Shapes.ball(visual, Vector3(0, 1.77, 0), 0.28, Color("#caa48f"))
	Shapes.box(visual, Vector3(0, 1.97, 0), Vector3(0.54, 0.16, 0.46), Color("#172d42") if officer else Color("#423a43"))
	left_leg = joint(Vector3(-0.18, 0.85, 0), Vector3(0.20, 0.75, 0.25), Color("#263144"), -0.38)
	right_leg = joint(Vector3(0.18, 0.85, 0), Vector3(0.20, 0.75, 0.25), Color("#263144"), -0.38)
	left_arm = joint(Vector3(-0.44, 1.49, 0), Vector3(0.19, 0.70, 0.23), outfit.darkened(0.09), -0.33)
	right_arm = joint(Vector3(0.44, 1.49, 0), Vector3(0.19, 0.70, 0.23), outfit.darkened(0.09), -0.33)
	if officer:
		Shapes.box(visual, Vector3(0, 1.15, -0.195), Vector3(0.21, 0.18, 0.035), Color("#a2d5e4"))
		Shapes.box(right_arm, Vector3(0.0, -0.64, -0.11), Vector3(0.075, 0.57, 0.08), Color("#101821"))
		Shapes.box(right_arm, Vector3(0.0, -0.94, -0.11), Vector3(0.12, 0.08, 0.13), Color("#69747a"))


func joint(at: Vector3, size: Vector3, tint: Color, height_offset: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	visual.add_child(pivot)
	Shapes.box(pivot, Vector3(0, height_offset, 0), size, tint)
	return pivot


func select_sidewalk_goal() -> void:
	var along := rng.randf_range(segment_min, segment_max)
	if sidewalk_axis == 0:
		target = Vector3(anchor.x, anchor.y, along)
	else:
		target = Vector3(along, anchor.y, anchor.z)


func _physics_process(delta: float) -> void:
	strike_cooldown = maxf(0.0, strike_cooldown - delta)
	if dead:
		velocity = Vector3.ZERO
		return
	if officer and engage and is_instance_valid(chase_target):
		target = chase_target.global_position
	elif global_position.distance_to(target) < 0.9:
		if officer:
			target = anchor + Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-6.0, 6.0))
		else:
			select_sidewalk_goal()
	var direction := target - global_position
	direction.y = 0
	var attack_lock := attack_clock >= 0.0
	var stop_distance := 2.1 if officer and engage else 0.72
	var is_walking := direction.length() > stop_distance and not attack_lock
	if is_walking:
		var speed := 5.2 if officer and engage else 2.1
		var unit_dir := direction.normalized()
		velocity.x = unit_dir.x * speed
		velocity.z = unit_dir.z * speed
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z) - rotation.y, delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 13.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 13.0)
	velocity.y = -0.4 if is_on_floor() else velocity.y - 19.6 * delta
	move_and_slide()
	moving = move_toward(moving, 1.0 if is_walking else 0.0, delta * 7.0)


func _process(delta: float) -> void:
	if dead:
		death_clock += delta
		visual.rotation.z = lerp_angle(visual.rotation.z, -PI * 0.51, delta * 3.3)
		visual.rotation.x = lerp_angle(visual.rotation.x, PI * 0.26, delta * 3.0)
		visual.position.y = -minf(death_clock * 0.20, 0.28)
		if death_clock > 0.7:
			var collider := get_node("CollisionShape3D") as CollisionShape3D
			if not collider.disabled:
				collider.set_deferred("disabled", true)
		if death_clock > 6.0:
			queue_free()
		return
	hurt_clock = maxf(0.0, hurt_clock - delta)
	walk_cycle += delta * (12.5 if officer and engage else 8.4)
	var swing := sin(walk_cycle) * moving
	left_leg.rotation.x = lerpf(left_leg.rotation.x, swing * 0.52, delta * 10.0)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -swing * 0.52, delta * 10.0)
	left_arm.rotation.x = lerpf(left_arm.rotation.x, -swing * 0.34, delta * 10.0)
	var right_pose := swing * 0.34
	if officer:
		right_pose = -0.35 + swing * 0.10
	if attack_clock >= 0.0:
		attack_clock += delta
		var phase := clampf(attack_clock / 0.55, 0.0, 1.0)
		right_pose = lerpf(-2.1, 0.55, sin(phase * PI * 0.5))
		if not attack_contact and phase >= 0.50:
			attack_contact = true
			if is_instance_valid(attack_target) and global_position.distance_to(attack_target.global_position) <= 2.75:
				if attack_target.has_method("hurt"):
					attack_target.hurt(attack_damage)
		if phase >= 1.0:
			attack_clock = -1.0
			attack_target = null
	right_arm.rotation.x = lerpf(right_arm.rotation.x, right_pose, delta * 17.0)
	visual.rotation.z = lerpf(visual.rotation.z, 0.16 if hurt_clock > 0.0 else 0.0, delta * 12.0)
	visual.position.y = sin(walk_cycle * 2.0) * 0.038 * moving


func try_baton_attack(victim: Node3D, points: float) -> bool:
	if dead or not officer or strike_cooldown > 0.0 or attack_clock >= 0.0:
		return false
	if not is_instance_valid(victim) or global_position.distance_to(victim.global_position) > 2.9:
		return false
	strike_cooldown = 1.6
	attack_clock = 0.0
	attack_contact = false
	attack_target = victim
	attack_damage = points
	return true


func hit(points: float) -> void:
	if dead:
		return
	health -= points
	hurt_clock = 0.28
	injured.emit(self)
	Fx.impact(get_parent(), global_position + Vector3(0, 1.12, 0), Color("#e55258"), points)
	if health <= 0.0:
		dead = true
		death_clock = 0.0
		moving = 0.0
		velocity = Vector3.ZERO
		died.emit(self)

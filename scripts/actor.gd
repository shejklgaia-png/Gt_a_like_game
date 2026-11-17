extends CharacterBody3D
class_name PocketActor

signal injured(actor: PocketActor)
signal died(actor: PocketActor)

const Shapes = preload("res://scripts/shape_factory.gd")
const Fx = preload("res://scripts/combat_fx.gd")
const TrafficRules = preload("res://scripts/traffic_rules.gd")
var officer: bool = false
var indoor_mode: bool = false
var mafia: bool = false
var resident_id: int = -1
var chatting: bool = false
var chat_target: Node3D
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
var stalled_time: float = 0.0
var previous_distance: float = INF
var path_queue: Array[Vector3] = []
var crosswalk_waiting: bool = false
var crosswalk_active: bool = false
var panic_time: float = 0.0
var navigation: PocketNavGrid
var pursuit_route := PackedVector2Array()
var pursuit_index: int = 0
var pursuit_refresh: float = 0.0
var last_seen_position := Vector3.ZERO
var lost_sight_time: float = 0.0


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
	# Initial sidewalk navigation must wait until the actor is inside the scene tree.
	# Its previous call here accessed global_position before add_child().


func _ready() -> void:
	# Nonblocking crowds: pedestrians still collide with buildings/ground and remain raycast targets.
	# Cars can see and brake for actors, but actors cannot deadlock each other in the same lane.
	collision_layer = 2
	collision_mask = 1
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
	var outfit: Color = Color("#334f85") if officer else (Color("#443b50") if mafia else Color.from_hsv(rng.randf(), 0.36, 0.83))
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
	elif not indoor_mode:
		select_sidewalk_goal()
	if mafia:
		Shapes.box(visual, Vector3(0, 1.12, -0.205), Vector3(0.24, 0.16, 0.04), Color("#ba485a"))


func joint(at: Vector3, size: Vector3, tint: Color, height_offset: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	visual.add_child(pivot)
	Shapes.box(pivot, Vector3(0, height_offset, 0), size, tint)
	return pivot


func select_sidewalk_goal() -> void:
	# A route has a sidewalk approach, the crossing, then a sidewalk destination.
	# Pedestrians never randomly cut across the vehicular lane.
	path_queue.clear()
	var reference: float = global_position.z if sidewalk_axis == 0 else global_position.x
	if reference == 0.0:
		reference = anchor.z if sidewalk_axis == 0 else anchor.x
	var index := clampi(floori(reference / 36.0), -3, 2)
	var other := index
	if rng.randf() < 0.22:
		other = clampi(index + (1 if rng.randf() < 0.5 else -1), -3, 2)
	var along := float(other) * 36.0 + rng.randf_range(9.0, 27.0)
	var sign_dir := 1.0 if along >= reference else -1.0
	var offset := sign_dir * 0.32
	var lateral := (anchor.x + offset) if sidewalk_axis == 0 else (anchor.z + offset)
	var final_goal := Vector3(lateral, anchor.y, along) if sidewalk_axis == 0 else Vector3(along, anchor.y, lateral)
	if other != index:
		var border := float(maxi(index, other)) * 36.0
		var approach := border - sign_dir * 6.8
		var landing := border + sign_dir * 6.8
		var first := Vector3(lateral, anchor.y, approach) if sidewalk_axis == 0 else Vector3(approach, anchor.y, lateral)
		var second := Vector3(lateral, anchor.y, landing) if sidewalk_axis == 0 else Vector3(landing, anchor.y, lateral)
		target = first
		path_queue.append(second)
		path_queue.append(final_goal)
		crosswalk_waiting = true
	else:
		target = final_goal
		crosswalk_waiting = false
	crosswalk_active = false
	previous_distance = INF
	stalled_time = 0.0


func advance_waypoint() -> void:
	if not path_queue.is_empty():
		if crosswalk_waiting and not TrafficRules.pedestrians_have_green(sidewalk_axis):
			return
		target = path_queue.pop_front()
		if crosswalk_waiting:
			crosswalk_waiting = false
			crosswalk_active = true
		else:
			crosswalk_active = false
		previous_distance = INF
		stalled_time = 0.0
	elif officer:
		target = anchor + Vector3(rng.randf_range(-6.0, 6.0), 0, rng.randf_range(-6.0, 6.0))
	else:
		select_sidewalk_goal()


func flee_from(at: Vector3) -> void:
	if officer or dead:
		return
	var away := global_position - at
	panic_time = 5.0
	var along := away.z if sidewalk_axis == 0 else away.x
	var delta := 12.0 if along >= 0.0 else -12.0
	var axis_value := global_position.z if sidewalk_axis == 0 else global_position.x
	var block := floorf(axis_value / 36.0)
	var extent := clampf(axis_value + delta, block * 36.0 + 7.5, (block + 1.0) * 36.0 - 7.5)
	path_queue.clear()
	crosswalk_waiting = false
	crosswalk_active = false
	target = Vector3(anchor.x, anchor.y, extent) if sidewalk_axis == 0 else Vector3(extent, anchor.y, anchor.z)
	stalled_time = 0.0
	previous_distance = INF


func _physics_process(delta: float) -> void:
	strike_cooldown = maxf(0.0, strike_cooldown - delta)
	panic_time = maxf(0.0, panic_time - delta)
	if dead:
		velocity = Vector3.ZERO
		return
	if indoor_mode:
		var moving_direction := Vector3.ZERO
		if mafia and is_instance_valid(chase_target) and not chase_target.get("dead"):
			var toward: Vector3 = chase_target.global_position - global_position
			toward.y = 0.0
			if toward.length() < 10.0:
				if toward.length() <= 2.75:
					try_baton_attack(chase_target, 8.0)
				elif attack_clock < 0.0:
					moving_direction = toward.normalized()
				if toward.length_squared() > 0.01:
					visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-toward.x, -toward.z) - rotation.y, clampf(delta * 7.0, 0.0, 1.0))
		velocity.x = moving_direction.x * 3.2
		velocity.z = moving_direction.z * 3.2
		velocity.y = -0.4 if is_on_floor() else velocity.y - 19.6 * delta
		move_and_slide()
		moving = move_toward(moving, 1.0 if moving_direction.length_squared() > 0.01 else 0.0, delta * 8.0)
		return
	if chatting and not officer:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.4 if is_on_floor() else velocity.y - 19.6 * delta
		move_and_slide()
		moving = move_toward(moving, 0.0, delta * 8.0)
		if is_instance_valid(chat_target):
			var toward := chat_target.global_position - global_position
			toward.y = 0.0
			if toward.length_squared() > 0.02:
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-toward.x, -toward.z) - rotation.y, clampf(delta * 7.0, 0.0, 1.0))
		return
	if officer and engage and is_instance_valid(chase_target):
		var foe_position: Vector3 = chase_target.global_position
		var target_distance := global_position.distance_to(foe_position)
		var seen := target_distance < 40.0
		if seen:
			var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.7, 0), foe_position + Vector3(0, 1.2, 0))
			ray.exclude = [get_rid()]
			ray.collision_mask = 1
			seen = get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		if seen:
			last_seen_position = foe_position
			lost_sight_time = 0.0
		else:
			lost_sight_time += delta
			if last_seen_position == Vector3.ZERO:
				last_seen_position = foe_position
		if lost_sight_time < 11.0:
			pursuit_refresh -= delta
			if pursuit_refresh <= 0.0:
				pursuit_refresh = 0.8
				if navigation != null:
					pursuit_route = navigation.path(global_position, last_seen_position)
				pursuit_index = 0
			while pursuit_index < pursuit_route.size():
				var next_point := pursuit_route[pursuit_index]
				if Vector2(global_position.x - next_point.x, global_position.z - next_point.y).length() > 1.20:
					break
				pursuit_index += 1
			if pursuit_index < pursuit_route.size():
				var waypoint := pursuit_route[pursuit_index]
				target = Vector3(waypoint.x, foe_position.y, waypoint.y)
			else:
				target = last_seen_position
		else:
			target = anchor
	elif Vector2(global_position.x - target.x, global_position.z - target.z).length() < 0.85:
		advance_waypoint()
	var direction := target - global_position
	direction.y = 0
	var attack_lock := attack_clock >= 0.0
	var stop_distance := 1.2 if officer and engage else 0.72
	var signal_wait := not officer and crosswalk_waiting and direction.length() < 0.9 and not TrafficRules.pedestrians_have_green(sidewalk_axis)
	var is_walking := direction.length() > stop_distance and not attack_lock and not signal_wait
	if is_walking:
		var speed := 5.2 if officer and engage else (4.7 if panic_time > 0.0 else 2.1)
		var unit_dir := direction.normalized()
		velocity.x = unit_dir.x * speed
		velocity.z = unit_dir.z * speed
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z) - rotation.y, delta * 7.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 13.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 13.0)
	velocity.y = -0.4 if is_on_floor() else velocity.y - 19.6 * delta
	move_and_slide()
	if not officer:
		if sidewalk_axis == 0:
			position.x = clampf(position.x, anchor.x - 0.38, anchor.x + 0.38)
		else:
			position.z = clampf(position.z, anchor.z - 0.38, anchor.z + 0.38)
	# Collisions with geometry no longer leave a civilian frozen forever at its target.
	# Reselect a safe lane waypoint when horizontal movement makes no progress.
	if not officer and is_walking:
		var remaining := Vector2(target.x - global_position.x, target.z - global_position.z).length()
		if remaining > previous_distance - 0.025:
			stalled_time += delta
		else:
			stalled_time = maxf(0.0, stalled_time - delta * 2.0)
		previous_distance = remaining
		if stalled_time > 1.8:
			if crosswalk_waiting and not TrafficRules.pedestrians_have_green(sidewalk_axis):
				stalled_time = 0.0
			else:
				select_sidewalk_goal()
	else:
		stalled_time = 0.0
		previous_distance = INF
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
				var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.35, 0), attack_target.global_position + Vector3(0, 1.05, 0))
				ray.collision_mask = 1
				ray.exclude = [get_rid()]
				if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and attack_target.has_method("hurt"):
					attack_target.hurt(attack_damage)
		if phase >= 1.0:
			attack_clock = -1.0
			attack_target = null
	right_arm.rotation.x = lerpf(right_arm.rotation.x, right_pose, delta * 17.0)
	visual.rotation.z = lerpf(visual.rotation.z, 0.16 if hurt_clock > 0.0 else 0.0, delta * 12.0)
	visual.position.y = sin(walk_cycle * 2.0) * 0.038 * moving


func try_baton_attack(victim: Node3D, points: float) -> bool:
	if dead or (not officer and not mafia) or strike_cooldown > 0.0 or attack_clock >= 0.0:
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

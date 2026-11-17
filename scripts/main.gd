extends Node3D

const CityScript = preload("res://scripts/city.gd")
const HeroScript = preload("res://scripts/hero.gd")
const InteriorScript = preload("res://scripts/interior.gd")
const Shapes = preload("res://scripts/shape_factory.gd")
const Fx = preload("res://scripts/combat_fx.gd")
const GameData = preload("res://scripts/gameplay_data.gd")
const SafeSave = preload("res://scripts/safe_save.gd")
const SoundBank = preload("res://scripts/sound_bank.gd")
const MapScript = preload("res://scripts/minimap.gd")
const PerfScript = preload("res://scripts/perf_overlay.gd")
const ResidentDialogue = preload("res://scripts/resident_dialogue.gd")

var WEAPONS: Array[Dictionary] = GameData.weapons()
const SAVE_PATH := "user://pocket_district_save.json"
# Test harnesses can redirect saves without touching an actual player save.
var save_path_override: String = ""

var city: PocketCity
var hero: PocketHero
var interior: PocketInterior
var camera: Camera3D
var sky: WorldEnvironment
var car_driven: PocketVehicle
var indoors: bool = false
var active_building: String = ""
var outdoor_exit: Vector3
var layouts: Dictionary = {}
var looted_buildings: Array[String] = []
var owned_weapons: Array[String] = ["Handgun"]
var current_weapon: int = 0
var ammunition: Dictionary = {"Handgun": 180}
var cash: int = 950
var wanted: int = 0
var wanted_idle: float = 0.0
var police_clock: float = 0.0
var shoot_clock: float = 0.0
var fire_held: bool = false
var sprint_enabled: bool = false
var mission_stage: int = 0
var mission_point := Vector3.ZERO
var mission_marker: Node3D
var mission_marker_label: Label3D
var deliveries: int = 0
var autosave_clock: float = 0.0
var camera_yaw: float = 0.0
var camera_pitch: float = deg_to_rad(69.0)
var camera_distance: float = 16.5
var camera_touch: int = -1
var camera_mouse: bool = false
var carjack_busy: bool = false
var death_pending: bool = false
var hurt_overlay: ColorRect
var sound: PocketSoundBank
var minimap: PocketMiniMap
var perf_overlay: PocketPerfOverlay
var loaded_rounds: Dictionary = {"Handgun": 15}
var reload_clock: float = 0.0
var reload_weapon_id: String = ""
var fire_latched: bool = false
var last_footstep: float = 0.0
var hud_update_clock: float = 0.0
var wanted_cleanup_clock: float = 0.0
var mission_limit: float = 0.0
var mission_reward: int = 0
var mission_failures: int = 0
var total_earnings: int = 0
var mission_last_index: int = 0
var zoom_enabled: bool = false
var pause_button: Button
var reload_button: Button
var aim_button: Button
var settings_panel: Panel
var display_message: String = ""
var display_message_time: float = 0.0
var camera_override_timer: float = 0.0
var crosshair_label: Label
var engine_audio: AudioStreamPlayer3D

var ui: Control
var status_label: Label
var mission_label: Label
var weapon_label: Label
var hint_label: Label
var action_button: Button
var fire_button: Button
var run_button: Button
var weapon_button: Button
var stick_outer: Panel
var stick_knob: Panel
var shop_panel: Panel
var shop_label: Label
var shop_buttons: Dictionary = {}
var stick_pointer: int = -1
var stick_value := Vector2.ZERO
var stick_center := Vector2.ZERO
var mouse_stick: bool = false
var resident_relations: Dictionary = {}
var conversation_actor: PocketActor
var conversation_tree: Dictionary = {}
var conversation_node: String = ""
var dialogue_panel: Panel
var dialogue_speaker: Label
var dialogue_text: Label
var dialogue_options: Array[Button] = []
var dialogue_exit: Button


func _ready() -> void:
	sound = SoundBank.new()
	sound.name = "SoundBank"
	add_child(sound)
	setup_lighting()
	city = CityScript.new()
	city.name = "OutdoorWorld"
	add_child(city)
	city.build_city()
	interior = InteriorScript.new()
	interior.name = "IndoorWorld"
	interior.visible = false
	add_child(interior)
	hero = HeroScript.new()
	hero.name = "Player"
	hero.position = Vector3(18.0, 0.30, -34.0)
	add_child(hero)
	camera = Camera3D.new()
	camera.fov = 69.0
	camera.current = true
	camera.far = 270.0
	add_child(camera)
	camera.position = hero.position + Vector3(0, 16.0, 5.9)
	camera.look_at(hero.position + Vector3(0, 1.0, 0))
	hero.damaged.connect(on_hero_damaged)
	hero.died.connect(on_hero_died)
	for person in city.people:
		connect_actor(person)
	load_game()
	hero.equip_weapon(String(selected_gun()["id"]))
	setup_ui()
	make_mission_marker()
	sound.play_ui("ui")
	get_viewport().size_changed.connect(layout_ui)
	layout_ui()


func setup_lighting() -> void:
	sky = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#819fb4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c7d1d7")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	sky.environment = env
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, -26, 0)
	sun.light_energy = 1.25
	sun.light_color = Color("#fff0d5")
	add_child(sun)


func connect_actor(actor: PocketActor) -> void:
	actor.injured.connect(on_actor_injured)
	actor.died.connect(on_actor_died)


func _physics_process(delta: float) -> void:
	shoot_clock = maxf(0.0, shoot_clock - delta)
	reload_clock = maxf(0.0, reload_clock - delta)
	if reload_weapon_id != "" and reload_clock <= 0.0:
		finish_reload()
	if dialogue_panel != null and dialogue_panel.visible:
		fire_held = false
		return
	var pressed := fire_held or Input.is_key_pressed(KEY_SPACE)
	var gun := selected_gun()
	if pressed and (bool(gun["auto"]) or not fire_latched):
		shoot()
	fire_latched = pressed
	if shop_panel != null and shop_panel.visible:
		return
	var motion := read_motion()
	if not carjack_busy and not hero.dead:
		if indoors or car_driven == null:
			hero.walk(motion, sprint_enabled or Input.is_key_pressed(KEY_SHIFT), camera, delta)
			if motion.length() > 0.15:
				last_footstep += delta
				if last_footstep > (0.30 if sprint_enabled else 0.43):
					last_footstep = 0.0
					sound.play("footstep", hero.global_position, -17.0, randf_range(0.9, 1.1))
		else:
			car_driven.drive_input = motion
			car_driven.nitro = sprint_enabled or Input.is_key_pressed(KEY_SHIFT)
			hero.global_position = car_driven.global_position + Vector3(0, 2.0, 0)
	if wanted > 0 and not indoors and not hero.dead:
		for officer_node in city.police_root.get_children():
			var officer := officer_node as PocketActor
			if not is_instance_valid(officer) or officer.dead:
				continue
			officer.engage = true
			officer.chase_target = car_driven if car_driven != null else hero
			var focus := car_driven.global_position if car_driven != null else hero.global_position
			if car_driven == null and officer.global_position.distance_to(focus) < 2.9:
				officer.try_baton_attack(hero, 7.0 + float(wanted))
			elif officer.global_position.distance_to(focus) > 95.0:
				officer.queue_free()
	camera_override_timer = maxf(0.0, camera_override_timer - delta)
	if camera_override_timer <= 0.0:
		if is_instance_valid(car_driven):
			# Vehicle mode: keep looking along the driven vehicle's heading.
			camera_yaw = lerp_angle(camera_yaw, car_driven.rotation.y, clampf(delta * 2.1, 0.0, 1.0))
		else:
			# On foot: fix the overhead viewing direction in world-space.
			# Camera-relative movement must not feed back into character heading.
			camera_yaw = lerp_angle(camera_yaw, 0.0, clampf(delta * 2.7, 0.0, 1.0))
		camera_pitch = lerpf(camera_pitch, deg_to_rad(69.0), clampf(delta * 2.4, 0.0, 1.0))
	update_camera(delta)


func _process(delta: float) -> void:
	if hero == null:
		return
	if dialogue_panel != null and dialogue_panel.visible:
		if not is_instance_valid(conversation_actor) or conversation_actor.dead or conversation_actor.panic_time > 0.0 or hero.dead or wanted > 0 or hero.global_position.distance_to(conversation_actor.global_position) > 4.5:
			end_conversation()
	if is_instance_valid(engine_audio) and is_instance_valid(car_driven):
		engine_audio.pitch_scale = clampf(0.72 + absf(car_driven.drive_speed) / 20.0, 0.7, 2.4)
		engine_audio.volume_db = -28.0 + minf(10.0, absf(car_driven.drive_speed) * 0.3)
	autosave_clock += delta
	if autosave_clock > 18.0:
		autosave_clock = 0.0
		save_game()
	if wanted > 0 and not indoors:
		wanted_idle += delta
		police_clock += delta
		if police_clock > 5.0:
			police_clock = 0.0
			var cap := wanted * 2 + 1
			if city.police_root.get_child_count() < cap:
				var at := car_driven.global_position if car_driven != null else hero.global_position
				var officer := city.add_police_near(at, randi())
				connect_actor(officer)
				sound.play("police", officer.global_position, -12.0)
		if wanted_idle > 32.0:
			wanted -= 1
			wanted_idle = 0.0
			if wanted == 0:
				wanted_cleanup_clock = 0.0
	elif wanted == 0:
		wanted_cleanup_clock += delta
		if wanted_cleanup_clock > 2.0:
			wanted_cleanup_clock = 0.0
			for cop in city.police_root.get_children():
				if is_instance_valid(cop):
					cop.queue_free()
	if mission_stage == 1 and mission_limit > 0.0 and not hero.dead:
		mission_limit -= delta
		if mission_limit <= 0.0:
			mission_stage = 0
			mission_failures += 1
			mission_limit = 0.0
			mission_point = GameData.delivery_sites()[7]
			show_message("DELIVERY FAILED")
			refresh_mission_marker()
			save_game()
	display_message_time = maxf(0.0, display_message_time - delta)
	animate_marker(delta)
	hud_update_clock += delta
	if hud_update_clock > 0.11:
		hud_update_clock = 0.0
		update_hud()

func read_motion() -> Vector2:
	var vector := stick_value
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y += 1.0
	if keyboard.length_squared() > 0.0:
		vector = keyboard.normalized()
	return vector.limit_length(1.0)


func update_camera(delta: float) -> void:
	var focus := hero.global_position
	if car_driven != null:
		focus = car_driven.global_position
	var elevation := 0.95 if car_driven == null else 1.55
	var look_at_position := focus + Vector3(0.0, elevation, 0.0)
	var arm_distance := camera_distance * (1.17 if car_driven != null else 1.0)
	if zoom_enabled:
		arm_distance *= 0.72
	var horizontal := cos(camera_pitch) * arm_distance
	var offset := Vector3(sin(camera_yaw) * horizontal, sin(camera_pitch) * arm_distance, cos(camera_yaw) * horizontal)
	var requested := look_at_position + offset
	var dir := (requested - look_at_position).normalized()
	var right := Vector3(dir.z, 0, -dir.x).normalized()
	if right.length_squared() < 0.1:
		right = Vector3.RIGHT
	var up := right.cross(dir).normalized()
	# Multiple ray probes approximate a sphere and protect the near plane from walls.
	var probes: Array[Vector3] = [Vector3.ZERO, right * 0.42, -right * 0.42, up * 0.36, -up * 0.36]
	var best_length := arm_distance
	var obstructed := false
	for probe in probes:
		var params := PhysicsRayQueryParameters3D.create(look_at_position + probe, requested + probe)
		params.collision_mask = 1
		params.exclude = [hero.get_rid()]
		if is_instance_valid(car_driven):
			params.exclude.append(car_driven.get_rid())
		var block := get_world_3d().direct_space_state.intersect_ray(params)
		if not block.is_empty():
			var impact: Vector3 = block["position"]
			var allowed := maxf(1.28, impact.distance_to(look_at_position + probe) - 0.50)
			if allowed < best_length:
				best_length = allowed
				obstructed = true
	var destination := look_at_position + dir * best_length
	var smooth := 20.0 if obstructed else (11.0 if indoors else 10.5)
	camera.global_position = camera.global_position.lerp(destination, clampf(delta * smooth, 0.0, 1.0))
	camera.look_at(look_at_position, Vector3.UP)


func rotate_camera(relative: Vector2) -> void:
	camera_override_timer = 3.0
	camera_yaw = wrapf(camera_yaw - relative.x * 0.008, -PI, PI)
	camera_pitch = clampf(camera_pitch + relative.y * 0.0055, deg_to_rad(42.0), deg_to_rad(78.0))


func shoot() -> void:
	if hero.dead or carjack_busy or shoot_clock > 0.0 or reload_weapon_id != "" or (shop_panel != null and shop_panel.visible):
		return
	var gun := selected_gun()
	var gun_id: String = gun["id"]
	if int(loaded_rounds.get(gun_id, 0)) <= 0:
		reload_gun()
		return
	shoot_clock = float(gun["rate"])
	loaded_rounds[gun_id] = int(loaded_rounds.get(gun_id, 0)) - 1
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() < 0.2:
		forward = Vector3.FORWARD
	var origin := hero.muzzle.global_position
	if car_driven != null:
		origin = car_driven.global_position + Vector3(0, 1.6, 0) - car_driven.global_transform.basis.z * 2.25
	else:
		hero.face_direction(forward, 1.0)
		hero.kick_recoil(0.55 if gun_id == "Shotgun" else 0.25)
		origin = hero.muzzle.global_position
	var aim := forward
	var best_rank := INF
	var cone_angle := deg_to_rad(2.0 if gun_id == "Sniper" else 10.0)
	var excludes: Array[RID] = [hero.get_rid()]
	if is_instance_valid(car_driven):
		excludes.append(car_driven.get_rid())
	var actors: Array[Node] = city.person_root.get_children() + city.police_root.get_children() if not indoors else []
	for item in actors:
		var candidate := item as PocketActor
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		var toward := candidate.global_position + Vector3(0, 1.10, 0) - origin
		var dist := toward.length()
		if dist < 0.5 or dist > float(gun["range"]):
			continue
		var alignment := forward.dot(toward.normalized())
		if alignment <= cos(cone_angle):
			continue
		var los := PhysicsRayQueryParameters3D.create(origin, candidate.global_position + Vector3(0, 1.0, 0))
		los.exclude = excludes
		var first := get_world_3d().direct_space_state.intersect_ray(los)
		if first.is_empty() or first.get("collider") != candidate:
			continue
		var rank := dist * (1.0 + (1.0 - alignment) * 10.0)
		if rank < best_rank:
			best_rank = rank
			aim = toward.normalized()
	var pellet_count: int = int(gun["pellets"])
	var angular_spread: float = float(gun["spread"])
	var total_hits: Dictionary = {}
	var victim_distance: Dictionary = {}
	Fx.flash(self, origin, 1.65 if gun_id == "Shotgun" else 1.0, aim)
	sound.play(gun_id, origin, -4.0)
	for pellet in range(pellet_count):
		var rad := deg_to_rad(angular_spread)
		var r := sqrt(randf()) * rad
		var theta := randf() * TAU
		var spread_dir := aim.rotated(Vector3.UP, cos(theta) * r)
		var lateral := spread_dir.cross(Vector3.UP).normalized()
		if lateral.length_squared() > 0.1:
			spread_dir = spread_dir.rotated(lateral, sin(theta) * r)
		spread_dir = spread_dir.normalized()
		var to := origin + spread_dir * float(gun["range"])
		var ray := PhysicsRayQueryParameters3D.create(origin, to)
		ray.exclude = excludes
		ray.collision_mask = 11 # World, people and vehicles.
		var collision := get_world_3d().direct_space_state.intersect_ray(ray)
		var endpoint := to
		if not collision.is_empty():
			endpoint = collision["position"]
			var collider: Object = collision["collider"]
			if collider is PocketActor and not (collider as PocketActor).dead:
				var actor := collider as PocketActor
				var part_bonus := 1.65 if endpoint.y > actor.global_position.y + 1.5 else (0.75 if endpoint.y < actor.global_position.y + 0.65 else 1.0)
				total_hits[actor] = float(total_hits.get(actor, 0.0)) + float(gun["damage"]) / float(pellet_count) * part_bonus
				victim_distance[actor] = origin.distance_to(endpoint)
			elif collider is PocketVehicle:
				(collider as PocketVehicle).hit(float(gun["damage"]) / float(pellet_count))
				Fx.impact(self, endpoint, Color("#ffd9a2"))
			elif pellet < 3:
				Fx.impact(self, endpoint, Color("#f9c884"))
		if pellet_count == 1 or pellet % 2 == 0:
			Fx.tracer(self, origin, endpoint, 0.022 if gun_id == "Sniper" else 0.034, Color("#ffd16b"), 0.10 if gun_id == "Sniper" else 0.065)
	for actor in total_hits:
		if is_instance_valid(actor):
			var length: float = float(victim_distance.get(actor, 0.0))
			var falloff := clampf(1.0 - maxf(0.0, length / float(gun["range"]) - 0.65) * 0.8, 0.72, 1.0)
			(actor as PocketActor).hit(float(total_hits[actor]) * falloff)
	for item in actors:
		var civilian := item as PocketActor
		if is_instance_valid(civilian) and not civilian.dead and not civilian.officer and civilian.global_position.distance_to(origin) < 20.0:
			civilian.flee_from(origin)
	if not indoors:
		if wanted == 0:
			add_wanted(1)
		else:
			wanted_idle = 0.0


func reload_gun() -> void:
	if reload_weapon_id != "" or hero.dead or carjack_busy:
		return
	var gun := selected_gun()
	var id: String = gun["id"]
	var count := int(loaded_rounds.get(id, 0))
	var capacity := int(gun["magazine"])
	if count >= capacity or int(ammunition.get(id, 0)) <= 0:
		return
	reload_weapon_id = id
	reload_clock = float(gun["reload"])
	sound.play_ui("ui")
	show_message("RELOADING " + id.to_upper())


func finish_reload() -> void:
	for gun in WEAPONS:
		if String(gun["id"]) != reload_weapon_id:
			continue
		var id: String = gun["id"]
		var available := maxi(0, int(ammunition.get(id, 0)))
		var needed := maxi(0, int(gun["magazine"]) - int(loaded_rounds.get(id, 0)))
		var amount := mini(available, needed)
		ammunition[id] = available - amount
		loaded_rounds[id] = int(loaded_rounds.get(id, 0)) + amount
		break
	reload_weapon_id = ""

func on_hero_damaged(points: float) -> void:
	if dialogue_panel != null and dialogue_panel.visible:
		end_conversation()
	sound.play("hurt", hero.global_position, -8.0)
	Fx.impact(self, hero.global_position + Vector3(0.0, 1.45, 0.0), Color("#ff7371"), points)
	if is_instance_valid(hurt_overlay):
		hurt_overlay.color = Color(0.83, 0.09, 0.08, 0.27)
		var fading := create_tween()
		fading.tween_property(hurt_overlay, "color:a", 0.0, 0.46)


func on_hero_died() -> void:
	if dialogue_panel != null and dialogue_panel.visible:
		end_conversation()
	if death_pending:
		return
	death_pending = true
	if is_instance_valid(car_driven):
		exit_car()
	sound.play("death", hero.global_position, -2.0)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_inside_tree():
			busted()
		death_pending = false
	)

func on_actor_injured(actor: PocketActor) -> void:
	if conversation_actor == actor and dialogue_panel != null and dialogue_panel.visible:
		end_conversation()
	if not actor.has_meta("crime_recorded"):
		actor.set_meta("crime_recorded", true)
		add_wanted(2 if actor.officer else 1)


func on_actor_died(actor: PocketActor) -> void:
	if actor.officer:
		add_wanted(1)
		sound.play("death", actor.global_position, -8.0)
		return
	sound.play("death", actor.global_position, -10.0)
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if is_instance_valid(city) and is_inside_tree():
			for newcomer in city.replenish_pedestrians():
				connect_actor(newcomer)
	)


func add_wanted(levels: int) -> void:
	wanted = clampi(wanted + levels, 0, 5)
	wanted_idle = 0.0


func busted() -> void:
	if indoors:
		leave_interior()
	if car_driven != null:
		var car := car_driven
		exit_car()
		if car_driven != null:
			car.occupied = false
			if is_instance_valid(engine_audio):
				engine_audio.stop()
				engine_audio.queue_free()
				engine_audio = null
			car.drive_input = Vector2.ZERO
			car.nitro = false
			car_driven = null
			hero.visible = true
			(hero.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", false)
	hero.position = Vector3(18.0, 0.35, -34.0)
	hero.reset_health()
	cash = maxi(0, cash - 200)
	wanted = 0
	for cop in city.police_root.get_children():
		cop.queue_free()
	save_game()


func selected_gun() -> Dictionary:
	for gun in WEAPONS:
		if gun["id"] == owned_weapons[current_weapon]:
			return gun
	return WEAPONS[0]


func next_weapon() -> void:
	if reload_weapon_id != "":
		return
	current_weapon = (current_weapon + 1) % owned_weapons.size()
	hero.equip_weapon(String(selected_gun()["id"]))
	zoom_enabled = false
	camera.fov = 69.0
	sound.play_ui("ui")


func interaction() -> void:
	if dialogue_panel != null and dialogue_panel.visible:
		end_conversation()
		return
	if hero.dead or carjack_busy:
		return
	if shop_panel.visible:
		close_shop()
		return
	if indoors:
		if interior.loot_near(hero.global_position):
			var reward := interior.search_loot(hero.global_position)
			if reward > 0:
				cash += reward
				total_earnings += reward
				if not looted_buildings.has(active_building):
					looted_buildings.append(active_building)
				sound.play_ui("cash")
				show_message("FOUND SUPPLIES +$%d" % reward)
				save_game()
		elif interior.exit_near(hero.global_position):
			leave_interior()
		return
	if car_driven != null:
		exit_car()
		return
	var door := city.closest_door(hero.global_position)
	if wanted == 0:
		var resident := city.closest_resident(hero.global_position)
		if resident != null and (door.is_empty() or hero.global_position.distance_to(door["door"]) > 1.6):
			begin_conversation(resident)
			return
	if not door.is_empty():
		if bool(door["shop"]):
			open_shop()
		else:
			enter_interior(door)
		return
	var near_car := city.closest_car(hero.global_position)
	if near_car != null:
		enter_car(near_car)
		return
	if hero.global_position.distance_to(mission_point) <= 5.2:
		advance_delivery()


func enter_car(car: PocketVehicle) -> void:
	if carjack_busy or car.occupied or car.being_stolen:
		return
	carjack_busy = true
	car.being_stolen = true
	car.open_driver_door(true)
	sound.play("car_door", car.global_position)
	hero.start_carjack()
	var destination := car.entrance_point()
	hero.face_direction(-car.global_transform.basis.x, 1.0)
	var tween := create_tween()
	tween.tween_property(hero, "global_position", Vector3(destination.x, 0.35, destination.z), 0.42).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(0.36)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(car) or not is_instance_valid(hero):
			carjack_busy = false
			return
		car_driven = car
		car.occupied = true
		car.being_stolen = false
		engine_audio = AudioStreamPlayer3D.new()
		engine_audio.stream = sound.sounds["engine"]
		engine_audio.unit_size = 19.0
		engine_audio.max_distance = 90.0
		engine_audio.volume_db = -26.0
		car.add_child(engine_audio)
		engine_audio.play()
		car.open_driver_door(false)
		sound.play("car_door", car.global_position)
		hero.stop_carjack()
		hero.visible = false
		var collider := hero.get_node("CollisionShape3D") as CollisionShape3D
		collider.set_deferred("disabled", true)
		carjack_busy = false
		add_wanted(1)
	)

func exit_car() -> void:
	if car_driven == null:
		return
	var vehicle := car_driven
	var options: Array[Vector3] = [
		vehicle.global_position + vehicle.global_transform.basis.x * 3.1,
		vehicle.global_position - vehicle.global_transform.basis.x * 3.1,
		vehicle.global_position + vehicle.global_transform.basis.z * 4.2,
		vehicle.global_position - vehicle.global_transform.basis.z * 4.2
	]
	for spoke in range(8):
		var angle := TAU * float(spoke) / 8.0
		options.append(vehicle.global_position + Vector3(cos(angle), 0, sin(angle)) * 5.2)
	var leave_at := Vector3.ZERO
	var valid := false
	for option in options:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.62
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, Vector3(option.x, 0.91, option.z))
		query.collision_mask = 9 # Static obstacles and other vehicles.
		query.exclude = [vehicle.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_shape(query, 1)
		if hit.is_empty():
			leave_at = option
			valid = true
			break
	if not valid:
		show_message("NO CLEAR PLACE TO EXIT")
		return
	hero.global_position = Vector3(leave_at.x, 0.24, leave_at.z)
	hero.visible = true
	var body := hero.get_node("CollisionShape3D") as CollisionShape3D
	body.set_deferred("disabled", false)
	sound.play("car_door", vehicle.global_position, -8.0)
	vehicle.occupied = false
	if is_instance_valid(engine_audio):
		engine_audio.stop()
		engine_audio.queue_free()
		engine_audio = null
	vehicle.drive_input = Vector2.ZERO
	vehicle.nitro = false
	car_driven = null


func enter_interior(door: Dictionary) -> void:
	if car_driven != null:
		exit_car()
	active_building = String(door["id"])
	outdoor_exit = door["door"]
	if not layouts.has(active_building):
		layouts[active_building] = InteriorScript.make_layout(active_building)
		save_game()
	interior.display_layout(active_building, layouts[active_building], looted_buildings.has(active_building))
	indoors = true
	sound.set_indoors(true)
	city.visible = false
	city.process_mode = Node.PROCESS_MODE_DISABLED
	interior.visible = true
	sky.environment.background_color = Color("#373b40")
	hero.global_position = InteriorScript.INTERIOR_ORIGIN + Vector3(0, 0.35, 6.5)
	hero.velocity = Vector3.ZERO
	stick_value = Vector2.ZERO


func leave_interior() -> void:
	indoors = false
	sound.set_indoors(false)
	interior.visible = false
	city.visible = true
	city.process_mode = Node.PROCESS_MODE_INHERIT
	sky.environment.background_color = Color("#819fb4")
	hero.global_position = outdoor_exit + Vector3(0, 0.38, -1.8)
	hero.velocity = Vector3.ZERO
	active_building = ""
	save_game()


func make_mission_marker() -> void:
	mission_marker = Node3D.new()
	city.add_child(mission_marker)
	Shapes.ball(mission_marker, Vector3(0, 1.2, 0), 0.65, Color("#ffc44e"))
	mission_marker_label = Shapes.sign3d(mission_marker, "PICKUP", Vector3(0, 2.7, 0), Color("#ffdf9c"))
	if mission_stage == 0:
		mission_point = GameData.delivery_sites()[7]
	else:
		var sites := GameData.delivery_sites()
		mission_point = sites[clampi(mission_last_index, 0, sites.size() - 1)]
	refresh_mission_marker()

func animate_marker(delta: float) -> void:
	if mission_marker != null:
		mission_marker.rotate_y(delta * 1.1)


func refresh_mission_marker() -> void:
	mission_marker.position = mission_point
	mission_marker_label.text = "PICKUP" if mission_stage == 0 else "DELIVERY"


func advance_delivery() -> void:
	if mission_stage == 0:
		mission_stage = 1
		var sites := GameData.delivery_sites()
		mission_last_index = (deliveries * 3 + 1) % sites.size()
		mission_point = sites[mission_last_index]
		var starting := car_driven.global_position if car_driven != null else hero.global_position
		var distance := starting.distance_to(mission_point)
		mission_limit = GameData.mission_time(distance)
		mission_reward = GameData.mission_reward(distance, mini(5, int(deliveries / 3)))
		show_message("DELIVERY STARTED  |  $%d REWARD" % mission_reward)
	else:
		mission_stage = 0
		deliveries += 1
		cash += mission_reward
		total_earnings += mission_reward
		sound.play_ui("cash")
		show_message("DELIVERED +$%d" % mission_reward)
		mission_limit = 0.0
		mission_point = GameData.delivery_sites()[7]
		save_game()
	refresh_mission_marker()
	save_game()


func show_message(message: String) -> void:
	display_message = message
	display_message_time = 2.6

func save_destination() -> String:
	return save_path_override if not save_path_override.is_empty() else SAVE_PATH


func load_game() -> void:
	var decoded: Dictionary = SafeSave.load_json(save_destination())
	if decoded.is_empty():
		return
	cash = maxi(0, int(decoded.get("cash", cash)))
	deliveries = maxi(0, int(decoded.get("deliveries", 0)))
	total_earnings = maxi(0, int(decoded.get("earnings", 0)))
	mission_failures = maxi(0, int(decoded.get("failures", 0)))
	mission_stage = clampi(int(decoded.get("mission_stage", 0)), 0, 1)
	mission_last_index = clampi(int(decoded.get("mission_index", 0)), 0, GameData.delivery_sites().size() - 1)
	mission_limit = maxf(0.0, float(decoded.get("mission_limit", 0.0)))
	mission_reward = maxi(0, int(decoded.get("mission_reward", 0)))
	layouts = decoded.get("interiors", {})
	resident_relations.clear()
	var saved_residents = decoded.get("residents", {})
	if saved_residents is Dictionary:
		for resident_key in saved_residents:
			var resident_value = saved_residents[resident_key]
			if not (resident_value is Dictionary):
				continue
			var slot := String(resident_key)
			if not slot.is_valid_int() or int(slot) < 0 or int(slot) >= city.people.size():
				continue
			resident_relations[slot] = {
				"talks": clampi(int(resident_value.get("talks", 0)), 0, 100000),
				"affinity": clampi(int(resident_value.get("affinity", 0)), 0, 100)
			}
	looted_buildings.clear()
	for location in decoded.get("looted", []):
		looted_buildings.append(String(location))
	owned_weapons.clear()
	for item in decoded.get("owned", ["Handgun"]):
		var name := String(item)
		if WEAPONS.any(func(g: Dictionary) -> bool: return g["id"] == name) and not owned_weapons.has(name):
			owned_weapons.append(name)
	if not owned_weapons.has("Handgun"):
		owned_weapons.push_front("Handgun")
	var saved_ammo = decoded.get("ammo", {"Handgun": 180})
	if saved_ammo is Dictionary:
		ammunition = saved_ammo
	var saved_mags = decoded.get("loaded", {"Handgun": 15})
	if saved_mags is Dictionary:
		loaded_rounds = saved_mags
	current_weapon = clampi(int(decoded.get("equipped", 0)), 0, owned_weapons.size() - 1)
	var coords = decoded.get("player_position", [])
	if coords is Array and coords.size() == 3:
		var p := Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
		if absf(p.x) < 120 and absf(p.z) < 120 and p.y > -2.0 and p.y < 10.0:
			hero.position = p


func save_game() -> void:
	var pos := hero.global_position
	if is_instance_valid(car_driven):
		pos = car_driven.global_position + Vector3(2.5, 0, 0)
	if indoors:
		pos = outdoor_exit
	var state := {
		"cash": cash,
		"deliveries": deliveries,
		"earnings": total_earnings,
		"failures": mission_failures,
		"mission_stage": mission_stage,
		"mission_index": mission_last_index,
		"mission_limit": mission_limit,
		"mission_reward": mission_reward,
		"interiors": layouts,
		"residents": resident_relations,
		"looted": looted_buildings,
		"owned": owned_weapons,
		"ammo": ammunition,
		"loaded": loaded_rounds,
		"equipped": current_weapon,
		"player_position": [pos.x, pos.y, pos.z]
	}
	if not SafeSave.save_json(save_destination(), state):
		push_warning("Save could not be written; last good backup was kept.")

func _input(event: InputEvent) -> void:
	if dialogue_panel != null and dialogue_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_E or event.keycode == KEY_F:
				end_conversation()
			elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
				select_conversation_option(event.keycode - KEY_1)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			interaction()
		elif event.keycode == KEY_Q or event.keycode == KEY_TAB:
			next_weapon()
		elif event.keycode == KEY_R:
			reload_gun()
		elif event.keycode == KEY_C:
			sprint_enabled = not sprint_enabled
		elif event.keycode == KEY_M and minimap != null:
			minimap.visible = not minimap.visible
		elif event.keycode == KEY_P:
			toggle_settings()
	if event is InputEventScreenTouch:
		if event.pressed and not on_action_button(event.position) and not shop_panel.visible:
			if stick_pointer == -1 and (event.position - stick_center).length() < 145.0:
				stick_pointer = event.index
				update_stick(event.position)
			elif camera_touch == -1 and event.position.y < stick_outer.position.y - 12.0:
				camera_touch = event.index
		elif not event.pressed:
			if event.index == stick_pointer:
				stick_pointer = -1
				update_stick(stick_center)
			if event.index == camera_touch:
				camera_touch = -1
	if event is InputEventScreenDrag:
		if event.index == stick_pointer:
			update_stick(event.position)
		elif event.index == camera_touch:
			rotate_camera(event.relative)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			camera_mouse = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and (event.position - stick_center).length() < 145.0 and not on_action_button(event.position):
				mouse_stick = true
				update_stick(event.position)
			elif not event.pressed and mouse_stick:
				mouse_stick = false
				update_stick(stick_center)
	if event is InputEventMouseMotion:
		if mouse_stick:
			update_stick(event.position)
		elif camera_mouse:
			rotate_camera(event.relative)


func on_action_button(point: Vector2) -> bool:
	for button in [fire_button, action_button, run_button, weapon_button, reload_button, aim_button, pause_button]:
		if button != null and button.get_global_rect().has_point(point):
			return true
	return false


func update_stick(point: Vector2) -> void:
	stick_value = ((point - stick_center) / 85.0).limit_length(1.0)
	if stick_knob != null:
		stick_knob.position = stick_outer.position + Vector2(59, 59) + stick_value * 68.0


func update_hud() -> void:
	if status_label == null:
		return
	status_label.text = "HP %03d    $%d    %s" % [ceili(hero.hp), cash, "★".repeat(wanted) + "☆".repeat(5 - wanted)]
	var gun := selected_gun()
	var gun_id: String = gun["id"]
	var active_mag := int(loaded_rounds.get(gun_id, 0))
	var reserve := int(ammunition.get(gun_id, 0))
	var suffix := ("  RELOADING %.1fs" % reload_clock) if reload_weapon_id != "" else ""
	weapon_label.text = "%s  %d/%d  (+%d)%s" % [gun_id, active_mag, int(gun["magazine"]), reserve, suffix]
	var current_position := car_driven.global_position if car_driven != null else hero.global_position
	var waypoint := mission_point - current_position
	var heading := waypoint_arrow(waypoint)
	mission_label.text = "DELIVERY %s %dm  •  %s [%d] %s" % [heading, int(waypoint.length()), "PICKUP" if mission_stage == 0 else "DROP OFF", deliveries, ("%.0fs" % mission_limit) if mission_stage == 1 else ""]
	var aim_dir := -camera.global_transform.basis.z
	aim_dir.y = 0.0
	aim_dir = aim_dir.normalized()
	var origin := car_driven.global_position if is_instance_valid(car_driven) else hero.global_position
	var target_world := origin + aim_dir * 10.0 + Vector3(0, 1.2, 0)
	if camera.is_position_behind(target_world):
		crosshair_label.visible = false
	else:
		crosshair_label.visible = true
		crosshair_label.position = camera.unproject_position(target_world) - Vector2(17, 20)
		crosshair_label.size = Vector2(34, 36)
	var nearby_door := city.closest_door(hero.global_position) if not indoors else {}
	var nearby_resident: PocketActor = null
	if not indoors and car_driven == null and wanted == 0:
		nearby_resident = city.closest_resident(hero.global_position)
	var caption := "MOVE: PAD  •  CAMERA: SWIPE SCENE  •  ACTION"
	if hero.dead:
		caption = "WASTED  •  RESPAWNING"
	elif carjack_busy:
		caption = "TAKING VEHICLE..."
	elif indoors:
		if interior.loot_near(hero.global_position):
			caption = "ACTION: SEARCH CACHE"
		else:
			caption = "ACTION: EXIT" if interior.exit_near(hero.global_position) else "RETURN TO THE EXIT MARKER"
	elif car_driven != null:
		caption = "ACTION: EXIT CAR  •  STICK TO DRIVE"
	elif nearby_resident != null and (nearby_door.is_empty() or hero.global_position.distance_to(nearby_door["door"]) > 1.6):
		var profile: Dictionary = ResidentDialogue.make_profile(nearby_resident.resident_id)
		caption = "ACTION: 話す - %s" % String(profile["name"])
	elif not nearby_door.is_empty():
		caption = "ACTION: GUN SHOP" if bool(nearby_door["shop"]) else "ACTION: ENTER BUILDING"
	elif city.closest_car(hero.global_position) != null:
		caption = "ACTION: TAKE VEHICLE"
	elif hero.global_position.distance_to(mission_point) < 5.2:
		caption = "ACTION: COLLECT PARCEL" if mission_stage == 0 else "ACTION: DELIVER PARCEL"
	hint_label.text = display_message if display_message_time > 0.0 else caption
	run_button.text = "SPRINT ON" if sprint_enabled else "SPRINT"


func waypoint_arrow(delta_to_goal: Vector3) -> String:
	var angle := atan2(delta_to_goal.z, delta_to_goal.x)
	var index: int = wrapi(int(round(angle / (PI / 4.0))), 0, 8)
	var symbols := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	return symbols[index]


func setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(ui)
	hurt_overlay = ColorRect.new()
	hurt_overlay.color = Color(0.8, 0.12, 0.10, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hurt_overlay)
	var banner := Panel.new()
	banner.name = "Banner"
	banner.add_theme_stylebox_override("panel", style(Color(0.045, 0.09, 0.14, 0.91), 14))
	ui.add_child(banner)
	status_label = make_label(25, Color("#f4f7fa"))
	ui.add_child(status_label)
	mission_label = make_label(18, Color("#f5d58c"))
	ui.add_child(mission_label)
	weapon_label = make_label(20, Color("#d6edee"))
	ui.add_child(weapon_label)
	crosshair_label = make_label(32, Color("#d6fff1"))
	crosshair_label.text = "+"
	crosshair_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(crosshair_label)
	hint_label = make_label(17, Color("#f3e5c4"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(hint_label)
	stick_outer = Panel.new()
	stick_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := style(Color(0.08, 0.18, 0.24, 0.34), 100)
	ring_style.border_color = Color("#6bded7")
	ring_style.border_width_top = 3
	ring_style.border_width_bottom = 3
	ring_style.border_width_left = 3
	ring_style.border_width_right = 3
	stick_outer.add_theme_stylebox_override("panel", ring_style)
	ui.add_child(stick_outer)
	stick_knob = Panel.new()
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_knob.add_theme_stylebox_override("panel", style(Color(0.30, 0.76, 0.78, 0.74), 50))
	ui.add_child(stick_knob)
	fire_button = make_button("FIRE", Color("#a94841"))
	action_button = make_button("ACTION", Color("#407d89"))
	run_button = make_button("SPRINT", Color("#435e86"))
	weapon_button = make_button("WEAPON", Color("#615a8d"))
	reload_button = make_button("RELOAD", Color("#4e696e"))
	aim_button = make_button("SCOPE", Color("#52636f"))
	pause_button = make_button("II", Color("#3c5365"))
	fire_button.button_down.connect(func() -> void: fire_held = true)
	fire_button.button_up.connect(func() -> void: fire_held = false)
	action_button.pressed.connect(interaction)
	run_button.pressed.connect(func() -> void: sprint_enabled = not sprint_enabled)
	weapon_button.pressed.connect(next_weapon)
	reload_button.pressed.connect(reload_gun)
	aim_button.pressed.connect(toggle_scope)
	pause_button.pressed.connect(toggle_settings)
	for button in [fire_button, action_button, run_button, weapon_button, reload_button, aim_button, pause_button]:
		ui.add_child(button)
	minimap = MapScript.new()
	minimap.game = self
	ui.add_child(minimap)
	perf_overlay = PerfScript.new()
	ui.add_child(perf_overlay)
	create_shop_ui()
	create_settings_ui()
	create_dialogue_ui()


func style(background: Color, radius: int) -> StyleBoxFlat:
	var flat := StyleBoxFlat.new()
	flat.bg_color = background
	flat.corner_radius_bottom_left = radius
	flat.corner_radius_bottom_right = radius
	flat.corner_radius_top_left = radius
	flat.corner_radius_top_right = radius
	return flat


func make_label(font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func make_button(caption: String, background: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", style(background, 18))
	button.add_theme_stylebox_override("hover", style(background.lightened(0.2), 18))
	button.add_theme_stylebox_override("pressed", style(background.darkened(0.25), 18))
	return button


func create_dialogue_ui() -> void:
	dialogue_panel = Panel.new()
	dialogue_panel.name = "ResidentDialogue"
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.add_theme_stylebox_override("panel", style(Color("#1c2f39"), 18))
	ui.add_child(dialogue_panel)
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 17)
	dialogue_panel.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	padding.add_child(stack)
	dialogue_speaker = make_label(25, Color("#f6d797"))
	stack.add_child(dialogue_speaker)
	dialogue_text = make_label(20, Color("#f3f6fb"))
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.custom_minimum_size = Vector2(0, 112)
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(dialogue_text)
	for index in range(4):
		var choice := make_button("", Color("#386574"))
		choice.custom_minimum_size = Vector2(0, 52)
		choice.add_theme_font_size_override("font_size", 18)
		choice.pressed.connect(select_conversation_option.bind(index))
		dialogue_options.append(choice)
		stack.add_child(choice)
	dialogue_exit = make_button("会話を終える", Color("#68545e"))
	dialogue_exit.custom_minimum_size = Vector2(0, 52)
	dialogue_exit.pressed.connect(end_conversation)
	stack.add_child(dialogue_exit)
	dialogue_panel.visible = false


func begin_conversation(resident: PocketActor) -> void:
	if not is_instance_valid(resident) or resident.dead or resident.officer or resident.panic_time > 0.0:
		return
	if resident.resident_id < 0 or hero.dead or car_driven != null or indoors or wanted > 0:
		return
	if dialogue_panel == null or dialogue_panel.visible:
		return
	var key := str(resident.resident_id)
	var record: Dictionary = resident_relations.get(key, {"talks": 0, "affinity": 0})
	var profile: Dictionary = ResidentDialogue.make_profile(resident.resident_id)
	var tree: Dictionary = ResidentDialogue.make_tree(profile, int(record.get("talks", 0)), int(record.get("affinity", 0)))
	if not ResidentDialogue.is_valid_tree(tree):
		push_warning("Invalid conversation tree for resident " + key)
		return
	record["talks"] = mini(100000, int(record.get("talks", 0)) + 1)
	resident_relations[key] = record
	conversation_tree = tree
	conversation_node = String(tree["start"])
	conversation_actor = resident
	resident.chatting = true
	resident.chat_target = hero
	stick_value = Vector2.ZERO
	fire_held = false
	dialogue_panel.visible = true
	sound.play_ui("ui")
	update_conversation_panel()


func select_conversation_option(index: int) -> void:
	if dialogue_panel == null or not dialogue_panel.visible:
		return
	var nodes: Dictionary = conversation_tree.get("nodes", {})
	var current: Dictionary = nodes.get(conversation_node, {})
	var choices: Array = current.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if is_instance_valid(conversation_actor):
		var key := str(conversation_actor.resident_id)
		var record: Dictionary = resident_relations.get(key, {"talks": 1, "affinity": 0})
		record["affinity"] = clampi(int(record.get("affinity", 0)) + int(choice.get("affinity", 0)), 0, 100)
		resident_relations[key] = record
	conversation_node = String(choice["next"])
	sound.play_ui("ui")
	update_conversation_panel()
	save_game()


func update_conversation_panel() -> void:
	if dialogue_panel == null or not dialogue_panel.visible or not is_instance_valid(conversation_actor):
		return
	var profile: Dictionary = ResidentDialogue.make_profile(conversation_actor.resident_id)
	var record: Dictionary = resident_relations.get(str(conversation_actor.resident_id), {})
	dialogue_speaker.text = "%s    ♥ %d" % [profile["name"], int(record.get("affinity", 0))]
	var node: Dictionary = conversation_tree["nodes"].get(conversation_node, {})
	dialogue_text.text = String(node.get("text", "また話しましょう。"))
	var choices: Array = node.get("choices", [])
	for i in range(dialogue_options.size()):
		var button := dialogue_options[i]
		button.visible = i < choices.size()
		if button.visible:
			button.text = "%d. %s" % [i + 1, String(choices[i]["text"])]
	dialogue_exit.text = "またね / 閉じる" if choices.is_empty() else "会話を終える"


func end_conversation() -> void:
	if dialogue_panel == null or not dialogue_panel.visible:
		return
	if is_instance_valid(conversation_actor):
		conversation_actor.chatting = false
		conversation_actor.chat_target = null
	conversation_actor = null
	conversation_tree.clear()
	conversation_node = ""
	dialogue_panel.visible = false
	stick_value = Vector2.ZERO
	fire_held = false
	save_game()


func create_shop_ui() -> void:
	shop_panel = Panel.new()
	shop_panel.add_theme_stylebox_override("panel", style(Color("#1e2935"), 18))
	ui.add_child(shop_panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	shop_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	shop_label = make_label(28, Color("#fbe3b0"))
	content.add_child(shop_label)
	var tip := make_label(17, Color("#cbd5dd"))
	tip.text = "SELECT A WEAPON TO PURCHASE OR RESTOCK"
	content.add_child(tip)
	for gun in WEAPONS:
		var gun_name: String = gun["id"]
		var button := make_button("", Color("#3c5365"))
		button.custom_minimum_size = Vector2(0, 66)
		button.pressed.connect(func() -> void: purchase_gun(gun_name))
		shop_buttons[gun_name] = button
		content.add_child(button)
	var close_button := make_button("CLOSE / BACK", Color("#755453"))
	close_button.custom_minimum_size = Vector2(0, 64)
	close_button.pressed.connect(close_shop)
	content.add_child(close_button)
	shop_panel.visible = false


func open_shop() -> void:
	stick_value = Vector2.ZERO
	fire_held = false
	shop_panel.visible = true
	refresh_shop_ui()


func close_shop() -> void:
	shop_panel.visible = false


func refresh_shop_ui() -> void:
	shop_label.text = "GUN SHOP    $%d" % cash
	for gun in WEAPONS:
		var gun_name: String = gun["id"]
		if not shop_buttons.has(gun_name):
			continue
		var already_owned := owned_weapons.has(gun_name)
		var price := maxi(100, int(gun["price"]) / 4) if already_owned else int(gun["price"])
		var title := "RESTOCK" if already_owned else "BUY"
		var button: Button = shop_buttons[gun_name]
		button.text = "%s   %s   $%d" % [gun_name.to_upper(), title, price]
		button.disabled = cash < price


func purchase_gun(gun_name: String) -> void:
	for gun in WEAPONS:
		if gun["id"] != gun_name:
			continue
		var already_owned := owned_weapons.has(gun_name)
		var price := maxi(100, int(gun["price"]) / 4) if already_owned else int(gun["price"])
		if cash < price:
			return
		cash -= price
		if not already_owned:
			owned_weapons.append(gun_name)
			current_weapon = owned_weapons.size() - 1
			loaded_rounds[gun_name] = int(gun["magazine"])
			hero.equip_weapon(gun_name)
		sound.play_ui("cash")
		ammunition[gun_name] = int(ammunition.get(gun_name, 0)) + int(gun["ammo"])
		save_game()
		refresh_shop_ui()
		return


func toggle_scope() -> void:
	if String(selected_gun()["id"]) != "Sniper":
		return
	zoom_enabled = not zoom_enabled
	camera.fov = 27.0 if zoom_enabled else 69.0
	aim_button.text = "UNZOOM" if zoom_enabled else "SCOPE"
	sound.play_ui("ui")


func create_settings_ui() -> void:
	settings_panel = Panel.new()
	settings_panel.add_theme_stylebox_override("panel", style(Color("#192733"), 20))
	ui.add_child(settings_panel)
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 16)
	settings_panel.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	padding.add_child(stack)
	var title := make_label(27, Color("#e3faf5"))
	title.text = "POCKET DISTRICT | PAUSE"
	stack.add_child(title)
	var sub := make_label(16, Color("#d2dce6"))
	sub.text = "CAMERA, DISPLAY & SOUND"
	stack.add_child(sub)
	var fov_button := make_button("CAMERA DISTANCE", Color("#4a6572"))
	fov_button.custom_minimum_size = Vector2(0, 48)
	fov_button.pressed.connect(func() -> void:
		camera_distance = 13.5 if camera_distance >= 19.5 else camera_distance + 1.0
		fov_button.text = "CAMERA DISTANCE %.0fm" % camera_distance
		sound.play_ui()
	)
	stack.add_child(fov_button)
	var map_button := make_button("SHOW / HIDE MINIMAP", Color("#4a6572"))
	map_button.custom_minimum_size = Vector2(0, 48)
	map_button.pressed.connect(func() -> void: minimap.visible = not minimap.visible)
	stack.add_child(map_button)
	var fps_button := make_button("SHOW / HIDE FPS", Color("#4a6572"))
	fps_button.custom_minimum_size = Vector2(0, 48)
	fps_button.pressed.connect(func() -> void: perf_overlay.visible = not perf_overlay.visible)
	stack.add_child(fps_button)
	var audio_button := make_button("SOUND ON / OFF", Color("#4a6572"))
	audio_button.custom_minimum_size = Vector2(0, 48)
	audio_button.pressed.connect(func() -> void:
		var index := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(index, not AudioServer.is_bus_mute(index))
	)
	stack.add_child(audio_button)
	var resume := make_button("RESUME GAME", Color("#28766a"))
	resume.custom_minimum_size = Vector2(0, 56)
	resume.pressed.connect(toggle_settings)
	stack.add_child(resume)
	settings_panel.visible = false


func toggle_settings() -> void:
	var show := not settings_panel.visible
	settings_panel.visible = show
	shop_panel.visible = false
	fire_held = false
	stick_value = Vector2.ZERO
	get_tree().paused = show


func layout_ui() -> void:
	if ui == null:
		return
	var screen := get_viewport().get_visible_rect().size
	ui.size = screen
	if is_instance_valid(hurt_overlay):
		hurt_overlay.size = screen
	var banner := ui.get_node("Banner") as Panel
	banner.position = Vector2(12, 12)
	banner.size = Vector2(screen.x - 24, 101)
	status_label.position = Vector2(24, 19)
	status_label.size = Vector2(screen.x - 36, 32)
	weapon_label.position = Vector2(24, 61)
	weapon_label.size = Vector2(screen.x - 36, 32)
	mission_label.position = Vector2(20, 121)
	mission_label.size = Vector2(screen.x - 102, 35)
	hint_label.position = Vector2(10, screen.y - 75)
	hint_label.size = Vector2(screen.x - 20, 55)
	stick_center = Vector2(screen.x * 0.73, screen.y - 115)
	stick_outer.position = stick_center - Vector2(100, 100)
	stick_outer.size = Vector2(200, 200)
	stick_knob.size = Vector2(82, 82)
	update_stick(stick_center)
	# Two rows of three buttons remain above the stick on a narrow 360px phone.
	var side := minf(128.0, (screen.x - 40.0) / 3.0)
	var gap := 8.0
	var group_left := screen.x - (side * 3.0 + gap * 2.0) - 12.0
	var top := screen.y - 393.0
	var bottom := screen.y - 317.0
	for entry in [
		{"button": weapon_button, "column": 0, "row": top},
		{"button": reload_button, "column": 1, "row": top},
		{"button": aim_button, "column": 2, "row": top},
		{"button": run_button, "column": 0, "row": bottom},
		{"button": action_button, "column": 1, "row": bottom},
		{"button": fire_button, "column": 2, "row": bottom}
	]:
		var button: Button = entry["button"]
		button.position = Vector2(group_left + float(entry["column"]) * (side + gap), float(entry["row"]))
		button.size = Vector2(side, 68)
	aim_button.disabled = String(selected_gun()["id"]) != "Sniper"
	if aim_button.disabled:
		zoom_enabled = false
		camera.fov = 69.0
	pause_button.position = Vector2(screen.x - 70, 116)
	pause_button.size = Vector2(57, 43)
	minimap.position = Vector2(14, 158)
	minimap.size = Vector2(minf(94, screen.x * 0.26), minf(94, screen.x * 0.26))
	perf_overlay.position = Vector2(15, 145)
	if settings_panel != null:
		settings_panel.size = Vector2(minf(screen.x - 28, 420), minf(screen.y - 65, 420))
		settings_panel.position = (screen - settings_panel.size) * 0.5
	shop_panel.size = Vector2(minf(screen.x - 30, 540), minf(screen.y - 55, 620))
	shop_panel.position = (screen - shop_panel.size) * 0.5
	if dialogue_panel != null:
		dialogue_panel.size = Vector2(minf(screen.x - 22.0, 560.0), minf(screen.y - 32.0, 540.0))
		dialogue_panel.position = (screen - dialogue_panel.size) * 0.5

extends Node3D

const CityScript = preload("res://scripts/city.gd")
const HeroScript = preload("res://scripts/hero.gd")
const InteriorScript = preload("res://scripts/interior.gd")
const Shapes = preload("res://scripts/shape_factory.gd")

const WEAPONS := [
	{"id": "Handgun", "price": 0, "damage": 25.0, "rate": 0.29, "range": 50.0, "ammo": 180},
	{"id": "Rifle", "price": 650, "damage": 32.0, "rate": 0.14, "range": 75.0, "ammo": 150},
	{"id": "Shotgun", "price": 450, "damage": 88.0, "rate": 0.78, "range": 24.0, "ammo": 45},
	{"id": "Sniper", "price": 1100, "damage": 140.0, "rate": 1.20, "range": 130.0, "ammo": 35},
	{"id": "Machine Gun", "price": 1500, "damage": 18.0, "rate": 0.075, "range": 66.0, "ammo": 350}
]
const SAVE_PATH := "user://pocket_district_save.json"

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


func _ready() -> void:
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
	camera.position = hero.position + Vector3(0, 7, 12)
	camera.look_at(hero.position + Vector3(0, 1.0, 0))
	for person in city.people:
		connect_actor(person)
	load_game()
	setup_ui()
	make_mission_marker()
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
	if fire_held or Input.is_key_pressed(KEY_SPACE):
		shoot()
	if shop_panel != null and shop_panel.visible:
		return
	var motion := read_motion()
	if indoors or car_driven == null:
		hero.walk(motion, sprint_enabled or Input.is_key_pressed(KEY_SHIFT), camera, delta)
	else:
		car_driven.drive_input = motion
		car_driven.nitro = sprint_enabled or Input.is_key_pressed(KEY_SHIFT)
		hero.global_position = car_driven.global_position + Vector3(0, 2.0, 0)
	if wanted > 0 and not indoors:
		for officer_node in city.police_root.get_children():
			var officer := officer_node as PocketActor
			if not is_instance_valid(officer):
				continue
			officer.engage = true
			officer.chase_target = car_driven if car_driven != null else hero
			var focus := car_driven.global_position if car_driven != null else hero.global_position
			if officer.global_position.distance_to(focus) < 12.0 and officer.strike_cooldown <= 0.0:
				officer.strike_cooldown = 1.7
				hero.hurt(7.0 + float(wanted))
				if hero.hp <= 0.0:
					busted()
			elif officer.global_position.distance_to(focus) > 95.0:
				officer.queue_free()


func _process(delta: float) -> void:
	autosave_clock += delta
	if autosave_clock > 20.0:
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
		if wanted_idle > 32.0:
			wanted -= 1
			wanted_idle = 0.0
	animate_marker(delta)
	update_camera(delta)
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
	var desired := focus + Vector3(0, 7.2, 12.0)
	if indoors:
		desired = focus + Vector3(0.0, 11.0, 6.4)
	elif car_driven != null:
		focus = car_driven.global_position
		desired = focus + car_driven.global_transform.basis.z * 11.5 + Vector3(0, 6.3, 0)
	camera.global_position = camera.global_position.lerp(desired, clampf(delta * (8.0 if indoors else 5.0), 0.0, 1.0))
	camera.look_at(focus + Vector3(0, 1.1, 0), Vector3.UP)


func shoot() -> void:
	if indoors or shoot_clock > 0.0 or (shop_panel != null and shop_panel.visible):
		return
	var gun := selected_gun()
	var gun_id: String = gun["id"]
	if int(ammunition.get(gun_id, 0)) <= 0:
		return
	shoot_clock = float(gun["rate"])
	ammunition[gun_id] = int(ammunition.get(gun_id, 0)) - 1
	var origin := hero.global_position + Vector3(0, 1.36, 0)
	var forward := -hero.body_visual.global_transform.basis.z
	if car_driven != null:
		origin = car_driven.global_position + Vector3(0, 1.55, -0.4)
		forward = -car_driven.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best_actor: PocketActor
	var best_rank := INF
	var max_range := float(gun["range"])
	var potential: Array[Node] = city.person_root.get_children() + city.police_root.get_children()
	for node in potential:
		var a := node as PocketActor
		if not is_instance_valid(a):
			continue
		var to_actor := a.global_position + Vector3(0, 1.2, 0) - origin
		var distance := to_actor.length()
		if distance > max_range or distance < 0.4:
			continue
		var alignment := forward.dot(to_actor.normalized())
		if alignment < (0.90 if gun_id == "Sniper" else 0.72):
			continue
		var rank := distance * (1.0 + (1.0 - alignment) * 5.0)
		if rank < best_rank:
			best_rank = rank
			best_actor = a
	var shot_to := origin + forward * minf(max_range, 42.0)
	if best_actor != null:
		var aim := best_actor.global_position + Vector3(0, 1.0, 0)
		var ray := PhysicsRayQueryParameters3D.create(origin, aim)
		if car_driven != null:
			ray.exclude = [car_driven.get_rid()]
		else:
			ray.exclude = [hero.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.get("collider") == best_actor:
			shot_to = aim
			best_actor.hit(float(gun["damage"]))
	add_tracer(origin, shot_to)
	if wanted == 0:
		add_wanted(1)


func add_tracer(start: Vector3, finish: Vector3) -> void:
	var span := finish - start
	if span.length_squared() < 0.02:
		return
	var bullet := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.025
	cylinder.height = span.length()
	bullet.mesh = cylinder
	bullet.material_override = Shapes.material(Color("#ffcd63"))
	bullet.position = (start + finish) * 0.5
	bullet.quaternion = Quaternion(Vector3.UP, span.normalized())
	add_child(bullet)
	get_tree().create_timer(0.065).timeout.connect(func() -> void:
		if is_instance_valid(bullet):
			bullet.queue_free()
	)


func on_actor_injured(actor: PocketActor) -> void:
	if not actor.has_meta("crime_recorded"):
		actor.set_meta("crime_recorded", true)
		add_wanted(2 if actor.officer else 1)


func on_actor_died(_actor: PocketActor) -> void:
	pass


func add_wanted(levels: int) -> void:
	wanted = clampi(wanted + levels, 0, 5)
	wanted_idle = 0.0


func busted() -> void:
	if car_driven != null:
		exit_car()
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
	current_weapon = (current_weapon + 1) % owned_weapons.size()
	shoot_clock = 0.0


func interaction() -> void:
	if shop_panel.visible:
		close_shop()
		return
	if indoors:
		if interior.exit_near(hero.global_position):
			leave_interior()
		return
	if car_driven != null:
		exit_car()
		return
	var door := city.closest_door(hero.global_position)
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
	car_driven = car
	car.occupied = true
	car.drive_speed = car.npc_speed
	hero.visible = false
	var body := hero.get_node("CollisionShape3D") as CollisionShape3D
	body.set_deferred("disabled", true)
	add_wanted(1)


func exit_car() -> void:
	if car_driven == null:
		return
	var leave_at := car_driven.global_position + car_driven.global_transform.basis.x * 3.1
	hero.global_position = Vector3(leave_at.x, 0.45, leave_at.z)
	hero.visible = true
	var body := hero.get_node("CollisionShape3D") as CollisionShape3D
	body.set_deferred("disabled", false)
	car_driven.occupied = false
	car_driven.drive_input = Vector2.ZERO
	car_driven.nitro = false
	car_driven = null


func enter_interior(door: Dictionary) -> void:
	if car_driven != null:
		exit_car()
	active_building = String(door["id"])
	outdoor_exit = door["door"]
	if not layouts.has(active_building):
		layouts[active_building] = InteriorScript.make_layout(active_building)
		save_game()
	interior.display_layout(active_building, layouts[active_building])
	indoors = true
	city.visible = false
	city.process_mode = Node.PROCESS_MODE_DISABLED
	interior.visible = true
	sky.environment.background_color = Color("#373b40")
	hero.global_position = InteriorScript.INTERIOR_ORIGIN + Vector3(0, 0.35, 6.5)
	hero.velocity = Vector3.ZERO
	stick_value = Vector2.ZERO


func leave_interior() -> void:
	indoors = false
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
		mission_point = Vector3(0, 0.2, 0)
	else:
		mission_point = Vector3(72, 0.2, 72)
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
		var destinations := [
			Vector3(72.0, 0.2, 72.0),
			Vector3(-72.0, 0.2, 36.0),
			Vector3(36.0, 0.2, -72.0),
			Vector3(-36.0, 0.2, -36.0)
		]
		mission_point = destinations[deliveries % destinations.size()]
	else:
		mission_stage = 0
		deliveries += 1
		cash += 360
		mission_point = Vector3(0, 0.2, 0)
		save_game()
	refresh_mission_marker()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	if not decoded is Dictionary:
		return
	cash = maxi(0, int(decoded.get("cash", cash)))
	deliveries = maxi(0, int(decoded.get("deliveries", 0)))
	layouts = decoded.get("interiors", {})
	owned_weapons.clear()
	for item in decoded.get("owned", ["Handgun"]):
		var name := String(item)
		if WEAPONS.any(func(g: Dictionary) -> bool: return g["id"] == name):
			owned_weapons.append(name)
	if owned_weapons.is_empty():
		owned_weapons.append("Handgun")
	ammunition = decoded.get("ammo", {"Handgun": 180})
	current_weapon = clampi(int(decoded.get("equipped", 0)), 0, owned_weapons.size() - 1)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var state := {
		"cash": cash,
		"deliveries": deliveries,
		"interiors": layouts,
		"owned": owned_weapons,
		"ammo": ammunition,
		"equipped": current_weapon
	}
	file.store_string(JSON.stringify(state, "\t"))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			interaction()
		elif event.keycode == KEY_Q or event.keycode == KEY_TAB:
			next_weapon()
		elif event.keycode == KEY_R:
			sprint_enabled = not sprint_enabled
	if event is InputEventScreenTouch:
		if event.pressed and stick_pointer == -1 and (event.position - stick_center).length() < 145.0 and not on_action_button(event.position):
			stick_pointer = event.index
			update_stick(event.position)
		elif not event.pressed and event.index == stick_pointer:
			stick_pointer = -1
			update_stick(stick_center)
	if event is InputEventScreenDrag and event.index == stick_pointer:
		update_stick(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (event.position - stick_center).length() < 145.0 and not on_action_button(event.position):
			mouse_stick = true
			update_stick(event.position)
		elif not event.pressed and mouse_stick:
			mouse_stick = false
			update_stick(stick_center)
	if event is InputEventMouseMotion and mouse_stick:
		update_stick(event.position)


func on_action_button(point: Vector2) -> bool:
	for button in [fire_button, action_button, run_button, weapon_button]:
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
	weapon_label.text = "%s   %d ROUNDS" % [gun["id"], int(ammunition.get(gun["id"], 0))]
	var current_position := car_driven.global_position if car_driven != null else hero.global_position
	var waypoint := mission_point - current_position
	var heading := waypoint_arrow(waypoint)
	mission_label.text = "DELIVERY %s %dm  •  %s  [%d]" % [heading, int(waypoint.length()), "PICKUP" if mission_stage == 0 else "DROP OFF", deliveries]
	var caption := "DRAG TO MOVE  •  ACTION TO INTERACT"
	if indoors:
		caption = "ACTION: EXIT" if interior.exit_near(hero.global_position) else "RETURN TO THE EXIT MARKER"
	elif car_driven != null:
		caption = "ACTION: EXIT CAR  •  STICK TO DRIVE"
	elif not city.closest_door(hero.global_position).is_empty():
		var door := city.closest_door(hero.global_position)
		caption = "ACTION: GUN SHOP" if bool(door["shop"]) else "ACTION: ENTER BUILDING"
	elif city.closest_car(hero.global_position) != null:
		caption = "ACTION: TAKE VEHICLE"
	elif hero.global_position.distance_to(mission_point) < 5.2:
		caption = "ACTION: COLLECT PARCEL" if mission_stage == 0 else "ACTION: DELIVER PARCEL"
	hint_label.text = caption
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
	layer.add_child(ui)
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
	fire_button.button_down.connect(func() -> void: fire_held = true)
	fire_button.button_up.connect(func() -> void: fire_held = false)
	action_button.pressed.connect(interaction)
	run_button.pressed.connect(func() -> void: sprint_enabled = not sprint_enabled)
	weapon_button.pressed.connect(next_weapon)
	for button in [fire_button, action_button, run_button, weapon_button]:
		ui.add_child(button)
	create_shop_ui()


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
		if gun["id"] == "Handgun":
			continue
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
		ammunition[gun_name] = int(ammunition.get(gun_name, 0)) + int(gun["ammo"])
		save_game()
		refresh_shop_ui()
		return


func layout_ui() -> void:
	if ui == null:
		return
	var screen := get_viewport().get_visible_rect().size
	ui.size = screen
	var banner := ui.get_node("Banner") as Panel
	banner.position = Vector2(12, 12)
	banner.size = Vector2(screen.x - 24, 101)
	status_label.position = Vector2(24, 19)
	status_label.size = Vector2(screen.x - 36, 32)
	weapon_label.position = Vector2(24, 61)
	weapon_label.size = Vector2(screen.x - 36, 32)
	mission_label.position = Vector2(21, 136)
	mission_label.size = Vector2(screen.x - 36, 32)
	hint_label.position = Vector2(10, screen.y - 74)
	hint_label.size = Vector2(screen.x - 20, 54)
	stick_center = Vector2(screen.x * 0.73, screen.y - 185)
	stick_outer.position = stick_center - Vector2(100, 100)
	stick_outer.size = Vector2(200, 200)
	stick_knob.size = Vector2(82, 82)
	update_stick(stick_center)
	fire_button.position = Vector2(screen.x - 142, screen.y - 486)
	action_button.position = Vector2(screen.x - 142, screen.y - 402)
	run_button.position = Vector2(screen.x - 292, screen.y - 486)
	weapon_button.position = Vector2(screen.x - 292, screen.y - 402)
	for button in [fire_button, action_button, run_button, weapon_button]:
		button.size = Vector2(128, 68)
	shop_panel.size = Vector2(minf(screen.x - 30, 540), 510)
	shop_panel.position = (screen - shop_panel.size) * 0.5

extends Control
class_name PocketMiniMap
## Draw-only minimap. Icons are procedural graphics (no textures).
var game: Node3D
var map_scale: float = 0.72
var compass_angle: float = 0.0
var refresh_clock: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	refresh_clock += delta
	if refresh_clock >= 0.12:
		refresh_clock = 0.0
		queue_redraw()

func to_map(world: Vector3, origin: Vector3) -> Vector2:
	var relative := Vector2(world.x - origin.x, world.z - origin.z) * map_scale
	return size / 2.0 + relative

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.09, 0.13, 0.83), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.33, 0.70, 0.74, 0.9), false, 1.5)
	if not is_instance_valid(game) or game.hero == null or game.city == null:
		return
	if game.indoors:
		draw_string(ThemeDB.fallback_font, Vector2(18, size.y * 0.54), "INTERIOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		return
	var focus: Vector3 = game.hero.global_position
	if is_instance_valid(game.car_driven):
		focus = game.car_driven.global_position
	for k in range(-3, 4):
		var p := float(k) * 36.0
		var dx := (p - focus.x) * map_scale + size.x * 0.5
		var dz := (p - focus.z) * map_scale + size.y * 0.5
		draw_line(Vector2(dx, 1), Vector2(dx, size.y - 1), Color("#47545d"), 5)
		draw_line(Vector2(1, dz), Vector2(size.x - 1, dz), Color("#47545d"), 5)
	for building in game.city.buildings:
		if bool(building["shop"]):
			var point := to_map(building["door"], focus)
			if Rect2(Vector2.ZERO, size).has_point(point):
				draw_circle(point, 4, Color("#a0e1ff"))
	for car in game.city.cars:
		if is_instance_valid(car):
			var point := to_map(car.global_position, focus)
			if Rect2(Vector2.ZERO, size).has_point(point):
				draw_circle(point, 2.0, Color("#a8b9c3"))
	for officer in game.city.police_root.get_children():
		if is_instance_valid(officer):
			var point := to_map(officer.global_position, focus)
			if Rect2(Vector2.ZERO, size).has_point(point):
				draw_circle(point, 3.4, Color("#ff6467"))
	var waypoint: Vector3 = game.mission_point
	var marker := to_map(waypoint, focus)
	marker = marker.clamp(Vector2(7, 7), size - Vector2(7, 7))
	draw_circle(marker, 5.0, Color("#ffd46a"))
	draw_circle(size * 0.5, 5.0, Color("#71fff1"))
	draw_line(size * 0.5, size * 0.5 - Vector2(sin(game.camera_yaw), cos(game.camera_yaw)) * 11, Color("#e2fffd"), 2.0)

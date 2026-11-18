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
	# Curves, raised expressway and service alleys share the world-space map.
	var freeway_from := to_map(Vector3(-144, 0, 137), focus)
	var freeway_to := to_map(Vector3(144, 0, 137), focus)
	draw_line(freeway_from, freeway_to, Color("#c9a36a"), 5)
	for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var previous := Vector2.ZERO
		for step in range(17):
			var angle := float(step) / 16.0 * PI * 0.5
			var world := Vector3(corner.x * (98.0 + cos(angle) * 30.0), 0, corner.y * (98.0 + sin(angle) * 30.0))
			var point := to_map(world, focus)
			if step > 0:
				draw_line(previous, point, Color("#647583"), 3)
			previous = point
	for building in game.city.buildings:
		# A partially rebuilt/tearing-down district can contain a temporary
		# incomplete lot: never crash the HUD drawing pass over absent keys.
		if not building.has("door") or not building.has("position"):
			continue
		if bool(building.get("alley", false)):
			var lot_center: Vector3 = building["block_center"]
			draw_line(to_map(lot_center + Vector3(8.4, 0, -17), focus), to_map(lot_center + Vector3(8.4, 0, 17), focus), Color("#8b9da0"), 2)
		var door: Vector3 = building["door"]
		var point := to_map(door, focus)
		if not Rect2(Vector2.ZERO, size).has_point(point):
			continue
		var business: String = String(building.get("business", ""))
		if business == "garage":
			draw_circle(point, 4.6, Color("#56ecd8"))
		elif business == "gun":
			draw_circle(point, 4, Color("#f1c780"))
		elif business == "apartment":
			var purchased: bool = game.purchased_homes.has(String(building["id"]))
			draw_circle(point, 4, Color("#6ef5b7") if purchased else Color("#82cfff"))
		elif business in ["supermarket", "convenience", "clothing", "furniture", "market"]:
			draw_circle(point, 3.5, Color("#ffe1a2"))
		elif business in ["lounge", "club"]:
			draw_circle(point, 3.5, Color("#dca1ed"))
	# Unclaimed cache discovery points are legible without changing NPC traffic.
	if is_instance_valid(game.street_finds):
		for cache_index in range(game.street_finds.total_count()):
			if game.street_finds.collected.has(game.street_finds.site_ids[cache_index]):
				continue
			var spot: Vector2 = to_map(game.street_finds.site_positions[cache_index], focus)
			if Rect2(Vector2.ZERO, size).has_point(spot):
				draw_circle(spot, 3.2, Color("#f5d78c"))
				draw_arc(spot, 5.1, 0.0, TAU, 10, Color("#314e5a"), 1.5)
	# Dedicated minimap symbols for optional neighborhood jobs and the owned car.
	if is_instance_valid(game.neighborhood_jobs):
		var board_point: Vector2 = to_map(game.neighborhood_jobs.board_position, focus)
		if Rect2(Vector2.ZERO, size).has_point(board_point):
			draw_circle(board_point, 4.4, Color("#7cc2ee"))
		if game.neighborhood_jobs.active:
			var job_point: Vector2 = to_map(game.neighborhood_jobs.objective_position(), focus)
			job_point = job_point.clamp(Vector2(6, 6), size - Vector2(6, 6))
			draw_circle(job_point, 5.0, Color("#74f3c9"))
	if is_instance_valid(game.garage_car):
		var owned_point: Vector2 = to_map(game.garage_car.global_position, focus)
		if Rect2(Vector2.ZERO, size).has_point(owned_point):
			draw_circle(owned_point, 3.8, Color("#49e5d5"))
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

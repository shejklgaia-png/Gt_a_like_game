extends RefCounted
class_name PocketSidewalkRoute
## Ground-level CITY GPS graph: along curb-side paths and only cross traffic
## lanes at marked intersection crosswalks. This is guidance, not autopilot.
## Dynamic endpoint projections connect to an immutable 196-node walkway mesh.
## On the outer ring/freeway the existing general CITY A* is used instead.

const TrafficRules = preload("res://scripts/traffic_rules.gd")
const ROADS := 7
const COORDS := ROADS * 2
const ROAD_STEP := 36.0
const CURB := 6.35
const START_ID := COORDS * COORDS + 1
const GOAL_ID := START_ID + 1
const REPATH_DISTANCE := 12.0
const GOAL_REPATH_DISTANCE := 3.0
const ROUTE_REFRESH_SECONDS := 1.5
const ARRIVAL_DISTANCE := 3.3
const MIN_GUIDANCE_DISTANCE := 4.4

var graph := AStar2D.new()
var city_nav: PocketNavGrid
var path_points: PackedVector2Array = PackedVector2Array()
var planned_from := Vector2.ZERO
var planned_to := Vector2.ZERO
var refresh_clock: float = 0.0
var computation_count: int = 0


static func horizontal(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


static func coord(index: int) -> float:
	var road := floori(float(index) / 2.0) - 3
	return float(road) * ROAD_STEP + (-CURB if index % 2 == 0 else CURB)


static func node_id(ix: int, iz: int) -> int:
	return iz * COORDS + ix + 1


func setup(nav: PocketNavGrid) -> void:
	city_nav = nav
	graph.clear()
	for iz in range(COORDS):
		for ix in range(COORDS):
			graph.add_point(node_id(ix, iz), Vector2(coord(ix), coord(iz)))
	for iz in range(COORDS):
		for ix in range(COORDS):
			if ix + 1 < COORDS:
				graph.connect_points(node_id(ix, iz), node_id(ix + 1, iz))
			if iz + 1 < COORDS:
				graph.connect_points(node_id(ix, iz), node_id(ix, iz + 1))
	graph.add_point(START_ID, Vector2.ZERO)
	graph.add_point(GOAL_ID, Vector2.ZERO)
	clear()


func clear() -> void:
	path_points.clear()
	planned_from = Vector2.ZERO
	planned_to = Vector2.ZERO
	refresh_clock = 0.0


func can_route(from: Vector3, goal: Vector3) -> bool:
	if city_nav == null:
		return false
	# The elevated freeway and outer ring use existing general navigation.
	return absf(from.x) <= 116.0 and absf(from.z) <= 116.0 and absf(goal.x) <= 116.0 and absf(goal.z) <= 116.0 and absf(from.y) <= 2.2 and absf(goal.y) <= 2.2


func nearest_link(at: Vector2) -> Dictionary:
	var nearest_clear := INF
	var nearest_any := INF
	var clear_choice: Dictionary = {}
	var any_choice: Dictionary = {}
	for iz in range(COORDS):
		for ix in range(COORDS):
			var start_id := node_id(ix, iz)
			var a: Vector2 = graph.get_point_position(start_id)
			for end_id in [node_id(ix + 1, iz) if ix + 1 < COORDS else -1, node_id(ix, iz + 1) if iz + 1 < COORDS else -1]:
				if end_id == -1:
					continue
				var b: Vector2 = graph.get_point_position(end_id)
				var segment: Vector2 = b - a
				var ratio := clampf((at - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
				var foot: Vector2 = a + segment * ratio
				var distance2 := at.distance_squared_to(foot)
				if distance2 < nearest_any:
					nearest_any = distance2
					any_choice = {"a": start_id, "b": end_id, "point": foot}
				if distance2 < nearest_clear and is_visible_connection(at, foot):
					nearest_clear = distance2
					clear_choice = {"a": start_id, "b": end_id, "point": foot}
	return clear_choice if not clear_choice.is_empty() else any_choice


func is_visible_connection(start: Vector2, finish: Vector2) -> bool:
	if city_nav == null:
		return true
	var gap: float = start.distance_to(finish)
	if gap > 20.0:
		return false
	var steps := maxi(1, ceili(gap))
	for step in range(1, steps):
		var sample: Vector2 = start.lerp(finish, float(step) / float(steps))
		var cell: Vector2i = city_nav.id_from_world(Vector3(sample.x, 0.0, sample.y))
		if city_nav.grid.is_in_boundsv(cell) and city_nav.grid.is_point_solid(cell):
			return false
	return true


func disconnect_temporary(id: int) -> void:
	for linked in graph.get_point_connections(id):
		graph.disconnect_points(id, linked)


func rebuild(from: Vector3, goal: Vector3) -> void:
	path_points.clear()
	disconnect_temporary(START_ID)
	disconnect_temporary(GOAL_ID)
	var entry: Dictionary = nearest_link(horizontal(from))
	var exit: Dictionary = nearest_link(horizontal(goal))
	if entry.is_empty() or exit.is_empty():
		return
	graph.set_point_position(START_ID, entry["point"])
	graph.set_point_position(GOAL_ID, exit["point"])
	for link in [int(entry["a"]), int(entry["b"])]:
		graph.connect_points(START_ID, link)
	for link in [int(exit["a"]), int(exit["b"])]:
		graph.connect_points(GOAL_ID, link)
	if int(entry["a"]) == int(exit["a"]) and int(entry["b"]) == int(exit["b"]):
		graph.connect_points(START_ID, GOAL_ID)
	path_points = graph.get_point_path(START_ID, GOAL_ID)


func refresh(from: Vector3, goal: Vector3, delta: float = 0.0) -> void:
	if not can_route(from, goal):
		clear()
		return
	var position2 := horizontal(from)
	var goal2 := horizontal(goal)
	refresh_clock = maxf(0.0, refresh_clock - delta)
	var target_changed := path_points.is_empty() or planned_to.distance_to(goal2) > GOAL_REPATH_DISTANCE
	var walked_far := planned_from.distance_to(position2) > REPATH_DISTANCE
	if not target_changed and (not walked_far or refresh_clock > 0.0):
		return
	if not target_changed and refresh_clock > 0.0:
		return
	planned_from = position2
	planned_to = goal2
	refresh_clock = ROUTE_REFRESH_SECONDS
	rebuild(from, goal)
	computation_count += 1


func closest_path_index(from: Vector3) -> int:
	if path_points.is_empty():
		return 0
	var current: Vector2 = horizontal(from)
	var best := INF
	var nearest := 0
	for index in range(path_points.size()):
		var distance2 := current.distance_squared_to(path_points[index])
		if distance2 < best:
			best = distance2
			nearest = index
	return nearest


func next_guidance_point(from: Vector3, goal: Vector3) -> Vector3:
	if path_points.size() < 2:
		return goal
	var at: Vector2 = horizontal(from)
	var nearest := closest_path_index(from)
	var next_id: int = mini(path_points.size() - 1, nearest + 1)
	for index in range(next_id, path_points.size()):
		if at.distance_to(path_points[index]) >= MIN_GUIDANCE_DISTANCE:
			next_id = index
			break
	var point: Vector2 = path_points[next_id]
	if next_id == path_points.size() - 1 and at.distance_to(point) < 3.0:
		return goal
	return Vector3(point.x, goal.y, point.y)


func remaining_distance(from: Vector3, goal: Vector3) -> float:
	var at: Vector2 = horizontal(from)
	var target: Vector2 = horizontal(goal)
	if path_points.size() < 2:
		return at.distance_to(target)
	var begin := closest_path_index(from)
	var length := at.distance_to(path_points[begin])
	for index in range(begin + 1, path_points.size()):
		length += path_points[index - 1].distance_to(path_points[index])
	length += path_points[path_points.size() - 1].distance_to(target)
	return length


func is_arrived(from: Vector3, goal: Vector3) -> bool:
	return horizontal(from).distance_to(horizontal(goal)) <= ARRIVAL_DISTANCE


func visible_route(from: Vector3, goal: Vector3) -> PackedVector2Array:
	var visible := PackedVector2Array()
	if path_points.size() < 2 or is_arrived(from, goal):
		return visible
	var nearest := closest_path_index(from)
	visible.append(horizontal(from))
	for index in range(nearest, path_points.size()):
		visible.append(path_points[index])
	visible.append(horizontal(goal))
	return visible


static func crosswalk_axis(a: Vector2, b: Vector2) -> int:
	# A true marked crossing is the 12.7 m gap between curbs at an
	# intersection: z-motion has sidewalk_axis=0 and x-motion has axis=1.
	var delta := b - a
	if absf(absf(delta.y) - CURB * 2.0) < 0.15 and absf(delta.x) < 0.15:
		var center_z := (a.y + b.y) * 0.5
		if absf(center_z - roundf(center_z / ROAD_STEP) * ROAD_STEP) < 0.2:
			return 0
	if absf(absf(delta.x) - CURB * 2.0) < 0.15 and absf(delta.y) < 0.15:
		var center_x := (a.x + b.x) * 0.5
		if absf(center_x - roundf(center_x / ROAD_STEP) * ROAD_STEP) < 0.2:
			return 1
	return -1


func next_crosswalk(from: Vector3) -> Dictionary:
	if path_points.size() < 2:
		return {}
	var at: Vector2 = horizontal(from)
	var begin := closest_path_index(from)
	for index in range(begin, mini(path_points.size() - 1, begin + 4)):
		var a: Vector2 = path_points[index]
		var b: Vector2 = path_points[index + 1]
		var axis := crosswalk_axis(a, b)
		if axis < 0:
			continue
		if at.distance_to(a) <= 6.5:
			return {"axis": axis, "from": a, "to": b, "green": TrafficRules.pedestrians_have_green(axis)}
	return {}


func crossing_hint(from: Vector3) -> String:
	var crossing := next_crosswalk(from)
	if crossing.is_empty():
		return ""
	return "横断歩道：青で進む" if bool(crossing["green"]) else "横断歩道：赤信号で待機"

extends RefCounted
class_name PocketCityRoute
## Low-frequency A* routing on the city's prebuilt, building-blocked grid.
## This is an advisory path, not autopilot or guaranteed signal-safe walkways.
## Existing city navigation serves police; no new grid or physical objects.

const REPATH_DISTANCE: float = 12.0
const GOAL_REPATH_DISTANCE: float = 3.0
const ROUTE_REFRESH_SECONDS: float = 1.5
const ARRIVAL_DISTANCE: float = 3.3
const MIN_GUIDANCE_DISTANCE: float = 4.4

var navigation: PocketNavGrid
var path_points: PackedVector2Array = PackedVector2Array()
var planned_from: Vector2 = Vector2.ZERO
var planned_to: Vector2 = Vector2.ZERO
var refresh_clock: float = 0.0
var computation_count: int = 0


func setup(source: PocketNavGrid) -> void:
	navigation = source
	clear()


func clear() -> void:
	path_points.clear()
	planned_from = Vector2.ZERO
	planned_to = Vector2.ZERO
	refresh_clock = 0.0


static func horizontal(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)


func refresh(from: Vector3, goal: Vector3, delta: float = 0.0) -> void:
	if navigation == null:
		return
	var start2: Vector2 = horizontal(from)
	var goal2: Vector2 = horizontal(goal)
	refresh_clock = maxf(0.0, refresh_clock - delta)
	var target_changed := path_points.is_empty() or planned_to.distance_to(goal2) > GOAL_REPATH_DISTANCE
	var walked_far := planned_from.distance_to(start2) > REPATH_DISTANCE
	if not target_changed and (not walked_far or refresh_clock > 0.0):
		return
	if not target_changed and refresh_clock > 0.0:
		return
	planned_from = start2
	planned_to = goal2
	refresh_clock = ROUTE_REFRESH_SECONDS
	path_points = navigation.path(from, goal)
	computation_count += 1


func closest_path_index(from: Vector3) -> int:
	if path_points.is_empty():
		return 0
	var at: Vector2 = horizontal(from)
	var best := INF
	var closest := 0
	for index in range(path_points.size()):
		var length_squared := at.distance_squared_to(path_points[index])
		if length_squared < best:
			best = length_squared
			closest = index
	return closest


func next_guidance_point(from: Vector3, goal: Vector3) -> Vector3:
	if path_points.size() < 2:
		return goal
	var at: Vector2 = horizontal(from)
	var nearest := closest_path_index(from)
	var next_index: int = mini(path_points.size() - 1, nearest + 1)
	for index in range(next_index, path_points.size()):
		if at.distance_to(path_points[index]) >= MIN_GUIDANCE_DISTANCE:
			next_index = index
			break
	var point: Vector2 = path_points[next_index]
	# Once the route leaves its last grid point, steer to the exact entrance.
	if next_index == path_points.size() - 1 and at.distance_to(point) < 3.0:
		return goal
	return Vector3(point.x, goal.y, point.y)


func remaining_distance(from: Vector3, goal: Vector3) -> float:
	var at: Vector2 = horizontal(from)
	var destination: Vector2 = horizontal(goal)
	if path_points.size() < 2:
		return at.distance_to(destination)
	var start := closest_path_index(from)
	var length := at.distance_to(path_points[start])
	for index in range(start + 1, path_points.size()):
		length += path_points[index - 1].distance_to(path_points[index])
	length += path_points[path_points.size() - 1].distance_to(destination)
	return length


func is_arrived(from: Vector3, goal: Vector3) -> bool:
	return horizontal(from).distance_to(horizontal(goal)) <= ARRIVAL_DISTANCE


func visible_route(from: Vector3, goal: Vector3) -> PackedVector2Array:
	var result := PackedVector2Array()
	if path_points.size() < 2 or is_arrived(from, goal):
		return result
	var nearest := closest_path_index(from)
	result.append(horizontal(from))
	# Skipping points that are already behind the player prevents old route
	# segments from reappearing on the minimap as they walk or drive forward.
	for index in range(nearest, path_points.size()):
		result.append(path_points[index])
	result.append(horizontal(goal))
	return result

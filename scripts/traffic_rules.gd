extends RefCounted
## A synchronized crossing schedule for both road directions and pedestrian corridors.
const CYCLE := 28.0
const GREEN_DURATION := 11.0
const ALL_RED_DURATION := 3.0
const ROAD_SPACING := 36.0

static func phase() -> float:
	return fposmod(float(Time.get_ticks_msec()) * 0.001, CYCLE)

static func cars_have_green(axis: int) -> bool:
	var t := phase()
	if axis == 0:
		return t < GREEN_DURATION
	return t >= GREEN_DURATION + ALL_RED_DURATION and t < 2.0 * GREEN_DURATION + ALL_RED_DURATION

static func pedestrians_have_green(sidewalk_axis: int) -> bool:
	# A pedestrian traveling along Z crosses an X-direction car lane, and vice versa.
	return cars_have_green(sidewalk_axis)

static func next_intersection_distance(axis: int, direction: float, at: Vector3) -> float:
	var along := at.z if axis == 0 else at.x
	if direction >= 0.0:
		var crossing := ceilf((along + 0.01) / ROAD_SPACING) * ROAD_SPACING
		return crossing - along
	var crossing := floorf((along - 0.01) / ROAD_SPACING) * ROAD_SPACING
	return along - crossing

static func must_stop_car(axis: int, travel: float, at: Vector3) -> bool:
	var d := next_intersection_distance(axis, travel, at)
	return d >= 6.0 and d <= 16.0 and not cars_have_green(axis)

static func crossing_center(along: float) -> float:
	return roundf(along / ROAD_SPACING) * ROAD_SPACING

static func safe_pedestrian_crossing(from: Vector3, target: Vector3, axis: int) -> bool:
	if axis == 0:
		return absf(target.z - from.z) < 0.1 or pedestrians_have_green(axis)
	return absf(target.x - from.x) < 0.1 or pedestrians_have_green(axis)

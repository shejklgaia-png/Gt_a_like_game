extends Node3D
class_name PocketNeighborhoodJobs
## Optional, non-violent neighborhood assignments independent of parcel delivery.
## Each assignment has two inspected locations; completion and progress persist.

const Shapes = preload("res://scripts/shape_factory.gd")
const CONTRACTS := [
	{"title": "STREET SURVEY", "places": ["office", "convenience"], "reward": 220},
	{"title": "MARKET INSPECTION", "places": ["supermarket", "restaurant"], "reward": 270},
	{"title": "NIGHT DISTRICT CHECK", "places": ["lounge", "club"], "reward": 320}
]

var board_position: Vector3 = Vector3.ZERO
var board_marker: Node3D
var destination_marker: Node3D
var locations: Array[Dictionary] = []
var completed: int = 0
var active: bool = false
var step_index: int = 0


func setup(buildings: Array[Dictionary], saved: Dictionary = {}) -> void:
	locations = buildings.duplicate(true)
	completed = clampi(int(saved.get("completed", 0)), 0, 100000)
	active = bool(saved.get("active", false))
	step_index = clampi(int(saved.get("step", 0)), 0, 1)
	var board_lot := find_lot("office")
	if board_lot.is_empty():
		return
	var office_door: Vector3 = board_lot["door"]
	board_position = office_door + Vector3(-3.6, 0.0, -0.9)
	board_marker = Node3D.new()
	board_marker.name = "NeighborhoodJobBoard"
	board_marker.position = board_position
	add_child(board_marker)
	Shapes.box(board_marker, Vector3(0, 1.10, 0), Vector3(1.65, 2.0, 0.24), Color("#42646c"))
	Shapes.box(board_marker, Vector3(0, 1.52, -0.17), Vector3(1.30, 0.72, 0.08), Color("#f1c47d"))
	Shapes.sign3d(board_marker, "JOBS", Vector3(0, 2.35, 0), Color("#f6e0ad"))
	destination_marker = Node3D.new()
	destination_marker.name = "NeighborhoodJobDestination"
	add_child(destination_marker)
	Shapes.ball(destination_marker, Vector3(0, 1.1, 0), 0.52, Color("#82e4d3"))
	Shapes.sign3d(destination_marker, "CHECK", Vector3(0, 2.6, 0), Color("#bdf9e5"))
	update_marker()


func restore(saved: Dictionary) -> void:
	completed = clampi(int(saved.get("completed", 0)), 0, 100000)
	active = bool(saved.get("active", false))
	step_index = clampi(int(saved.get("step", 0)), 0, 1)
	update_marker()


func find_lot(business: String) -> Dictionary:
	for lot in locations:
		if String(lot.get("business", "")) == business:
			return lot
	return {}


func active_contract() -> Dictionary:
	return CONTRACTS[completed % CONTRACTS.size()]


func objective_position() -> Vector3:
	if not active:
		return board_position
	var contract: Dictionary = active_contract()
	var businesses: Array = contract["places"]
	var lot := find_lot(String(businesses[step_index]))
	if not lot.is_empty():
		var destination: Vector3 = lot["door"]
		return destination
	return board_position


func update_marker() -> void:
	if not is_instance_valid(destination_marker):
		return
	destination_marker.visible = active
	if active:
		destination_marker.position = objective_position()


func close_to_job(at: Vector3, distance_m: float = 2.9) -> bool:
	if not is_instance_valid(board_marker):
		return false
	return at.distance_to(objective_position()) <= distance_m


func action_hint() -> String:
	if not active:
		return "ACCEPT A NEIGHBORHOOD JOB"
	return "INSPECT LOCATION %d/2" % (step_index + 1)


func describe_progress() -> String:
	if not active:
		return "JOBS AVAILABLE"
	return "%s %d/2" % [String(active_contract()["title"]), step_index + 1]


func try_interact(at: Vector3) -> Dictionary:
	if not close_to_job(at):
		return {}
	if not active:
		active = true
		step_index = 0
		update_marker()
		return {"event": "start", "reward": 0, "message": String(active_contract()["title"]) + " STARTED"}
	step_index += 1
	if step_index < 2:
		update_marker()
		return {"event": "step", "reward": 0, "message": "SITE CHECKED - NEXT STOP"}
	var reward: int = int(active_contract()["reward"])
	completed += 1
	active = false
	step_index = 0
	update_marker()
	return {"event": "finish", "reward": reward, "message": "SIDE JOB COMPLETED +$%d" % reward}


func save_state() -> Dictionary:
	return {"completed": completed, "active": active, "step": step_index}

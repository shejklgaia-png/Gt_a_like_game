extends Node3D
class_name PocketConversationActivities
## Optional activities accepted in a resident conversation. NPC speech is
## untouched: offer labels and rewards are player-facing game UI, not dialogue.
## Routes, cash rewards, rapport and completion are persistent and independent
## of courier and neighborhood contracts.

const Shapes = preload("res://scripts/shape_factory.gd")
const TYPES := [
	{"id": "food", "title": "食べ歩きの下見", "role": "外食", "locations": ["restaurant", "supermarket"], "reward": 120},
	{"id": "work", "title": "職場まわりのお手伝い", "role": "勤務", "locations": ["office", "market"], "reward": 175},
	{"id": "market", "title": "買い出しルート探し", "role": "買い物", "locations": ["market", "convenience"], "reward": 135},
	{"id": "home", "title": "部屋づくりの相談", "role": "帰宅", "locations": ["furniture", "apartment"], "reward": 145},
	{"id": "night", "title": "夜の街の見回り", "role": "外食", "locations": ["lounge", "club"], "reward": 180},
	{"id": "garage", "title": "車と街の施設を調べる", "role": "勤務", "locations": ["garage", "convenience"], "reward": 150},
	{"id": "meet", "title": "別の住民を紹介してもらう", "role": "帰宅", "locations": [], "reward": 160}
]

var buildings: Array[Dictionary] = []
var citizens: Array[PocketActor] = []
var active: bool = false
var kind: String = ""
var giver_id: int = -1
var step_index: int = 0
var completed: Dictionary = {}
var total_completed: int = 0
var marker: Node3D


func setup(lots: Array[Dictionary], people: Array[PocketActor], saved: Dictionary = {}) -> void:
	buildings = lots
	citizens = people
	marker = Node3D.new()
	marker.name = "ResidentActivityGoal"
	add_child(marker)
	Shapes.ball(marker, Vector3(0, 1.25, 0), 0.39, Color("#ffcf85"))
	Shapes.sign3d(marker, "ACTIVITY", Vector3(0, 2.65, 0), Color("#ffe7bc"))
	restore(saved)


func offer_by_id(activity_id: String) -> Dictionary:
	for offer in TYPES:
		if String(offer["id"]) == activity_id:
			return offer
	return {}


func record_key(id: int, activity_id: String) -> String:
	return "%d:%s" % [id, activity_id]


func offers_for(resident_id: int, daily_role: String, scenario: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if active or resident_id < 0 or resident_id >= citizens.size():
		return options
	var preferred := -1
	for index in range(TYPES.size()):
		if String(TYPES[index]["role"]) == daily_role:
			preferred = index
			break
	if preferred < 0:
		preferred = posmod(resident_id, TYPES.size())
	# A familiar activity reflects a resident's daily routine; a second
	# introduces a less obvious neighborhood experience from the topic.
	var candidates: Array[int] = [preferred, posmod(scenario / 10 + resident_id * 3, TYPES.size())]
	for index in range(TYPES.size()):
		candidates.append(posmod(preferred + index, TYPES.size()))
	for choice in candidates:
		if options.size() >= 2:
			break
		var offer: Dictionary = TYPES[choice]
		var activity_id: String = String(offer["id"])
		if completed.has(record_key(resident_id, activity_id)):
			continue
		if not find_available_destination(offer, resident_id):
			continue
		if options.any(func(entry: Dictionary) -> bool: return String(entry["id"]) == activity_id):
			continue
		options.append(offer.duplicate(true))
	return options


func find_available_destination(offer: Dictionary, resident_id: int) -> bool:
	if String(offer.get("id", "")) == "meet":
		for person in citizens:
			if is_instance_valid(person) and person.resident_id != resident_id and not person.dead:
				return true
		return false
	for business in offer.get("locations", []):
		if find_lot(String(business)).is_empty():
			return false
	return true


func find_lot(business: String) -> Dictionary:
	for lot in buildings:
		if String(lot.get("business", "")) == business and lot.has("door"):
			return lot
	return {}


func target_resident_id() -> int:
	if citizens.size() < 2 or giver_id < 0:
		return -1
	for offset in range(1, citizens.size()):
		var candidate: int = posmod(giver_id + offset * 7, citizens.size())
		if candidate == giver_id:
			continue
		if is_instance_valid(citizens[candidate]) and not citizens[candidate].dead:
			return candidate
	return -1


func active_offer() -> Dictionary:
	return offer_by_id(kind) if active else {}


func objective_position() -> Vector3:
	if not active:
		return Vector3.ZERO
	if kind == "meet":
		var peer_id := target_resident_id()
		if peer_id >= 0:
			return citizens[peer_id].global_position
		return Vector3.ZERO
	var offer: Dictionary = active_offer()
	if offer.is_empty():
		return Vector3.ZERO
	var locations: Array = offer["locations"]
	var business: String = String(locations[clampi(step_index, 0, locations.size() - 1)])
	var lot := find_lot(business)
	if lot.is_empty():
		return Vector3.ZERO
	var door: Vector3 = lot["door"]
	return door


func objective_description() -> String:
	if not active:
		return ""
	if kind == "meet":
		var peer := target_resident_id()
		return "紹介された住民と会話する" if peer >= 0 else "会える住民を探しています"
	var offer: Dictionary = active_offer()
	var location_names := {
		"restaurant": "飲食店", "supermarket": "スーパー", "office": "オフィス",
		"market": "市場", "convenience": "コンビニ", "furniture": "家具店",
		"apartment": "住宅", "lounge": "ラウンジ", "club": "クラブ", "garage": "ガレージ"
	}
	var locations: Array = offer.get("locations", [])
	if locations.is_empty():
		return ""
	var business: String = String(locations[clampi(step_index, 0, locations.size() - 1)])
	return "%sを調べる（%d/%d）" % [String(location_names.get(business, business)), step_index + 1, locations.size()]


func progress_text() -> String:
	if not active:
		return "会話から住民の活動を受注できます"
	var offer: Dictionary = active_offer()
	return "%s：%s" % [String(offer.get("title", "")), objective_description()]


func accept(activity_id: String, resident_id: int) -> bool:
	if active or resident_id < 0 or resident_id >= citizens.size():
		return false
	if completed.has(record_key(resident_id, activity_id)):
		return false
	var offer := offer_by_id(activity_id)
	if offer.is_empty() or not find_available_destination(offer, resident_id):
		return false
	active = true
	kind = activity_id
	giver_id = resident_id
	step_index = 0
	update_marker()
	return true


func _process(_delta: float) -> void:
	if active and kind == "meet" and is_instance_valid(marker):
		marker.position = objective_position()


func update_marker() -> void:
	if not is_instance_valid(marker):
		return
	marker.visible = active
	if active:
		marker.position = objective_position()


func abandon() -> bool:
	# A player must not be trapped by an unfinished request or an NPC who
	# disappears from the simulated city. No payout or progress is awarded.
	if not active:
		return false
	active = false
	kind = ""
	giver_id = -1
	step_index = 0
	update_marker()
	return true


func finish() -> Dictionary:
	if not active:
		return {}
	var offer: Dictionary = active_offer()
	if offer.is_empty():
		return {}
	completed[record_key(giver_id, kind)] = true
	total_completed = mini(100000, total_completed + 1)
	var result := {
		"event": "finish",
		"reward": int(offer["reward"]),
		"giver": giver_id,
		"message": "%s 完了 +$%d" % [String(offer["title"]), int(offer["reward"])]
	}
	active = false
	kind = ""
	giver_id = -1
	step_index = 0
	update_marker()
	return result


func interact_at(at: Vector3) -> Dictionary:
	if not active or kind == "meet":
		return {}
	if Vector2(at.x, at.z).distance_to(Vector2(objective_position().x, objective_position().z)) > 2.9:
		return {}
	var offer: Dictionary = active_offer()
	var locations: Array = offer["locations"]
	step_index += 1
	if step_index >= locations.size():
		return finish()
	update_marker()
	return {
		"event": "step",
		"reward": 0,
		"giver": giver_id,
		"message": "現地確認完了：次は" + objective_description()
	}


func meet_resident(resident_id: int) -> Dictionary:
	if not active or kind != "meet" or resident_id != target_resident_id():
		return {}
	return finish()


func save_state() -> Dictionary:
	return {
		"active": active, "kind": kind, "giver": giver_id,
		"step": step_index, "completed": completed.duplicate(true), "total": total_completed
	}


func restore(saved: Dictionary) -> void:
	completed.clear()
	var safe_entries = saved.get("completed", {})
	if safe_entries is Dictionary:
		for key in safe_entries:
			var parts: PackedStringArray = String(key).split(":")
			if parts.size() != 2 or not parts[0].is_valid_int() or not bool(safe_entries[key]):
				continue
			var id := int(parts[0])
			if id >= 0 and id < citizens.size() and not offer_by_id(parts[1]).is_empty():
				completed[String(key)] = true
	total_completed = clampi(int(saved.get("total", completed.size())), 0, 100000)
	kind = String(saved.get("kind", ""))
	giver_id = int(saved.get("giver", -1))
	step_index = clampi(int(saved.get("step", 0)), 0, 1)
	active = bool(saved.get("active", false))
	var offer := offer_by_id(kind)
	if not active or offer.is_empty() or giver_id < 0 or giver_id >= citizens.size() or completed.has(record_key(giver_id, kind)):
		active = false
		kind = ""
		giver_id = -1
		step_index = 0
	update_marker()

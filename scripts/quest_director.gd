extends Node
class_name PocketQuestDirector
## Event-driven narrative jobs. 200 authored records, 25 distinct triggers,
## at most three concurrent jobs, unique rewards and safe save restoration.
## Never synthesizes NPC speech or replaces the existing dialogue catalog.

signal started(record: Dictionary)
signal advanced(record: Dictionary)
signal finished(record: Dictionary)

const FILES := [
	"res://data/quests_01.json",
	"res://data/quests_02.json",
	"res://data/quests_03.json",
	"res://data/quests_04.json",
	"res://data/quests_05.json"
]
const MAX_ACTIVE: int = 3
const REOFFER_DELAY: float = 18.0

var catalog: Dictionary = {}
var event_index: Dictionary = {}
var active: Array[Dictionary] = []
var completed: Dictionary = {}
var lots: Array[Dictionary] = []
var citizens: Array[PocketActor] = []
var started_at: Dictionary = {}
var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta


func setup(buildings: Array[Dictionary], people: Array[PocketActor], saved: Dictionary = {}) -> void:
	lots = buildings
	citizens = people
	load_catalog()
	restore(saved)


func load_catalog() -> void:
	catalog.clear()
	event_index.clear()
	for file in FILES:
		if not FileAccess.file_exists(file):
			push_error("Quest catalog missing: " + file)
			continue
		var document = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not document is Dictionary:
			push_error("Quest catalog invalid JSON: " + file)
			continue
		var data: Dictionary = document
		var entries = data.get("quests", [])
		if not entries is Array:
			push_error("Quest chapter has no array: " + file)
			continue
		for value in entries:
			if not value is Dictionary:
				continue
			var entry: Dictionary = value
			var id := String(entry.get("id", ""))
			var event := String(entry.get("trigger", ""))
			var steps = entry.get("stages", [])
			if not id.begins_with("Q") or id.length() != 4 or not id.substr(1).is_valid_int() or catalog.has(id) or event.is_empty() or not steps is Array or steps.size() != 2:
				push_error("Quest entry rejected: " + id)
				continue
			catalog[id] = entry.duplicate(true)
			if not event_index.has(event):
				event_index[event] = []
			var ids: Array = event_index[event]
			ids.append(id)
	if catalog.size() != 200 or event_index.size() != 25:
		push_error("Expected exactly 200 quests / 25 triggers; found %d / %d" % [catalog.size(), event_index.size()])


func get_quest(id: String) -> Dictionary:
	return catalog.get(id, {})


func completed_count() -> int:
	return completed.size()


func save_state() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"completed": completed.duplicate(true)
	}


func restore(saved: Dictionary) -> void:
	active.clear()
	completed.clear()
	var done = saved.get("completed", {})
	if done is Dictionary:
		for id in done:
			if catalog.has(String(id)) and bool(done[id]):
				completed[String(id)] = true
	var active_saved = saved.get("active", [])
	if active_saved is Array:
		for incoming in active_saved:
			if active.size() >= MAX_ACTIVE:
				break
			if not incoming is Dictionary:
				continue
			var id: String = String(incoming.get("id", ""))
			if not catalog.has(id) or completed.has(id):
				continue
			var step := clampi(int(incoming.get("step", 0)), 0, 1)
			if active.any(func(a: Dictionary) -> bool: return String(a["id"]) == id):
				continue
			active.append({
				"id": id, "step": step,
				"progress": clampf(float(incoming.get("progress", 0.0)), 0.0, 100000.0),
				"giver": clampi(int(incoming.get("giver", -1)), -1, 100000)
			})


func stage_for(record: Dictionary) -> Dictionary:
	var quest: Dictionary = get_quest(String(record.get("id", "")))
	var stages: Array = quest.get("stages", [])
	var index: int = int(record.get("step", 0))
	if index >= 0 and index < stages.size() and stages[index] is Dictionary:
		return stages[index]
	return {}


func stage_text(stage: Dictionary) -> String:
	var action: String = String(stage.get("event", ""))
	var business: String = String(stage.get("business", ""))
	var names := {
		"gun": "武器店", "garage": "ガレージ", "supermarket": "スーパー",
		"convenience": "コンビニ", "clothing": "洋服店", "furniture": "家具店",
		"market": "市場", "office": "オフィス", "restaurant": "飲食店",
		"apartment": "住居", "lounge": "ラウンジ", "club": "クラブ",
		"general": "一般施設"
	}
	var place: String = String(names.get(business, business))
	match action:
		"lot_action": return place + "の入口でACTION"
		"interior_enter": return place + "の中へ入る"
		"interior_exit": return "入った建物から退出する"
		"conversation": return "住民と会話する" if String(stage.get("resident", "")) != "giver" else "依頼主の住民と再び会話する"
		"police_contact": return "巡回警官にACTIONで話しかける"
		"furniture_bought": return "家具店で" + String(stage.get("item", "")) + "を購入"
		"furniture_placed": return "マイルームに" + String(stage.get("item", "")) + "を配置"
		"weapon_bought": return "武器店で装備を購入"
		"car_entered": return "車に乗る"
		"driving": return "車であと約%d m移動" % int(stage.get("amount", 40))
		"wanted_cleared": return "警戒度を0に戻して安全を確保する"
		"sidejob_completed": return "地域ジョブを1件完了する"
		"delivery_completed": return "配達を1件完了する"
		"street_find": return "街中の隠し物資を回収する"
		_: return "街で関連する行動を行う"


func describe(record: Dictionary) -> String:
	var row: Dictionary = get_quest(String(record.get("id", "")))
	if row.is_empty():
		return ""
	var stage := stage_for(record)
	var detail := stage_text(stage)
	if String(stage.get("event", "")) == "driving":
		var remain := maxi(0, int(stage.get("amount", 0)) - int(record.get("progress", 0)))
		detail = "車であと約%d m走る" % remain
	return "%s（%d/2）：%s" % [String(row.get("title", "")), int(record.get("step", 0)) + 1, detail]


func matches(conditions: Dictionary, payload: Dictionary, record: Dictionary = {}) -> bool:
	for field in conditions:
		if String(field) in ["event", "amount"]:
			continue
		var expected: String = String(conditions[field])
		if expected == "" or expected == "any":
			continue
		if field == "resident" and expected == "giver":
			if not payload.has("resident_id") or int(payload["resident_id"]) != int(record.get("giver", -1)):
				return false
		elif String(payload.get(field, "")) != expected:
			return false
	return true


func on_event(event: String, payload: Dictionary = {}) -> void:
	# Existing jobs react first; a freshly offered job cannot complete
	# instantly from the same event that started it.
	for index in range(active.size() - 1, -1, -1):
		var record: Dictionary = active[index]
		var stage: Dictionary = stage_for(record)
		if String(stage.get("event", "")) != event:
			continue
		if not matches(stage, payload, record):
			continue
		if stage.has("amount"):
			var amount: float = maxf(0.0, float(payload.get("amount", 0.0)))
			record["progress"] = float(record.get("progress", 0.0)) + amount
			if float(record["progress"]) < float(stage["amount"]):
				active[index] = record
				continue
		record["step"] = int(record["step"]) + 1
		record["progress"] = 0.0
		var row: Dictionary = get_quest(String(record["id"]))
		if int(record["step"]) >= 2:
			active.remove_at(index)
			completed[String(record["id"])] = true
			var result: Dictionary = row.duplicate(true)
			result["giver"] = int(record.get("giver", -1))
			finished.emit(result)
		else:
			active[index] = record
			var result: Dictionary = row.duplicate(true)
			result["record"] = record.duplicate(true)
			advanced.emit(result)
	# Only known events can start quests.
	if not event_index.has(event) or active.size() >= MAX_ACTIVE:
		return
	# Distance accumulation updates active vehicle steps every frame. Only a
	# genuine 45 m travel milestone is allowed to discover a new driving job.
	if event == "driving" and not bool(payload.get("ready", false)):
		return
	if active.any(func(entry: Dictionary) -> bool: return String(get_quest(String(entry["id"])).get("trigger", "")) == event):
		return
	if elapsed - float(started_at.get(event, -10000.0)) < REOFFER_DELAY:
		return
	var choices: Array = event_index[event]
	for id in choices:
		var code := String(id)
		if completed.has(code) or active.any(func(entry: Dictionary) -> bool: return String(entry["id"]) == code):
			continue
		var quest: Dictionary = catalog[code]
		if not matches(quest.get("require", {}), payload):
			continue
		var giver := int(payload.get("resident_id", -1))
		var record := {"id": code, "step": 0, "progress": 0.0, "giver": giver}
		active.append(record)
		started_at[event] = elapsed
		var result: Dictionary = quest.duplicate(true)
		result["record"] = record.duplicate(true)
		started.emit(result)
		return


func abandon(id: String) -> bool:
	for index in range(active.size()):
		if String(active[index]["id"]) == id:
			active.remove_at(index)
			return true
	return false


func closest_lot(business: String, from: Vector3) -> Dictionary:
	var nearest := INF
	var result: Dictionary = {}
	for lot in lots:
		if not lot.has("door") or String(lot.get("business", "")) != business:
			continue
		var at: Vector3 = lot["door"]
		var distance := Vector2(at.x - from.x, at.z - from.z).length_squared()
		if distance < nearest:
			nearest = distance
			result = lot
	return result


func waypoint(record: Dictionary, from: Vector3, garage: Node3D = null, job_board: Vector3 = Vector3.ZERO, delivery: Vector3 = Vector3.ZERO) -> Dictionary:
	var stage := stage_for(record)
	if stage.is_empty():
		return {}
	var action := String(stage.get("event", ""))
	var business := String(stage.get("business", ""))
	if business != "":
		var lot := closest_lot(business, from)
		if not lot.is_empty():
			return {"point": lot["door"], "label": stage_text(stage)}
	if action == "conversation":
		var id := int(record.get("giver", -1)) if String(stage.get("resident", "")) == "giver" else -1
		if id >= 0 and id < citizens.size() and is_instance_valid(citizens[id]) and not citizens[id].dead:
			return {"point": citizens[id].global_position, "label": stage_text(stage)}
		var best := INF
		for resident in citizens:
			if not is_instance_valid(resident) or resident.dead:
				continue
			var gap: float = from.distance_squared_to(resident.global_position)
			if gap < best:
				best = gap
				id = resident.resident_id
		if id >= 0 and id < citizens.size():
			return {"point": citizens[id].global_position, "label": stage_text(stage)}
	if action == "police_contact":
		return {"point": Vector3(6.35, 0.25, 18.0), "label": stage_text(stage)}
	if action in ["furniture_bought", "furniture_placed"]:
		var shop := closest_lot("furniture" if action == "furniture_bought" else "apartment", from)
		if not shop.is_empty():
			return {"point": shop["door"], "label": stage_text(stage)}
	if action in ["car_entered", "driving"]:
		if is_instance_valid(garage):
			return {"point": garage.global_position, "label": stage_text(stage)}
		var garage_lot := closest_lot("garage", from)
		if not garage_lot.is_empty():
			return {"point": garage_lot["door"], "label": stage_text(stage)}
	if action == "sidejob_completed":
		return {"point": job_board, "label": stage_text(stage)}
	if action == "delivery_completed":
		return {"point": delivery, "label": stage_text(stage)}
	return {}

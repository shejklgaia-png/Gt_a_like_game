extends Node3D
class_name PocketStreetFinds
## Lightweight one-time street discoveries. No collision shapes or imported art.
## Stable lot IDs make these collectible caches backward-compatible with saves.

const Shapes = preload("res://scripts/shape_factory.gd")

var site_ids: Array[String] = []
var site_positions: Array[Vector3] = []
var markers: Array[Node3D] = []
var collected: Dictionary = {}


func setup(buildings: Array[Dictionary], completed: Dictionary = {}) -> void:
	collected = completed.duplicate(true)
	for index in range(buildings.size()):
		if index % 3 != 0:
			continue
		var lot: Dictionary = buildings[index]
		var site_id: String = String(lot["id"])
		var door: Vector3 = lot["door"]
		# In front of the facade, not in the traffic lane or inside a wall.
		var site := door + Vector3(3.15, 0.0, -1.75)
		var node := Node3D.new()
		node.name = "Cache_" + site_id
		node.position = site
		add_child(node)
		Shapes.box(node, Vector3(0.0, 0.24, 0.0), Vector3(0.62, 0.48, 0.52), Color("#395a61"))
		Shapes.ball(node, Vector3(0, 0.60, 0), 0.23, Color("#f0cb78"))
		site_ids.append(site_id)
		site_positions.append(site)
		markers.append(node)
	refresh()


func refresh() -> void:
	for index in range(markers.size()):
		markers[index].visible = not collected.has(site_ids[index])


func nearest(at: Vector3, range_m: float = 2.15) -> int:
	var best := range_m
	var result := -1
	for index in range(site_positions.size()):
		if collected.has(site_ids[index]):
			continue
		var distance := at.distance_to(site_positions[index])
		if distance < best:
			best = distance
			result = index
	return result


func collect(index: int) -> int:
	if index < 0 or index >= site_ids.size() or collected.has(site_ids[index]):
		return 0
	collected[site_ids[index]] = true
	markers[index].visible = false
	return reward_for(index)


func reward_for(index: int) -> int:
	return 70 + (index % 4) * 25


func count_collected() -> int:
	var count := 0
	for site_id in site_ids:
		if collected.has(site_id):
			count += 1
	return count


func total_count() -> int:
	return site_ids.size()

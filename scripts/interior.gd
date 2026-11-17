extends Node3D
class_name PocketInterior

const Shapes = preload("res://scripts/shape_factory.gd")
const LootItem = preload("res://scripts/loot_item.gd")
const Actor = preload("res://scripts/actor.gd")
const Furniture = preload("res://scripts/furniture_catalog.gd")
const INTERIOR_ORIGIN := Vector3(920.0, 0.0, 920.0)
var active_id: String = ""
var loot: PocketLoot
var occupants: Array[PocketActor] = []
var room_furniture: Node3D
var home_mode: bool = false


static func make_layout(building_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(building_id.hash()) + 993451
	var plan := rng.randi_range(0, 3)
	var props: Array[Dictionary] = []
	var occupied := PackedVector2Array()
	var tries := 0
	# Keep a central access corridor plus all internal door openings clear.
	while props.size() < 11 and tries < 130:
		tries += 1
		var x := snappedf(rng.randf_range(-7.0, 7.0), 0.5)
		var z := snappedf(rng.randf_range(-7.1, 5.9), 0.5)
		if absf(x) < 2.25 or Vector2(x - 4.5, z - 5.2).length() < 2.3:
			continue
		if plan == 0 and absf(x + 1.0) < 1.25:
			continue
		if plan == 1 and absf(z + 1.0) < 1.25:
			continue
		if plan == 2 and (absf(x - 2.2) < 1.25 or absf(z + 3.8) < 1.25):
			continue
		if plan == 3 and (absf(x + 3.8) < 1.25 or absf(z - 2.0) < 1.25):
			continue
		var overlap := false
		for old in occupied:
			if old.distance_to(Vector2(x, z)) < 2.5:
				overlap = true
				break
		if overlap:
			continue
		occupied.append(Vector2(x, z))
		props.append({
			"x": x,
			"z": z,
			"kind": rng.randi_range(0, 4),
			"color": rng.randi_range(0, 3)
		})
	return {
		"template": plan,
		"props": props,
		"building": building_id,
		"loot_value": rng.randi_range(90, 240)
	}


func display_layout(building_id: String, layout: Dictionary, loot_taken: bool = false, business: String = "general", owned_home: bool = false, furniture_items: Array = [], visit: int = 0) -> void:
	active_id = building_id
	home_mode = owned_home
	loot = null
	occupants.clear()
	for old_node in get_children():
		remove_child(old_node)
		old_node.queue_free()
	position = INTERIOR_ORIGIN
	var palette := [Color("#4a525a"), Color("#625857"), Color("#516467"), Color("#65665b")]
	var floor_color: Color = palette[int(layout.get("template", 0)) % palette.size()]
	var wall_color := Color("#92959a")
	Shapes.box(self, Vector3(0, -0.2, 0), Vector3(18, 0.4, 18), floor_color, true)
	Shapes.box(self, Vector3(-9, 2.05, 0), Vector3(0.35, 4.1, 18.3), wall_color, true)
	Shapes.box(self, Vector3(9, 2.05, 0), Vector3(0.35, 4.1, 18.3), wall_color, true)
	Shapes.box(self, Vector3(0, 2.05, -9), Vector3(18.3, 4.1, 0.35), wall_color, true)
	Shapes.box(self, Vector3(-5.2, 2.05, 9), Vector3(7.6, 4.1, 0.35), wall_color, true)
	Shapes.box(self, Vector3(5.2, 2.05, 9), Vector3(7.6, 4.1, 0.35), wall_color, true)
	Shapes.box(self, Vector3(0, 3.55, 9), Vector3(2.8, 1.1, 0.35), wall_color, true)
	Shapes.box(self, Vector3(0, 0.08, 8.84), Vector3(2.7, 0.06, 0.16), Color("#e1bd5a"))
	Shapes.sign3d(self, "EXIT", Vector3(0, 2.80, 8.8), Color("#ffdf9d"))
	var layout_type := int(layout.get("template", 0))
	set_meta("room_template", layout_type)
	if layout_type == 0:
		partition_vertical(-1.0, wall_color)
	elif layout_type == 1:
		partition_horizontal(-1.0, wall_color)
	elif layout_type == 2:
		partition_vertical(2.2, wall_color)
		partition_horizontal(-3.8, wall_color)
	else:
		partition_horizontal(2.0, wall_color)
		partition_vertical(-3.8, wall_color)
	var colors := [Color("#5f8791"), Color("#bd9b71"), Color("#86698d"), Color("#6d896e")]
	for prop in ([] if home_mode else layout.get("props", [])):
		var px := float(prop.get("x", 0.0))
		var pz := float(prop.get("z", 0.0))
		if px > -1.8 and px < 1.8 and pz > 5.0:
			continue
		var kind := int(prop.get("kind", 0))
		var color: Color = colors[int(prop.get("color", 0)) % colors.size()]
		if kind == 0:
			Shapes.box(self, Vector3(px, 0.6, pz), Vector3(1.4, 1.2, 0.7), color, true)
		elif kind == 1:
			Shapes.box(self, Vector3(px, 0.5, pz), Vector3(1.5, 1.0, 1.4), color, true)
		elif kind == 2:
			Shapes.box(self, Vector3(px, 0.92, pz), Vector3(2.0, 0.14, 1.2), color, true)
			Shapes.box(self, Vector3(px, 0.41, pz), Vector3(0.20, 0.84, 0.20), Color("#52575d"))
		else:
			Shapes.box(self, Vector3(px, 0.55, pz), Vector3(0.88, 1.1, 0.88), color, true)
	if not home_mode:
		loot = LootItem.new()
		loot.name = "SearchableLoot"
		loot.claimed = loot_taken
		loot.worth = maxi(30, int(layout.get("loot_value", 120)))
		loot.position = Vector3(4.5, 0.77, 5.2)
		add_child(loot)
	room_furniture = Node3D.new()
	room_furniture.name = "PlacedFurniture"
	add_child(room_furniture)
	for record in furniture_items:
		if record is Dictionary:
			Furniture.place(room_furniture, record)
	if not home_mode:
		populate_interior(building_id, business, visit)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.75, 0)
	lamp.light_color = Color("#f0e5d0")
	lamp.light_energy = 1.9
	lamp.omni_range = 25.0
	add_child(lamp)


func partition_vertical(x: float, tint: Color) -> void:
	Shapes.box(self, Vector3(x, 1.6, -5.7), Vector3(0.20, 3.2, 6.6), tint, true)
	Shapes.box(self, Vector3(x, 1.6, 4.8), Vector3(0.20, 3.2, 7.7), tint, true)


func partition_horizontal(z: float, tint: Color) -> void:
	Shapes.box(self, Vector3(-5.7, 1.6, z), Vector3(6.6, 3.2, 0.20), tint, true)
	Shapes.box(self, Vector3(4.8, 1.6, z), Vector3(7.7, 3.2, 0.20), tint, true)


func exit_near(at: Vector3) -> bool:
	return Vector2(at.x - INTERIOR_ORIGIN.x, at.z - (INTERIOR_ORIGIN.z + 7.6)).length() < 3.6

func loot_near(at: Vector3) -> bool:
	return loot != null and is_instance_valid(loot) and not loot.claimed and loot.global_position.distance_to(at) < 2.4

func search_loot(at: Vector3) -> int:
	if loot_near(at):
		return loot.collect()
	return 0


func populate_interior(building_id: String, business: String, visit: int = 0) -> void:
	# One to four inhabitants, instantiated only in the currently active room.
	# Most visits have exclusively civilians. Nightlife quarters modestly raise
	# the chance of encountering a hostile mafia group.
	var random := RandomNumberGenerator.new()
	random.seed = abs(building_id.hash()) * 17 + maxi(visit, 0) * 13007 + 151
	var chance := 0.20 if business in ["club", "lounge"] else 0.10
	var hostile_visit: bool = random.randf() < chance
	var quantity: int = random.randi_range(1, 4)
	var positions := [
		Vector3(-5.9, 0.12, -5.9), Vector3(5.9, 0.12, -5.9),
		Vector3(-5.9, 0.12, 3.4), Vector3(5.9, 0.12, 3.4)
	]
	for index in range(quantity):
		var person: PocketActor = Actor.new()
		person.name = "Mafia" if hostile_visit and index == quantity - 1 else "Civilian"
		person.position = positions[index]
		person.mafia = hostile_visit and index == quantity - 1
		person.indoor_mode = true
		person.resident_id = 46 + posmod(building_id.hash(), 10000) * 4 + index
		if person.mafia:
			person.position = Vector3(0.2, 0.12, 3.2)
		person.setup(false, person.position, random.randi())
		add_child(person)
		occupants.append(person)


func arm_hostiles(player: Node3D) -> void:
	for person in occupants:
		if is_instance_valid(person) and person.mafia and not person.dead:
			person.chase_target = player


func valid_furniture_position(local: Vector3, kind: String, existing: Array) -> bool:
	if not home_mode or Furniture.find(kind).is_empty():
		return false
	var size: Vector2 = Furniture.find(kind)["size"]
	var margin: float = maxf(size.x, size.y) * 0.5 + 0.5
	if absf(local.x) > 8.0 - margin or absf(local.z) > 8.0 - margin:
		return false
	# Exit space and broad center-to-exit approach remain accessible.
	if local.z > 3.8 and absf(local.x) < 2.5 + size.x * 0.5:
		return false
	# Keep major partition walls free. The same room template remains valid.
	if int(get_meta("room_template", -1)) == 0 and absf(local.x + 1.0) < 1.1 + size.x * 0.5:
		return false
	if int(get_meta("room_template", -1)) == 1 and absf(local.z + 1.0) < 1.1 + size.y * 0.5:
		return false
	if int(get_meta("room_template", -1)) == 2 and (absf(local.x - 2.2) < 1.1 + size.x * 0.5 or absf(local.z + 3.8) < 1.1 + size.y * 0.5):
		return false
	if int(get_meta("room_template", -1)) == 3 and (absf(local.x + 3.8) < 1.1 + size.x * 0.5 or absf(local.z - 2.0) < 1.1 + size.y * 0.5):
		return false
	for item in existing:
		if not (item is Dictionary):
			continue
		var other: Dictionary = Furniture.find(String(item.get("kind", "")))
		if other.is_empty():
			continue
		var other_size: Vector2 = other["size"]
		var dx: float = absf(local.x - float(item.get("x", 0.0)))
		var dz: float = absf(local.z - float(item.get("z", 0.0)))
		if dx < (size.x + other_size.x) * 0.5 + 0.4 and dz < (size.y + other_size.y) * 0.5 + 0.4:
			return false
	return true


func add_furniture(record: Dictionary) -> bool:
	if not home_mode or not is_instance_valid(room_furniture):
		return false
	return Furniture.place(room_furniture, record) != null


func closest_civilian(at: Vector3, max_distance: float = 2.9) -> PocketActor:
	var best: float = max_distance
	var found: PocketActor = null
	for person in occupants:
		if not is_instance_valid(person) or person.mafia or person.dead or person.panic_time > 0.0:
			continue
		var distance: float = Vector2(at.x - person.global_position.x, at.z - person.global_position.z).length()
		if distance < best:
			found = person
			best = distance
	return found

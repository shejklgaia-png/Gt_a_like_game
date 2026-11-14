extends Node3D
class_name PocketInterior

const Shapes = preload("res://scripts/shape_factory.gd")
const INTERIOR_ORIGIN := Vector3(920.0, 0.0, 920.0)
var active_id: String = ""


static func make_layout(building_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(building_id.hash()) + 993451
	var props: Array[Dictionary] = []
	for index in range(7):
		var x := rng.randf_range(-6.8, 6.8)
		var z := rng.randf_range(-6.4, 4.5)
		if absf(x) < 1.5 and z > 3.5:
			z -= 4.2
		props.append({
			"x": snappedf(x, 0.5),
			"z": snappedf(z, 0.5),
			"kind": rng.randi_range(0, 3),
			"color": rng.randi_range(0, 3)
		})
	return {
		"template": rng.randi_range(0, 3),
		"props": props,
		"building": building_id
	}


func display_layout(building_id: String, layout: Dictionary) -> void:
	active_id = building_id
	for old_node in get_children():
		remove_child(old_node)
		old_node.queue_free()
	position = INTERIOR_ORIGIN
	var floor_color := Color("#4a525a")
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
	for prop in layout.get("props", []):
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

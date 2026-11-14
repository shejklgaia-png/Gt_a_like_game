extends Node3D
class_name PocketTrafficLights
const Rules = preload("res://scripts/traffic_rules.gd")
const Shapes = preload("res://scripts/shape_factory.gd")
var east_lights: Array[MeshInstance3D] = []
var north_lights: Array[MeshInstance3D] = []
var elapsed: float = 0.0
var last_status: int = -1
var off := Color("#17252c")
var red := Color("#ed5350")
var green := Color("#39c394")

func _ready() -> void:
	for xi in range(-3, 4):
		for zi in range(-3, 4):
			var x := float(xi) * 36.0
			var z := float(zi) * 36.0
			for side in [-1.0, 1.0]:
				var base := Vector3(x + side * 5.35, 0.0, z + side * 5.35)
				Shapes.box(self, base + Vector3(0, 2.5, 0), Vector3(0.14, 5.0, 0.14), Color("#202e34"))
				var x_light := Shapes.box(self, base + Vector3(0.0, 4.5, -0.3), Vector3(0.55, 0.88, 0.25), off)
				var z_light := Shapes.box(self, base + Vector3(-0.3, 4.5, 0.0), Vector3(0.25, 0.88, 0.55), off)
				east_lights.append(x_light.get_child(0) as MeshInstance3D)
				north_lights.append(z_light.get_child(0) as MeshInstance3D)
	refresh_state()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 0.5:
		elapsed = 0.0
		refresh_state()

func refresh_state() -> void:
	var state := (1 if Rules.cars_have_green(0) else 0) + (2 if Rules.cars_have_green(1) else 0)
	if state == last_status:
		return
	last_status = state
	var north_mat := Shapes.material(green if (state & 1) != 0 else red)
	var east_mat := Shapes.material(green if (state & 2) != 0 else red)
	for bulb in north_lights:
		bulb.material_override = north_mat
	for bulb in east_lights:
		bulb.material_override = east_mat

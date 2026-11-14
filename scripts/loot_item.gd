extends Node3D
class_name PocketLoot
const Shapes = preload("res://scripts/shape_factory.gd")
var claimed: bool = false
var worth: int = 120
var bob: float = 0.0
var floating_visual: Node3D

func _ready() -> void:
	floating_visual = Node3D.new()
	add_child(floating_visual)
	Shapes.box(floating_visual, Vector3.ZERO, Vector3(0.66, 0.36, 0.48), Color("#ddbd60"))
	Shapes.box(floating_visual, Vector3(0, 0.2, 0), Vector3(0.36, 0.05, 0.18), Color("#fff3b2"))
	Shapes.sign3d(floating_visual, "SEARCH", Vector3(0, 0.65, 0), Color("#ffdc90"))
	visible = not claimed

func _process(delta: float) -> void:
	bob += delta * 2.0
	if is_instance_valid(floating_visual):
		floating_visual.position.y = sin(bob) * 0.09
		floating_visual.rotation.y += delta * 0.55

func collect() -> int:
	if claimed:
		return 0
	claimed = true
	visible = false
	return worth

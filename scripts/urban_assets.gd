extends RefCounted
const Shapes = preload("res://scripts/shape_factory.gd")

static func install(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 40542
	# Deterministic handmade-looking procedural props.
	for index in range(46):
		var xi := rng.randi_range(-3, 2)
		var zi := rng.randi_range(-3, 2)
		var left_right := 1.0 if index % 2 == 0 else -1.0
		var x := (float(xi) + 0.5) * 36.0 + 13.0 * left_right
		var z := (float(zi) + 0.5) * 36.0 - 13.0 * left_right
		var offset := Vector3(x, 0.05, z)
		match index % 4:
			0: make_tree(parent, offset)
			1: make_bench(parent, offset)
			2: make_trash(parent, offset)
			3: make_hydrant(parent, offset)

static func make_tree(parent: Node3D, at: Vector3) -> void:
	Shapes.box(parent, at + Vector3(0, 1.2, 0), Vector3(0.35, 2.4, 0.35), Color("#655348"))
	Shapes.ball(parent, at + Vector3(0, 3.15, 0), 1.35, Color("#426f58"))
	Shapes.ball(parent, at + Vector3(0.67, 2.75, -0.15), 0.79, Color("#4b8060"))
	Shapes.ball(parent, at + Vector3(-0.45, 2.75, 0.38), 0.67, Color("#315b4d"))

static func make_bench(parent: Node3D, at: Vector3) -> void:
	Shapes.box(parent, at + Vector3(0, 0.54, 0), Vector3(2.1, 0.18, 0.65), Color("#86755f"), true)
	Shapes.box(parent, at + Vector3(0, 1.12, 0.27), Vector3(2.1, 0.88, 0.14), Color("#86755f"))
	for side in [-0.8, 0.8]:
		Shapes.box(parent, at + Vector3(side, 0.26, 0), Vector3(0.12, 0.52, 0.45), Color("#35434c"))

static func make_trash(parent: Node3D, at: Vector3) -> void:
	Shapes.box(parent, at + Vector3(0, 0.51, 0), Vector3(0.60, 1.02, 0.60), Color("#335c5f"), true)
	Shapes.box(parent, at + Vector3(0, 1.04, 0), Vector3(0.72, 0.08, 0.72), Color("#182f39"))

static func make_hydrant(parent: Node3D, at: Vector3) -> void:
	Shapes.box(parent, at + Vector3(0, 0.43, 0), Vector3(0.34, 0.8, 0.34), Color("#bd5d4b"))
	Shapes.box(parent, at + Vector3(0, 0.63, 0), Vector3(0.64, 0.17, 0.25), Color("#d86d55"))
	Shapes.ball(parent, at + Vector3(0, 0.91, 0), 0.24, Color("#dc7660"))

extends RefCounted
const Shapes = preload("res://scripts/shape_factory.gd")

static func flash(parent: Node3D, at: Vector3, intensity: float = 1.0, direction: Vector3 = Vector3.FORWARD) -> void:
	var sparks := Node3D.new()
	sparks.position = at
	parent.add_child(sparks)
	if direction.length_squared() > 0.01:
		sparks.quaternion = Quaternion(Vector3.FORWARD, direction.normalized())
	Shapes.ball(sparks, Vector3.ZERO, 0.12 * intensity, Color("#fff5bc"))
	Shapes.box(sparks, Vector3(0.0, 0.0, -0.13 * intensity), Vector3(0.13, 0.13, 0.48 * intensity), Color("#ffac43"))
	for i in range(4):
		var angle := float(i) * TAU / 4.0
		var shard := Shapes.box(sparks, Vector3(cos(angle) * 0.14, sin(angle) * 0.14, 0), Vector3(0.04, 0.30 * intensity, 0.05), Color("#fff4d2"))
		shard.rotation.z = angle
	erase_after(parent, sparks, 0.11)


static func tracer(parent: Node3D, start: Vector3, finish: Vector3, thick: float, tint: Color, duration: float) -> void:
	var span := finish - start
	if span.length_squared() < 0.003:
		return
	var visual := MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = thick
	beam.bottom_radius = thick * 0.65
	beam.height = span.length()
	visual.mesh = beam
	var mat := Shapes.material(tint)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = mat
	# global_position is only valid after the visual has entered the scene tree.
	parent.add_child(visual)
	visual.global_position = (start + finish) * 0.5
	visual.quaternion = Quaternion(Vector3.UP, span.normalized())
	erase_after(parent, visual, duration)


static func impact(parent: Node3D, at: Vector3, tint: Color, points: float = 0.0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at
	Shapes.ball(root, Vector3.ZERO, 0.17 if points > 0.0 else 0.10, tint)
	for k in range(5):
		var ang := TAU * float(k) / 5.0
		var outward := Vector3(cos(ang), 0.5 + sin(ang) * 0.5, sin(ang))
		var fragment := Shapes.box(root, outward * 0.25, Vector3(0.055, 0.08, 0.06), tint.lightened(0.28))
		var tween := parent.create_tween()
		tween.tween_property(fragment, "position", outward * 0.95, 0.25)
	if points > 0.0:
		var text3d := Shapes.sign3d(root, str(roundi(points)), Vector3(0, 0.56, 0), Color("#ffddbe"))
		text3d.font_size = 58
		text3d.outline_size = 6
		var tween := parent.create_tween()
		tween.tween_property(text3d, "position:y", 1.75, 0.6)
		tween.parallel().tween_property(text3d, "modulate:a", 0.0, 0.6)
	erase_after(parent, root, 0.72 if points > 0.0 else 0.32)


static func erase_after(owner: Node, target: Node, time_sec: float) -> void:
	var tree := owner.get_tree()
	tree.create_timer(time_sec).timeout.connect(func() -> void:
		if is_instance_valid(target):
			target.queue_free()
	)

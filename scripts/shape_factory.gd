extends RefCounted
## Lightweight procedural primitives shared by the town and interiors.

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = false) -> Node3D:
	var base: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		parent.add_child(body)
		var shape := CollisionShape3D.new()
		var data := BoxShape3D.new()
		data.size = size
		shape.shape = data
		body.add_child(shape)
		base = body
	else:
		var visual := Node3D.new()
		visual.position = at
		parent.add_child(visual)
		base = visual
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material(color)
	base.add_child(mesh_node)
	return base


static func ball(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = at
	node.material_override = material(color)
	parent.add_child(node)
	return node


static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.08
	mat.roughness = 0.8
	return mat


static func sign3d(parent: Node3D, caption: String, at: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font_size = 44
	label.pixel_size = 0.011
	label.modulate = color
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	parent.add_child(label)
	return label

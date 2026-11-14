extends RefCounted
## Five native geometry silhouettes, all pointing down local -Z.
const Shapes = preload("res://scripts/shape_factory.gd")

static func build(parent: Node3D, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "EquippedGun"
	parent.add_child(root)
	var black := Color("#1c2630")
	var metal := Color("#515b64")
	var wood := Color("#745848")
	var accent := Color("#a9b8ba")
	var muzzle_z: float = -0.68
	match kind:
		"Handgun":
			Shapes.box(root, Vector3(0, 0.06, -0.23), Vector3(0.20, 0.15, 0.48), black)
			Shapes.box(root, Vector3(0, 0.16, -0.21), Vector3(0.22, 0.10, 0.51), metal)
			Shapes.box(root, Vector3(0, -0.12, -0.06), Vector3(0.16, 0.32, 0.18), black)
			Shapes.box(root, Vector3(0, 0.24, -0.48), Vector3(0.06, 0.08, 0.06), accent)
			muzzle_z = -0.51
		"Rifle":
			Shapes.box(root, Vector3(0, 0.05, -0.35), Vector3(0.22, 0.20, 1.05), metal)
			Shapes.box(root, Vector3(0, 0.01, 0.23), Vector3(0.27, 0.27, 0.47), black)
			Shapes.box(root, Vector3(0, 0.05, 0.58), Vector3(0.16, 0.19, 0.54), black)
			Shapes.box(root, Vector3(0, -0.22, -0.17), Vector3(0.17, 0.42, 0.22), metal)
			Shapes.box(root, Vector3(0, 0.19, -0.41), Vector3(0.09, 0.11, 0.52), black)
			Shapes.box(root, Vector3(0, 0.035, -1.09), Vector3(0.065, 0.065, 0.60), accent)
			muzzle_z = -1.41
		"Shotgun":
			Shapes.box(root, Vector3(0, 0.02, 0.40), Vector3(0.20, 0.24, 0.85), wood)
			Shapes.box(root, Vector3(0, 0.05, -0.24), Vector3(0.21, 0.20, 0.64), metal)
			Shapes.box(root, Vector3(0, -0.01, -0.79), Vector3(0.12, 0.12, 0.72), metal)
			Shapes.box(root, Vector3(0, -0.13, -0.84), Vector3(0.095, 0.095, 0.68), black)
			Shapes.box(root, Vector3(0, -0.10, -0.38), Vector3(0.23, 0.21, 0.30), wood)
			Shapes.box(root, Vector3(0, -0.22, 0.05), Vector3(0.15, 0.26, 0.16), black)
			muzzle_z = -1.19
		"Sniper":
			Shapes.box(root, Vector3(0, 0.04, -0.19), Vector3(0.22, 0.16, 1.05), metal)
			Shapes.box(root, Vector3(0, 0.04, 0.57), Vector3(0.19, 0.20, 0.70), wood)
			Shapes.box(root, Vector3(0, 0.04, -1.14), Vector3(0.07, 0.07, 1.10), black)
			Shapes.box(root, Vector3(0, 0.28, -0.41), Vector3(0.15, 0.16, 0.73), black)
			Shapes.box(root, Vector3(0, 0.24, -0.73), Vector3(0.21, 0.22, 0.12), accent)
			Shapes.box(root, Vector3(0, -0.19, 0.01), Vector3(0.13, 0.34, 0.20), wood)
			Shapes.box(root, Vector3(0, 0.04, -1.73), Vector3(0.19, 0.14, 0.29), metal)
			muzzle_z = -1.92
		"Machine Gun":
			Shapes.box(root, Vector3(0, 0.06, -0.33), Vector3(0.32, 0.27, 1.16), black)
			Shapes.box(root, Vector3(0, 0.08, 0.43), Vector3(0.16, 0.23, 0.66), metal)
			Shapes.box(root, Vector3(0, 0.04, -1.10), Vector3(0.12, 0.12, 0.55), metal)
			Shapes.box(root, Vector3(0, -0.29, -0.37), Vector3(0.42, 0.56, 0.44), metal)
			Shapes.box(root, Vector3(0, 0.28, -0.24), Vector3(0.30, 0.18, 0.82), accent)
			Shapes.box(root, Vector3(0, -0.18, 0.22), Vector3(0.13, 0.30, 0.20), black)
			Shapes.box(root, Vector3(0, 0.04, -1.39), Vector3(0.21, 0.18, 0.25), black)
			muzzle_z = -1.51
		_:
			return build(parent, "Handgun")
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.065, muzzle_z)
	root.add_child(muzzle)
	return root

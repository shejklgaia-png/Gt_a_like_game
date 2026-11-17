extends RefCounted
const Shapes = preload("res://scripts/shape_factory.gd")

## Street-facing architectural identity. No new physics bodies, lights or
## per-frame scripts: inexpensive static meshes and a handful of signs.
static func install(parent: Node3D, buildings: Array[Dictionary]) -> void:
	var root := Node3D.new()
	root.name = "DistrictStorefronts"
	parent.add_child(root)
	for index in range(buildings.size()):
		if OS.get_name() == "Android" and index % 2 != 0:
			continue
		var lot: Dictionary = buildings[index]
		var center: Vector3 = lot["position"]
		var width: float = float(lot["width"])
		var depth: float = float(lot["depth"])
		var front: float = center.z - depth * 0.5 - 0.16
		var business: String = String(lot.get("business", "general"))
		var district: String = String(lot.get("district", "central"))
		var sign_tint := Color("#c3dde7")
		match district:
			"office":
				sign_tint = Color("#9ec9ef")
				for pane in [-1.0, 1.0]:
					Shapes.box(root, Vector3(center.x + pane * width * 0.28, 7.2, front), Vector3(2.6, 8.1, 0.09), Color("#698fa4"))
			"market":
				sign_tint = Color("#e6ba76")
				for side in [-1.0, 1.0]:
					Shapes.box(root, Vector3(center.x + side * width * 0.29, 2.4, front - 0.36), Vector3(3.0, 0.17, 1.15), Color("#d9b36b"))
					Shapes.box(root, Vector3(center.x + side * width * 0.29, 0.84, front - 0.29), Vector3(1.75, 1.25, 0.72), Color("#826a58"))
			"shopping":
				sign_tint = Color("#f8a5c3")
				Shapes.box(root, Vector3(center.x, 4.75, front - 0.18), Vector3(width * 0.78, 0.55, 0.27), sign_tint)
			"nightlife":
				sign_tint = Color("#d39ef9")
				for row in range(3):
					Shapes.box(root, Vector3(center.x + width * 0.37, 5.2 + float(row) * 1.3, front), Vector3(0.17, 0.78, 0.12), Color("#da8df0"))
				Shapes.box(root, Vector3(center.x, 5.4, front - 0.21), Vector3(width * 0.75, 0.25, 0.21), Color("#e6a3ec"))
			"residential":
				sign_tint = Color("#a9d3a5")
			_:
				pass
		if business == "apartment":
			Shapes.box(root, Vector3(center.x + width * 0.30, 1.3, front - 0.28), Vector3(1.3, 1.5, 0.12), Color("#477b75"))
			Shapes.sign3d(root, "HOME $%d" % int(lot["home_price"]), Vector3(center.x + width * 0.30, 1.8, front - 0.40), Color("#dcf5cc"))
		elif business in ["supermarket", "convenience", "clothing", "furniture"]:
			for side in [-1.0, 1.0]:
				Shapes.box(root, Vector3(center.x + side * width * 0.28, 1.7, front), Vector3(2.4, 2.45, 0.10), Color("#73aab2"))
			Shapes.box(root, Vector3(center.x, 4.6, front - 0.1), Vector3(width * 0.70, 0.12, 0.3), sign_tint)
		elif business in ["club", "lounge"]:
			Shapes.box(root, Vector3(center.x, 0.25, front - 0.33), Vector3(3.0, 0.07, 0.65), sign_tint)
		elif business == "restaurant":
			Shapes.box(root, Vector3(center.x + width * 0.28, 3.2, front - 0.1), Vector3(1.75, 0.55, 0.21), Color("#f0c687"))

extends RefCounted
## Shared shop stock and placed-home visuals. Data are small, serializable dictionaries.
const Shapes = preload("res://scripts/shape_factory.gd")
const STOCK := [
	{"id": "sofa", "name": "ソファ", "price": 220, "size": Vector2(2.4, 1.0), "color": Color("#996e9e")},
	{"id": "bed", "name": "ベッド", "price": 320, "size": Vector2(2.0, 2.7), "color": Color("#789aaf")},
	{"id": "table", "name": "テーブル", "price": 140, "size": Vector2(1.5, 1.1), "color": Color("#ad936c")},
	{"id": "chair", "name": "チェア", "price": 80, "size": Vector2(0.75, 0.75), "color": Color("#a5826e")},
	{"id": "shelf", "name": "本棚", "price": 190, "size": Vector2(1.4, 0.65), "color": Color("#89765e")},
	{"id": "lamp", "name": "スタンドライト", "price": 95, "size": Vector2(0.6, 0.6), "color": Color("#e9c78f")},
	{"id": "plant", "name": "観葉植物", "price": 75, "size": Vector2(0.7, 0.7), "color": Color("#5f9d78")},
	{"id": "wardrobe", "name": "ワードローブ", "price": 270, "size": Vector2(1.75, 0.85), "color": Color("#9b8775")}
]


static func find(kind: String) -> Dictionary:
	for item in STOCK:
		if String(item["id"]) == kind:
			return item
	return {}


static func place(parent: Node3D, furniture: Dictionary) -> Node3D:
	var kind: String = String(furniture.get("kind", ""))
	var stock: Dictionary = find(kind)
	if stock.is_empty():
		return null
	var item := Node3D.new()
	item.name = "Furniture_" + kind
	item.position = Vector3(float(furniture.get("x", 0.0)), 0.0, float(furniture.get("z", 0.0)))
	item.rotation.y = float(furniture.get("rotation", 0.0))
	parent.add_child(item)
	var footprint: Vector2 = stock["size"]
	var tint: Color = stock["color"]
	# One solid base per item, no expensive compound collision hierarchy.
	match kind:
		"sofa":
			Shapes.box(item, Vector3(0, 0.33, 0), Vector3(footprint.x, 0.64, footprint.y), tint, true)
			Shapes.box(item, Vector3(0, 0.83, 0.39), Vector3(footprint.x, 0.95, 0.23), tint.darkened(0.12))
			for x in [-0.99, 0.99]:
				Shapes.box(item, Vector3(x, 0.57, 0), Vector3(0.20, 0.65, 1.12), tint.lightened(0.12))
		"bed":
			Shapes.box(item, Vector3(0, 0.32, 0), Vector3(footprint.x, 0.60, footprint.y), tint, true)
			Shapes.box(item, Vector3(0, 0.67, 0.15), Vector3(1.8, 0.17, 2.25), Color("#d6cfba"))
			Shapes.box(item, Vector3(0, 0.77, -0.92), Vector3(1.5, 0.17, 0.65), Color("#f1f2e7"))
		"table":
			Shapes.box(item, Vector3(0, 0.64, 0), Vector3(footprint.x, 0.08, footprint.y), tint, true)
			for x in [-0.56, 0.56]:
				for z in [-0.41, 0.41]:
					Shapes.box(item, Vector3(x, 0.31, z), Vector3(0.11, 0.57, 0.11), tint.darkened(0.25))
		"chair":
			Shapes.box(item, Vector3(0, 0.42, 0), Vector3(0.75, 0.19, 0.75), tint, true)
			Shapes.box(item, Vector3(0, 0.86, 0.28), Vector3(0.75, 0.87, 0.18), tint.darkened(0.10))
		"shelf":
			Shapes.box(item, Vector3(0, 0.94, 0), Vector3(footprint.x, 1.88, footprint.y), tint, true)
			for row in range(4):
				Shapes.box(item, Vector3(0, 0.35 + row * 0.44, -0.34), Vector3(1.12, 0.10, 0.05), Color("#d7c1a1"))
		"lamp":
			Shapes.box(item, Vector3(0, 0.10, 0), Vector3(0.6, 0.20, 0.6), Color("#52606b"), true)
			Shapes.box(item, Vector3(0, 0.98, 0), Vector3(0.10, 1.75, 0.10), Color("#b0a8a0"))
			Shapes.box(item, Vector3(0, 1.80, 0), Vector3(0.61, 0.42, 0.61), tint)
		"plant":
			Shapes.box(item, Vector3(0, 0.25, 0), Vector3(0.65, 0.50, 0.65), Color("#887765"), true)
			Shapes.ball(item, Vector3(0, 1.00, 0), 0.56, tint)
		"wardrobe":
			Shapes.box(item, Vector3(0, 1.10, 0), Vector3(footprint.x, 2.2, footprint.y), tint, true)
			Shapes.box(item, Vector3(0, 1.09, -0.44), Vector3(0.04, 1.95, 0.04), Color("#e0d5ba"))
	return item

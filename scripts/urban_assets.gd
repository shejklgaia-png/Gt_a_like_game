extends RefCounted
const Shapes = preload("res://scripts/shape_factory.gd")

## Street props occupy the side facades, near the middle of a block and away from crossings.
## Pedestrian sidewalk centerlines run 11.65 m from each lot center on either axis.
const SIDEWALK_LANE_DISTANCE := 11.65
const ACTOR_CLEARANCE := 0.85

static func install(parent: Node3D, blocks: Array[Dictionary]) -> void:
	var decor := Node3D.new()
	decor.name = "StreetProps"
	parent.add_child(decor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40542
	for building_index in range(blocks.size()):
		var block: Dictionary = blocks[building_index]
		var center: Vector3 = block["position"]
		var half_width: float = float(block["width"]) * 0.5
		var half_depth: float = float(block["depth"]) * 0.5
		# Place objects next to the facade, at least a metre away from pedestrian
		# corridors. Keep the doorway (center x +/- 2 m) unobstructed.
		for side in [-1, 1]:
			var facing: float = float(side)
			var kind := (building_index * 3 + (1 if side > 0 else 0)) % 4
			var length_radius := 1.10 if kind == 1 else (0.35 if kind == 2 else 0.40)
			var along_facade := clampf(-5.4 if side < 0 else 5.4, -half_depth + length_radius + 0.45, half_depth - length_radius - 0.45)
			var x := center.x + facing * (half_width + 0.72)
			var z := center.z + along_facade
			# On this side facade, the sidewalk runs parallel to Z.
			# Include the entire bench width and walking-lane lateral offsets.
			var footprint_depth := 0.44 if kind == 1 else (0.38 if kind == 2 else 0.34)
			var lane_clearance := SIDEWALK_LANE_DISTANCE - (half_width + 0.72) - footprint_depth
			if lane_clearance < ACTOR_CLEARANCE:
				continue
			var anchor := Node3D.new()
			anchor.name = "Prop_%02d_%s" % [building_index, "Right" if side > 0 else "Left"]
			anchor.position = Vector3(x, 0.05, z)
			# Bench backrest faces the building wall; the long seat follows the facade.
			anchor.rotation.y = -facing * PI * 0.5
			anchor.set_meta("lot", String(block["id"]))
			anchor.set_meta("kind", kind)
			anchor.set_meta("pedestrian_lane_clearance", lane_clearance)
			anchor.set_meta("building_frontage", true)
			anchor.set_meta("side", side)
			decor.add_child(anchor)
			match kind:
				0: make_tree(anchor, Vector3.ZERO, rng)
				1: make_bench(anchor, Vector3.ZERO, rng)
				2: make_trash(anchor, Vector3.ZERO, rng)
				3: make_hydrant(anchor, Vector3.ZERO, rng)

static func make_tree(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	Shapes.box(parent, at + Vector3(0, 1.2, 0), Vector3(0.34, 2.4, 0.34), Color("#725b4c"))
	var leaves := Color.from_hsv(rng.randf_range(0.26, 0.43), rng.randf_range(0.45, 0.67), rng.randf_range(0.60, 0.86))
	Shapes.ball(parent, at + Vector3(0, 3.15, 0), 1.20, leaves)
	Shapes.ball(parent, at + Vector3(0.57, 2.76, -0.11), 0.70, leaves.lightened(0.11))
	Shapes.ball(parent, at + Vector3(-0.39, 2.80, 0.29), 0.61, leaves.darkened(0.12))

static func make_bench(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var seat := Color.from_hsv(rng.randf_range(0.04, 0.11), 0.34, rng.randf_range(0.57, 0.76))
	Shapes.box(parent, at + Vector3(0, 0.54, 0), Vector3(2.1, 0.18, 0.65), seat, true)
	Shapes.box(parent, at + Vector3(0, 1.12, 0.27), Vector3(2.1, 0.88, 0.14), seat)
	for x in [-0.8, 0.8]:
		Shapes.box(parent, at + Vector3(x, 0.26, 0), Vector3(0.12, 0.52, 0.45), Color("#35434c"))

static func make_trash(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var tint := Color.from_hsv(rng.randf_range(0.45, 0.59), 0.52, 0.64)
	Shapes.box(parent, at + Vector3(0, 0.51, 0), Vector3(0.60, 1.02, 0.60), tint, true)
	Shapes.box(parent, at + Vector3(0, 1.04, 0), Vector3(0.72, 0.08, 0.72), tint.darkened(0.32))

static func make_hydrant(parent: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var tint := Color.from_hsv(rng.randf_range(0.00, 0.11), 0.73, 0.86)
	Shapes.box(parent, at + Vector3(0, 0.43, 0), Vector3(0.34, 0.8, 0.34), tint)
	Shapes.box(parent, at + Vector3(0, 0.63, 0), Vector3(0.64, 0.17, 0.25), tint.lightened(0.12))
	Shapes.ball(parent, at + Vector3(0, 0.91, 0), 0.24, tint)

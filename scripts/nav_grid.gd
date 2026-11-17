extends RefCounted
class_name PocketNavGrid
## Reusable two-meter A* lattice, blocked by actual building footprints.
const CELL: float = 2.0
const START: int = -91
const WIDTH: int = 183
var grid: AStarGrid2D

func _init() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(START, START, WIDTH, WIDTH)
	grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()

func building(at: Vector3, half_x: float, half_z: float) -> void:
	var padding := 1.0
	var min_x := int(ceilf((at.x - half_x - padding) / CELL))
	var max_x := int(floorf((at.x + half_x + padding) / CELL))
	var min_z := int(ceilf((at.z - half_z - padding) / CELL))
	var max_z := int(floorf((at.z + half_z + padding) / CELL))
	for ix in range(min_x, max_x + 1):
		for iz in range(min_z, max_z + 1):
			var id := Vector2i(ix, iz)
			if grid.is_in_boundsv(id):
				grid.set_point_solid(id, true)

func id_from_world(at: Vector3) -> Vector2i:
	return Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))

func nearest_open(id: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(id) and not grid.is_point_solid(id):
		return id
	for radius in range(1, 7):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dz) != radius:
					continue
				var next := id + Vector2i(dx, dz)
				if grid.is_in_boundsv(next) and not grid.is_point_solid(next):
					return next
	return id

func path(from: Vector3, to: Vector3) -> PackedVector2Array:
	var start := nearest_open(id_from_world(from))
	var goal := nearest_open(id_from_world(to))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(goal):
		return PackedVector2Array()
	if grid.is_point_solid(start) or grid.is_point_solid(goal):
		return PackedVector2Array()
	return grid.get_point_path(start, goal)

extends Label
class_name PocketPerfOverlay

var time_accum: float = 0.0
var frames: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 14)
	add_theme_color_override("font_color", Color("#bce7d9"))
	visible = false

func _process(delta: float) -> void:
	frames += 1
	time_accum += delta
	if time_accum > 1.0:
		var fps := int(round(float(frames) / time_accum))
		text = "FPS %d  |  3D %d  |  Objects %d" % [fps, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)]
		frames = 0
		time_accum = 0.0

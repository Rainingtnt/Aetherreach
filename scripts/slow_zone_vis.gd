extends Node2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var sz: Vector2 = get_meta("zone_size") if has_meta("zone_size") else Vector2(100, 80)
	draw_rect(Rect2(-sz * 0.5, sz), Color(0.25, 0.55, 0.18, 0.18))
	draw_rect(Rect2(-sz * 0.5, sz), Color(0.35, 0.72, 0.25, 0.45), false, 1.5)
	var grid := 20.0
	for x in range(int(-sz.x * 0.5), int(sz.x * 0.5), int(grid)):
		for y in range(int(-sz.y * 0.5), int(sz.y * 0.5), int(grid)):
			draw_circle(Vector2(x + grid * 0.5, y + grid * 0.5), 1.5, Color(0.3, 0.65, 0.2, 0.3))

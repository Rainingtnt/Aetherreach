extends Node2D

var _t := randf() * TAU

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var sz: Vector2 = get_meta("zone_size") if has_meta("zone_size") else Vector2(100, 80)
	var pulse := sin(_t * 1.4) * 0.08
	# Murky bog fill
	draw_rect(Rect2(-sz * 0.5, sz), Color(0.18, 0.38, 0.12, 0.20 + pulse))
	# Border
	draw_rect(Rect2(-sz * 0.5, sz), Color(0.30, 0.65, 0.18, 0.50), false, 1.8)
	# Moving ripples
	var ripple_r := fmod(_t * 18.0, sz.x * 0.5)
	draw_arc(Vector2.ZERO, ripple_r, 0, TAU, 24, Color(0.35, 0.72, 0.22, 0.22 * (1.0 - ripple_r / (sz.x * 0.5))), 1.0)
	# Bubble dots
	for i in 5:
		var a := _t * 0.6 + i * TAU / 5.0
		var r := sz.length() * 0.25
		var bp := Vector2(cos(a) * r * 0.6, sin(a) * r * 0.4)
		draw_circle(bp, 2.0, Color(0.4, 0.8, 0.25, 0.40 + pulse))
	# Slow warning text proxy: three horizontal lines
	draw_line(Vector2(-12, -3), Vector2(12, -3), Color(0.3, 0.65, 0.2, 0.5), 1.5)
	draw_line(Vector2(-8, 0),   Vector2(8, 0),   Color(0.3, 0.65, 0.2, 0.4), 1.2)
	draw_line(Vector2(-12, 3),  Vector2(12, 3),  Color(0.3, 0.65, 0.2, 0.5), 1.5)

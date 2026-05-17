extends Node2D

var _t := randf() * TAU

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := sin(_t * 2.2) * 0.12 + 0.88
	# Pit void
	draw_circle(Vector2.ZERO, 22, Color(0.03, 0.01, 0.08))
	# Outer danger ring
	draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(0.52, 0.08, 0.72, 0.75 * pulse), 2.5)
	# Inner rotating indicators
	for i in 6:
		var a := _t * 0.8 + i * TAU / 6.0
		draw_circle(Vector2(cos(a), sin(a)) * 14, 2.8, Color(0.55, 0.10, 0.80, 0.70 * pulse))
	# Void center glow
	draw_circle(Vector2.ZERO, 7, Color(0.28, 0.04, 0.42, 0.45 + sin(_t * 3.5) * 0.12))
	draw_circle(Vector2.ZERO, 3, Color(0.80, 0.20, 1.00, 0.60 * pulse))
	# Danger cross
	draw_line(Vector2(-10, 0), Vector2(10, 0), Color(0.5, 0.08, 0.7, 0.35), 1.2)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(0.5, 0.08, 0.7, 0.35), 1.2)

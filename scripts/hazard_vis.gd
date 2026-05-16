extends Node2D

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 22, Color(0.06, 0.03, 0.14))
	draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(0.45, 0.08, 0.65, 0.8), 2)
	for i in 6:
		var a := i * TAU / 6.0
		draw_circle(Vector2(cos(a), sin(a)) * 14, 3, Color(0.5, 0.1, 0.75, 0.7))
	draw_circle(Vector2.ZERO, 5, Color(0.3, 0.06, 0.45, 0.5))

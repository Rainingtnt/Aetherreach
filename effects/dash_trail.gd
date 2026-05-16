extends Node2D

var lifetime := 0.18
var radius := 11.0

func _process(delta: float) -> void:
	lifetime -= delta
	modulate.a = max(0.0, lifetime / 0.18) * 0.45
	queue_redraw()
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color.CYAN)

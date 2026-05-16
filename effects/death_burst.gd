extends Node2D

var color := Color(1, 0.3, 0.3)
var lifetime := 0.45
var max_lifetime := 0.45
var particles := []

func _ready() -> void:
	for i in 7:
		var angle = i * TAU / 7.0 + randf() * 0.4
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(50, 120),
			"radius": randf_range(3.0, 7.0),
		})
	queue_redraw()

func _process(delta: float) -> void:
	lifetime -= delta
	for p in particles:
		p["pos"] += p["vel"] * delta
		p["vel"] *= 0.88
	modulate.a = clamp(lifetime / max_lifetime, 0.0, 1.0)
	queue_redraw()
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	var t = 1.0 - (lifetime / max_lifetime)
	draw_circle(Vector2.ZERO, t * 22.0, Color(color.r, color.g, color.b, 0.25))
	for p in particles:
		draw_circle(p["pos"], p["radius"], color)

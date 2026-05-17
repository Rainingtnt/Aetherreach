extends Area2D

# Glacira's ice bolt — slows player on hit

const SPEED := 175.0

var direction := Vector2.RIGHT
var damage    := 2
var _t        := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _draw() -> void:
	# Ice trail
	for i in 5:
		var tp := -direction * (6 + i * 5)
		draw_circle(tp, 5.5 - i * 0.8, Color(0.35, 0.70, 1.0, (5 - i) * 0.08))
	# Shard core
	draw_colored_polygon(PackedVector2Array([
		direction * 8, direction.rotated(PI * 0.5) * 4, -direction * 4,
		direction.rotated(-PI * 0.5) * 4,
	]), Color(0.50, 0.82, 1.0))
	draw_circle(Vector2.ZERO, 3, Color(0.80, 0.95, 1.0))

func _physics_process(delta: float) -> void:
	_t += delta
	position += direction * SPEED * delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		if body.has_method("apply_slow"):
			body.speed_mult = 0.45
			get_tree().create_timer(1.8).timeout.connect(func():
				if is_instance_valid(body): body.speed_mult = 1.0
			)
		queue_free.call_deferred()

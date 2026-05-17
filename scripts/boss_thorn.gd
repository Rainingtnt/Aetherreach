extends Area2D

# Verdana's thorn — medium speed, creates slow zone on impact

const SPEED := 160.0

var direction := Vector2.RIGHT
var damage    := 2
var _t        := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(4.2).timeout.connect(queue_free)

func _draw() -> void:
	# Vine trail
	for i in 4:
		var tp := -direction * (5 + i * 6)
		draw_circle(tp, 4.5 - i * 0.7, Color(0.22, 0.70, 0.18, (4 - i) * 0.10))
	# Thorn tip
	draw_colored_polygon(PackedVector2Array([
		direction * 9, direction.rotated(PI * 0.5) * 3.5, -direction * 3,
		direction.rotated(-PI * 0.5) * 3.5,
	]), Color(0.28, 0.80, 0.22))
	draw_circle(Vector2.ZERO, 2.5, Color(0.60, 1.0, 0.40))

func _physics_process(delta: float) -> void:
	_t += delta
	position += direction * SPEED * delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		# Brief root (slow)
		if "speed_mult" in body:
			body.speed_mult = 0.30
			get_tree().create_timer(1.2).timeout.connect(func():
				if is_instance_valid(body): body.speed_mult = 1.0
			)
		queue_free.call_deferred()

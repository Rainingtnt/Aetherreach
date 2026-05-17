extends Area2D

const SPEED := 195.0

var direction := Vector2.RIGHT
var damage    := 2
var _t        := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(3.8).timeout.connect(queue_free)

func _draw() -> void:
	# Trail
	for i in 5:
		var tp := -direction * (7 + i * 5)
		draw_circle(tp, 6.0 - i * 0.8, Color(1.0, 0.45, 0.0, (5 - i) * 0.10))
	# Core
	draw_circle(Vector2.ZERO, 7, Color(1.0, 0.32, 0.0))
	draw_circle(Vector2.ZERO, 4, Color(1.0, 0.75, 0.15))
	draw_circle(Vector2.ZERO, 2, Color.WHITE)

func _physics_process(delta: float) -> void:
	_t += delta
	position += direction * SPEED * delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		queue_free.call_deferred()

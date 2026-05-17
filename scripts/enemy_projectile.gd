extends Area2D

const SPEED := 190.0

var direction := Vector2.RIGHT
var damage := 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5, Color(0.75, 0.35, 1.0))
	draw_circle(Vector2.ZERO, 3, Color(0.9, 0.7, 1.0))

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		queue_free.call_deferred()

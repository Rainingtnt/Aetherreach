extends Area2D

const SPEED := 450.0

var direction := Vector2.RIGHT
var damage := 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5, Color(1, 0.95, 0.3))

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()

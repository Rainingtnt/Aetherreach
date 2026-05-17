extends Area2D

# Tempestine's lightning bolt — homing, fast

const SPEED          := 240.0
const TURN_SPEED     := 3.5
const HOMING_DURATION := 1.8

var direction := Vector2.RIGHT
var damage    := 2
var _t        := 0.0
var _player: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(3.5).timeout.connect(queue_free)
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		_player = pl[0]

func _draw() -> void:
	# Electric trail
	for i in 4:
		var tp := -direction * (5 + i * 5)
		draw_circle(tp, 4.0 - i * 0.6, Color(0.80, 0.70, 1.0, (4 - i) * 0.10))
	# Zigzag bolt shape
	var d := direction
	var p := d.rotated(PI * 0.5) * 3
	draw_polyline(PackedVector2Array([
		d * 9, p * 0.0 + d * 4, -p + d * 0.0, d * -4,
	]), Color(0.90, 0.85, 1.0), 2.0)
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 1.0, 0.6, 0.9))

func _physics_process(delta: float) -> void:
	_t += delta
	# Homing phase
	if _t < HOMING_DURATION and is_instance_valid(_player):
		var target_dir := (_player.global_position - global_position).normalized()
		direction = direction.slerp(target_dir, TURN_SPEED * delta).normalized()
	position += direction * SPEED * delta
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage)
		queue_free.call_deferred()

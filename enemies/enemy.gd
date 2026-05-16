extends CharacterBody2D

const SPEED := 55.0
const CONTACT_COOLDOWN := 0.8

var health := 3
var damage := 1
var player: Node2D = null
var contact_timer := 0.0
var hit_flash := false

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _draw() -> void:
	var color = Color(1, 0.9, 0.9) if hit_flash else Color(1, 0.3, 0.3)
	draw_circle(Vector2.ZERO, 14, color)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	contact_timer -= delta
	velocity = (player.global_position - global_position).normalized() * SPEED
	move_and_slide()
	if global_position.distance_to(player.global_position) < 24 and contact_timer <= 0.0:
		player.take_damage(damage)
		contact_timer = CONTACT_COOLDOWN

func take_damage(amount: int) -> void:
	health -= amount
	hit_flash = true
	queue_redraw()
	get_tree().create_timer(0.1).timeout.connect(func():
		hit_flash = false
		queue_redraw()
	)
	if health <= 0:
		queue_free()

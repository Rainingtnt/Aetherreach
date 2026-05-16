extends CharacterBody2D

const SPEED := 55.0
const CONTACT_COOLDOWN := 0.8

var max_health := 3
var health := 3
var damage := 1
var player: Node2D = null
var contact_timer := 0.0
var hit_flash := false
var speed_mult := 1.0
var slow_timer := 0.0

const DeathBurst = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _draw() -> void:
	var col = Color(1, 0.9, 0.9) if hit_flash else Color(1, 0.3, 0.3)
	if slow_timer > 0:
		col = col.lerp(Color(0.4, 0.7, 1.0), 0.6)
	draw_circle(Vector2.ZERO, 14, col)
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -22, 28, 3), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-14, -22, 28.0 * pct, 3), Color(0.25, 1, 0.3))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			speed_mult = 1.0
	if player == null:
		return
	contact_timer -= delta
	velocity = (player.global_position - global_position).normalized() * SPEED * speed_mult
	move_and_slide()
	if global_position.distance_to(player.global_position) < 24 and contact_timer <= 0.0:
		player.take_damage(damage)
		contact_timer = CONTACT_COOLDOWN

func apply_slow(duration: float) -> void:
	speed_mult = 0.35
	slow_timer = duration
	queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	hit_flash = true
	queue_redraw()
	get_tree().create_timer(0.1).timeout.connect(func():
		hit_flash = false
		queue_redraw()
	)
	if health <= 0:
		var burst = DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(1, 0.3, 0.3)
		get_parent().add_child(burst)
		if randf() < 0.65:
			var frac = FracturePickup.instantiate()
			get_parent().add_child(frac)
			var elem = FractureManager.Element.FIRE if randf() < 0.5 else FractureManager.Element.STORM
			frac.setup(elem, global_position)
		GameEvents.enemy_died.emit(global_position, 1)
		queue_free()

extends CharacterBody2D

const SPEED := 45.0
const PREFERRED_RANGE := 230.0
const SHOOT_INTERVAL := 2.8
const CONTACT_COOLDOWN := 1.0

var health := 5
var damage := 1
var player: Node2D = null
var shoot_timer := 1.2
var contact_timer := 0.0
var hit_flash := false

const DeathBurst = preload("res://effects/death_burst.tscn")
const EnemyProjectile = preload("res://scripts/enemy_projectile.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _draw() -> void:
	var col = Color(0.88, 0.88, 1.0) if hit_flash else Color(0.55, 0.25, 1.0)
	var pts = PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0), Vector2(0, -16)]), Color(0.75, 0.5, 1.0), 1.5)

func _physics_process(delta: float) -> void:
	if player == null:
		return

	shoot_timer -= delta
	contact_timer -= delta

	if shoot_timer <= 0.0:
		_shoot()
		shoot_timer = SHOOT_INTERVAL

	var dist = global_position.distance_to(player.global_position)
	var dir = (player.global_position - global_position).normalized()

	if dist > PREFERRED_RANGE + 30:
		velocity = dir * SPEED
	elif dist < PREFERRED_RANGE - 30:
		velocity = -dir * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)

	move_and_slide()

	if dist < 22 and contact_timer <= 0.0:
		player.take_damage(damage)
		contact_timer = CONTACT_COOLDOWN

func _shoot() -> void:
	if player == null:
		return
	var proj = EnemyProjectile.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction = (player.global_position - global_position).normalized()

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
		burst.color = Color(0.6, 0.3, 1.0)
		get_parent().add_child(burst)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free()

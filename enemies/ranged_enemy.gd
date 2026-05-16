extends CharacterBody2D

const SPEED := 45.0
const PREFERRED_RANGE := 230.0
const SHOOT_INTERVAL := 2.8
const CONTACT_COOLDOWN := 1.0

var max_health := 5
var health := 5
var damage := 1
var player: Node2D = null
var shoot_timer := 1.2
var contact_timer := 0.0
var hit_flash := false
var speed_mult := 1.0
var slow_timer := 0.0

const DeathBurst = preload("res://effects/death_burst.tscn")
const EnemyProjectile = preload("res://scripts/enemy_projectile.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _draw() -> void:
	var col = Color(0.88, 0.88, 1.0) if hit_flash else Color(0.55, 0.25, 1.0)
	if slow_timer > 0:
		col = col.lerp(Color(0.4, 0.7, 1.0), 0.6)
	var pts = PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0), Vector2(0, -16)]), Color(0.75, 0.5, 1.0), 1.5)
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -24, 28, 3), Color(0.15, 0.15, 0.15))
		draw_rect(Rect2(-14, -24, 28.0 * pct, 3), Color(0.6, 0.3, 1.0))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			speed_mult = 1.0
	if player == null:
		return
	shoot_timer -= delta
	contact_timer -= delta
	if shoot_timer <= 0.0:
		_shoot()
		shoot_timer = SHOOT_INTERVAL
	var dist := global_position.distance_to(player.global_position)
	var dir := (player.global_position - global_position).normalized()
	if dist > PREFERRED_RANGE + 30:
		velocity = dir * SPEED * speed_mult
	elif dist < PREFERRED_RANGE - 30:
		velocity = -dir * SPEED * speed_mult
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
		burst.color = Color(0.6, 0.3, 1.0)
		get_parent().add_child(burst)
		if randf() < 0.8:
			var frac = FracturePickup.instantiate()
			get_parent().add_child(frac)
			var elem = FractureManager.Element.FROST if randf() < 0.5 else FractureManager.Element.NATURE
			frac.setup(elem, global_position)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free()

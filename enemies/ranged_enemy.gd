extends CharacterBody2D

# Arcane Caster — floating robed silhouette with single large eye

const SPEED          := 45.0
const PREFERRED_RANGE := 230.0
const SHOOT_INTERVAL  := 2.8
const CONTACT_COOLDOWN := 1.0

var max_health := 5
var health     := 5
var damage     := 1
var player: Node2D = null
var shoot_t    := 1.2
var contact_t  := 0.0
var hit_flash  := false
var speed_mult := 1.0
var slow_timer := 0.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const EnemyProjectile = preload("res://scripts/enemy_projectile.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _draw() -> void:
	var col := Color(0.88, 0.88, 1.0) if hit_flash else Color(0.52, 0.22, 1.0)
	if slow_timer > 0:
		col = col.lerp(Color(0.4, 0.7, 1.0), 0.5)
	var dark := Color(col.r * 0.7, col.g * 0.6, col.b * 0.7)
	# Orb body
	draw_circle(Vector2.ZERO, 13, col)
	# Robe hem
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 3), Vector2(13, 3),
		Vector2(10, 17), Vector2(-10, 17),
	]), dark)
	# Single eye
	draw_circle(Vector2(0, -2), 7, Color(0.08, 0.04, 0.18))
	draw_circle(Vector2(0, -2), 5, Color(0.75, 0.38, 1.0))
	draw_circle(Vector2(1, -2), 2.5, Color(0.04, 0.02, 0.08))
	draw_circle(Vector2(2, -3.5), 1.0, Color.WHITE)
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-13, -22, 26, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-13, -22, 26.0 * pct, 3), Color(0.58, 0.28, 1.0))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null:
		return
	shoot_t -= delta
	contact_t -= delta
	if shoot_t <= 0.0:
		_shoot()
		shoot_t = SHOOT_INTERVAL
	var dist := global_position.distance_to(player.global_position)
	var dir  := (player.global_position - global_position).normalized()
	if dist > PREFERRED_RANGE + 30:
		velocity = dir * SPEED * speed_mult
	elif dist < PREFERRED_RANGE - 30:
		velocity = -dir * SPEED * speed_mult
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)
	move_and_slide()
	if dist < 22 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_COOLDOWN

func _shoot() -> void:
	if player == null: return
	var proj := EnemyProjectile.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction = (player.global_position - global_position).normalized()

func apply_slow(duration: float) -> void:
	speed_mult = 0.35
	slow_timer = duration
	queue_redraw()

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	hit_flash = true
	queue_redraw()
	get_tree().create_timer(0.1).timeout.connect(func(): hit_flash = false; queue_redraw())
	if health <= 0:
		Juice.hit_stop(0.045)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.52, 0.22, 1.0)
		get_parent().add_child(burst)
		if randf() < 0.8:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(FractureManager.Element.FROST if randf() < 0.5 else FractureManager.Element.NATURE, global_position)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free()

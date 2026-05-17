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
var speed_mult := 1.0
var slow_timer := 0.0
var _anim_t    := randf() * TAU

const DeathBurst      = preload("res://effects/death_burst.tscn")
const EnemyProjectile = preload("res://scripts/enemy_projectile.tscn")
const FracturePickup  = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture    = preload("res://assets/sprites/enemy_caster.svg")

var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	_sprite = Sprite2D.new()
	_sprite.texture = EnemyTexture
	_sprite.scale   = Vector2(0.44, 0.44)
	add_child(_sprite)
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _process(delta: float) -> void:
	_anim_t += delta
	if _sprite != null:
		var wobble := sin(_anim_t * 1.8) * 0.018
		_sprite.scale = Vector2(0.44, 0.44 + wobble)
		# Hover offset
		_sprite.offset = Vector2(0, sin(_anim_t * 1.8) * 2.5)
		if slow_timer > 0:
			_sprite.modulate = Color(0.5, 0.7, 1.0)
		else:
			_sprite.modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-13, -28, 26, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-13, -28, 26.0 * pct, 3), Color(0.58, 0.28, 1.0))

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
	get_parent().call_deferred("add_child", proj)
	proj.global_position = global_position
	proj.direction = (player.global_position - global_position).normalized()

func apply_slow(duration: float, mult: float = 0.35) -> void:
	speed_mult = mult
	slow_timer = duration

func heal(amount: int) -> void:
	health = min(health + amount, max_health)

func take_damage(amount: int) -> void:
	health -= amount
	if _sprite != null:
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(_sprite): _sprite.modulate = Color.WHITE
		)
	if health <= 0:
		Juice.hit_stop(0.045)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.52, 0.22, 1.0)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.8:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.FROST if randf() < 0.5 else FractureManager.Element.NATURE, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free.call_deferred()

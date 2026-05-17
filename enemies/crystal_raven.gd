extends CharacterBody2D

# Crystal Raven — Frost biome. Circles at distance then dives. Leaves ice trail.

const SPEED_CIRCLE := 75.0
const SPEED_DIVE   := 290.0
const DIVE_RANGE   := 260.0
const DIVE_CD      := 2.5
const CONTACT_CD   := 0.55

var health     := 2
var max_health := 2
var damage     := 1
var player: Node2D = null
var contact_t  := 0.0
var dive_t     := randf_range(1.0, DIVE_CD)
var _diving    := false
var _dive_dir  := Vector2.ZERO
var _dive_dist := 0.0
var _anim_t    := randf() * TAU
var speed_mult := 1.0
var slow_timer := 0.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_crystal_raven.svg")

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
		if _diving:
			# Stretch in dive direction
			_sprite.rotation = _dive_dir.angle()
			_sprite.scale = Vector2(0.50, 0.36)
			_sprite.modulate = Color(1.3, 1.3, 1.5)
		else:
			_sprite.rotation = velocity.angle() if velocity.length() > 10 else 0.0
			_sprite.scale = Vector2(0.44, 0.44)
			if slow_timer > 0:
				_sprite.modulate = Color(0.5, 0.7, 1.0)
			else:
				_sprite.modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -22, 28, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-14, -22, 28.0 * pct, 3), Color(0.45, 0.85, 1.0))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	contact_t -= delta
	dive_t    -= delta

	var dist := global_position.distance_to(player.global_position)

	if _diving:
		velocity = _dive_dir * SPEED_DIVE
		_dive_dist -= velocity.length() * delta
		if _dive_dist <= 0 or dist < 20:
			_diving = false
			dive_t  = DIVE_CD
			if dist < 20 and contact_t <= 0.0:
				player.take_damage(damage)
				contact_t = CONTACT_CD
	else:
		# Circle at range
		var to_p := (player.global_position - global_position).normalized()
		var perp  := Vector2(-to_p.y, to_p.x)
		var range_err := dist - DIVE_RANGE
		velocity = (to_p * range_err * 0.4 + perp * SPEED_CIRCLE) * speed_mult
		# Initiate dive
		if dive_t <= 0 and dist < DIVE_RANGE + 80:
			_diving   = true
			_dive_dir = to_p
			_dive_dist = dist + 20
	move_and_slide()

func apply_slow(duration: float, mult: float = 0.35) -> void:
	speed_mult = mult
	slow_timer = duration

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)

func take_damage(amount: int) -> void:
	health -= amount
	if _sprite != null:
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(_sprite): _sprite.modulate = Color.WHITE
		)
	if health <= 0:
		Juice.hit_stop(0.035)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.45, 0.80, 1.0)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.55:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.FROST, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free.call_deferred()

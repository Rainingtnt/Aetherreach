extends CharacterBody2D

# Emberling — Fire biome. Bounces chaotically, homes in close range, explodes on death.

const SPEED        := 130.0
const HOME_RANGE   := 90.0
const CONTACT_CD   := 0.35
const DIR_CHANGE   := 0.5

var health      := 1
var max_health  := 1
var damage      := 1
var player: Node2D = null
var contact_t   := 0.0
var dir_t       := 0.0
var _anim_t     := randf() * TAU
var _bounce_dir := Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_emberling.svg")

var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	_sprite = Sprite2D.new()
	_sprite.texture = EnemyTexture
	_sprite.scale   = Vector2(0.42, 0.42)
	add_child(_sprite)
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _process(delta: float) -> void:
	_anim_t += delta
	if _sprite != null:
		var bounce: float = abs(sin(_anim_t * 6.0)) * 0.08
		_sprite.scale = Vector2(0.42 + bounce, 0.42 - bounce * 0.5)
		_sprite.offset = Vector2(0, -sin(_anim_t * 6.0) * 4.0)

func _physics_process(delta: float) -> void:
	if player == null: return
	contact_t -= delta
	dir_t     -= delta

	var dist := global_position.distance_to(player.global_position)
	if dist < HOME_RANGE:
		# Home in on player
		velocity = (player.global_position - global_position).normalized() * SPEED * 1.4
	else:
		# Bounce chaotically — change direction periodically
		if dir_t <= 0:
			dir_t = randf_range(0.3, DIR_CHANGE)
			_bounce_dir = Vector2(randf_range(-1,1), randf_range(-1,1)).normalized()
			# Occasionally drift toward player
			if randf() < 0.4:
				_bounce_dir = (_bounce_dir + (player.global_position - global_position).normalized()).normalized()
		velocity = _bounce_dir * SPEED

	move_and_slide()

	# Bounce off room walls
	if abs(global_position.x) > 420:
		_bounce_dir.x *= -1
		global_position.x = clampf(global_position.x, -420, 420)
	if abs(global_position.y) > 270:
		_bounce_dir.y *= -1
		global_position.y = clampf(global_position.y, -270, 270)

	if dist < 16 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_CD

func heal(_a: int) -> void: pass
func apply_slow(_d: float, _m: float = 0.35) -> void: pass

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		Juice.hit_stop(0.02)
		# Small ember burst explosion on death — damages nearby enemies too
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(1.0, 0.45, 0.04)
		get_parent().call_deferred("add_child", burst)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != self and e.global_position.distance_to(global_position) < 38:
				e.take_damage(1)
		if randf() < 0.25:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.FIRE, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 1)
		queue_free.call_deferred()

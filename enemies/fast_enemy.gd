extends CharacterBody2D

# Speeder — blade-like silhouette, zigzag movement, one-shot fragile

const SPEED            := 165.0
const ZIGZAG_AMP       := 85.0
const ZIGZAG_FREQ      := 4.0
const CONTACT_COOLDOWN := 0.45

var health     := 1
var max_health := 1
var damage     := 1
var player: Node2D = null
var zigzag_t   := randf() * TAU
var contact_t  := 0.0
var _anim_t    := randf() * TAU

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_speeder.svg")

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
		var wobble := sin(_anim_t * 4.5) * 0.018
		_sprite.scale    = Vector2(0.44 + wobble, 0.44 - wobble)
		# Face movement direction
		if velocity.length() > 10:
			_sprite.rotation = velocity.angle() + PI * 0.5

func _physics_process(delta: float) -> void:
	if player == null: return
	zigzag_t  += delta
	contact_t -= delta
	var to_p := (player.global_position - global_position).normalized()
	var perp := Vector2(-to_p.y, to_p.x)
	velocity = (to_p * SPEED + perp * sin(zigzag_t * ZIGZAG_FREQ) * ZIGZAG_AMP).normalized() * SPEED
	move_and_slide()
	if global_position.distance_to(player.global_position) < 18 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_COOLDOWN

func heal(_a: int) -> void: pass
func apply_slow(_d: float, _m: float = 0.35) -> void: pass

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		Juice.hit_stop(0.03)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.12, 0.90, 0.72)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.35:
			var frac := FracturePickup.instantiate()
			frac.setup(randi() % 4, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 2)
		queue_free.call_deferred()

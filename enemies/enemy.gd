extends CharacterBody2D

# Melee Chaser — spiked aggressive silhouette with yellow eyes

const SPEED          := 55.0
const CONTACT_COOLDOWN := 0.8

var max_health := 3
var health     := 3
var damage     := 1
var player: Node2D = null
var contact_t  := 0.0
var speed_mult := 1.0
var slow_timer := 0.0
var _anim_t    := randf() * TAU

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_chaser.svg")

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
		var wobble := sin(_anim_t * 2.6) * 0.015
		_sprite.scale    = Vector2(0.44, 0.44 + wobble)
		_sprite.rotation = velocity.x * 0.003
		if slow_timer > 0:
			_sprite.modulate = Color(0.5, 0.7, 1.0)
		else:
			_sprite.modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -26, 28, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-14, -26, 28.0 * pct, 3), Color(0.28, 1.0, 0.3))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			speed_mult = 1.0
	if player == null:
		return
	contact_t -= delta
	velocity = (player.global_position - global_position).normalized() * SPEED * speed_mult
	move_and_slide()
	if global_position.distance_to(player.global_position) < 24 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_COOLDOWN

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
		burst.color = Color(0.88, 0.22, 0.22)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.65:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.FIRE if randf() < 0.5 else FractureManager.Element.STORM, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 1)
		queue_free.call_deferred()

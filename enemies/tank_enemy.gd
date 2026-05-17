extends CharacterBody2D

# Tank — heavy armored knight, telegraphed charge with orange windup glow

const SPEED_WALK   := 30.0
const SPEED_CHARGE := 200.0
const CHARGE_CD    := 5.0
const CONTACT_CD   := 1.0

var max_health := 14
var health     := 14
var damage     := 2
var player: Node2D = null
var contact_t  := 0.0
var charge_t   := randf_range(2.0, 4.0)
var windup_t   := 0.0
var is_charging := false
var speed_mult := 1.0
var slow_timer := 0.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_tank.svg")

var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	_sprite = Sprite2D.new()
	_sprite.texture = EnemyTexture
	_sprite.scale   = Vector2(0.52, 0.52)
	add_child(_sprite)
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _process(_delta: float) -> void:
	if _sprite == null:
		return
	# Windup glow — tint orange as charge builds
	if windup_t > 0:
		var t := 1.0 - windup_t / 0.8
		_sprite.modulate = Color(1.0, 0.5 + t * 0.5, t * 0.2 + 0.2)
	elif slow_timer > 0:
		_sprite.modulate = Color(0.5, 0.7, 1.0)
	else:
		_sprite.modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-20, -34, 40, 4), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-20, -34, 40.0 * pct, 4), Color(0.4, 0.4, 1.0))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	contact_t -= delta
	charge_t  -= delta

	if windup_t > 0:
		windup_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 400 * delta)
		if windup_t <= 0: is_charging = true
		move_and_slide()
		return

	if is_charging:
		velocity = (player.global_position - global_position).normalized() * SPEED_CHARGE
		move_and_slide()
		if global_position.distance_to(player.global_position) < 34 and contact_t <= 0.0:
			player.take_damage(damage)
			contact_t   = CONTACT_CD
			is_charging = false
			charge_t    = CHARGE_CD
		if velocity.length() < 8:
			is_charging = false
			charge_t    = CHARGE_CD
		return

	if charge_t <= 0:
		windup_t = 0.8
		return

	velocity = (player.global_position - global_position).normalized() * SPEED_WALK * speed_mult
	move_and_slide()
	if global_position.distance_to(player.global_position) < 34 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_CD

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
		Juice.hit_stop(0.07)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.28, 0.28, 0.48)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.9:
			var frac := FracturePickup.instantiate()
			frac.setup(randi() % 4, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 5)
		queue_free.call_deferred()

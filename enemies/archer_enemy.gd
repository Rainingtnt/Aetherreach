extends CharacterBody2D

# Archer — keeps medium range, fires 2-shot burst, strafes sideways

const SPEED          := 52.0
const PREFERRED_RANGE := 200.0
const SHOOT_INTERVAL  := 2.2
const BURST_GAP       := 0.18
const CONTACT_CD      := 1.0

var max_health := 3
var health     := 3
var damage     := 1
var player: Node2D = null
var shoot_t    := randf_range(0.8, 1.8)
var contact_t  := 0.0
var speed_mult := 1.0
var slow_timer := 0.0
var _anim_t    := randf() * TAU
var _strafe    := 1.0

const EnemyProjectile = preload("res://scripts/enemy_projectile.tscn")
const DeathBurst      = preload("res://effects/death_burst.tscn")
const FracturePickup  = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture    = preload("res://assets/sprites/enemy_archer.svg")

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
	# Randomize initial strafe direction
	_strafe = 1.0 if randf() > 0.5 else -1.0

func _process(delta: float) -> void:
	_anim_t += delta
	if _sprite != null:
		var wobble := sin(_anim_t * 2.2) * 0.012
		_sprite.scale = Vector2(0.44, 0.44 + wobble)
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
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	shoot_t -= delta
	contact_t -= delta

	var dist := global_position.distance_to(player.global_position)
	var dir  := (player.global_position - global_position).normalized()
	var perp := Vector2(-dir.y, dir.x) * _strafe

	# Maintain preferred range with lateral strafe
	if dist > PREFERRED_RANGE + 40:
		velocity = (dir + perp * 0.4).normalized() * SPEED * speed_mult
	elif dist < PREFERRED_RANGE - 40:
		velocity = (-dir + perp * 0.5).normalized() * SPEED * speed_mult
	else:
		velocity = perp * SPEED * speed_mult
		# Occasionally flip strafe direction
		if randf() < 0.008:
			_strafe *= -1.0
	move_and_slide()

	if dist < 24 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_CD
	if shoot_t <= 0.0:
		shoot_t = SHOOT_INTERVAL
		_burst_shoot()

func _burst_shoot() -> void:
	if player == null: return
	_shoot()
	await get_tree().create_timer(BURST_GAP).timeout
	if is_instance_valid(self) and is_inside_tree():
		_shoot()

func _shoot() -> void:
	if player == null or not is_inside_tree(): return
	var proj := EnemyProjectile.instantiate()
	var spread := randf_range(-0.06, 0.06)
	proj.direction = (player.global_position - global_position).normalized().rotated(spread)
	get_parent().call_deferred("add_child", proj)
	proj.global_position = global_position

func apply_slow(duration: float, mult: float = 0.35) -> void:
	speed_mult = mult
	slow_timer = duration

func heal(amount: int) -> void:
	health = mini(health + amount, max_health)

func take_damage(amount: int) -> void:
	health -= amount
	if _sprite != null:
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(_sprite): _sprite.modulate = Color.WHITE
		)
	if health <= 0:
		Juice.hit_stop(0.035)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.55, 0.75, 0.28)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.60:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.NATURE if randf() < 0.5 else FractureManager.Element.STORM, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 2)
		queue_free.call_deferred()

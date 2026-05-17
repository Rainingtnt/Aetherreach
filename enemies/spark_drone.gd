extends CharacterBody2D

# Spark Drone — Storm biome. Hovering construct that fires 3-way burst and teleports.

const SPEED        := 65.0
const RANGE        := 220.0
const SHOOT_CD     := 2.0
const TELE_CD      := 4.5
const CONTACT_CD   := 0.9

var health     := 2
var max_health := 2
var damage     := 1
var player: Node2D = null
var contact_t  := 0.0
var shoot_t    := randf_range(0.8, SHOOT_CD)
var tele_t     := randf_range(2.0, TELE_CD)
var _anim_t    := randf() * TAU
var _flash     := false
var speed_mult := 1.0
var slow_timer := 0.0

const EnemyProjectile = preload("res://scripts/enemy_projectile.tscn")
const DeathBurst      = preload("res://effects/death_burst.tscn")
const FracturePickup  = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture    = preload("res://assets/sprites/enemy_spark_drone.svg")

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
		# Spin the armor ring
		_sprite.rotation = _anim_t * 1.4
		var hover: float = sin(_anim_t * 3.0) * 0.016
		_sprite.scale = Vector2(0.44 + hover, 0.44 + hover)
		if _flash:
			_sprite.modulate = Color(2.0, 2.0, 0.5)
		elif slow_timer > 0:
			_sprite.modulate = Color(0.5, 0.7, 1.0)
		else:
			# Subtle electric pulse
			var buzz: float = sin(_anim_t * 18.0) * 0.1 + 0.9
			_sprite.modulate = Color(buzz, buzz, 1.2)

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	contact_t -= delta
	shoot_t   -= delta
	tele_t    -= delta

	var dist := global_position.distance_to(player.global_position)
	var dir  := (player.global_position - global_position).normalized()
	# Keep at preferred range
	if dist > RANGE + 40:
		velocity = dir * SPEED * speed_mult
	elif dist < RANGE - 40:
		velocity = -dir * SPEED * speed_mult
	else:
		# Strafe sideways
		velocity = Vector2(-dir.y, dir.x) * SPEED * speed_mult
	move_and_slide()

	if dist < 22 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_CD
	if shoot_t <= 0.0:
		shoot_t = SHOOT_CD
		_shoot_burst()
	if tele_t <= 0.0:
		tele_t = TELE_CD
		_teleport()

func _shoot_burst() -> void:
	if player == null or not is_inside_tree(): return
	var base_dir := (player.global_position - global_position).normalized()
	for i in 3:
		var angle := (i - 1) * 0.35
		var proj := EnemyProjectile.instantiate()
		proj.direction = base_dir.rotated(angle)
		get_parent().call_deferred("add_child", proj)
		proj.global_position = global_position

func _teleport() -> void:
	if not is_instance_valid(player): return
	_flash = true
	if _sprite: _sprite.modulate = Color(2.0, 2.0, 0.5)
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self): return
	var angle := randf() * TAU
	var dist  := randf_range(100.0, 200.0)
	global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	_flash = false

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
		burst.color = Color(0.80, 0.60, 1.0)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.55:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.STORM, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 4)
		queue_free.call_deferred()

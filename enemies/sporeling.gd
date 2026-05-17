extends CharacterBody2D

# Sporeling — Nature biome. Slow wanderer that releases spore clouds (AoE slow).

const SPEED        := 40.0
const CONTACT_CD   := 0.8
const SPORE_CD     := 3.2

var health     := 4
var max_health := 4
var damage     := 1
var player: Node2D = null
var contact_t  := 0.0
var spore_t    := randf_range(1.5, SPORE_CD)
var _anim_t    := randf() * TAU
var _puff_t    := 0.0
var speed_mult := 1.0
var slow_timer := 0.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_sporeling.svg")

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
	if _puff_t > 0:
		_puff_t -= delta
	if _sprite != null:
		var bob: float = sin(_anim_t * 2.8) * 0.016
		_sprite.scale = Vector2(0.44 + bob * 0.5, 0.44 + bob)
		_sprite.offset = Vector2(0, sin(_anim_t * 2.8) * 2.5)
		if slow_timer > 0:
			_sprite.modulate = Color(0.5, 0.7, 1.0)
		elif _puff_t > 0:
			_sprite.modulate = Color(0.8, 0.5, 1.0)
		else:
			_sprite.modulate = Color.WHITE
	queue_redraw()

func _draw() -> void:
	# Spore puff ring
	if _puff_t > 0:
		var r := (1.0 - _puff_t / 0.6) * 65.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(0.65, 0.35, 1.0, _puff_t / 0.6 * 0.45), 2.0)
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -26, 28, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-14, -26, 28.0 * pct, 3), Color(0.55, 0.90, 0.25))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	contact_t -= delta
	spore_t   -= delta

	velocity = (player.global_position - global_position).normalized() * SPEED * speed_mult
	move_and_slide()

	var dist := global_position.distance_to(player.global_position)
	if dist < 20 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_CD

	if spore_t <= 0.0:
		spore_t = SPORE_CD
		_release_spores()

func _release_spores() -> void:
	_puff_t = 0.6
	# Slow player and nearby enemies in radius 65
	var pl_list := get_tree().get_nodes_in_group("player")
	for p in pl_list:
		if (p as Node2D).global_position.distance_to(global_position) < 65 and "speed_mult" in p:
			p.speed_mult = 0.45
			get_tree().create_timer(2.2).timeout.connect(func():
				if is_instance_valid(p): p.speed_mult = 1.0
			)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.global_position.distance_to(global_position) < 65 and e.has_method("apply_slow"):
			e.apply_slow(1.5, 0.55)

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
		Juice.hit_stop(0.04)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.60, 0.30, 0.90)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.70:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.NATURE, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free.call_deferred()

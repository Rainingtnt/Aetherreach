extends CharacterBody2D

# Healer — flees player, leaf-crowned sprite, pulses heal ring to allies

const SPEED         := 55.0
const FLEE_RANGE    := 220.0
const HEAL_INTERVAL := 3.5
const HEAL_RANGE    := 160.0
const HEAL_AMOUNT   := 1

var max_health := 5
var health     := 5
var player: Node2D = null
var heal_t     := HEAL_INTERVAL * 0.5
var pulse_t    := 0.0
var speed_mult := 1.0
var slow_timer := 0.0
var _anim_t    := randf() * TAU

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_healer.svg")

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
		var wobble := sin(_anim_t * 2.0) * 0.014
		_sprite.scale  = Vector2(0.44, 0.44 + wobble)
		_sprite.offset = Vector2(0, sin(_anim_t * 2.0) * 2.0)
		if slow_timer > 0:
			_sprite.modulate = Color(0.5, 0.7, 1.0)
		else:
			_sprite.modulate = Color.WHITE
	if pulse_t > 0:
		pulse_t -= delta * 2.0
		pulse_t = max(0.0, pulse_t)
	queue_redraw()

func _draw() -> void:
	# Healing pulse ring
	if pulse_t > 0:
		draw_arc(Vector2.ZERO, (1.0 - pulse_t) * HEAL_RANGE, 0, TAU, 32,
			Color(0.18, 0.88, 0.32, pulse_t * 0.45), 2.5)
	# Health bar
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -28, 28, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-14, -28, 28.0 * pct, 3), Color(0.2, 0.9, 0.3))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	heal_t -= delta
	if heal_t <= 0:
		heal_t = HEAL_INTERVAL
		_pulse_heal()
	var dist := global_position.distance_to(player.global_position)
	var dir  := (global_position - player.global_position).normalized()
	velocity = (dir * SPEED * speed_mult) if dist < FLEE_RANGE else \
		velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)
	move_and_slide()

func _pulse_heal() -> void:
	pulse_t = 1.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self: continue
		if e.global_position.distance_to(global_position) <= HEAL_RANGE and e.has_method("heal"):
			e.heal(HEAL_AMOUNT)

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
		burst.color = Color(0.16, 0.78, 0.28)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.75:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.NATURE, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free.call_deferred()

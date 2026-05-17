extends CharacterBody2D

# Summoner — floats at long range, periodically spawns fast_enemies, must be priority target

const SPEED          := 32.0
const PREFERRED_RANGE := 280.0
const SUMMON_INTERVAL := 4.0
const MAX_MINIONS     := 3
const CONTACT_CD      := 1.2

var max_health := 4
var health     := 4
var player: Node2D = null
var summon_t   := 2.0
var contact_t  := 0.0
var speed_mult := 1.0
var slow_timer := 0.0
var _anim_t    := randf() * TAU
var _minion_count := 0

const FastEnemy      = preload("res://enemies/fast_enemy.tscn")
const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const EnemyTexture   = preload("res://assets/sprites/enemy_summoner.svg")

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
		# Hover bob
		_sprite.offset = Vector2(0, sin(_anim_t * 1.6) * 3.0)
		var wobble := sin(_anim_t * 1.6) * 0.014
		_sprite.scale = Vector2(0.44, 0.44 + wobble)
		if slow_timer > 0:
			_sprite.modulate = Color(0.5, 0.7, 1.0)
		else:
			# Pulse color when about to summon
			var pulse := maxf(0.0, 1.0 - summon_t / SUMMON_INTERVAL)
			_sprite.modulate = Color(1.0 + pulse * 0.4, 1.0 - pulse * 0.2, 1.0 + pulse * 0.2)
	queue_redraw()

func _draw() -> void:
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -32, 28, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-14, -32, 28.0 * pct, 3), Color(0.55, 0.28, 1.0))
	# Summoning charge ring (builds as timer counts down)
	if _minion_count < MAX_MINIONS:
		var charge := 1.0 - summon_t / SUMMON_INTERVAL
		if charge > 0.1:
			draw_arc(Vector2.ZERO, 22, -PI * 0.5, -PI * 0.5 + charge * TAU, 24,
				Color(0.70, 0.35, 1.0, 0.65), 2.0)

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	summon_t  -= delta
	contact_t -= delta

	var dist := global_position.distance_to(player.global_position)
	var dir  := (player.global_position - global_position).normalized()

	# Keep distance
	if dist > PREFERRED_RANGE + 50:
		velocity = dir * SPEED * speed_mult
	elif dist < PREFERRED_RANGE - 50:
		velocity = -dir * SPEED * speed_mult
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 3 * delta)
	move_and_slide()

	if dist < 26 and contact_t <= 0.0:
		player.take_damage(1)
		contact_t = CONTACT_CD
	if summon_t <= 0.0 and _minion_count < MAX_MINIONS:
		summon_t = SUMMON_INTERVAL
		_summon()

func _summon() -> void:
	if not is_inside_tree(): return
	var minion := FastEnemy.instantiate()
	minion.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-35, 35))
	get_parent().call_deferred("add_child", minion)
	_minion_count += 1
	minion.tree_exited.connect(func(): _minion_count = maxi(0, _minion_count - 1))

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
		burst.color = Color(0.60, 0.28, 1.0)
		get_parent().call_deferred("add_child", burst)
		if randf() < 0.80:
			var frac := FracturePickup.instantiate()
			frac.setup(FractureManager.Element.STORM, global_position)
			get_parent().call_deferred("add_child", frac)
		GameEvents.enemy_died.emit(global_position, 4)
		queue_free.call_deferred()

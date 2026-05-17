extends CharacterBody2D

# Melee Chaser — spiked aggressive silhouette with yellow eyes

const SPEED          := 55.0
const CONTACT_COOLDOWN := 0.8

var max_health := 3
var health     := 3
var damage     := 1
var player: Node2D = null
var contact_t  := 0.0
var hit_flash  := false
var speed_mult := 1.0
var slow_timer := 0.0
var _anim_t    := randf() * TAU

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _process(delta: float) -> void:
	_anim_t += delta
	queue_redraw()

func _draw() -> void:
	var wobble := sin(_anim_t * 2.6) * 1.4
	draw_set_transform(Vector2(0, wobble))
	var col := Color(0.88, 0.88, 1.0) if hit_flash else Color(0.85, 0.22, 0.22)
	if slow_timer > 0:
		col = col.lerp(Color(0.4, 0.7, 1.0), 0.5)
	var body := PackedVector2Array([
		Vector2(0, -16), Vector2(7, -8), Vector2(14, 0),
		Vector2(7, 7), Vector2(0, 12), Vector2(-7, 7),
		Vector2(-14, 0), Vector2(-7, -8),
	])
	draw_colored_polygon(body, col)
	# Eyes
	for sign_x in [-1, 1]:
		draw_circle(Vector2(sign_x * 5, -4), 3.2, Color(1.0, 0.82, 0.12))
		draw_circle(Vector2(sign_x * 5, -4), 1.5, Color(0.08, 0.04, 0.0))
	# Health bar
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-14, -24, 28, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-14, -24, 28.0 * pct, 3), Color(0.28, 1.0, 0.3))
	draw_set_transform(Vector2.ZERO)

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
	queue_redraw()

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	hit_flash = true
	queue_redraw()
	get_tree().create_timer(0.1).timeout.connect(func(): hit_flash = false; queue_redraw())
	if health <= 0:
		Juice.hit_stop(0.045)
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.88, 0.22, 0.22)
		get_parent().add_child(burst)
		if randf() < 0.65:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(FractureManager.Element.FIRE if randf() < 0.5 else FractureManager.Element.STORM, global_position)
		GameEvents.enemy_died.emit(global_position, 1)
		queue_free()

extends CharacterBody2D

# Cowardly. Flees player. Pulses to heal nearby allies. Kill first.

const SPEED         := 55.0
const FLEE_RANGE    := 220.0
const HEAL_INTERVAL := 3.5
const HEAL_RANGE    := 160.0
const HEAL_AMOUNT   := 1

var health     := 5
var max_health := 5
var player: Node2D = null
var heal_timer  := HEAL_INTERVAL * 0.5
var pulse_t     := 0.0   # 0 = no pulse, >0 = animating
var hit_flash   := false
var slow_timer  := 0.0
var speed_mult  := 1.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _draw() -> void:
	var col := Color(0.85, 1.0, 0.85) if hit_flash else Color(0.18, 0.78, 0.30)
	draw_circle(Vector2.ZERO, 13, col)
	draw_rect(Rect2(-2.5, -9, 5, 18), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(-9, -2.5, 18, 5), Color(1, 1, 1, 0.85))
	if pulse_t > 0:
		var ring_r := (1.0 - pulse_t) * HEAL_RANGE
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, Color(0.2, 0.9, 0.35, pulse_t * 0.5), 2.5)
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-13, -21, 26, 3), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-13, -21, 26.0 * pct, 3), Color(0.2, 0.9, 0.3))

func _process(delta: float) -> void:
	if pulse_t > 0:
		pulse_t -= delta * 2.0
		pulse_t = max(0.0, pulse_t)
		queue_redraw()

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			speed_mult = 1.0
	if player == null:
		return
	heal_timer -= delta
	if heal_timer <= 0:
		heal_timer = HEAL_INTERVAL
		_pulse_heal()

	var dist := global_position.distance_to(player.global_position)
	var dir  := (global_position - player.global_position).normalized()
	if dist < FLEE_RANGE:
		velocity = dir * SPEED * speed_mult
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED * 4 * delta)
	move_and_slide()

func _pulse_heal() -> void:
	pulse_t = 1.0
	queue_redraw()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self:
			continue
		if enemy.global_position.distance_to(global_position) <= HEAL_RANGE:
			if enemy.has_method("heal"):
				enemy.heal(HEAL_AMOUNT)

func apply_slow(duration: float) -> void:
	speed_mult = 0.35
	slow_timer = duration

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	queue_redraw()

func take_damage(amount: int) -> void:
	health -= amount
	hit_flash = true
	queue_redraw()
	get_tree().create_timer(0.1).timeout.connect(func(): hit_flash = false; queue_redraw())
	if health <= 0:
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.18, 0.78, 0.30)
		get_parent().add_child(burst)
		if randf() < 0.75:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(FractureManager.Element.NATURE, global_position)
		GameEvents.enemy_died.emit(global_position, 3)
		queue_free()

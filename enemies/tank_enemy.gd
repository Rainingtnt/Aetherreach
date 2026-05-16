extends CharacterBody2D

# Slow, massive, tanky. Pushes player. Telegraphs charge with a windup.

const SPEED_NORMAL    := 30.0
const SPEED_CHARGE    := 200.0
const CHARGE_COOLDOWN := 5.0
const CONTACT_COOLDOWN := 1.0

var health     := 14
var max_health := 14
var damage     := 2
var player: Node2D = null
var contact_timer  := 0.0
var charge_timer   := randf_range(2.0, 4.0)
var hit_flash      := false
var is_charging    := false
var windup_timer   := 0.0
var slow_timer     := 0.0
var speed_mult     := 1.0

const DeathBurst     = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]

func _draw() -> void:
	var col := Color(0.88, 0.88, 1.0) if hit_flash else Color(0.28, 0.28, 0.48)
	if windup_timer > 0:
		col = Color(1.0, 0.5, 0.1).lerp(col, windup_timer / 0.8)
	draw_rect(Rect2(-20, -20, 40, 40), col)
	draw_rect(Rect2(-20, -20, 40, 40), Color(0.5, 0.5, 0.85), false, 2.5)
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-20, -28, 40, 4), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-20, -28, 40.0 * pct, 4), Color(0.4, 0.4, 1.0))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			speed_mult = 1.0
	if player == null:
		return
	contact_timer -= delta
	charge_timer  -= delta

	if windup_timer > 0:
		windup_timer -= delta
		queue_redraw()
		velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
		if windup_timer <= 0:
			is_charging = true
		move_and_slide()
		return

	if is_charging:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * SPEED_CHARGE
		move_and_slide()
		if global_position.distance_to(player.global_position) < 32 and contact_timer <= 0.0:
			player.take_damage(damage)
			contact_timer = CONTACT_COOLDOWN
			is_charging = false
			charge_timer = CHARGE_COOLDOWN
		if velocity.length() < 10:
			is_charging = false
			charge_timer = CHARGE_COOLDOWN
		return

	if charge_timer <= 0:
		windup_timer = 0.8
		queue_redraw()
		return

	var dir := (player.global_position - global_position).normalized()
	velocity = dir * SPEED_NORMAL * speed_mult
	move_and_slide()
	if global_position.distance_to(player.global_position) < 32 and contact_timer <= 0.0:
		player.take_damage(damage)
		contact_timer = CONTACT_COOLDOWN

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
	get_tree().create_timer(0.12).timeout.connect(func(): hit_flash = false; queue_redraw())
	if health <= 0:
		var burst := DeathBurst.instantiate()
		burst.global_position = global_position
		burst.color = Color(0.28, 0.28, 0.48)
		get_parent().add_child(burst)
		if randf() < 0.9:
			var frac := FracturePickup.instantiate()
			get_parent().add_child(frac)
			frac.setup(randi() % 4, global_position)
		GameEvents.enemy_died.emit(global_position, 5)
		queue_free()

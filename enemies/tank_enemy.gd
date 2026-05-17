extends CharacterBody2D

# Tank — heavy armored square, telegraphed charge with orange windup glow

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
var hit_flash  := false
var is_charging := false
var speed_mult := 1.0
var slow_timer := 0.0

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
	if windup_t > 0:
		col = col.lerp(Color(1.0, 0.48, 0.08), 1.0 - windup_t / 0.8)
	# Armored plate body
	draw_rect(Rect2(-20, -22, 40, 44), col)
	draw_rect(Rect2(-20, -22, 40, 44), Color(0.48, 0.48, 0.85, 0.8), false, 2.5)
	# Armor grooves
	draw_line(Vector2(-20, -4), Vector2(20, -4), Color(0.38, 0.38, 0.68, 0.5), 1.5)
	draw_line(Vector2(-20, 10), Vector2(20, 10), Color(0.38, 0.38, 0.68, 0.5), 1.5)
	# Eye slit
	draw_rect(Rect2(-10, -16, 20, 5), Color(0.08, 0.06, 0.16))
	draw_rect(Rect2(-7, -15, 14, 3), Color(0.55, 0.55, 0.85, 0.8))
	if health < max_health:
		var pct := float(health) / float(max_health)
		draw_rect(Rect2(-20, -30, 40, 4), Color(0.12, 0.12, 0.12))
		draw_rect(Rect2(-20, -30, 40.0 * pct, 4), Color(0.4, 0.4, 1.0))

func _physics_process(delta: float) -> void:
	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0: speed_mult = 1.0
	if player == null: return
	contact_t -= delta
	charge_t  -= delta

	if windup_t > 0:
		windup_t -= delta
		queue_redraw()
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
		if velocity.length() < 8: # Hit wall
			is_charging = false
			charge_t    = CHARGE_CD
		return

	if charge_t <= 0:
		windup_t = 0.8
		queue_redraw()
		return

	velocity = (player.global_position - global_position).normalized() * SPEED_WALK * speed_mult
	move_and_slide()
	if global_position.distance_to(player.global_position) < 34 and contact_t <= 0.0:
		player.take_damage(damage)
		contact_t = CONTACT_CD

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
		Juice.hit_stop(0.07)
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

extends CharacterBody2D

const SPEED := 180.0
const ACCELERATION := 1200.0
const FRICTION := 900.0
const DASH_SPEED := 520.0
const DASH_DURATION := 0.15
const DASH_COOLDOWN := 0.6
const INVINCIBILITY_DURATION := 1.0

var max_health := 5
var health := 5
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO
var can_take_damage := true
var invincibility_timer := 0.0

var projectile_scene := preload("res://scripts/projectile.tscn")

func _ready() -> void:
	add_to_group("player")
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color.CYAN)
	if is_dashing:
		draw_circle(Vector2.ZERO, 18, Color(0.4, 1, 1, 0.3))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	_handle_invincibility(delta)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_handle_dash_timers(delta)
	if is_dashing:
		velocity = dash_direction * DASH_SPEED
	else:
		_handle_movement(delta)
		_try_dash()
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * SPEED, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _try_dash() -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		dash_direction = input_dir if input_dir != Vector2.ZERO else Vector2.RIGHT
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cooldown_timer = DASH_COOLDOWN

func _handle_dash_timers(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

func _handle_invincibility(delta: float) -> void:
	if invincibility_timer > 0.0:
		invincibility_timer -= delta
		modulate.a = 0.3 if fmod(invincibility_timer, 0.2) > 0.1 else 1.0
		if invincibility_timer <= 0.0:
			can_take_damage = true
			modulate.a = 1.0

func _shoot() -> void:
	var proj = projectile_scene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction = (get_global_mouse_position() - global_position).normalized()

func take_damage(amount: int) -> void:
	if not can_take_damage or is_dashing:
		return
	health -= amount
	can_take_damage = false
	invincibility_timer = INVINCIBILITY_DURATION
	if health <= 0:
		get_tree().reload_current_scene()

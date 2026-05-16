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
var regen_timer := 0.0
var trail_timer := 0.0

var cam_shake_amount := 0.0
var cam_shake_duration := 0.0

@onready var camera: Camera2D = $Camera2D
const ProjectileScene = preload("res://scripts/projectile.tscn")
const DashTrailScript = preload("res://effects/dash_trail.gd")

func _ready() -> void:
	add_to_group("player")
	GameEvents.player_hit.emit(health, max_health)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12, Color.CYAN)
	if is_dashing:
		draw_circle(Vector2.ZERO, 20, Color(0.4, 1.0, 1.0, 0.28))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	_handle_invincibility(delta)
	_handle_regen(delta)
	_update_camera_shake(delta)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_handle_dash_timers(delta)
	if is_dashing:
		velocity = dash_direction * DASH_SPEED
		trail_timer -= delta
		if trail_timer <= 0.0:
			_spawn_trail()
			trail_timer = 0.045
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
		trail_timer = 0.0

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

func _handle_regen(delta: float) -> void:
	var interval := FractureManager.get_nature_regen_interval()
	if interval <= 0.0 or health >= max_health:
		return
	regen_timer -= delta
	if regen_timer <= 0.0:
		regen_timer = interval
		health = min(health + 1, max_health)
		GameEvents.player_hit.emit(health, max_health)

func _update_camera_shake(delta: float) -> void:
	if cam_shake_duration > 0.0:
		cam_shake_duration -= delta
		camera.offset = Vector2(
			randf_range(-cam_shake_amount, cam_shake_amount),
			randf_range(-cam_shake_amount, cam_shake_amount)
		)
	else:
		camera.offset = Vector2.ZERO

func _spawn_trail() -> void:
	var trail := Node2D.new()
	trail.set_script(DashTrailScript)
	trail.global_position = global_position
	get_parent().add_child(trail)

func _shoot() -> void:
	var proj = ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction = (get_global_mouse_position() - global_position).normalized()

func take_damage(amount: int) -> void:
	if not can_take_damage or is_dashing:
		return
	health -= amount
	can_take_damage = false
	invincibility_timer = INVINCIBILITY_DURATION
	cam_shake_amount = 7.0
	cam_shake_duration = 0.22
	GameEvents.player_hit.emit(health, max_health)
	if health <= 0:
		GameEvents.player_died.emit()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

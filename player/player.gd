extends CharacterBody2D

const SPEED        := 180.0
const ACCELERATION := 1200.0
const FRICTION     := 900.0
const DASH_SPEED   := 520.0
const DASH_DURATION  := 0.15
const DASH_COOLDOWN  := 0.6
const INVINCIBILITY  := 1.0

var max_health  := 5
var health      := 5
var can_move    := true
var speed_mult  := 1.0
var is_dashing  := false
var dash_timer  := 0.0
var dash_cd     := 0.0
var dash_dir    := Vector2.ZERO
var inv_timer   := 0.0
var can_dmg     := true
var regen_t     := 0.0
var trail_t     := 0.0

var cam_shake_amt := 0.0
var cam_shake_dur := 0.0

@onready var camera: Camera2D = $Camera2D
const ProjectileScene = preload("res://scripts/projectile.tscn")
const DashTrailScript = preload("res://effects/dash_trail.gd")

func _ready() -> void:
	add_to_group("player")
	GameEvents.player_hit.emit(health, max_health)
	queue_redraw()

# ── Visual ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var mouse_dir := (get_global_mouse_position() - global_position).normalized()
	var fracs := FractureManager.active_fractures

	# Fracture aura rings
	for i in fracs.size():
		var fc: Color = FractureManager.ELEMENT_COLORS[fracs[i]] as Color
		draw_arc(Vector2.ZERO, 17 + i * 5, 0, TAU, 28, Color(fc.r, fc.g, fc.b, 0.22), 1.5)

	# Body — hooded drifter silhouette
	var body_col := _body_color()
	var dark_col := Color(body_col.r * 0.55, body_col.g * 0.50, body_col.b * 0.55)
	var body := PackedVector2Array([
		Vector2(-8, 12), Vector2(8, 12), Vector2(9, 5),
		Vector2(7, -4), Vector2(3, -10), Vector2(0, -14),
		Vector2(-3, -10), Vector2(-7, -4), Vector2(-9, 5),
	])
	draw_colored_polygon(body, body_col)

	# Hood shadow
	var hood := PackedVector2Array([
		Vector2(-5, -7), Vector2(0, -15), Vector2(5, -7)
	])
	draw_colored_polygon(hood, dark_col)

	# Scarf / elemental accessory strip
	if not fracs.is_empty():
		var sc: Color = FractureManager.ELEMENT_COLORS[fracs[fracs.size()-1]] as Color
		draw_rect(Rect2(-8, 2, 16, 3), Color(sc.r, sc.g, sc.b, 0.75))

	# Glowing fracture core
	var glow := _glow_color()
	draw_circle(Vector2(0, 2), 4, Color(glow.r, glow.g, glow.b, 0.55))
	draw_circle(Vector2(0, 2), 2.5, glow)

	# Aim arrow
	var tip  := mouse_dir * 21
	var perp := mouse_dir.rotated(PI * 0.5) * 4.5
	draw_colored_polygon(
		PackedVector2Array([tip, mouse_dir * 14 + perp, mouse_dir * 14 - perp]),
		Color(1, 1, 1, 0.65)
	)

	# Dash glow
	if is_dashing:
		draw_arc(Vector2.ZERO, 16, 0, TAU, 16, Color(0.45, 1.0, 1.0, 0.35), 2)

func _body_color() -> Color:
	var fracs := FractureManager.active_fractures
	var base := Color(0.52, 0.60, 0.72)
	if fracs.is_empty():
		return base
	var fc: Color = FractureManager.ELEMENT_COLORS[fracs[fracs.size()-1]] as Color
	return base.lerp(fc, 0.38)

func _glow_color() -> Color:
	var fracs := FractureManager.active_fractures
	if fracs.is_empty():
		return Color(0.75, 0.88, 1.0)
	return FractureManager.ELEMENT_COLORS[fracs[fracs.size()-1]] as Color

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not can_move:
		return
	if Input.is_action_just_pressed("shoot"):
		_shoot()
	_handle_inv(delta)
	_handle_regen(delta)
	_update_cam_shake(delta)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_tick_dash(delta)
	if is_dashing:
		velocity = dash_dir * DASH_SPEED
		trail_t -= delta
		if trail_t <= 0.0:
			_spawn_trail()
			trail_t = 0.045
	elif can_move:
		_move(delta)
		_try_dash()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()

func _move(delta: float) -> void:
	var inp := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if inp != Vector2.ZERO:
		velocity = velocity.move_toward(inp * SPEED * speed_mult, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

func _try_dash() -> void:
	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0:
		var inp := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		dash_dir = inp if inp != Vector2.ZERO else Vector2.RIGHT
		is_dashing = true
		dash_timer = DASH_DURATION
		dash_cd    = DASH_COOLDOWN
		trail_t    = 0.0

func _tick_dash(delta: float) -> void:
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	if dash_cd > 0.0:
		dash_cd -= delta

func _handle_inv(delta: float) -> void:
	if inv_timer > 0.0:
		inv_timer -= delta
		modulate.a = 0.28 if fmod(inv_timer, 0.2) > 0.1 else 1.0
		if inv_timer <= 0.0:
			can_dmg = true
			modulate.a = 1.0

func _handle_regen(delta: float) -> void:
	var interval := FractureManager.get_nature_regen_interval()
	if interval <= 0.0 or health >= max_health:
		return
	regen_t -= delta
	if regen_t <= 0.0:
		regen_t = interval
		health = min(health + 1, max_health)
		GameEvents.player_hit.emit(health, max_health)

func _update_cam_shake(delta: float) -> void:
	if cam_shake_dur > 0.0:
		cam_shake_dur -= delta
		camera.offset = Vector2(
			randf_range(-cam_shake_amt, cam_shake_amt),
			randf_range(-cam_shake_amt, cam_shake_amt)
		)
	else:
		camera.offset = Vector2.ZERO

func _spawn_trail() -> void:
	var t := Node2D.new()
	t.set_script(DashTrailScript)
	t.global_position = global_position
	get_parent().add_child(t)

func _shoot() -> void:
	var proj := ProjectileScene.instantiate()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.direction = (get_global_mouse_position() - global_position).normalized()

func take_damage(amount: int) -> void:
	if not can_dmg or is_dashing:
		return
	health -= amount
	can_dmg       = false
	inv_timer     = INVINCIBILITY
	cam_shake_amt = 8.0
	cam_shake_dur = 0.24
	Juice.screen_flash(camera)
	GameEvents.player_hit.emit(health, max_health)
	if health <= 0:
		GameEvents.player_died.emit()
		FractureManager.reset()
		RoomManager.reset()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

extends CharacterBody2D

# Princess Pyra — Emberwild Dominion
# Phase 1 (HP > 60%): Spread shots + ring attack
# Phase 2 (HP 30-60%): Faster, more shots, ember orbit
# Phase 3 (HP < 30%): Berserk, charge attacks

const MAX_HP     := 80
const SPEED_P    := [42.0, 72.0, 118.0]
const ATCK_CD    := [2.20, 1.55, 0.95]
const RING_CD    := [6.50, 5.00, 3.50]
const SPREAD_CNT := [3, 4, 6]
const CONTACT_CD := 0.7

var health  := MAX_HP
var phase   := 1
var _dying  := false
var _hit_flash   := false
var _ember_t     := 0.0
var _attack_t    := 2.0
var _ring_t      := 5.5
var _contact_t   := 0.0
var player: Node2D = null

const BossFireball = preload("res://scripts/boss_fireball.tscn")
const DeathBurst   = preload("res://effects/death_burst.tscn")

func _ready() -> void:
	add_to_group("enemies")
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]
	GameEvents.boss_hp_changed.emit(health, MAX_HP)
	queue_redraw()

# ── Visual ──────────────────────────────────────────────────────────────────
func _draw() -> void:
	var base := _phase_color()
	if _hit_flash:
		base = Color.WHITE
	var dark := Color(base.r * 0.5, base.g * 0.4, base.b * 0.4)

	# Ember orbit (phase 2+)
	if phase >= 2:
		var cnt := 4 + (phase - 2) * 3
		for i in cnt:
			var a := _ember_t * 1.8 + i * TAU / cnt
			var r := 32.0 + sin(_ember_t * 2.5 + i) * 5
			draw_circle(Vector2(cos(a), sin(a)) * r, 3.0, Color(1.0, 0.38, 0.0, 0.65))

	# Cloak / dress
	var cloak := PackedVector2Array([
		Vector2(-20, 34), Vector2(20, 34),
		Vector2(24, 12), Vector2(18, -8),
		Vector2(10, -22), Vector2(0, -30),
		Vector2(-10, -22), Vector2(-18, -8), Vector2(-24, 12),
	])
	draw_colored_polygon(cloak, base)

	# Shoulders / cape detail
	var cape := PackedVector2Array([
		Vector2(-22, 12), Vector2(-18, -6), Vector2(-10, -20),
		Vector2(0, -26), Vector2(10, -20), Vector2(18, -6), Vector2(22, 12),
	])
	draw_polyline(cape, Color(base.r * 0.7, base.g * 0.55, base.b * 0.5, 0.7), 1.5)

	# Head (shadowed hood)
	draw_circle(Vector2(0, -18), 11, dark)

	# Crown spikes
	var crown_y := -29.0
	for i in 5:
		var cx := -10.0 + i * 5.0
		var spike_h := 10.0 if i == 2 else (7.0 if i in [1, 3] else 5.0)
		draw_line(Vector2(cx, crown_y), Vector2(cx, crown_y - spike_h), Color(1.0, 0.65, 0.1), 2.0)
	draw_circle(Vector2(0, crown_y - 12), 4, Color(1.0, 0.28, 0.0))

	# Glowing eyes
	var eye_col := Color(1.0, 0.55, 0.0) if phase == 1 else \
	              (Color(1.0, 0.28, 0.0) if phase == 2 else Color(1.0, 0.08, 0.0))
	draw_circle(Vector2(-4.5, -19), 3.5, eye_col)
	draw_circle(Vector2( 4.5, -19), 3.5, eye_col)
	draw_circle(Vector2(-4.5, -19), 1.5, Color(0.08, 0.02, 0.0))
	draw_circle(Vector2( 4.5, -19), 1.5, Color(0.08, 0.02, 0.0))

	# Phase 3 berserk aura
	if phase == 3:
		draw_arc(Vector2.ZERO, 36, 0, TAU, 32, Color(1.0, 0.18, 0.0, 0.22), 3)

# ── Logic ────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_ember_t += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _dying or player == null:
		return
	_update_phase()
	_contact_t -= delta
	_attack_t  -= delta
	_ring_t    -= delta

	# Movement
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * (SPEED_P[phase - 1] as float)
	move_and_slide()

	# Contact damage
	if global_position.distance_to(player.global_position) < 32 and _contact_t <= 0.0:
		player.take_damage(2 + (phase - 1))
		_contact_t = CONTACT_CD

	# Spread attack
	if _attack_t <= 0.0:
		_attack_t = ATCK_CD[phase - 1] as float
		_spread_shot()

	# Ring attack
	if _ring_t <= 0.0:
		_ring_t = RING_CD[phase - 1] as float
		_ring_shot()

func _update_phase() -> void:
	var new_p := 1
	if health <= MAX_HP * 0.60: new_p = 2
	if health <= MAX_HP * 0.30: new_p = 3
	if new_p != phase:
		phase = new_p
		GameEvents.boss_hp_changed.emit(health, MAX_HP)

func _spread_shot() -> void:
	var cnt: int = SPREAD_CNT[phase - 1] as int
	var base_dir := (player.global_position - global_position).normalized()
	var step := deg_to_rad(22.0)
	var start := -step * float(cnt - 1) / 2.0
	for i in cnt:
		_fire(base_dir.rotated(start + i * step))

func _ring_shot() -> void:
	var cnt := 8 + (phase - 1) * 4
	for i in cnt:
		_fire(Vector2(1, 0).rotated(i * TAU / cnt))

func _fire(dir: Vector2) -> void:
	if not is_inside_tree():
		return
	var fb := BossFireball.instantiate()
	fb.direction = dir
	fb.global_position = global_position
	get_parent().add_child(fb)

# ── Damage / Death ───────────────────────────────────────────────────────────
func apply_slow(_d: float) -> void:
	pass  # Boss immune

func heal(_a: int) -> void:
	pass  # Boss not healable

func take_damage(amount: int) -> void:
	if _dying:
		return
	health -= amount
	_hit_flash = true
	GameEvents.boss_hp_changed.emit(health, MAX_HP)
	queue_redraw()
	Juice.hit_stop(0.04)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			_hit_flash = false
			queue_redraw()
	)
	if health <= 0:
		_dying = true
		_die()

func _phase_color() -> Color:
	match phase:
		1: return Color(0.82, 0.26, 0.10)
		2: return Color(1.00, 0.20, 0.04)
		3: return Color(1.00, 0.08, 0.00)
	return Color(0.82, 0.26, 0.10)

func _die() -> void:
	var parent := get_parent()
	var pos    := global_position
	for i in 7:
		var burst := DeathBurst.instantiate()
		burst.global_position = pos + Vector2(randf_range(-55, 55), randf_range(-55, 55))
		burst.color = Color(1.0, lerp(0.28, 0.72, float(i) / 6.0), 0.0)
		parent.add_child(burst)
	GameEvents.enemy_died.emit(pos, 20)
	GameEvents.boss_defeated.emit()
	queue_free()

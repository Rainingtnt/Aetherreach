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
var _ember_t     := 0.0
var _attack_t    := 2.0
var _ring_t      := 5.5
var _contact_t   := 0.0
var player: Node2D = null

const BossFireball  = preload("res://scripts/boss_fireball.tscn")
const DeathBurst    = preload("res://effects/death_burst.tscn")
const BossTexture   = preload("res://assets/sprites/boss_pyra.svg")

var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("enemies")
	_sprite = Sprite2D.new()
	_sprite.texture = BossTexture
	_sprite.scale   = Vector2(0.60, 0.60)
	add_child(_sprite)
	var pl := get_tree().get_nodes_in_group("player")
	if pl.size() > 0:
		player = pl[0]
	GameEvents.boss_hp_changed.emit(health, MAX_HP)

# ── Visual ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_ember_t += delta
	_update_sprite()
	queue_redraw()

func _update_sprite() -> void:
	if _sprite == null:
		return
	# Breathing scale
	var breathe := sin(_ember_t * 1.4) * 0.012
	_sprite.scale = Vector2(0.60 + breathe, 0.60 - breathe)
	# Phase tint
	match phase:
		1: _sprite.modulate = Color(1.0, 0.80, 0.70)
		2: _sprite.modulate = Color(1.0, 0.50, 0.30)
		3: _sprite.modulate = Color(1.0, 0.20, 0.10)

func _draw() -> void:
	# Ember orbit (phase 2+)
	if phase >= 2:
		var cnt := 4 + (phase - 2) * 3
		for i in cnt:
			var a := _ember_t * 1.8 + i * TAU / cnt
			var r := 46.0 + sin(_ember_t * 2.5 + i) * 5
			draw_circle(Vector2(cos(a), sin(a)) * r, 4.0, Color(1.0, 0.38, 0.0, 0.65))

	# Phase 3 berserk aura
	if phase == 3:
		draw_arc(Vector2.ZERO, 52, 0, TAU, 32, Color(1.0, 0.18, 0.0, 0.22), 3)

# ── Logic ────────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _dying or player == null:
		return
	_update_phase()
	_contact_t -= delta
	_attack_t  -= delta
	_ring_t    -= delta

	var dir := (player.global_position - global_position).normalized()
	velocity = dir * (SPEED_P[phase - 1] as float)
	move_and_slide()

	if global_position.distance_to(player.global_position) < 32 and _contact_t <= 0.0:
		player.take_damage(2 + (phase - 1))
		_contact_t = CONTACT_CD

	if _attack_t <= 0.0:
		_attack_t = ATCK_CD[phase - 1] as float
		_spread_shot()

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
	get_parent().call_deferred("add_child", fb)

# ── Damage / Death ───────────────────────────────────────────────────────────
func apply_slow(_d: float, _m: float = 0.35) -> void:
	pass  # Boss immune

func heal(_a: int) -> void:
	pass  # Boss not healable

func take_damage(amount: int) -> void:
	if _dying:
		return
	health -= amount
	GameEvents.boss_hp_changed.emit(health, MAX_HP)
	Juice.hit_stop(0.04)
	if _sprite != null:
		_sprite.modulate = Color(2.0, 2.0, 2.0)
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(self): _update_sprite()
		)
	if health <= 0:
		_dying = true
		_die()

func _die() -> void:
	var parent := get_parent()
	var pos    := global_position
	for i in 7:
		var burst := DeathBurst.instantiate()
		burst.global_position = pos + Vector2(randf_range(-55, 55), randf_range(-55, 55))
		burst.color = Color(1.0, lerp(0.28, 0.72, float(i) / 6.0), 0.0)
		parent.call_deferred("add_child", burst)
	GameEvents.enemy_died.emit(pos, 20)
	GameEvents.boss_defeated.emit()
	queue_free.call_deferred()

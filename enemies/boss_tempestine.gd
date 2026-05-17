extends CharacterBody2D

# Princess Tempestine — Tempest Expanse
# Phase 1 (HP > 60%): Homing lightning bolts + 4-way spread
# Phase 2 (HP 30-60%): Rapid lightning sweep, teleport on damage
# Phase 3 (HP < 30%): Full-room lightning, berserk teleport

const MAX_HP      := 100
const SPEED_P     := [45.0, 70.0, 120.0]
const ATCK_CD     := [2.00, 1.40, 0.85]
const SWEEP_CD    := [5.50, 4.00, 2.80]
const SPREAD_CNT  := [4, 5, 7]
const CONTACT_CD  := 0.65
const TELEPORT_CD := 3.0

var health  := MAX_HP
var phase   := 1
var _dying  := false
var _t           := 0.0
var _attack_t    := 1.8
var _sweep_t     := 4.0
var _tele_t      := 0.0
var _contact_t   := 0.0
var _flash_visible := true
var player: Node2D = null

const BossBolt    = preload("res://scripts/boss_bolt.tscn")
const DeathBurst  = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const BossTexture = preload("res://assets/sprites/boss_tempestine.svg")

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
	GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS TEMPESTINE")

func _process(delta: float) -> void:
	_t += delta
	_update_sprite()
	queue_redraw()

func _update_sprite() -> void:
	if _sprite == null: return
	# Electric flicker
	var flicker := sin(_t * 22.0) * 0.06
	_sprite.scale = Vector2(0.60 + flicker, 0.60 - flicker * 0.5)
	match phase:
		1: _sprite.modulate = Color(0.90, 0.85, 1.0)
		2: _sprite.modulate = Color(0.75, 0.60, 1.0)
		3: _sprite.modulate = Color(0.60, 0.40, 1.0)
	if not _flash_visible:
		_sprite.modulate.a = 0.0

func _draw() -> void:
	# Electric orbit rings
	if phase >= 2:
		var cnt := 4 + (phase - 2) * 3
		for i in cnt:
			var a := _t * 2.2 + i * TAU / cnt
			var r := 50.0
			var sp := Vector2(cos(a), sin(a)) * r
			draw_circle(sp, 3.0, Color(0.85, 0.75, 1.0, 0.70))
			# Arc to next spark
			var a2 := a + TAU / cnt
			draw_line(sp, Vector2(cos(a2), sin(a2)) * r, Color(0.70, 0.55, 1.0, 0.35), 0.8)
	if phase == 3:
		draw_arc(Vector2.ZERO, 56, 0, TAU, 32, Color(0.85, 0.75, 1.0, 0.22), 3)
		# Random lightning lines radiating outward
		if sin(_t * 15.0) > 0.85:
			for _i in 3:
				var a := randf() * TAU
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 50,
					Color(1.0, 1.0, 0.5, 0.45), 1.5)

func _physics_process(delta: float) -> void:
	if _dying or player == null: return
	_update_phase()
	_contact_t -= delta
	_attack_t  -= delta
	_sweep_t   -= delta
	if phase >= 2: _tele_t -= delta

	velocity = (player.global_position - global_position).normalized() * (SPEED_P[phase - 1] as float)
	move_and_slide()

	if global_position.distance_to(player.global_position) < 32 and _contact_t <= 0.0:
		player.take_damage(2 + (phase - 1))
		_contact_t = CONTACT_CD
	if _attack_t <= 0.0:
		_attack_t = ATCK_CD[phase - 1] as float
		_spread_shot()
	if _sweep_t <= 0.0:
		_sweep_t = SWEEP_CD[phase - 1] as float
		_lightning_sweep()
	if phase >= 2 and _tele_t <= 0.0:
		_tele_t = TELEPORT_CD
		_teleport()

const DIALOGUE := [
	"", "You cannot outrun the storm.", "I  AM  THE  STORM.",
]

func _update_phase() -> void:
	var new_p := 1
	if health <= MAX_HP * 0.60: new_p = 2
	if health <= MAX_HP * 0.30: new_p = 3
	if new_p != phase:
		phase = new_p
		GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS TEMPESTINE")
		if new_p - 1 < DIALOGUE.size() and DIALOGUE[new_p - 1] != "":
			GameEvents.boss_dialogue.emit(DIALOGUE[new_p - 1], Color(0.80, 0.65, 1.0))

func _spread_shot() -> void:
	var cnt: int = SPREAD_CNT[phase - 1] as int
	var base_dir := (player.global_position - global_position).normalized()
	var step := deg_to_rad(20.0)
	var start := -step * float(cnt - 1) / 2.0
	for i in cnt:
		_fire(base_dir.rotated(start + i * step))

func _lightning_sweep() -> void:
	# Rapid-fire bolts in a sweep arc
	var cnt := 12 + (phase - 1) * 4
	for i in cnt:
		_fire(Vector2(1, 0).rotated(i * TAU / cnt))

func _fire(dir: Vector2) -> void:
	if not is_inside_tree(): return
	var fb := BossBolt.instantiate()
	fb.direction = dir
	fb.global_position = global_position
	get_parent().call_deferred("add_child", fb)

func _teleport() -> void:
	if not is_instance_valid(player): return
	_flash_visible = false
	_update_sprite()
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or _dying: return
	# Teleport to a position near player but not on top
	var angle := randf() * TAU
	var dist  := randf_range(120, 220)
	global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist
	_flash_visible = true
	_update_sprite()

func apply_slow(_d: float, _m: float = 0.35) -> void: pass
func heal(_a: int) -> void: pass

func take_damage(amount: int) -> void:
	if _dying: return
	health -= amount
	GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS TEMPESTINE")
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
		burst.color = Color(0.75, 0.55, 1.0)
		parent.call_deferred("add_child", burst)
	if randf() < 0.85:
		var frac := FracturePickup.instantiate()
		frac.setup(FractureManager.Element.STORM, pos)
		parent.call_deferred("add_child", frac)
	GameEvents.enemy_died.emit(pos, 28)
	GameEvents.boss_defeated.emit()
	queue_free.call_deferred()

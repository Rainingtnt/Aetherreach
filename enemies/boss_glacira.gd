extends CharacterBody2D

# Princess Glacira — Glacia Cathedral
# Phase 1 (HP > 60%): Ice shard 3-way + frost nova every 7s
# Phase 2 (HP 30-60%): 5-way shards, ice beam sweep, faster
# Phase 3 (HP < 30%): Berserk 6-way, drops frost zones

const MAX_HP      := 90
const SPEED_P     := [38.0, 62.0, 105.0]
const ATCK_CD     := [2.40, 1.70, 1.05]
const NOVA_CD     := [7.00, 5.20, 3.50]
const SPREAD_CNT  := [3, 5, 6]
const CONTACT_CD  := 0.7

var health  := MAX_HP
var phase   := 1
var _dying  := false
var _ember_t     := 0.0
var _attack_t    := 2.2
var _nova_t      := 5.5
var _contact_t   := 0.0
var _frost_t     := 0.0
var player: Node2D = null

const BossIcebolt = preload("res://scripts/boss_icebolt.tscn")
const DeathBurst  = preload("res://effects/death_burst.tscn")
const FracturePickup = preload("res://scripts/fracture_pickup.tscn")
const BossTexture = preload("res://assets/sprites/boss_glacira.svg")

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
	GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS GLACIRA")

func _process(delta: float) -> void:
	_ember_t += delta
	_update_sprite()
	queue_redraw()

func _update_sprite() -> void:
	if _sprite == null: return
	var breathe := sin(_ember_t * 1.2) * 0.010
	_sprite.scale = Vector2(0.60 + breathe, 0.60 - breathe)
	match phase:
		1: _sprite.modulate = Color(0.85, 0.95, 1.0)
		2: _sprite.modulate = Color(0.65, 0.85, 1.0)
		3: _sprite.modulate = Color(0.45, 0.70, 1.0)

func _draw() -> void:
	# Ice crystal orbit (phase 2+)
	if phase >= 2:
		var cnt := 3 + (phase - 2) * 2
		for i in cnt:
			var a := _ember_t * 1.4 + i * TAU / cnt
			var r := 48.0 + sin(_ember_t * 2.0 + i) * 4
			var shard := Vector2(cos(a), sin(a)) * r
			draw_colored_polygon(PackedVector2Array([
				shard, shard + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 4,
				shard - Vector2(cos(a), sin(a)) * 8,
				shard + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * 4,
			]), Color(0.55, 0.85, 1.0, 0.70))
	# Phase 3 blizzard aura
	if phase == 3:
		draw_arc(Vector2.ZERO, 55, 0, TAU, 32, Color(0.55, 0.85, 1.0, 0.20), 3)

func _physics_process(delta: float) -> void:
	if _dying or player == null: return
	_update_phase()
	_contact_t -= delta
	_attack_t  -= delta
	_nova_t    -= delta
	_frost_t   -= delta

	velocity = (player.global_position - global_position).normalized() * (SPEED_P[phase - 1] as float)
	move_and_slide()

	if global_position.distance_to(player.global_position) < 32 and _contact_t <= 0.0:
		player.take_damage(2 + (phase - 1))
		_contact_t = CONTACT_CD
	if _attack_t <= 0.0:
		_attack_t = ATCK_CD[phase - 1] as float
		_spread_shot()
	if _nova_t <= 0.0:
		_nova_t = NOVA_CD[phase - 1] as float
		_nova_shot()
	# Phase 3: drop frost zones
	if phase == 3 and _frost_t <= 0.0:
		_frost_t = 3.5
		_drop_frost_zone()

func _update_phase() -> void:
	var new_p := 1
	if health <= MAX_HP * 0.60: new_p = 2
	if health <= MAX_HP * 0.30: new_p = 3
	if new_p != phase:
		phase = new_p
		GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS GLACIRA")

func _spread_shot() -> void:
	var cnt: int = SPREAD_CNT[phase - 1] as int
	var base_dir := (player.global_position - global_position).normalized()
	var step := deg_to_rad(24.0)
	var start := -step * float(cnt - 1) / 2.0
	for i in cnt:
		_fire(base_dir.rotated(start + i * step))

func _nova_shot() -> void:
	var cnt := 8 + (phase - 1) * 3
	for i in cnt:
		_fire(Vector2(1, 0).rotated(i * TAU / cnt))

func _fire(dir: Vector2) -> void:
	if not is_inside_tree(): return
	var fb := BossIcebolt.instantiate()
	fb.direction = dir
	fb.global_position = global_position
	get_parent().call_deferred("add_child", fb)

func _drop_frost_zone() -> void:
	if not is_instance_valid(player): return
	var zone := Area2D.new()
	var zcs  := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 45.0
	zcs.shape = circ
	zone.global_position = player.global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40))
	zone.add_child(zcs)
	get_parent().call_deferred("add_child", zone)
	zone.body_entered.connect(func(b: Node2D):
		if "speed_mult" in b: b.speed_mult = 0.35
	)
	zone.body_exited.connect(func(b: Node2D):
		if "speed_mult" in b: b.speed_mult = 1.0
	)
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(zone): zone.queue_free()
	)

func apply_slow(_d: float, _m: float = 0.35) -> void: pass
func heal(_a: int) -> void: pass

func take_damage(amount: int) -> void:
	if _dying: return
	health -= amount
	GameEvents.boss_hp_changed.emit(health, MAX_HP, "PRINCESS GLACIRA")
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
		burst.color = Color(0.45, 0.78, 1.0)
		parent.call_deferred("add_child", burst)
	if randf() < 0.85:
		var frac := FracturePickup.instantiate()
		frac.setup(FractureManager.Element.FROST, pos)
		parent.call_deferred("add_child", frac)
	GameEvents.enemy_died.emit(pos, 22)
	GameEvents.boss_defeated.emit()
	queue_free.call_deferred()
